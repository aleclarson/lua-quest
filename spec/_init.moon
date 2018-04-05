cs = require 'cqueues.socket'
cq = require 'cqueues'

if DEBUG
  trim = (s) -> s\match '^%s*(.-)%s*$'

  -- Print any socket writes.
  local xwrite
  xwrite = cs.interpose 'xwrite', (...) ->
    str = trim select 2, ...
    if str ~= '' then log.pale_yellow 'xwrite:', str
    return xwrite ...

  -- Print stream state changes.
  h1_stream = require 'http.h1_stream'
  set_state = h1_stream.set_state
  h1_stream.set_state = (state) =>
    log.pale_yellow 'set_state:', state
    return set_state self, state

  -- Start the debugger on unhandled errors.
  if dbg ~= nil
    Emitter = require 'emitter'
    Emitter.setFallback 'error', (err) -> dbg!

_G.co = coroutine
co.run = (fn) -> co.resume co.create fn
co.every = (delay, fn) ->
  time = cq.monotime!
  return co.create ->
    while true
      now = cq.monotime!
      if (now - time) >= delay
        time = now
        break if fn!
      cq.poll!

_G.loop = cq.new!
step -> loop\step!

loop\attach co.every 5, ->
  log.coal '(tick)'
