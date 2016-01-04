MongoDB driver for Haxe
====================================

Pure-haxe driver for MongoDB for sys targets. Based on https://github.com/MattTuttle/mongo-haxe-driver project.

Improvements (compared to base project):

 * production-ready (used by russian social network [http://vkrugudruzei.ru/](http://vkrugudruzei.ru/));
 * major refactored to avoid static methods (now support many connections to mongo instances);
 * Int64 always threated as Float (this prevent bugs when type hiddenly changed on records editing/importing/exporting);
 * support Date type;
 * several major bugfixes.

Find all objects in a collection
------------------------------------
Finding rows in a relational database can be a daunting process. Thankfully with Mongo it's just like accessing a regular Haxe object instance.

```haxe
import org.mongodb.Mongo;
...
var mongo = new Mongo("localhost", 27017);
for (post in mongo.blog.find())
{
	trace(post.title); // assumes that all posts have a title
}
```

Inserting and updating
------------------------------------
```haxe
import org.mongodb.Mongo;
...
var mongo = new Mongo("localhost", 27017);
var post = {
	title: 'My awesome post',
	body: 'MongoDB is easy as pie'
};
mongo.blog.posts.insert(post);

post.body = 'Made some updates to my post';
mongo.blog.posts.update({title: post.title}, post); // update the post
```