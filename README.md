# IGOR

Igor is a dedicated assistant for helping to bring your database to life!

[ShareJS](http://sharejs.org) and hence [Derby.js](http://derbyjs.com) use the distributed real-time database
[livedb](https://github.com/share/LiveDB) which uses a Redis journal to power its real-time magic.  

This means the data you most likely already have in Mongo needs to be initialized in Redis. To help
with this we created the *itsalive* script.



```
npm install

// It`s Alive
// turn database to livedb 0.2 database
coffee itsalive.coffee --host 127.0.0.1 --port 27017 --db project --user myuser --pass mypass --rhost 127.0.0.1 --rport 6379 --rdb 2
// or
coffee itsalive.coffee --url myuser:mypass@localhost:27017/project --rhost localhost --rport 6379 --rdb 2

// Migrate Oplog
// migrate from livedb 0.1 to livedb 0.2
coffee migrate-oplog.coffee --host 127.0.0.1 --port 27017 --db project --user myuser --pass mypass --rhost 127.0.0.1 --rport 6379 --rdb 2
// or
coffee migrate-oplog.coffee --url myuser:mypass@localhost:27017/project --rhost localhost --rport 6379 --rdb 2
```

Options itsalive:
* -b: Allow user to process operation in batches of specified number, in case their data is too large

Options migrate-oplog:
* -d: Delete operations from Redis (default: no)


Mongo options:
* --url: Mongo Url (it will overwrite other Mongo options)
* --host: host (default: localhost)
* --port: port (default: 27017)
* --db: database (default: test)
* --user: user
* --pass: password

Redis options:
* --rhost: host (default: localhost)
* --rport: port (default: 6379)
* --rdb: database (default: 1)