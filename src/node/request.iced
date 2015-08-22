
base = require '../base/request'

#======================================================================

exports.Request = class Request extends base.Request

  # @param {Function} get_csrf_token A function that returns a current
  #   CSRF token to pass into the request call.
  constructor : ({@libs, get_csrf_token}) ->
    super { get_csrf_token }

  #------------------------

  request : (inargs, cb) ->

    { method } = inargs
    headers = @_make_headers inargs

    uri = @libs.url.parse inargs.url

    req_args = { uri, headers, method, jar : true, json : true }

    switch method
      when 'GET', 'DELETE'
        uri.query = inargs.params
      when 'POST'
        req_args.body = inargs.params

    await @libs.request req_args, defer err, res, body
    @_handle_response { err, inargs, body, http_status : res?.statusCode }, cb

#======================================================================

