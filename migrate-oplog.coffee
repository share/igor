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
        , callback

    async.each results, iterator, callback

if require.main == module
  oplog = require('livedb-mongo') 'localhost:27017/test?auto_reconnect', safe:true
  client = redis.createClient()

  migrate oplog, client, (err) ->
    console.log 'Done!', err
    client.quit()
    oplog.close()


