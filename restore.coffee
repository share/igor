async = require 'async'
arrayDiff = require 'arraydiff'

ascending = (a,b) ->
  return -1 if a.docName < b.docName
  return 1

ottypes = require('ottypes')
jsonType = ottypes.json0.uri

module.exports.snapshots = (collection, snapshots, options, callback) ->
  callback new Error("bad data") if not collection or not snapshots or not snapshots.length

  # Setup the db
  mongo = require './backend/mongo'
  redis = require './backend/redis'
  redisObserver = require './backend/redisObserver'
  livedb = require 'livedb'
  {LiveDbMongo} = require 'livedb-mongo'
  db = livedb.client new LiveDbMongo(mongo), redis, redisObserver

  # it would be nice support pagination/batching so we don't have to put everything in memory
  # but pagination is a little tricky because # of documents could change between queries
  # and we can't tell which elements to remove
  query = options.query or {}
  db.queryFetch collection, query, {}, (err, docs) ->
    return callback err if err

    #array diff wants sorted items
    snapshots.sort ascending
    docs.sort ascending
    console.log snapshots.length, "snapshots"
    console.log docs.length, "docs"

    # get the difference between our old docs and new docs
    diff = arrayDiff docs, snapshots, (a,b) -> a.docName == b.docName
    # we get the names (ids) of the documents to be removed
    removed = []
    diff.filter((d) -> d.type == "remove").forEach (r) ->
      rem = docs.splice(r.index, r.howMany)
      removed = removed.concat(rem)

    console.log "removed!", removed.length
    # delete docs not not in intersection of snapshots and oldDocs
    async.map removed, (oldDoc, removeCb) ->
      db.submit collection, oldDoc.docName, {del:true}, removeCb
    , (err, done) ->
      console.log err if err
      console.log "DONE REMOVING", done.length

      # apply a "patch" of data (create and set)
      async.map snapshots, (newDoc, docCb) ->
        # create new docs
        #console.log "SUP"
        id = newDoc.docName
        # TODO: this could probably be optimized by using docs we already have in memory
        db.fetch collection, id, (err, oldDoc) ->
          return docCb err if err
          if !oldDoc.type
            # create a new doc
            db.submit collection, id, { create: {v: oldDoc.v or 0, type: jsonType, data: newDoc.data}}, (err) ->
              if err
                console.log "create", collection, id, oldDoc
              docCb(err)
          else
            # set existing docs
            db.submit collection, id, {v: oldDoc.v, op: {p: [], od: oldDoc.data, oi: newDoc.data}}, (err) ->
              if err
                console.log "set", collection, id, oldDoc
              docCb(err)

      , (err, done) ->
        return callback err if err
        console.log "DONE ADDING", done.length
        callback()


module.exports.operations = (collection, operations, options, callback) ->
  # restore the operations
  # WARNING this will flush the redis database

  # TODO: limit restoration of operations to a query like we allow for snapshots
  redis = require './backend/redis'
  redis.flushdb (err) ->
    async.map operations, (doc, docCb) ->
      key = "#{collection}.#{doc.name} ops"
      redis.del key, (err) ->
        console.log "ERRR", err if err
        return docCb(err) if err
        redis.lpush key, doc.ops, (err) ->
          console.log "ERRR :(", err if err
          docCb(err)
    , callback


