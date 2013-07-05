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
blacklist = ['system.indexes']

ottypes = require('ottypes')
jsonType = ottypes.json0.uri

rc.on 'error', (err) ->
  console.error("redis error", err)

processCollection = (name, cb) ->
  #go through all of the docs in the collection and create an op log for it
  collection = db.collection(name)
  options = if batch then {batchSize: +batch} else {}
  collection.find({}, options).toArray (err, docs) ->
    console.log name, "DOCS", docs.length
    async.map docs, (doc, redisCb) ->
      runningOps = 2
      done = (err) ->
        console.error(err) if err
        redisCb(err) if (--runningOps is 0)

      key = "#{name}.#{doc._id} ops" # key format: "collectionName.docId ops"
      op = JSON.stringify create: {type: jsonType, data: doc}
      rc.del key, (err) ->
        console.error(err) if err
        rc.rpush key, op, done

      collection.update {_id: doc._id}, {$set: id: doc._id, _v: 1, _type: jsonType}, done

    , (err, added) ->
      if docs.length isnt added.length
        console.log("#{docs.length} found, #{added.length} processed")
      console.error(err) if err
      return cb err

db.collections (err, collections) ->
  names = []
  collections.forEach (c) ->
    if blacklist.indexOf(c.collectionName) < 0
      names.push c.collectionName

  console.log "collections", names
  async.map names, processCollection, (err, results) ->
    console.error(err) if err
    console.log "All done. Processed #{results.length} collections"
    db.close()
    process.exit()