
##=======================================================================

exports.xor_buffers = xor_buffers = (buffers...) ->
  err = res = null
  if buffers.length < 2
    throw new Error "need 2 or more buffers"
  l = buffers[0].length
  res = Buffer.alloc(l)
  for b,i in buffers
    if b.length isnt l
      err = new Error "Buffer #{i} is length #{b.length} != #{l}"
      break
    for c,j in b
      res[j] ^= c
  res

##=======================================================================
