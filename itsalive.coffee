# Turn a mongo db into a live-db
# you should probably redis-cli flushdb; before running this script

async = require 'async'
redis = require 'redis'
mongo = require 'mongoskin'
argv = require('optimist').argv

mongo_host = process.env.MONGO_HOST or 'localhost'
mongo_port = process.env.MONGO_PORT or 27017
mongo_db   = argv.db or process.env.MONGO_DB or 'test'
db         = mongo.db(mongo_host + ':' + mongo_port + '/' + mongo_db + '?auto_reconnect')

if process.env.REDIS_PORT and process.env.REDIS_HOST
  rc = redis.createClient(process.env.REDIS_PORT, process.env.REDIS_HOST)
else
  rc = redis.createClient()

if process.env.REDIS_AUTH
  rc.auth(process.env.REDIS_AUTH)

rc.select argv.r ? 1

# Allow user to process operation in batches of specified number, in case their data is too large for .toArray()
batch = +argv.b

#don't need to make these collections live
blacklist = ['system.indexes']

ottypes = require('ottypes')
jsonType = ottypes.json0.uri

rc.on 'error', (err) ->
  console.log("redis error", err)

processCollection = (name, cb) ->
  processBatch = (batchNum) ->
    #go through all of the docs in the collection and create an op log for it
    collection = db.collection(name)
    cursor = collection.find()
    if batch
      cursor.limit batch
      cursor.skip batchNum * batch
    cursor.toArray (err, docs) ->
      console.log name, "DOCS", docs.length
      async.map docs, (doc, redisCb) ->
        op =
          create:
            type: jsonType
            data: doc
        #key format: "collectionName.docId ops"
        key = name + '.' + doc._id + ' ops'
        rc.del key, (err) ->
          return cb err if err
          rc.rpush key, JSON.stringify(op), (err) ->
            return cb err if err
            doc.id = doc._id
            doc._v = 1
            doc._type  = jsonType
            collection.update {_id: doc._id}, doc, redisCb
      , (err, added) ->
        # they didn't pass in `batch`, so we process everything (or there was an error)
        return cb(err) if (err or !batch)
        # the most recent batch size is less than `batch` option, meaning we've reached the end
        return cb(err) if added.length < batch
        # else keep iterating
        processBatch(++batchNum)
  processBatch(0)

db.collections (err, collections) ->
  names = []
  collections.forEach (c) ->
    if blacklist.indexOf(c.collectionName) < 0
      names.push c.collectionName

  console.log "collections", names
  async.map names, processCollection, (err, results) ->
    console.error(err) if err
    console.log 'all done'
    db.close()
    process.exit()