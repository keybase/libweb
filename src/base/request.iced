
#------------------

EUI = () -> new Error "Unimplemented"

#------------------

exports.Request = class Request

  # @param {Function} impl A function that takes request-like parmeters
  #   and calls back with an (err, body) pair
  constructor : ( {@get_csrf_token}) ->

  #---------------

  request : ( args, cb) -> cb EUI()

  #---------------

  _make_headers : ({headers, method}) ->
    headers or= {}
    if method is "POST" and (t = @get_csrf_token?())? and t.length
      headers["X-CSRF-Token"] = t
    headers

  #---------------

  _handle_response : ({err, inargs, body, http_status}, cb) ->

    {url, method, ok_http_status_codes, ok_json_status_codes, ok_empty_body} = inargs
    ok_http_status_codes or= [ 200 ]
    ok_json_status_codes or= [ 'OK' ]

    err = null
    json_status = null

    if http_status? and not (http_status in ok_http_status_codes)
      msg = "error in #{method}"
      if http_status? then msg += " (HTTP code #{http_status})"
      err = new Error msg
    else if err? then #noop
    else if not body?
      err = new Error "empty body sent back from server" if not ok_empty_body
    else if not (json_status = body.status?.name)? or not (json_status in ok_json_status_codes)
      msg = "Server failure"
      if (d = body?.status?.desc) then msg += ": #{d}"
      err = new Error msg

    cb err, {body, json_status, http_status}

#------------------


