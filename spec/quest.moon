quest = require 'quest'
cq = require 'cqueues'

HOME = os.getenv 'HOME'

test 'async quest.fetch', ->
  sock = quest.sock HOME .. '/.cara/cdn.sock'
  sock.queue = loop

  res = sock\fetch '/b/assets.json',
    'x-bucket': 'coinyada'

  res\on 'head', log.pale_yellow
  res\on 'data', log.pale_green
  res\on 'error', fail
  res\on 'end', pass

  async!
  return

xtest 'sync event-stream', ->
  sock = quest.sock HOME .. '/.wch/server.sock'
  req = sock\request '/events',
    accept: 'text/event-stream'

  started = cq.monotime!
  res, err, errno = req\send
    root: os.getenv 'PWD'

  assert err == nil
  log.pale_green 'got response in', 1000 * (cq.monotime! - started), 'ms'
  for name, value in res.headers\each!
    log.blue name, '=>', value

  for chunk in res\each_chunk!
    log.yellow chunk

  pass!
  return

xtest 'async event-stream', ->
  sock = quest.sock HOME .. '/.wch/server.sock'
  req = sock\request '/events',
    accept: 'text/event-stream'
  req.queue = loop
  req\on 'error', fail

  started = cq.monotime!
  res = req\send
    root: os.getenv 'PWD'

  res\on 'error', fail
  res\on 'data', log.yellow
  res\on 'end', pass

  req\on 'response', ->
    log.pale_green 'got response in', 1000 * (cq.monotime! - started), 'ms'
    assert req.queue == cq.running!
    for name, value in res.headers\each!
      log.blue name, '=>', value

  async!
  return
