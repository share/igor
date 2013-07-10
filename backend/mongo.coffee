mongoskin = require 'mongoskin'
argv = require('optimist').argv

mongo_host = process.env.MONGO_HOST or 'localhost'
mongo_port = process.env.MONGO_PORT or 27017
mongo_db   = argv.db or process.env.MONGO_DB or 'test'
url = "#{mongo_host}:#{mongo_port}/#{mongo_db}?auto_reconnect"

module.exports = mongoskin.db(url, {native_parser:true, safe: true})
