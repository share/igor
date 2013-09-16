optimist = require 'optimist'

module.exports = ->

  argv = optimist.argv

  conf =
    host: argv.host or process.env.REDIS_HOST or 'localhost'
    port: argv.port or process.env.REDIS_PORT or 6379
    db: argv.db or process.env.REDIS_DB or 1

  console.log "Redis: #{conf.host}:#{conf.port} #{conf.db}"

  redis = require('redis').createClient conf.port, conf.host
  redis.select conf.db

  return redis
