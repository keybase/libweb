
#------------------

EUI = () -> new Error "Unimplemented"

#------------------

exports.Request = class Request

  # @param {Function} impl A function that takes request-like parmeters
  #   and calls back with an (err, body) pair
  constructor : ( {@get_csrf_token}) ->

  request : ( args, cb) -> cb EUI()

#---------------

exports.Config = class Config

  # @param {Request} request A request object that tells us how to make requests
  #    to the remote Web server; can be either Ajax-y or Node-y
  constructor : ( { @request }) ->

#---------------
