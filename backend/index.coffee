livedb = require 'livedb'
{LiveDbMongo} = require 'livedb-mongo'
#LiveDbSolr = require 'livedb-solr'
#solr = require './solr'
mongo = require './mongo'
redis = require './redis'
redisObserver = require './redisObserver'

module.exports = livedb.client new LiveDbMongo(mongo), redis, redisObserver
