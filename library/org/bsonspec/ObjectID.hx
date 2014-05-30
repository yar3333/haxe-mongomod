package org.bsonspec;

import haxe.io.Input;
import haxe.io.Bytes;
import haxe.io.BytesOutput;

class ObjectID
{
	static var pid = Std.random(65536);
	
	static var sequence = 0;
	
#if (neko || php || cpp)
	static var machine:Bytes = Bytes.ofString(sys.net.Host.localhost());
#else
	static var machine:Bytes = Bytes.ofString("flash");
#end
	
	public var bytes(default, null):Bytes;
	
	public function new(?input:Input)
	{
		if (input == null)
		{
			// generate a new id
			var out:BytesOutput = new BytesOutput();
#if haxe3
			out.writeInt32(Math.floor(Date.now().getTime() / 1000)); // seconds
#else
			out.writeInt32(haxe.Int32.ofInt(Math.floor(Date.now().getTime() / 1000))); // seconds
#end
			out.writeBytes(machine, 0, 3);
			out.writeUInt16(pid);
			out.writeUInt24(sequence++);
			if (sequence > 0xFFFFFF) sequence = 0;
			bytes = out.getBytes();
		}
		else
		{
			bytes = input.read(12);
		}
	}

	public function toString():String
	{
		return 'ObjectID("' + bytes.toHex() + '")';
	}
	
	public static function fromString(s:String) : ObjectID
	{
		var r = new ObjectID();
		var i = 0; while (i < s.length)
		{
			r.bytes.set(i >> 1, Std.parseInt("0x" + s.substr(i, 2)));
			i += 2;
		}
		return r;
	}
}