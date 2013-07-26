async = require 'async'

# TODO: stream data out?
module.exports.collection = (collection, options, callback) ->
  batch = options.batch

  # Setup the db
  mongo = require './backend/mongo'
  redis = require './backend/redis'
  redisObserver = require './backend/redisObserver'
  livedb = require 'livedb'
  {LiveDbMongo} = require 'livedb-mongo'
  db = livedb.client new LiveDbMongo(mongo), redis, redisObserver

  # loop through the collection
  # TODO: support pagination/batching so we don't have to put everything in memory
  query = options.query or {}
  db.queryFetch collection, query, {}, (err, docs) ->
    return callback err if err
    from = 0
    to = null
    async.map docs, (doc, docCb) ->
      db.getOps collection, doc.docName, from, to, (err, ops) ->
        return docCb err if err
        docCb null, { name: doc.docName, ops: JSON.stringify(ops) }
    , (err, operations) ->
      return callback err if err
      callback null, {
        collection: collection
        snapshots: docs
        operations: operations
      }
