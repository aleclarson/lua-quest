Emitter = require 'emitter'
reasons = require 'http.h1_reason_phrases'
ce = require 'cqueues.errno'
cq = require 'cqueues'

{:JSON} = require 'quest.inject'

class IncomingMessage extends Emitter
  new: (stream, queue) =>
    super()
    @queue = queue
    @stream = stream

    -- Ensure the "close" event is emitted.
    stream.connection\onidle ->
      -- Ensure `closed` equals true once the response is processed.
      if stream.close_when_done and stream.state == 'closed'
        @_onclose!

  on: (name, listener) =>
    if name == 'data'
      assert @queue, '"data" events require `queue` to exist'
      if @stream and @headers then @resume!
    super name, listener

  off: (name, listener) =>
    if name == 'data'
      pausing = listener == nil or @len(name) == 1
      if pausing then @pause!
    super name, listener

  json: (timeout) =>
    local body, err

    -- Handle thrown and returned errors
    ok, err = pcall ->
      body, err = @stream\get_body_as_string timeout
      body, err = JSON.decode body if not err
      return err

    if err then nil, err
    else body

  next: (timeout) =>
    @stream\get_next_chunk timeout

  read: (timeout) =>
    @stream\get_body_as_string timeout

  read_chars: (n, timeout) =>
    @stream\get_body_chars n, timeout

  read_line: (timeout) =>
    @stream\get_body_until '\n', true, false, timeout

  read_until: (pattern, plain, include_pattern, timeout) =>
    if type(plain) == 'number'
      timeout, include_pattern, plain = plain, false, false
    @stream\get_body_until pattern, plain, include_pattern, timeout

  resume: =>
    assert @stream, 'cannot resume after close'
    assert not @ended, 'cannot resume after end'
    unless @reading
      @reading = true
      @queue\wrap @_resume, self
    return

  pause: =>
    @reading = false
    return self

  close: =>
    {:stream} = self
    return if stream == nil
    @_onclose!

    if stream.state ~= 'closed'
      stream\set_state 'closed'
      @reading = false
    return

  -- Wait for the response headers.
  _wait: (timeout) =>
    local err, eno
    ok, err = pcall ->
      @headers, err, eno = @stream\get_headers timeout
      err

    if err == nil
      status = @headers\get ':status'
      @status = tonumber status
      @ok = @status >= 200 and @status < 300
      @reason = status..' '..reasons[status] if not @ok

      if @queue ~= nil

        -- Signal the headers are available.
        @emit 'status', @status, @ok

        -- Begin reading if "data" listeners exist.
        @resume! if @events.data

      return self

    if @queue ~= nil
      @emit 'error', err, eno

    return nil, err, eno

  -- Read from the socket until paused or EOF.
  _resume: =>
    stream = @stream

    -- Avoid reading if no one is listening.
    return @close! unless @events.data

    local err, eno
    while true
      chunk, err, eno = stream\get_next_chunk!
      break if chunk == nil

      if @reading
        @emit 'data', chunk
      else
        ok, err, eno = stream\unget chunk
        @emit 'error', err, eno if not ok
        return

    -- The socket was closed.
    return if @stream == nil

    if err ~= nil
      @emit 'error', err, eno
      return @close!

    if @reading
      @reading = false
      @ended = true
      @emit 'end'
    return

  -- Emit the "close" event once.
  _onclose: =>
    @stream.connection\onidle nil
    @stream = nil
    if @queue ~= nil
      @queue\wrap @emit, self, 'close'
    return

return IncomingMessage
