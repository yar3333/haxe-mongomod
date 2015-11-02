package org.mongodb;

import haxe.Int64;
import haxe.EnumFlags;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.io.Output;
import haxe.io.Input;
import org.bsonspec.BSON;
import org.bsonspec.BSONDocument;
import org.bsonspec.ObjectID;

#if flash
import flash.net.Socket;
import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.SecurityErrorEvent;
#else
import sys.net.Socket;
import sys.net.Host;
#end

enum ReplyFlags
{
	CursorNotFound;
	QueryFailure;
	ShardConfigStale;
	AwaitCapable;
}

class Protocol
{
	private static inline var OP_REPLY        = 1; // used by server
	private static inline var OP_MSG          = 1000; // not used
	private static inline var OP_UPDATE       = 2001;
	private static inline var OP_INSERT       = 2002;
	private static inline var OP_QUERY        = 2004;
	private static inline var OP_GETMORE      = 2005;
	private static inline var OP_DELETE       = 2006;
	private static inline var OP_KILL_CURSORS = 2007;
	
	private var socket : Socket;
	private var requestId = 0;
	
	public function new(host="localhost", port=27017)
	{
		socket = new Socket();
#if flash
		socket.connect(host, port);
		socket.endian = flash.utils.Endian.LITTLE_ENDIAN;
		
		socket.addEventListener(IOErrorEvent.IO_ERROR, function(e:Event) trace(e), false, 0, true);
		socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function(e:Event) trace(e), false, 0, true);
#else
		socket.connect(new Host(host), port);
#end
	}
	
	public function close()
	{
		socket.close();
	}
	
	public inline function query(collection:String, ?query:Dynamic, ?returnFields:Dynamic, skip=0, number=0, flags=0)
	{
		var out:BytesOutput = new BytesOutput();
		writeInt32(out, flags);
		out.writeString(collection);
		out.writeByte(0x00); // string terminator
		writeInt32(out, skip);
		writeInt32(out, number);
		
		if (query == null) query = {};
		writeDocument(out, query);
		
		if (returnFields != null)
		{
			writeDocument(out, returnFields);
		}
		
		request(OP_QUERY, out.getBytes());
	}

	public inline function getMore(collection:String, cursorId:Int64, number:Int = 0)
	{
		var out:BytesOutput = new BytesOutput();
		writeInt32(out, 0); // reserved
		out.writeString(collection);
		out.writeByte(0x00); // string terminator
		writeInt32(out, number);
		
		// write Int64
		out.writeInt32(cursorId.high);
		out.writeInt32(cursorId.low);
		
		request(OP_GETMORE, out.getBytes());
	}

	public function insert(collection:String, fields:Dynamic)
	{
		var out:BytesOutput = new BytesOutput();
		writeInt32(out, 0); // TODO: flags
		out.writeString(collection);
		out.writeByte(0x00); // string terminator
		
		// check for _id field, generate if it doesn't exist
		function writeField(field)
		{
			if (!Reflect.hasField(field, '_id'))
			{
				if (!Std.is(field, BSONDocument))
				{
					field._id = new ObjectID();
				}
				else
				if (!Lambda.exists( { iterator:cast(field, BSONDocument).nodes }, function(node) return node.key == "_id"))
				{
					cast(field, BSONDocument).append("_id", new ObjectID());
				}
			}
			writeDocument(out, field);
		};
		
		// write multiple documents, if an array
		if (Std.is(fields, Array))
		{
			var list = cast(fields, Array<Dynamic>);
			for (field in list)
			{
				writeField(field);
			}
		}
		else
		{
			writeField(fields);
		}
		
		// write request
		request(OP_INSERT, out.getBytes());
	}
	
	public inline function update(collection:String, select:Dynamic, fields:Dynamic, flags:Int)
	{
		var out:BytesOutput = new BytesOutput();
		writeInt32(out, 0); // reserved
		out.writeString(collection);
		out.writeByte(0x00); // string terminator
		writeInt32(out, flags);
		
		writeDocument(out, select);
		writeDocument(out, fields);
		
		// write request
		request(OP_UPDATE, out.getBytes());
	}

	public inline function remove(collection:String, ?select:Dynamic)
	{
		var out:BytesOutput = new BytesOutput();
		writeInt32(out, 0); // reserved
		out.writeString(collection);
		out.writeByte(0x00); // string terminator
		writeInt32(out, 0); // TODO: flags
		
		writeDocument(out, select != null ? select : {});
		
		request(OP_DELETE, out.getBytes());
	}

	public inline function killCursors(cursors:Array<Int64>)
	{
		var out:BytesOutput = new BytesOutput();
		writeInt32(out, 0); // reserved
		writeInt32(out, cursors.length); // num of cursors
		for (cursor in cursors)
		{
			out.writeInt32(cursor.high);
			out.writeInt32(cursor.low);
		}
		
		request(OP_KILL_CURSORS, out.getBytes());
	}

	public inline function getOne():Dynamic
	{
		var details = read();
		
		if (details.numReturned == 1)
			return BSON.decode(details.input);
		else
			return null;
	}

	public inline function response(documents:Array<Dynamic>):Int64
	{
		var details = read();
		
		for (i in 0...details.numReturned)
		{
			documents.push(BSON.decode(details.input));
		}
		return details.cursorId;
	}

	private function read():Dynamic
	{
		var length:Int = 0, input:Input = null;
		
#if flash
		var bytes = new flash.utils.ByteArray();
		try {
			length = socket.readInt();
		} catch(e:Dynamic) {
			return { numReturned: 0 };
		}
		socket.readBytes(bytes, 0, length);
		input = new haxe.io.BytesInput(Bytes.ofData(bytes), 0, length);
#else
		length = readInt32(socket.input);
		input = socket.input;
#end
		
		var details = {
//			length:       input.readInt32(), // length
			length:       length,
			input:        input,
			requestId:    input.readInt32(), // request id
			responseTo:   input.readInt32(), // response to
			opcode:       input.readInt32(), // opcode
			flags:        readInt32(input), // flags
			cursorId:     readInt64(input),
			startingFrom: input.readInt32(),
			numReturned:  readInt32(input)
		};
		
		var flags:EnumFlags<ReplyFlags> = EnumFlags.ofInt(details.flags);
		if (flags.has(CursorNotFound) && details.numReturned != 0)
		{
			throw "Cursor not found";
		}
		if (flags.has(QueryFailure))
		{
			trace(BSON.decode(input));
			throw "Query failed";
		}
		
		return details;
	}
	
	private inline function readInt64(input:Input):Int64
	{
		var high = input.readInt32();
		var low = input.readInt32();
		return Int64.make(high, low);
	}
	
	private inline function request(opcode:Int, data:Bytes, ?responseTo:Int = 0):Int
	{
		if (socket == null)
		{
			throw "Not connected";
		}
		var out = new BytesOutput();
		writeInt32(out, data.length + 16); // include header length
		writeInt32(out, requestId);
		writeInt32(out, responseTo);
		writeInt32(out, opcode);
		out.writeBytes(data, 0, data.length);

		var bytes = out.getBytes();
#if flash
		socket.writeBytes(bytes.getData());
		socket.flush();
#else
		socket.output.writeBytes(bytes, 0, bytes.length);
		socket.output.flush();
#end
		return requestId++;
	}
	
	private inline function writeDocument(out:BytesOutput, data:Dynamic)
	{
		var d = BSON.encode(data);
		out.writeBytes(d, 0, d.length);
	}
	
	// Int32 compatibility for Haxe 2.x
#if haxe3
	private inline function writeInt32(out:Output, value:Int)
	{
		out.writeInt32(value);
	}
	private inline function readInt32(input:Input):Int
	{
		return input.readInt32();
	}
#else
	private inline function writeInt32(out:Output, value:Int)
	{
		out.writeInt32(haxe.Int32.ofInt(value));
	}
	private inline function readInt32(input:Input):Int
	{
		return haxe.Int32.toNativeInt(input.readInt32());
	}
#end
}