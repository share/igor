argv = require('optimist').argv

port = process.env.REDIS_PORT or 6379
host = process.env.REDIS_HOST or '127.0.0.1'
redis = require('redis').createClient port, host

if process.env.REDIS_AUTH
  redis.auth(process.env.REDIS_AUTH)
redis.select(argv.r or process.env.REDIS_DB or 1)

module.exports = redis
