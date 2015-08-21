
#---------------

exports.Config = class Config

  # @param {Request} reqeng A request object that tells us how to make requests
  #    to the remote Web server; can be either Ajax-y or Node-y
  # @param {Object} C a dictionary of constants that are avaible as Keybase public
  #    constants.
  # @parm {Function} fq_api_endpoint Given an API endpoint, make a fully-qualified
  #    URL. Maps strings to strings.
  # @param {Function escape_user_content} Run all error messages through this filter
  #    to guard against XSS attacks
  constructor : ( { @reqeng, @C, @fq_api_endpoint, @escape_user_content }) ->

  #
  # Make a request to an API endpoint.
  #
  # @param {Object} args Request parameters
  # @param {Callback} cb A callback to call with (err, res) after the request completes.
  #
  request : (args, cb) ->
    args.url = @fq_api_endpoint(args.endpoint) if args.endpoint? and @fq_api_endpoint?
    await @reqeng.request args, defer err, res
    if err? and @escape_user_content?
      err = new Error @escape_user_content err.message
    cb err, res

#---------------
