mongoskin = require 'mongoskin'
optimist = require 'optimist'

consoleError = (err) ->
  return console.error err if err

module.exports = ->

  argv = optimist.argv

  conf =
    host:argv.host or process.env.MONGO_HOST or 'localhost'
    port: argv.port or process.env.MONGO_PORT or 27017
    db: argv.db or process.env.MONGO_DB or 'test'
    user: argv.user
    pass: argv.pass
    url: argv.url

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
