
triplesec = require "triplesec"
kbpgp = require 'kbpgp'
WordArray = triplesec.WordArray
{KeyManager} = kbpgp
{make_esc} = require 'iced-error'
{xor_buffers} = require '../base/util'
{athrow} = require('iced-utils').util
proofs = require 'keybase-proofs'

#=======================================================================================

# There's historically been trouble with the slice() operator on Browserify's
# buffers, so just do the safe/slow/stupid thing.
myslice = (buf, s, e) ->
  l = e - s
  out = new Buffer l
  for i in [0...l]
    out.writeUInt8(buf.readUInt8(i+s), i)
  out

bufsplit = (buf, lens) ->
  s = 0
  ret = []
  for l in lens
    e = s+l
    ret.push myslice(buf,s,e)
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
    cb pwh, @nacl.eddsa

  #---------------

  fix_signup_bundle : (bundle, cb) ->
    err = null
    nb = triplesec.V[@triplesec_version].salt_size
    await kbpgp.rand.SRF().random_bytes nb, defer salt
    await @scrypt_hash_passphrase { key : bundle.pw, salt, encoding : 'hex' }, defer bundle.pwh, secret32_eddsa
    await secret32_to_signing_kid { secret32 : secret32_eddsa }, defer err, bundle.pdpka5_kid
    bundle.salt = salt.toString 'hex'
    bundle.pwh_version = @triplesec_version
    delete bundle.pw
    cb err

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
    esc = make_esc cb, "pw_to_pwh"
    err = pwh = pwh_version = salt = null
    params = { email_or_username, uid, pdpka_login : true }
    await @config.request { method : "GET", endpoint : 'getsalt', params }, esc defer res
    if err? then # noop
    else if not ((got = res?.body?.pwh_version) is @triplesec_version)
      err = new Error "Can only support PW hash version #{@triplesec_version}; got #{got} for #{@config.escape_user_content email_or_username}"
    else
      salt = new triplesec.Buffer res.body.salt, 'hex'
      await @scrypt_hash_passphrase { salt, key : pw, encoding : null }, defer pwh, secret32_eddsa
      await secret32_to_signing_km { secret32 : pwh }, esc defer pdpka4_km
      await secret32_to_signing_km { secret32 : secret32_eddsa }, esc defer pdpka5_km
      pwh_version = @triplesec_version
    cb err, pwh, pwh_version, salt, res?.body?.login_session, pdpka4_km, pdpka5_km

  #---------------

  pw_to_login : ({pw, email_or_username, hostname, uid}, cb) ->
    esc = make_esc cb, "pw_to_login"
    login_session = hmac_pwh = null
    await @pw_to_pwh { pw, email_or_username, uid }, esc defer pwh, pwh_version, salt, login_session_b64, pdpka4_km, pdpka5_km
    await @pwh_to_login_params { hostname, login_session_b64, pwh, email_or_username, uid, pdpka5_km, pdpka4_km }, esc defer { login_session, hmac_pwh, pdpka4, pdpka5 }
    cb null, login_session, hmac_pwh, salt, pdpka4, pdpka5

  #---------------

  pwh_to_login_params : ({hostname, login_session_b64, pwh, email_or_username, uid, pdpka4_km, pdpka5_km}, cb) ->
    esc = make_esc cb, "pwh_to_login_params"

    login_session = new triplesec.Buffer login_session_b64, 'base64'
    # Make a new HMAC-SHA512'er, and the key is the output of the
    hmac = new triplesec.HMAC(WordArray.from_buffer(pwh))
    hmac_pwh = hmac.update(WordArray.from_buffer(login_session)).finalize().to_hex()
    session = login_session = login_session_b64
    user = to_user { email_or_username, uid }
    await generate_pdpka { km : pdpka4_km, user, session, hostname }, esc defer pdpka4
    await generate_pdpka { km : pdpka5_km, user, session, hostname }, esc defer pdpka5
    cb null, { login_session, hmac_pwh, pdpka4, pdpka5  }

  #---------------

  _change_passphrase_compute_login : ({hostname, uid, login_session_b64, pwh, eddsa}, cb) ->
    esc = make_esc cb, "_change_passphrase_compute_login"
    await secret32_to_signing_km { secret32 : pwh }, esc defer pdpka4_km
    await secret32_to_signing_km { secret32 : eddsa }, esc defer pdpka5_km
    await @pwh_to_login_params { hostname, login_session_b64, uid, pwh, pdpka4_km, pdpka5_km }, esc defer { hmac_pwh, pdpka4, pdpka5 }
    cb null, hmac_pwh, pdpka4, pdpka5

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
    @get_unlocked_private_pgp_key { pw }, cb

  #---------------

  get_unlocked_private_pgp_key : ({pw, kid, no_check_keys, time_travel}, cb) ->
    esc = make_esc (err) -> cb err, null
    passphrase = new triplesec.Buffer pw
    await @config.request { method : "GET", endpoint : "me" }, esc defer res

    bundle = null

    if kid?
      for sk in res?.body?.me?.private_keys?.all when sk.kid is kid
        break if (bundle = sk.bundle)?
    else
      bundle = res?.body?.me?.private_keys?.primary?.bundle

    sk = err = null
    if bundle?
      tsenc = @get_tsenc_for_decryption { passphrase }
      await KeyManager.import_from_p3skb { raw: bundle, no_check_keys, time_travel }, esc defer sk
      await sk.unlock_p3skb { tsenc, no_check_keys, time_travel }, esc defer()
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
      await KeyManager.import_from_p3skb { raw: sk.bundle }, esc defer sk
      await sk.unlock_p3skb { tsenc : tsenc.clone() }, esc defer()
      sks.push sk
    cb err, sks

  #---------------

  export_my_private_key: ({kid, pw, no_check_keys, time_travel}, cb) ->
    esc = make_esc cb, "export_my_private_key"
    err = armored_private = null
    passphrase = new triplesec.Buffer pw
    await @get_unlocked_private_pgp_key { kid, pw, no_check_keys, time_travel }, esc defer sk
    await sk.sign {}, esc defer()
    await sk.export_pgp_private_to_client {passphrase}, esc defer armored_private
    cb null, armored_private

  #---------------

  # Run passphrase stretching on the given salt/passphrase
  # combination, without side-effects.
  _change_passphrase_derive_passphrase_components : ( { tsenc, salt, passphrase}, cb) ->
    esc = make_esc cb, "_change_passphrase_derive_passphrase_components"
    key = new Buffer passphrase, 'utf8'
    {C} = @config
    tsenc or= new triplesec.Encryptor { version : @triplesec_version }
    tsenc.set_key key
    await tsenc.resalt { @extra_keymaterial, salt }, esc defer keys
    km = keys.extra
    [pwh, eddsa, _, lks_client_half ] = bufsplit km, [
      C.pwh.derived_key_bytes,
      C.nacl.eddsa_secret_key_bytes,
      C.nacl.dh_secret_key_bytes,
      C.device.lks_client_half_bytes
    ]
    cb null, { tsenc, pwh, lks_client_half, eddsa }

  #---------------

  _change_passphrase_encrypt_lks_client_half : ( { me, client_half }, cb) ->
    ret = {}
    esc = make_esc cb, "_change_passphrase_encrypt_lks_client_half"
    for deviceid, {keys} of me.devices
      for {kid,key_role} in keys when (key_role is @config.C.key.key_role.ENCRYPTION)
        await kbpgp.ukm.import_armored_public { armored : kid }, esc defer km
        await kbpgp.kb.box { encrypt_for : km, msg : client_half }, esc defer ret[kid]
    cb null, ret

  #---------------

  _change_passphrase_reencrypt_pgp_private_keys : ( { me, old_ppc, new_ppc, exclude_kids }, cb ) ->
    outputs = []
    exclude_kids or= []
    esc = make_esc cb, "_change_passphrase_reencrypt_pgp_private_key"
    for {kid,bundle} in (me?.private_keys?.all or []) when not (kid in exclude_kids)
      await KeyManager.import_from_p3skb { armored : bundle }, esc defer km
      await km.unlock_p3skb { tsenc : old_ppc.tsenc.clone() }, esc defer()
      {tsenc,passphrase_generation} = new_ppc
      await km.export_private_to_server {tsenc, passphrase_generation}, esc defer output
      outputs.push output
    cb null, outputs

  #---------------

  _change_passphrase_compute_lks_mask : ( { old_ppc, new_ppc}, cb) ->
    lks_mask = xor_buffers(old_ppc.lks_client_half, new_ppc.lks_client_half).toString('hex')
    cb null, lks_mask

  #---------------

  # Reset the user's passphrase given then authentication link 'l'.
  reset_passphrase : ( {new_pp, uid, hostname, l}, cb) ->
    esc = make_esc cb, "reset_passphrase"
    params = { uid }
    await @config.request { method : "GET", endpoint : 'getsalt', params }, esc defer res
    salt = new triplesec.Buffer res.body.salt, 'hex'
    await @scrypt_hash_passphrase { salt, key : new_pp, encoding : null }, defer pwh, secret32_eddsa
    await secret32_to_signing_kid { secret32 : pwh }, esc defer pdpka4_kid
    await secret32_to_signing_kid { secret32 : secret32_eddsa }, esc defer pdpka5_kid

    params = {
      pdpka4_kid : pdpka4_kid
      pdpka5_kid : pdpka5_kid
      l : l
    }
    await @config.request { method : "POST", endpoint : "passphrase/reset", params }, esc defer res
    cb null

  #---------------

  #
  # Use v2 of the passphrase change system, which changes the LKS mask
  # and also encrypts the LKS client half for all known encryption devices.
  # .. In addition to reencrypting PGP private keys...
  #
  # @param {string} old_pp The old passphrase
  # @param {string} new_pp The new passphrase
  # @param {vec<string>} exclude_kids Don't reencrypt these KIDs or include
  #   them in the upload.  Primarily useful for testing
  # @param {callback<error>} cb Callback, will fire with an Error
  #   if the update didn't work.
  #
  change_passphrase : ( {old_pp, new_pp, exclude_kids, hostname}, cb) ->
    old_ppc = new_ppc = null
    esc = make_esc cb, "change_passphrase"

    params = { make_login_session : 1 }
    await @config.request { method : "GET", endpoint : "me", params }, esc defer res
    unless (me = res?.body?.me)? and (login_session_b64 = res?.body?.login_session)?
      await athrow (new Error "Cannot load 'me' from server"), esc defer()

    salt = new Buffer me.basics.salt, 'hex'

    await @_change_passphrase_derive_passphrase_components { tsenc : @enc, salt, passphrase : old_pp }, esc defer old_ppc
    await @_change_passphrase_derive_passphrase_components { salt, passphrase : new_pp }, esc defer new_ppc

    await @_change_passphrase_compute_login { uid : me.id, login_session_b64, pwh : old_ppc.pwh, eddsa : old_ppc.eddsa, hostname }, esc defer hmac_pwh, old_pdpka4, old_pdpka5

    old_ppc.passphrase_generation = me.basics.passphrase_generation
    new_ppc.passphrase_generation = old_ppc.passphrase_generation + 1

    await @_change_passphrase_encrypt_lks_client_half { me, client_half : new_ppc.lks_client_half }, esc defer lksch
    await @_change_passphrase_reencrypt_pgp_private_keys { me, old_ppc, new_ppc, exclude_kids}, esc defer private_keys
    await @_change_passphrase_compute_lks_mask { old_ppc, new_ppc }, esc defer lks_mask
    await secret32_to_signing_kid { secret32 : new_ppc.eddsa }, esc defer pdpka5_kid

    params = {
      hmac_pwh : hmac_pwh
      old_pdpka4 : old_pdpka4
      old_pdpka5 : old_pdpka5
      pdpka5_kid : pdpka5_kid
      login_session : login_session_b64
      pwh : new_ppc.pwh.toString('hex'),
      pwh_version : @triplesec_version,
      ppgen : old_ppc.passphrase_generation,
      lks_mask,
      lks_client_halves : JSON.stringify(lksch),
      private_keys
    }
    await @config.request { method : "POST", endpoint : "passphrase/replace", params }, esc defer res

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

exports.secret32_to_signing_km = secret32_to_signing_km = ({secret32}, cb) ->
  ret = err = null
  await kbpgp.kb.KeyManager.generate { seed : secret32, split : false }, defer err, km
  cb err, km

#=======================================================================================

exports.secret32_to_signing_kid = secret32_to_signing_kid = ({secret32}, cb) ->
  ret = err = null
  await secret32_to_signing_km { secret32 }, defer err, km
  unless err?
    await km.export_public {}, defer err, kid
  cb err, kid, km

#=======================================================================================

exports.generate_pdpka = generate_pdpka = ({km, session, user, hostname}, cb) ->
  await kbpgp.rand.SRF().random_bytes 16, defer nonce
  arg =
    sig_eng : km.make_sig_eng()
    host : hostname
    user : local : user
  arg.nonce = nonce if nonce?
  arg.session = session if session?
  eng = new proofs.Auth arg
  await eng.generate defer err, sig
  cb err, sig?.armored

#=======================================================================================

to_user = ({email_or_username, uid}) ->
  user = {}
  if uid? then user.uid = uid
  if email_or_username?
    if email_or_username.indexOf('@') >= 0 then user.email = email_or_username
    else user.username = email_or_username
  user

#=======================================================================================

