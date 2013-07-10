# Turn a mongo db into a live-db
# you should probably redis-cli flushdb; before running this script

async = require 'async'
redis = require 'redis'
mongo = require 'mongoskin'
argv = require('optimist').argv

db = require './backend/mongo'
rc = require './backend/redis'

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

  # Each must be used for large datasets, toArray won't fit in memory: http://mongodb.github.io/node-mongodb-native/api-generated/cursor.html#each
  async.each names, (name, cb) ->
    #go through all of the docs in the collection and create an op log for it
    collection = db.collection(name)
    collection.count (err, count) ->
      return cb err if err
      console.log name, "DOCS", count
      counter = 0

      cursor = collection.find()
      cursor.batchSize(+batch) if batch
      cursor.each (err, doc) ->
        return cb err if err
        #we are done when we get a null doc
        if !doc
          cb(null, counter) if counter == count
          return

        key = "#{name}.#{doc._id} ops" # key format: "collectionName.docId ops"
        op = JSON.stringify create: {type: jsonType, data: doc}
        rc.del key, (err) ->
          console.error err if err
          rc.rpush key, op, (err) ->
            console.error err if err
            collection.update {_id: doc._id}, {$set: id: doc._id, _v: 1, _type: jsonType}, (err) ->
              cb(err) if err
              counter++
              cb(null, counter) if counter == count

  , (err, results) ->
    console.log "ALL DONE"
    db.close()
    process.exit()
