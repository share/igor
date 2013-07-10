# Turn a mongo db into a live-db
# you should probably redis-cli flushdb; before running this script

async = require 'async'
redis = require 'redis'
mongo = require 'mongoskin'
argv = require('optimist').argv

mongo_host = process.env.MONGO_HOST or 'localhost'
mongo_port = process.env.MONGO_PORT or 27017
mongo_db   = argv.db or process.env.MONGO_DB or 'test'
db         = mongo.db "#{mongo_host}:#{mongo_port}/#{mongo_db}?auto_reconnect", {native_parser:true}
# Regarding batchSize & {native_parser:true}, see https://github.com/mongodb/node-mongodb-native/issues/593

if process.env.REDIS_PORT and process.env.REDIS_HOST
  rc = redis.createClient(process.env.REDIS_PORT, process.env.REDIS_HOST)
else
  rc = redis.createClient()

if process.env.REDIS_AUTH
  rc.auth(process.env.REDIS_AUTH)

rc.select argv.r ? 1

# Allow user to process operation in batches of specified number, in case their data is too large for .toArray()
batch = argv.b

#don't need to make these collections live
blacklist = ['system.indexes', 'system.users', 'configs']

ottypes = require('ottypes')
jsonType = ottypes.json0.uri

rc.on 'error', (err) ->
  console.error("redis error", err)

db.collections (err, collections) ->
  names = []
  collections.forEach (c) ->
    names.push c.collectionName unless ~blacklist.indexOf(c.collectionName)

  counter = collections: names.length, items: 0, total: 0
  itemDone = (err) ->
    console.error(err) if err
    if (counter.collections is 0) and (--counter.items is 0)
      console.log "All done. Processed #{counter.total} collections"
      db.close()
      process.exit()

  # Each must be used for large datasets, toArray won't fit in memory: http://mongodb.github.io/node-mongodb-native/api-generated/cursor.html#each
  names.forEach (name) ->
    #go through all of the docs in the collection and create an op log for it
    collection = db.collection(name)
    collection.count (err, count) ->
      console.error err if err
      counter.items += +count
      counter.total += +count
      counter.collections--
      console.log name, "DOCS", count

      cursor = collection.find()
      cursor.batchSize(+batch) if batch
      cursor.each (err, doc) ->
        return itemDone("null doc... ???") unless doc

        key = "#{name}.#{doc._id} ops" # key format: "collectionName.docId ops"
        op = JSON.stringify create: {type: jsonType, data: doc}
        rc.del key, (err) ->
          console.error err if err
          rc.rpush key, op, (err) ->
            console.error err if err
            collection.update {_id: doc._id}, {$set: id: doc._id, _v: 1, _type: jsonType}, itemDone