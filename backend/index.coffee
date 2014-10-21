livedb = require 'livedb'
{LiveDbMongo} = require 'livedb-mongo'
createMongo = require './mongo'
createRedis = require './redis'

module.exports = exports = (conf = {}) ->

  redis = createRedis(conf.redis?)
  redisObserver = createRedis(conf.redis?)
  driver = livedb.redisDriver db, redis, redisObserver
  console.log "CMON"
  livedb.client
    db: new LiveDbMongo createMongo(conf.mongo?)
    driver: driver

exports.createMongo = createMongo
exports.createRedis = createRedis
