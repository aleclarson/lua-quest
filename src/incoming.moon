Emitter = require 'emitter'
ce = require 'cqueues.errno'

class IncomingMessage extends Emitter
  new: (stream, queue) =>
    super()
    @queue = queue
    @_stream = stream
    @_paused = true
    @_stream.connection.onidle

  on: (name, listener) =>
    if name == 'data'
      if @queue == nil
        error 'Cannot listen for "data" events unless a `queue` exists'
      if @headers then @resume!
    super name, listener

  off: (name, listener) =>
    if name == 'data'
      pausing = listener == nil or @len(name) == 1
      if pausing then @pause!
    super name, listener

  json: (timeout) =>
    body = @_stream\get_body_as_string timeout

    -- Handle thrown and returned errors
    ok, err = pcall ->
      body, err = JSON.decode body
      return err

    err and nil or body, err

  read: (timeout) =>
    @_stream\get_body_as_string timeout

  read_chars: (n, timeout) =>
    @_stream\get_body_chars n, timeout

  read_line: (timeout) =>
    @_stream\get_body_until '\n', true, false, timeout

  read_until: (pattern, plain, include_pattern, timeout) =>
    if type(plain) == 'number'
      timeout, include_pattern, pattern = plain, false, false
    @_stream\get_body_until pattern, plain, include_pattern, timeout

  next_chunk: (timeout) =>
    @_stream\get_next_chunk timeout

  each_chunk: =>
    @_stream\each_chunk!

  resume: =>
    if @_paused
      @_paused = false
      @queue\wrap -> @_resume!
    return self

  pause: =>
    @_paused = true
    return self

  destroy: =>
    @_stream.connection\close!
    return self

  _resume: =>
    while true
      chunk, err, errno = @_stream\get_next_chunk!

      if @_paused and chunk
        ok, err, errno = @_stream\unget chunk
        break if ok

      if err or chunk == nil
        @_paused = true
        @emit 'error', err, errno if err
        break

      @emit 'data', chunk
      break if @_paused

    if @_stream.state == 'closed'
      @emit 'end'
      return

return IncomingMessage
