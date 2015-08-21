
base = require '../base/request'

#======================================================================

exports.Request = class Request extends base.Request

  # @param {jQuery} $ Pass the jQuery object, which we'll wrap accordingly.
  # @param {Function} get_csrf_token A function that returns a current
  #   CSRF token to pass into the request call.
  constructor : ({$, get_csrf_token}) ->
    @jQuery = $
    super { get_csrf_token }

  #------------------------

  request : (inargs, cb) ->
    headers = @_make_headers inargs

    params = {
      type : inargs.method
      url : inargs.url
      data : inargs.params
      headers : headers
      dataType : "json"
    }

    xhr = @jQuery.ajax(params)

    finish = (err) =>
      return unless (tmp = cb)?
      cb = null
      @_handle_response { err, inargs, body : xhr.responseJSON, http_status : xhr.status }, tmp

    xhr.fail (_,textStatus) -> finish new Error textStatus
    xhr.done () -> finish null

#======================================================================


