package org.mongodb;

import org.bsonspec.BSONDocument;

class Collection
{
	var protocol : Protocol;
	
	public var fullname(default, null) : String;
	public var name(default, null) : String;
	public var db : Database;
	
	public function new(protocol:Protocol, name:String, db:Database)
	{
		this.protocol = protocol;
		this.name = name;
		this.fullname = db.name + "." + name;
		this.db = db;
	}

	/**
	 * @param	query			Query object.
	 * @param	returnFields	Projection object.
	 * @param	skip			Number of the records to skip.
	 * @param	number			Number of the record to return by mongo at first (inner optimization). Use negative values to limit total count of the returned records. Also, mongo treat 1 as -1.
	 */
	public inline function find(?query:Dynamic, ?returnFields:Dynamic, skip=0, number=0, flags=0) : Cursor
	{
		protocol.query(fullname, query, returnFields, skip, number, flags);
		return new Cursor(protocol, fullname);
	}

	public inline function findOne(?query:Dynamic, ?returnFields:Dynamic):Dynamic
	{
		protocol.query(fullname, query, returnFields, 0, -1);
		return protocol.getOne();
	}

	public inline function insert(fields:Dynamic)
	{
		protocol.insert(fullname, fields);
	}

	public inline function update(select:Dynamic, fields:Dynamic, ?upsert:Bool, ?multi:Bool)
	{
		var flags = 0x0 | (upsert ? 0x1 : 0) | (multi ? 0x2 : 0);
		protocol.update(fullname, select, fields, flags);
	}

	public inline function remove(?select:Dynamic)
	{
		protocol.remove(fullname, select);
	}

	public inline function create() db.createCollection(name);
	public inline function drop() db.dropCollection(name);
	public inline function rename(to:String) db.renameCollection(name, to);

	public function getIndexes() : Cursor
	{
		protocol.query(db.name + ".system.indexes", {ns: fullname});
		return new Cursor(protocol, fullname);
	}

	public function ensureIndex(keyPattern:Dynamic, ?options:Dynamic)
	{
		// TODO: remove when name is deprecated
		var nameList = new List<String>();
		for (field in Reflect.fields(keyPattern))
		{
			nameList.add(field + "_" + Reflect.field(keyPattern, field));
		}
		var name = nameList.join("_");

		if (options == null)
		{
			options = { name: name, ns: fullname, key: keyPattern };
		}
		else
		{
			Reflect.setField(options, "name", name);
			Reflect.setField(options, "ns", fullname);
			Reflect.setField(options, "key", keyPattern);
		}

		protocol.insert(db.name + ".system.indexes", options);
	}

	public function dropIndexes()
	{
		db.runCommand({dropIndexes: name, index: '*'});
	}

	public function dropIndex(nameOrPattern:Dynamic)
	{
		db.runCommand({dropIndexes: name, index: nameOrPattern});
	}

	public function reIndex()
	{
		db.runCommand({reIndex: name});
	}

	public inline function count():Int
	{
		var result = db.runCommand({count: name});
		return result.n;
	}

	public inline function distinct(key:String, ?query:Dynamic):Array<Dynamic>
	{
		var cmd = BSONDocument.create();
		cmd.append("distinct", name);
		cmd.append("key", key);
		if (query != null) cmd.append("query", query);
		
		var result = db.runCommand(cmd);
		return result.values;
	}
}