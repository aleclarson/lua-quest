Incoming = require 'quest.incoming'
Headers = require 'http.headers'
Emitter = require 'emitter'
cq = require 'cqueues'
{:JSON} = require 'quest.inject'
{:connect} = require 'http.client'
{:monotime} = cq

class OutgoingMessage extends Emitter
  new: (opts, headers) =>
    super!

    -- TODO: Use connection pooling
    connection = assert connect
      tls: opts.scheme == 'https'
      host: opts.host
      port: opts.port
      path: not opts.host and opts.path or nil
      version: opts.version

    fd = connection.socket\pollfd!

    {:shutdown} = connection
    connection.shutdown = (dir) =>
      shutdown self, dir

    @fd = fd
    @stream = assert connection\new_stream!
    @version = connection.version

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
    assert not @opened, 'the headers are already sent'
    @opened = true

    if @queue == nil
      return @_open timeout

    @queue\wrap @_open, self, timeout
    return self

  write: (chunk, timeout) =>
    assert type(chunk) == 'string', 'chunk must be a string'

    -- Use a write buffer if the headers are not sent.
    if @headers or @buffer
      @_push chunk
      return true

    -- Write the chunk and return errors.
    @stream\write_chunk chunk, false, timeout

  send: (chunk, timeout) =>
    assert not @sent, 'the request is already sent'
    @sent = true

    if timeout == nil and type(chunk) == 'number'
      chunk, timeout = nil, chunk

    if @queue ~= nil
      @queue\wrap @_finish, self, chunk, timeout
    else
      ok, err, eno = @_finish chunk, timeout
      return nil, err, eno if not ok

    res = Incoming @stream, @queue
    res.fd = @fd
    res.version = @version
    @res = res

    if @queue == nil
      return @_wait res

    @queue\wrap @_wait, self, res
    return res

  close: =>
    return @res\close! if @res

    return if @stream == nil
    stream, @stream = @stream, nil

    {:socket} = stream.connection
    if socket
      socket\shutdown!
      cq.poll!
      cq.poll!
      socket\close!

    if stream.state ~= 'closed'
      stream\set_state 'closed'
    return

  -- Send the request headers and write buffer.
  _open: (timeout) =>
    deadline = timeout and monotime! + timeout
    ok, err, eno = @stream\write_headers @headers, false, timeout
    if not ok
      if @queue ~= nil
        @emit 'error', err, eno
      return ok, err, eno

    -- TODO: Check if flush loop is faster.
    if @buffer ~= nil
      chunk = table.concat @buffer, ''
      timeout = deadline and deadline - monotime!
      ok, err, eno = @stream\write_chunk chunk, false, timeout
      return ok if ok
      if @queue ~= nil
        @emit 'error', err, eno
      return ok, err, eno
    return true

  -- Finish the request.
  _finish: (chunk, timeout) =>

    if not @opened
      @opened = true
      deadline = timeout and monotime! + timeout
      ok, err, eno = @_open timeout
      return ok, err, eno if not ok
      timeout = deadline and deadline - monotime!

    if JSON and type(chunk) == 'table'
      chunk = JSON.encode chunk

    if chunk ~= nil and type(chunk) ~= 'string'
      error 'chunk must be a string or table'

    ok, err, eno = @stream\write_chunk chunk or '', true, timeout
    return ok if ok
    if @queue ~= nil
      @emit 'error', err, eno
    return ok, err, eno

  -- Wait for the response headers.
  _wait: (res) =>

    if res.queue == nil
      return res\_wait @timeout

    res.queue\wrap res._wait, res, @timeout
    return res

return OutgoingMessage
