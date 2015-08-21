
triplesec = require "triplesec"
kbpgp = require 'kbpgp'
WordArray = triplesec.WordArray
{KeyManager} = kbpgp
{make_esc} = require 'iced-error'

#=======================================================================================

bufsplit = (buf, lens) ->
  s = 0
  ret = []
  for l in lens
    e = s+l
    ret.push buf[s...e]
    s = e
  return ret

#=======================================================================================

#
# Class for Keybase account manipulation
#
exports.Account = class Account

  #
  # @param {Config} config A Config object that explains how we'll
  #   do things like contacting the keybase server.
  #
  constructor : ({@config}) ->
    {C} = @config
    @triplesec_version = @config.C.triplesec.version
    @enc = new triplesec.Encryptor { version  : @triplesec_version }
    @nacl = {}
    @lks = {}
    @extra_keymaterial = C.pwh.derived_key_bytes +
      C.nacl.eddsa_secret_key_bytes +
      C.nacl.dh_secret_key_bytes +
      C.device.lks_client_half_bytes

  #---------------

  resalt : ({ salt, progress_hook }, cb) ->
    await @enc.resalt { salt, @extra_keymaterial, progress_hook }, defer err, keys
    throw err if err?
    cb keys

  #---------------

  # Given a passphrase and salt, hash it using Scrypt with the
  # standard V3 parameters. We're doig this as somewhat of a hack,
  # allocating the keys needed for triplesec'ing, and then using the
  # "extra" keys after that.
  #
  # @param {string} key A key as a utf8-string that's the passphrase
  # @param {Buffer} salt The salt as a buffer of binary data
  # @param {function} progress_hook A progress hook if we care....
  # @param {callback} cb Call when completed with the passphrase hash. The PWH
  #    is presented as a hex-encoded string, suitable for sending over AJAX.
  scrypt_hash_passphrase : ({key, salt, progress_hook, encoding}, cb) ->
    key = new triplesec.Buffer key, 'utf8'
    @enc.set_key key
    {C} = @config
    await @resalt { salt, progress_hook }, defer keys
    km = keys.extra

    [pwh, @nacl.eddsa, @nacl.dh, @lks.clienf_half ] = bufsplit km, [
      C.pwh.derived_key_bytes,
      C.nacl.eddsa_secret_key_bytes,
      C.nacl.dh_secret_key_bytes,
      C.device.lks_client_half_bytes
    ]
    if encoding? then pwh = pwh.toString encoding
    cb pwh

  #---------------

  fix_signup_bundle : (bundle, cb) ->
    nb = triplesec.V[@triplesec_version].salt_size
    await kbpgp.rand.SRF().random_bytes nb, defer salt
    await @scrypt_hash_passphrase { key : bundle.pw, salt, encoding : 'hex' }, defer bundle.pwh
    bundle.salt = salt.toString 'hex'
    bundle.pwh_version = @triplesec_version
    delete bundle.pw
    cb()

  #---------------

  # used during password change.
  #
  # @param {string} pw Passphrase as a utf8-encoded string
  # @param {Buffer} salt The raw binary salt as a buffer, returned from
  #     pw_to_login below, most likely.
  # @param {callback} cb called with err, pwh, pwh_version
  gen_new_pwh : ({pw, salt}, cb) ->
    await @scrypt_hash_passphrase { key : pw, salt, encoding : 'hex' }, defer pwh
    pwh_version = @triplesec_version
    cb null, pwh, pwh_version

  #---------------

  # Convert a pw into a password hash.
  #
  # @param {String} pw the input passprhase
  # @param {String} email_or_username the email or username to use in the salt lookup.
  # @param {Callback} cb callback with a quad: <Error,Buffer,Int,Buffer>, containing
  #    an error (if one happened), a Buffer with the pwh, an int for what version,
  #    and a buffer with the salt.
  pw_to_pwh : ({pw, email_or_username, uid}, cb) ->
    err = pwh = pwh_version = salt = null
    await @config.request { method : "GET", endpoint : 'getsalt', params : { email_or_username, uid } }, defer err, res
    if err? then # noop
    else if not ((got = res?.body?.pwh_version) is @triplesec_version)
      err = new Error "Can only support PW hash version #{@triplesec_version}; got #{got} for #{@config.escape_user_content email_or_username}"
    else
      salt = new triplesec.Buffer res.body.salt, 'hex'
      await @scrypt_hash_passphrase { salt, key : pw, encoding : null }, defer pwh
      pwh_version = @triplesec_version
    console.log res?.body
    cb err, pwh, pwh_version, salt, res?.body?.login_session

  #---------------

  pw_to_login : ({pw, email_or_username}, cb) ->
    login_session = hmac_pwh = null
    await @pw_to_pwh { pw, email_or_username }, defer err, pwh, pwh_version, salt, login_session_b64
    unless err?
      login_session = new triplesec.Buffer login_session_b64, 'base64'
      # Make a new HMAC-SHA512'er, and the key is the output of the
      hmac = new triplesec.HMAC(WordArray.from_buffer(pwh))
      hmac_pwh = hmac.update(WordArray.from_buffer(login_session)).finalize().to_hex()
      login_session = login_session_b64

    cb err, login_session, hmac_pwh, salt

  #---------------

  get_public_key: (username, cb) ->
    err = ret = null
    await @config.request { endpoint : "user/lookup", params : {username} }, defer err, res
    unless err?
      ret = res?.body?.them?.public_keys?.primary?.bundle
      err = new Error "Cannot find a public key for '#{@config.escape_user_content username}'" unless ret?
    cb err, ret

  #---------------

  get_unlocked_private_key : (pw, cb) ->
    esc = make_esc (err) -> cb err, null
    passphrase = new triplesec.Buffer pw
    await @config.request { method : "GET", endpoint : "me" }, esc defer res
    bundle = res?.body?.me?.private_keys?.primary?.bundle
    sk = err = null
    if bundle?
      tsenc = @get_tsenc_for_decryption { passphrase }
      await KeyManager.import_from_p3skb { raw: bundle }, esc defer sk
      await sk.unlock_p3skb {   tsenc }, esc defer()
    err = null
    unless sk?
      err = new Error "Failed to get and unlock your private key"
    cb err, sk

  #---------------

  export_my_private_key: (pw, cb) ->
    esc = make_esc cb, "export_my_private_key"
    err = armored_private = null
    passphrase = new triplesec.Buffer pw
    await @get_unlocked_private_key pw, esc defer sk
    await sk.sign {}, esc defer()
    await sk.export_pgp_private_to_client {passphrase}, esc defer armored_private
    cb null, armored_private

  #---------------

  reencrypt_private_key : (sk, cb) ->
    await sk.export_private_to_server { tsenc : @enc }, defer err, key
    cb err, key

  #---------------

  change_passphrase : (oldpw, newpw, cb) ->
    params = {}
    esc = make_esc cb, "change_password"
    await @pw_to_login { pw : oldpw }, esc defer params.login_session, params.hmac_pwh, salt
    await @get_unlocked_private_key oldpw, esc defer sk
    await @gen_new_pwh { pw : newpw, salt }, esc defer params.pwh, params.pwh_version
    if sk?
      endpoint = "key/add"
      await @reencrypt_private_key sk, esc defer params.private_key
    else
      endpoint = "account/update"
    await @config.request { method : "POST", endpoint, params }, esc defer res
    cb null, res?.body

  #---------------

  # @param {Buffer} passphrase
  get_tsenc_for_decryption : ({passphrase}) ->
    @enc.set_key passphrase
    @enc

  #---------------

  gen_nacl_eddsa_key : (params, cb) ->
    gen = kbpgp.kb.KeyManager.generate
    await gen { seed : @nacl.eddsa, split : true }, defer err, km
    cb err, km

  #---------------

  gen_nacl_dh_key : (params, cb) ->
    gen = kbpgp.kb.EncKeyManager.generate
    await gen { seed : @nacl.dh, split : true }, defer err, km
    cb err, km

#=======================================================================================

