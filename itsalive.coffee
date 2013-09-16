# Turn a mongo db into a live-db
# you should probably redis-cli flushdb; before running this script
async = require 'async'

consoleError = (err) ->
  return console.error err if err

# Taken from livedb-mongo/mongo.js
shallowClone = (object) ->
  out = {}
  for key of object
    out[key] = object[key]
  return out

castToDoc = (docName, data) ->
  doc = if (typeof data.data == 'object' && data.data != null && !Array.isArray(data.data))
    shallowClone(data.data)
  else
    _data: if data.data is undefined then null else data.data
  doc._type = data.type || null
  doc._v = data.v
  doc._id = docName
  return doc

castToSnapshot = (doc) ->
  return if !doc
  type = doc._type
  v = doc._v
  docName = doc._id
  data = doc._data
  if data is undefined
    doc = shallowClone(doc)
    delete doc._type
    delete doc._v
    delete doc._id
    return {
      data: doc
      type: type
      v: v
      docName: docName
    }
  return {
    data: data
    type: type
    v: v
    docName: docName
  }


exports = module.exports
exports.itsalive = (options = {}, callback) ->
  #don't need to make these collections live
  blacklist = ['system.indexes', 'system.users', 'configs', 'sessions']
  batch = options.batch

  # Setup the db
  backend = require './backend'
  livedb = require 'livedb'
  {LiveDbMongo} = require 'livedb-mongo'
  mongo = backend.createMongo options.mongo
  db = new LiveDbMongo mongo
  ldbc = livedb.client
    db: db
    redis: backend.createRedis(options.redis)
    redisObserver: backend.createRedis(options.redis)

  ottypes = require('ottypes')
  jsonType = ottypes.json0.uri

  mongo.collections (err, cols) ->
    return callback err if err
    collections = []
    cols.forEach (c) ->
      console.log "collection", c.collectionName
      if not ~blacklist.indexOf(c.collectionName) and not /_ops$/.test c.collectionName
        collections.push c

    # Each must be used for large datasets, toArray won't fit in memory: http://mongodb.github.io/node-mongodb-native/api-generated/cursor.html#each
    async.each collections, (collection, cb) ->
      #go through all of the docs in the collection and create an op log for it
      cName = collection.collectionName
      mongo.collection(cName + "_ops").ensureIndex {name: 1, v: 1}, false, consoleError
      collection.count (err, count) ->
        return cb err if err
        console.log cName, "DOCS", count
        counter = 0

        cursor = collection.find()
        cursor.batchSize(+batch) if batch
        cursor.each (err, doc) ->
          return cb err if err
          #we are done when we get a null doc
          if !doc
            cb(null, counter) if counter == count
            return

          doc._type ?= jsonType
          snapshot = castToSnapshot doc
          docName = snapshot.docName

          #console.log "doc", counter, cName, docName
          db.getVersion cName, docName, (err, opVersion) ->
            return cb err if err

            if opVersion is 0
              console.log "no ops", counter
              # Create an operation that creates the document snapshot
              opData = create: {type: jsonType, data: snapshot.data}, v:0

              db.writeOp cName, docName, opData, (err) ->
                return cb err if err

                snapshot.v = 1
                db.writeSnapshot cName, docName, snapshot, (err) ->
                  return cb err if err
                  counter++
                  cb null, counter if counter is count

            else if opVersion isnt doc._v
              # replay oplog, which is the source of truth
              console.log "diff  ops", counter

              db.writeSnapshot cName, docName, {v:0}, (err) ->
                return cb err if err
                ldbc.fetch cName, docName, (err, snapshot) ->
                  return cb err if err
                  db.writeSnapshot cName, docName, snapshot, (err) ->
                    return cb err if err
                    counter++
                    cb null, counter if counter is count

            else
              console.log "ok", counter
              counter++
              cb null, counter if counter is count

    , (err) ->
      console.log("callback?", err)
      return callback err if err
      db.close()
      callback()


#called directly from command line (not required as a module)
if require.main == module
  # Allow user to process operation in batches of specified number, in case their data is too large for .toArray()
  argv = require('optimist').argv
  batch = argv.b
  options =
    batch: batch
    mongo:
      host: 'localhost'
      port: 27017
      db: 'test'
    redis:
      host: 'localhost'
      port: 6379
      db: 1

  exports.itsalive options, (err, results) ->
    if err
      console.log "ERROR! NOT FINISHED!"
      console.log err
    else
      console.log "ALL DONE"
    process.exit()
