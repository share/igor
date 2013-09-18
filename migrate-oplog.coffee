redis = require 'redis'
async = require 'async'
backend = require './backend'
LiveDbMongo = require 'livedb-mongo'
argv = require('optimist').argv


exports = module.exports
exports.migrate = (options = {}, callback) ->
  oplog = new LiveDbMongo backend.createMongo options
  client = backend.createRedis options

  client.keys '* ops', (err, results) ->
    return callback? err if err

    iterator = (k, callback) ->
      client.lrange k, 0, -1, (err, ops) ->
        return callback "Could not migrate #{k}: #{err}" if err

        path = k.split(" ops")[0]
        [cName, docName] = path.split '.'
        console.log cName, docName
        ops = for op, v in ops
          op = JSON.parse op
          op.v = v
          op

        async.each ops, (op, callback) ->
          oplog.writeOp cName, docName, op, (err) ->
            console.warn "Error writing op #{cName} #{docName}: #{err}" if err
            callback()
        , (err) ->
          return callback err if err

          # Delete the ops from redis.
          if migrate.del
            client.del k, callback
          else
            callback()

    async.each results, iterator, callback

# Should the script also delete the original ops in redis when it copies them in?
#
# This defaults to not delete - livedb can deal with junk in the oplog.
migrate.del = argv.d

if require.main == module

  exports.migrate null, (err) ->
    if err
      console.log "ERROR! NOT FINISHED!"
      console.log err
    else
      console.log "ALL DONE"
    process.exit()

