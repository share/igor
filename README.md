# IGOR

Igor is a dedicated assistant for helping to bring your database to life!

[ShareJS](http://sharejs.org) and hence [Derby.js](http://derbyjs.com) use the distributed real-time database
[livedb](https://github.com/share/LiveDB) which uses a Redis journal to power its real-time magic.  

This means the data you most likely already have in Mongo needs to be initialized in Redis. To help
with this we created the *itsalive* script.


## It's Alive

```
npm install
coffee itsalive.coffee -r 1 --db project
```

* -r: this will select the redis database you want to use
* --db: this will choose the mongo database you want to bring to life. it will run against all collections in the database automatically.
