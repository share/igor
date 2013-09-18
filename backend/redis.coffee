optimist = require 'optimist'

module.exports = (options) ->

  argv = optimist.argv

  options.rhost ?= argv.rhost or process.env.REDIS_HOST or 'localhost'
  options.rport ?= argv.rport or process.env.REDIS_PORT or 6379
  options.db ?= argv.rdb or process.env.REDIS_DB or 1

  console.log "Redis: #{options.rhost}:#{options.rport} #{options.rdb}"

  redis = require('redis').createClient options.rport, options.rhost
  redis.select options.rdb

  redis