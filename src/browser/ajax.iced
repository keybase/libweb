
{base} = require '../base/index'

#======================================================================

exports.Request = class Request extends base.Request

  # @param {jQuery} $ Pass the jQuery object, which we'll wrap accordingly.
  # @param {Function} get_csrf_token A function that returns a current
  #   CSRF token to pass into the request call.
  constructor : ({@$, get_csrf_token}) ->
    super { get_csrf_token }

  #------------------------

  request : ({url, params, ok_http_status_codes, ok_json_status_codes, ok_empty_body, method}, cb) ->
    headers = {}
    headers["X-CSRF-Token"] = t if (t = @get_csrf_token?())? and t.length

    ok_http_status_codes or= [ 200 ]
    ok_json_status_codes or= [ 'OK' ]

    #-------------

    always = (xhr) ->
      err = null
      out =
        body : null
        http_status : null
        json_status : null

      if (out.http_status = xhr.status)? and (out.http_status in ok_http_status_codes)

        if not (body = xhr.responseJSON)?
          err = new Error "empty body sent back from server" if not ok_empty_body

        else if not (out.json_status = body.status?.name)? or not (out.json_status in ok_json_status_codes)
          msg = "Server failure"
          if (d = body?.status?.desc) then msg += ": #{d}"
          err = new Error msg

        else
          out.body = body

      else
        msg = "error in #{method}"
        if out.http_status? then msg += " (HTTP code #{out.http_status})"
        err = new Error msg

      cb err, out

    #-------------

    params = {
      type : method
      url
      data : params
      headers
      dataType : "json"
    }

    #-------------

    xhr = $.ajax(params)
    xhr.always () -> always xhr

#======================================================================

