package org.mongodb;

import haxe.Int64;

class Cursor
{
	/**
	 * Tailable means cursor is not closed when the last data is retrieved. Rather, the cursor marks the final object’s position. You can resume using the cursor later, from where it was located, if more data were received. Like any “latent cursor”, the cursor may become invalid at some point (CursorNotFound) – for example if the final object it references were deleted.
	 */
	public static inline var TailableCursor = 2;
	/**
	 * Allow query of replica slave. Normally these return an error except for namespace “local”.
	 */
	public static inline var SlaveOk = 4;
	/**
	 * Internal replication use only - driver should not set
	 */
	public static inline var OplogReplay = 8;
	/**
	 * The server normally times out idle cursors after an inactivity period (10 minutes) to prevent excess memory use. Set this option to prevent that.
	 */
	public static inline var NoCursorTimeout = 16;
	/**
	 * Use with TailableCursor. If we are at the end of the data, block for a while rather than returning no data. After a timeout period, we do return as normal.
	 */
	public static inline var AwaitData = 32;
	/**
	 * Stream the data down full blast in multiple “more” packages, on the assumption that the client will fully read all data queried. Faster when you are pulling a lot of data and know you want to pull it all down. Note: the client is not allowed to not read all the data unless it closes the connection.
	 */
	public static inline var Exhaust = 64;
	/**
	 * Get partial results from a mongos if some shards are down (instead of throwing an error)
	 */
	public static inline var Partial = 128;
	
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
			if (cursorId != cast null)
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