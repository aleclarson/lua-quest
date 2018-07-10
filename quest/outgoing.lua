local Incoming = require('quest.incoming')
local Headers = require('http.headers')
local Emitter = require('emitter')
local cq = require('cqueues')
local JSON
JSON = require('quest.inject').JSON
local connect
connect = require('http.client').connect
local monotime
monotime = cq.monotime
local OutgoingMessage
do
  local _class_0
  local _parent_0 = Emitter
  local _base_0 = {
    get = function(self, name)
      return self.headers:get(name)
    end,
    set = function(self, name, value)
      return self.headers:upsert(name, value)
    end,
    append = function(self, name, value)
      return self.headers:append(name, value)
    end,
    send_headers = function(self, timeout)
      assert(not self.opened, 'the headers are already sent')
      self.opened = true
      if self.queue == nil then
        return self:_open(timeout)
      end
      self.queue:wrap(self._open, self, timeout)
      return self
    end,
    write = function(self, chunk, timeout)
      assert(type(chunk) == 'string', 'chunk must be a string')
      if self.headers or self.buffer then
        self:_push(chunk)
        return true
      end
      return self.stream:write_chunk(chunk, false, timeout)
    end,
    send = function(self, chunk, timeout)
      assert(not self.sent, 'the request is already sent')
      self.sent = true
      if timeout == nil and type(chunk) == 'number' then
        chunk, timeout = nil, chunk
      end
      if self.queue ~= nil then
        self.queue:wrap(self._finish, self, chunk, timeout)
      else
        local ok, err, eno = self:_finish(chunk, timeout)
        if not ok then
          return nil, err, eno
        end
      end
      local res = Incoming(self.stream, self.queue)
      res.fd = self.fd
      res.version = self.version
      self.res = res
      if self.queue == nil then
        return self:_wait(res)
      end
      self.queue:wrap(self._wait, self, res)
      return res
    end,
    close = function(self)
      if self.res then
        return self.res:close()
      end
      if self.stream == nil then
        return 
      end
      local stream
      stream, self.stream = self.stream, nil
      local socket
      socket = stream.connection.socket
      if socket then
        socket:shutdown()
        cq.poll()
        cq.poll()
        socket:close()
      end
      if stream.state ~= 'closed' then
        stream:set_state('closed')
      end
    end,
    _open = function(self, timeout)
      local deadline = timeout and monotime() + timeout
      local ok, err, eno = self.stream:write_headers(self.headers, false, timeout)
      if not ok then
        if self.queue ~= nil then
          self:emit('error', err, eno)
        end
        return ok, err, eno
      end
      if self.buffer ~= nil then
        local chunk = table.concat(self.buffer, '')
        timeout = deadline and deadline - monotime()
        ok, err, eno = self.stream:write_chunk(chunk, false, timeout)
        if ok then
          return ok
        end
        if self.queue ~= nil then
          self:emit('error', err, eno)
        end
        return ok, err, eno
      end
      return true
    end,
    _finish = function(self, chunk, timeout)
      if not self.opened then
        self.opened = true
        local deadline = timeout and monotime() + timeout
        local ok, err, eno = self:_open(timeout)
        if not ok then
          return ok, err, eno
        end
        timeout = deadline and deadline - monotime()
      end
      if JSON and type(chunk) == 'table' then
        chunk = JSON.encode(chunk)
      end
      if chunk ~= nil and type(chunk) ~= 'string' then
        error('chunk must be a string or table')
      end
      local ok, err, eno = self.stream:write_chunk(chunk or '', true, timeout)
      if ok then
        return ok
      end
      if self.queue ~= nil then
        self:emit('error', err, eno)
      end
      return ok, err, eno
    end,
    _wait = function(self, res)
      if res.queue == nil then
        return res:_wait(self.timeout)
      end
      res.queue:wrap(res._wait, res, self.timeout)
      return res
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, opts, headers)
      _class_0.__parent.__init(self)
      local connection = assert(connect({
        tls = opts.scheme == 'https',
        host = opts.host,
        port = opts.port,
        path = not opts.host and opts.path or nil,
        version = opts.version
      }))
      local fd = connection.socket:pollfd()
      local shutdown
      shutdown = connection.shutdown
      connection.shutdown = function(self, dir)
        return shutdown(self, dir)
      end
      self.fd = fd
      self.stream = assert(connection:new_stream())
      self.version = connection.version
      if headers == nil then
        self.headers = Headers.new()
      else
        self.headers = headers
        if getmetatable(headers) ~= Headers.mt then
          assert(type(headers) == 'table', '`headers` must be an object, Headers instance, or nil')
          headers = Headers.new()
          for name, value in pairs(self.headers) do
            headers:upsert(name, value)
          end
          self.headers = headers
        end
      end
    end,
    __base = _base_0,
    __name = "OutgoingMessage",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  OutgoingMessage = _class_0
end
return OutgoingMessage