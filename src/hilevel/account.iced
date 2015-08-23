
triplesec = require "triplesec"
kbpgp = require 'kbpgp'
WordArray = triplesec.WordArray
{KeyManager} = kbpgp
{make_esc} = require 'iced-error'
{xor_buffers} = require '../base/util'

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
    @nacl = {}
    @lks = {}
    @extra_keymaterial = C.pwh.derived_key_bytes +
      C.nacl.eddsa_secret_key_bytes +
      C.nacl.dh_secret_key_bytes +
      C.device.lks_client_half_bytes
    @new_tsenc()

  #---------------

  new_tsenc : () -> 
    @enc = new triplesec.Encryptor { version : @triplesec_version }

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

  get_public_pgp_key: (username, cb) ->
    err = ret = null
    fields = "public_keys"
    await @config.request { endpoint : "user/lookup", params : {username, fields} }, defer err, res
    unless err?
      ret = res?.body?.them?.public_keys?.primary?.bundle
      err = new Error "Cannot find a public key for '#{@config.escape_user_content username}'" unless ret?
    cb err, ret

  #---------------

  get_devices : ({username}, cb) ->
    err = ret = null
    fields = "devices"
    await @config.request { endpoint : "user/lookup", params : { username, fields } }, defer err, res
    unless err?
      ret = res?.body?.them?.devices
      err = new Error "Cannot find devices for '#{@config.escape_user_content username}" unless ret?
    cb err, ret

  #---------------

  get_public_pgp_keys : (username, cb) ->
    err = ret = null
    fields = "public_keys"
    await @config.request { endpoint : "user/lookup", params : {username} }, defer err, res
    unless err?
      ret = res?.body?.them?.public_keys?.pgp_public_keys
      err = new Error "Cannot find a public key for '#{@config.escape_user_content username}'" unless ret?.length
    cb err, ret

  #---------------

  get_unlocked_private_primary_pgp_key : (pw, cb) ->
    esc = make_esc (err) -> cb err, null
    passphrase = new triplesec.Buffer pw
    await @config.request { method : "GET", endpoint : "me" }, esc defer res
    bundle = res?.body?.me?.private_keys?.primary?.bundle
    sk = err = null
    if bundle?
      tsenc = @get_tsenc_for_decryption { passphrase }
      await KeyManager.import_from_p3skb { raw: bundle }, esc defer sk
      await sk.unlock_p3skb { tsenc }, esc defer()
    err = null
    unless sk?
      err = new Error "Failed to get and unlock your private key"
    cb err, sk

  #---------------

  get_unlocked_private_pgp_keys : (pw, cb) ->
    esc = make_esc cb, "get_unlocked_private_pgp_keys"
    sks = []
    passphrase = new triplesec.Buffer pw
    tsenc = @get_tsenc_for_decryption { passphrase }
    await @config.request { method : "GET", endpoint : "me" }, esc defer res
    for sk in res?.body?.me?.private_keys?.all when (sk.type is @config.C.key.key_type.P3KSB_PRIVATE)
      await KeyManager.import_from_p3skb { raw: bundle }, esc defer sk
      await sk.unlock_p3skb { tsenc }, esc defer()
      sks.push sk
    cb err, sks

  #---------------

  export_my_private_key: (pw, cb) ->
    esc = make_esc cb, "export_my_private_key"
    err = armored_private = null
    passphrase = new triplesec.Buffer pw
    await @get_unlocked_private_primary_pgp_key pw, esc defer sk
    await sk.sign {}, esc defer()
    await sk.export_pgp_private_to_client {passphrase}, esc defer armored_private
    cb null, armored_private

  #---------------

  change_passphrase : (oldpw, newpw, cb) ->
    params = {}
    esc = make_esc cb, "change_password"
    await @pw_to_login { pw : oldpw }, esc defer params.login_session, params.hmac_pwh, salt
    await @get_unlocked_private_primary_pgp_key oldpw, esc defer sk
    await @gen_new_pwh { pw : newpw, salt }, esc defer params.pwh, params.pwh_version
    if sk?
      endpoint = "key/add"
      await sk.export_private_to_server { tsenc : @enc }, esc defer params.private_key
    else
      endpoint = "account/update"
    await @config.request { method : "POST", endpoint, params }, esc defer res
    cb null, res?.body

  #---------------

  # Run passphrase stretching on the given salt/passphrase 
  # combination, without side-effects.
  _cpp2_derive_passphrase_components : ( { tsenc, salt, passphrase}, cb) -> 
    key = new Buffer passphrase, 'utf8'
    {C} = @config
    tsenc or= new triplesec.Encryptor { version : @triplesec_version }
    await tsenc.resalt { salt }, defer keys
    km = keys.extra
    [pwh, _, _, lks_clienf_half ] = bufsplit km, [
      C.pwh.derived_key_bytes,
      C.nacl.eddsa_secret_key_bytes,
      C.nacl.dh_secret_key_bytes,
      C.device.lks_client_half_bytes
    ]
    cb null, { tsenc, pwh, lks_client_half }

  #---------------

  _cpp2_encrypt_lks_client_half : ( { me, client_half }, cb) ->
    ret = {}
    esc = make_esc cb, "_cpp2_encrypt_lks_client_half"
    for deviceid, device of me.devices
      for {kid,key_role} in device.keys when (key_role is @config.C.keys.key_role.ENCRYPTION)
        await kbpgp.ukm.import_armored_public { armored : kid }, esc defer km
        await kbpgp.kb.box { encrypt_for : kid, msg : client_half }, esc defer ret[kid]
    cb null, ret

  #---------------

  _cpp2_reencrypt_pgp_private_key : ( { me, old_ppc, new_ppc }, cb ) ->
    output = null
    if (key = me?.private_keys?.primary?.bundle)?
      await KeyManager.import_from_p3skb { armored : key }, esc km
      await km.unlock_p3skb { tsenc : old_ppc.tsenc }, esc defer()
      await km.export_private_to_server { tsenc : new_ppc.tsenc }, esc defer output
    cb null, output

  #---------------

  _cpp2_compute_lks_mask : ( { old_ppc, new_ppc}, cb) ->
    lks_mask = xor_buffers(old_ppc.lks_client_half, new_ppc.lks_client_half).toString('hex')
    cb null, lks_mask

  #---------------

  #
  # Use v2 of the passphrase change system, which changes the LKS mask
  # and also encrypt the LKS client half for all known encryption devices.
  # .. In addition to reencrypting PGP private keys...
  #
  # @param {string} old_pp The old passphrase
  # @param {string} new_pp The new passphrase
  # @param {callback<error>} cb Callback, will fire with an Error 
  #   if the update didn't work. 
  #
  change_passphrase_v2 : ( {old_pp, new_pp}, cb) -> 
    old_ppc = new_ppc = null
    esc = make_esc cb, "change_passphrase_v2" 

    await @config.request { method : "GET", endpoint : "me" }, esc defer me

    salt = new Buffer me.basics.salt, 'hex'

    await @_cpp2_derive_passphrase_components { tsenc : @enc, salt, passphrase : old_pp }, esc defer old_ppc
    await @_cpp2_derive_passphrase_components { salt, passphrase : new_pp }, esc defer new_ppc
    await @_cpp2_encrypt_lks_client_half { me, client_half : new_ppc.lks_client_half }, esc defer lksch
    await @_cpp2_reencrypt_pgp_private_key { me, old_ppc, new_ppc}, esc defer private_key
    await @_cpp2_compute_lks_mask { old_ppc, new_ppc }, esc defer lks_mask

    params = {
      pwh : new_ppc.pwh,
      pwh_version : @triplesec_version,
      pwh_version : me.basics.passphrase_generation,
      lks_mask,
      lks_client_half : JSON.stringify(lksch)
    }
    await @config.request { method : "POST", endpoint : "passphrase/replace", params }, esc defer()

    # Now reset our internal triplesec to the new one.
    @enc = new_ppc.tsenc
    cb null, new_ppc

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

