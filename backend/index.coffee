livedb = require 'livedb'
{LiveDbMongo} = require 'livedb-mongo'
createMongo = require './mongo'
createRedis = require './redis'

module.exports = exports = (conf = {}) ->
  livedb.client
    db: new LiveDbMongo createMongo(conf.mongo?)
    redis: createRedis(conf.redis?)
    redisObserver: createRedis(conf.redis?)

exports.createMongo = createMongo
exports.createRedis = createRedis
