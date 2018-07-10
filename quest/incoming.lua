local Emitter = require('emitter')
local reasons = require('http.h1_reason_phrases')
local ce = require('cqueues.errno')
local cq = require('cqueues')
local JSON
JSON = require('quest.inject').JSON
local IncomingMessage
do
  local _class_0
  local _parent_0 = Emitter
  local _base_0 = {
    on = function(self, name, listener)
      if name == 'data' then
        assert(self.queue, '"data" events require `queue` to exist')
        if self.stream and self.headers then
          self:resume()
        end
      end
      return _class_0.__parent.__base.on(self, name, listener)
    end,
    off = function(self, name, listener)
      if name == 'data' then
        local pausing = listener == nil or self:len(name) == 1
        if pausing then
          self:pause()
        end
      end
      return _class_0.__parent.__base.off(self, name, listener)
    end,
    json = function(self, timeout)
      local body, err
      local ok
      ok, err = pcall(function()
        body, err = self.stream:get_body_as_string(timeout)
        if not err then
          body, err = JSON.decode(body)
        end
        return err
      end)
      if err then
        return nil, err
      else
        return body
      end
    end,
    next = function(self, timeout)
      return self.stream:get_next_chunk(timeout)
    end,
    read = function(self, timeout)
      return self.stream:get_body_as_string(timeout)
    end,
    read_chars = function(self, n, timeout)
      return self.stream:get_body_chars(n, timeout)
    end,
    read_line = function(self, timeout)
      return self.stream:get_body_until('\n', true, false, timeout)
    end,
    read_until = function(self, pattern, plain, include_pattern, timeout)
      if type(plain) == 'number' then
        timeout, include_pattern, plain = plain, false, false
      end
      return self.stream:get_body_until(pattern, plain, include_pattern, timeout)
    end,
    resume = function(self)
      assert(self.stream, 'cannot resume after close')
      assert(not self.ended, 'cannot resume after end')
      if not (self.reading) then
        self.reading = true
        self.queue:wrap(self._resume, self)
      end
    end,
    pause = function(self)
      self.reading = false
      return self
    end,
    close = function(self)
      local stream
      stream = self.stream
      if stream == nil then
        return 
      end
      self:_onclose()
      if stream.state ~= 'closed' then
        stream:set_state('closed')
        self.reading = false
      end
    end,
    _wait = function(self, timeout)
      local err, eno
      local ok
      ok, err = pcall(function()
        self.headers, err, eno = self.stream:get_headers(timeout)
        return err
      end)
      if err == nil then
        local status = self.headers:get(':status')
        self.status = tonumber(status)
        self.ok = self.status >= 200 and self.status < 300
        if not self.ok then
          self.reason = status .. ' ' .. reasons[status]
        end
        if self.queue ~= nil then
          self:emit('status', self.status, self.ok)
          if self.events.data then
            self:resume()
          end
        end
        return self
      end
      if self.queue ~= nil then
        self:emit('error', err, eno)
      end
      return nil, err, eno
    end,
    _resume = function(self)
      local stream = self.stream
      if not (self.events.data) then
        return self:close()
      end
      local err, eno
      while true do
        local chunk
        chunk, err, eno = stream:get_next_chunk()
        if chunk == nil then
          break
        end
        if self.reading then
          self:emit('data', chunk)
        else
          local ok
          ok, err, eno = stream:unget(chunk)
          if not ok then
            self:emit('error', err, eno)
          end
          return 
        end
      end
      if self.stream == nil then
        return 
      end
      if err ~= nil then
        self:emit('error', err, eno)
        return self:close()
      end
      if self.reading then
        self.reading = false
        self.ended = true
        self:emit('end')
      end
    end,
    _onclose = function(self)
      self.stream.connection:onidle(nil)
      self.stream = nil
      if self.queue ~= nil then
        self.queue:wrap(self.emit, self, 'close')
      end
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, stream, queue)
      _class_0.__parent.__init(self)
      self.queue = queue
      self.stream = stream
      return stream.connection:onidle(function()
        if stream.close_when_done and stream.state == 'closed' then
          return self:_onclose()
        end
      end)
    end,
    __base = _base_0,
    __name = "IncomingMessage",
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
  IncomingMessage = _class_0
end
return IncomingMessage