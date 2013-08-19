package org.mongodb;

import haxe.Int64;

class Cursor
{
	var protocol : Protocol;
	var collection : String;
	var cursorId : Int64;
	var documents : Array<Dynamic>;
	var finished : Bool;
	
	public function new(protocol:Protocol, collection:String)
	{
		this.protocol = protocol;
		this.collection = collection;
		this.finished = false;
		this.documents = new Array<Dynamic>();

		checkResponse();
	}

	private inline function checkResponse():Bool
	{
		cursorId = protocol.response(documents);
		if (documents.length == 0)
		{
			finished = true;
			if (cursorId != null)
			{
				protocol.killCursors([cursorId]);
			}
			return false;
		}
		else
		{
			return true;
		}
	}

	public function hasNext():Bool
	{
		// we've depleted the cursor
		if (finished) return false;

		if (documents.length > 0)
		{
			return true;
		}
		else
		{
			protocol.getMore(collection, cursorId);
			if (checkResponse())
			{
				return true;
			}
		}
		return false;
	}

	public function next():Dynamic
	{
		return documents.shift();
	}
}