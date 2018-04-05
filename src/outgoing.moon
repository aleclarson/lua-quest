HttpClient = require 'http.client'
Incoming = require 'quest.incoming'
Headers = require 'http.headers'
Emitter = require 'emitter'
cqueues = require 'cqueues'
{:JSON} = require 'quest.inject'
{:monotime} = cqueues

-- TODO: Add stream timeout.
class OutgoingMessage extends Emitter
  new: (opts, headers) =>
    super!

    -- TODO: Add `opts.agent` for connection pooling
    @_stream = HttpClient.connect(opts)\new_stream!

    if headers == nil
      @headers = Headers.new!
    else
      @headers = headers
      if getmetatable(headers) ~= Headers.mt
        assert type(headers) == 'table', '`headers` must be an object, Headers instance, or nil'
        headers = Headers.new!
        for name, value in pairs @headers
          headers\upsert name, value
        @headers = headers

  get: (name) =>
    @headers\get name

  set: (name, value) =>
    @headers\upsert name, value

  append: (name, value) =>
    @headers\append name, value

  send_headers: (timeout) =>
    headers = @headers
    if headers == nil
      error 'Cannot send headers twice'
    @headers = nil

    stream = @_stream
    if @queue == nil
      return @_send stream, headers, timeout

    @queue\wrap -> @_send stream, headers, timeout
    return self

  write: (chunk, timeout) =>

    if type(chunk) ~= 'string'
      error 'Chunk must be a string'

    -- Use a write buffer if the headers are not sent.
    if @headers or @_buffer
      @_push chunk
      return true

    -- Write the chunk and return errors.
    @_stream\write_chunk chunk, false, timeout

  send: (chunk, timeout) =>
    stream = @_stream
    if stream == nil
      error 'Already sent'
    @_stream = nil

    @_res = Incoming stream, @queue
    if @queue == nil
      err, errno = @_end stream, chunk, timeout, @_res
      if err ~= nil
        return nil, err, errno
      return @_res

    @queue\wrap -> @_end stream, chunk, timeout, @_res
    return @_res

  destroy: =>
    stream = @_stream or @_res._stream
    stream.connection\close!
    return self

  _end: (stream, chunk, timeout, res) =>

    -- if not cqueues.running!
    --   error 'Must set req.queue or send from a cqueue'

    headers = @headers
    if headers ~= nil
      @headers = nil
      deadline = timeout and monotime! + timeout
      err, errno = @_send stream, headers, timeout
      return err, errno if err ~= nil
      timeout = deadline and deadline - monotime!

    if JSON and type(chunk) == 'table'
      chunk = JSON.encode chunk

    if chunk ~= nil and type(chunk) ~= 'string'
      error 'Chunk must be a string'

    ok, err, errno = stream\write_chunk chunk or '', true, timeout
    if not ok
      log.pale_red 'failed to send request'
      if @queue ~= nil
        @emit 'error', err, errno
      return err, errno

    -- TODO: What if req.queue exists, but res.queue is nil?
    res.headers, err, errno = stream\get_headers @timeout
    if err == nil
      res.status = res.headers\get ':status'

      if @queue ~= nil
        @emit 'response', res

      if res.queue ~= nil
        res\emit 'head', res.status, res.headers
        res\resume! if res.events.data
      return

    log.pale_red 'failed to get response headers'
    if @queue ~= nil
      res\emit 'error', err, errno
    return err, errno

  _send: (stream, headers, timeout) =>
    deadline = timeout and monotime! + timeout
    ok, err, errno = stream\write_headers headers, false, timeout
    if not ok
      log.red 'failed to write headers'
      if @queue ~= nil
        @emit 'error', err, errno
      return err, errno

    -- TODO: Check if significant blocking occurs.
    -- TODO: Check if flushing via loop is faster.
    if @_buffer ~= nil
      chunk = table.concat @_buffer, ''
      timeout = deadline and deadline - monotime!
      ok, err, errno = stream\write_chunk chunk, false, timeout
      if not ok
        log.red 'failed to write buffer'
        if @queue ~= nil
          @emit 'error', err, errno
        return err, errno

return OutgoingMessage
