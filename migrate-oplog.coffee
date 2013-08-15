redis = require 'redis'
async = require 'async'

migrate = module.exports = (oplog, client = redis.createClient(), callback) ->
  [client, callback] = [redis.createClient(), client] if typeof client is 'function'
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
migrate.del = true

if require.main == module
  oplog = require('livedb-mongo') 'localhost:27017/test?auto_reconnect', safe:true
  client = redis.createClient()
  client.select 1

  migrate oplog, client, (err) ->
    return console.error err if err
    console.log 'Done!'
    client.quit()
    oplog.close()


