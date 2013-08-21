package ;

class Main
{
    static function main()
	{
		var r = new haxe.unit.TestRunner();
		r.add(new BSONTest());
		r.add(new MongoTest());
		r.run();
	}
}
