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

rc = redis.createClient()
rc.select argv.r ? 1

#don't need to make these collections live
blacklist = ['system.indexes']

ottypes = require('ottypes')
jsonType = ottypes.json0.uri

rc.on 'error', (err) ->
  console.log("redis error", err)

processCollection = (name, cb) ->
  #go through all of the docs in the collection and create an op log for it
  collection = db.collection(name)
  collection.find().toArray (err, docs) ->
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
      return cb err

db.collections (err, collections) ->
  names = []
  collections.forEach (c) ->
    if blacklist.indexOf(c.collectionName) < 0
      names.push c.collectionName
    
  console.log "collections", names
  async.map names, processCollection, (err, results) ->
    console.log 'all done'
    db.close()
    process.exit()


