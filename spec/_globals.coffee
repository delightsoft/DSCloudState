module.exports = (->
  GLOBAL.Promise = require 'bluebird'
  GLOBAL.R = require 'ramda'
  return)
