
#------------------

exports.Request = class Request

  # @param {Function} impl A function that takes request-like parmeters
  #   and calls back with an (err, body) pair
  # @param {Function} get_csrf_token A function that returns a current
  #   CSRF token to pass into the request call.
  constructor : ( {@impl, @get_csrf_token}) ->

#---------------

exports.Config = class Config

  # @param {Request} request A request object that tells us how to make requests
  #    to the remote Web server; can be either Ajax-y or Node-y
  constructor : ( { @request }) ->

#---------------
