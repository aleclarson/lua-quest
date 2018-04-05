local HttpClient = require('http.client')
local Incoming = require('quest.incoming')
local Headers = require('http.headers')
local Emitter = require('emitter')
local cqueues = require('cqueues')
local JSON
JSON = require('quest.inject').JSON
local monotime
monotime = cqueues.monotime
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
      local headers = self.headers
      if headers == nil then
        error('Cannot send headers twice')
      end
      self.headers = nil
      local stream = self._stream
      if self.queue == nil then
        return self:_send(stream, headers, timeout)
      end
      self.queue:wrap(function()
        return self:_send(stream, headers, timeout)
      end)
      return self
    end,
    write = function(self, chunk, timeout)
      if type(chunk) ~= 'string' then
        error('Chunk must be a string')
      end
      if self.headers or self._buffer then
        self:_push(chunk)
        return true
      end
      return self._stream:write_chunk(chunk, false, timeout)
    end,
    send = function(self, chunk, timeout)
      local stream = self._stream
      if stream == nil then
        error('Already sent')
      end
      self._stream = nil
      self._res = Incoming(stream, self.queue)
      if self.queue == nil then
        local err, errno = self:_end(stream, chunk, timeout, self._res)
        if err ~= nil then
          return nil, err, errno
        end
        return self._res
      end
      self.queue:wrap(function()
        return self:_end(stream, chunk, timeout, self._res)
      end)
      return self._res
    end,
    destroy = function(self)
      local stream = self._stream or self._res._stream
      stream.connection:close()
      return self
    end,
    _end = function(self, stream, chunk, timeout, res)
      local headers = self.headers
      if headers ~= nil then
        self.headers = nil
        local deadline = timeout and monotime() + timeout
        local err, errno = self:_send(stream, headers, timeout)
        if err ~= nil then
          return err, errno
        end
        timeout = deadline and deadline - monotime()
      end
      if JSON and type(chunk) == 'table' then
        chunk = JSON.encode(chunk)
      end
      if chunk ~= nil and type(chunk) ~= 'string' then
        error('Chunk must be a string')
      end
      local ok, err, errno = stream:write_chunk(chunk or '', true, timeout)
      if not ok then
        log.pale_red('failed to send request')
        if self.queue ~= nil then
          self:emit('error', err, errno)
        end
        return err, errno
      end
      res.headers, err, errno = stream:get_headers(self.timeout)
      if err == nil then
        res.status = res.headers:get(':status')
        if self.queue ~= nil then
          self:emit('response', res)
        end
        if res.queue ~= nil then
          res:emit('head', res.status, res.headers)
          if res.events.data then
            res:resume()
          end
        end
        return 
      end
      log.pale_red('failed to get response headers')
      if self.queue ~= nil then
        res:emit('error', err, errno)
      end
      return err, errno
    end,
    _send = function(self, stream, headers, timeout)
      local deadline = timeout and monotime() + timeout
      local ok, err, errno = stream:write_headers(headers, false, timeout)
      if not ok then
        log.red('failed to write headers')
        if self.queue ~= nil then
          self:emit('error', err, errno)
        end
        return err, errno
      end
      if self._buffer ~= nil then
        local chunk = table.concat(self._buffer, '')
        timeout = deadline and deadline - monotime()
        ok, err, errno = stream:write_chunk(chunk, false, timeout)
        if not ok then
          log.red('failed to write buffer')
          if self.queue ~= nil then
            self:emit('error', err, errno)
          end
          return err, errno
        end
      end
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, opts, headers)
      _class_0.__parent.__init(self)
      self._stream = HttpClient.connect(opts):new_stream()
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