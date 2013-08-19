module.exports = (conf = {}) ->

  port = conf.port or 6379
  host = conf.host or '127.0.0.1'
  redis = require('redis').createClient port, host
  redis.select(conf.db || 1)

  return redis
