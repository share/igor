mongoskin = require 'mongoskin'

consoleError = (err) ->
  return console.error err if err

module.exports = (conf = {}) ->

  mongo_host = conf.host or process.env.MONGO_HOST or 'localhost'
  mongo_port = conf.port or process.env.MONGO_PORT or 27017
  mongo_db   = conf.db or process.env.MONGO_DB or 'test'
  url = "#{mongo_host}:#{mongo_port}/#{mongo_db}?auto_reconnect"
  db = mongoskin.db(url, safe: true)
  return db
