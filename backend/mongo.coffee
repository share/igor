mongoskin = require 'mongoskin'
optimist = require 'optimist'

consoleError = (err) ->
  return console.error err if err

module.exports = (options) ->

  argv = optimist.argv

  options.host ?= argv.host or process.env.MONGO_HOST or 'localhost'
  options.port ?= argv.port or process.env.MONGO_PORT or 27017
  options.db ?= argv.db or process.env.MONGO_DB or 'test'
  options.user ?= argv.user
  options.pass ?= argv.pass
  options.url ?= argv.url

  if options.url
    url = options.url
  else if options.user and options.pass
    url = "#{options.user}:#{options.pass}@#{options.host}:#{options.port}/#{options.db}"
  else
    url = "#{options.host}:#{options.port}/#{options.db}"

  if '?auto_reconnect' not in url
    url += '?auto_reconnect'

  console.log 'Mongo: ' + url

  db = mongoskin.db(url, safe: true)
  
  db