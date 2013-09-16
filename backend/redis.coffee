module.exports = (conf) ->

  conf.host ?= process.env.REDIS_HOST or 'localhost'
  conf.port ?= process.env.REDIS_PORT or 6379
  conf.db ?= process.env.REDIS_DB or 1

  console.log "Redis: #{conf.host}:#{conf.port} #{conf.db}"

  redis = require('redis').createClient conf.port, conf.host
  redis.select conf.db

  return redis
