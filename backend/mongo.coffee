mongoskin = require 'mongoskin'

consoleError = (err) ->
  return console.error err if err

module.exports = (conf) ->

  conf.host ?= process.env.MONGO_HOST or 'localhost'
  conf.port ?= process.env.MONGO_PORT or 27017
  conf.db ?= process.env.MONGO_DB or 'test'

  if conf.url
    url = conf.url
  else if conf.user and conf.pass
    url = "#{conf.user}:#{conf.pass}@#{conf.host}:#{conf.port}/#{conf.db}"
  else
    url = "#{conf.host}:#{conf.port}/#{conf.db}"

  if '?auto_reconnect' not in url
    url += '?auto_reconnect'

  console.log 'Mongo: ' + url

  db = mongoskin.db(url, safe: true)
  return db
