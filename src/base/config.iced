
#---------------

exports.Config = class Config

  # @param {Request} request A request object that tells us how to make requests
  #    to the remote Web server; can be either Ajax-y or Node-y
  constructor : ( { @request }) ->

#---------------
