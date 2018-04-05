local Emitter = require('emitter')
local ce = require('cqueues.errno')
local IncomingMessage
do
  local _class_0
  local _parent_0 = Emitter
  local _base_0 = {
    on = function(self, name, listener)
      if name == 'data' then
        if self.queue == nil then
          error('Cannot listen for "data" events unless a `queue` exists')
        end
        if self.headers then
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
      local body = self._stream:get_body_as_string(timeout)
      local ok, err = pcall(function()
        body, err = JSON.decode(body)
        return err
      end)
      return err and nil or body, err
    end,
    read = function(self, timeout)
      return self._stream:get_body_as_string(timeout)
    end,
    read_chars = function(self, n, timeout)
      return self._stream:get_body_chars(n, timeout)
    end,
    read_line = function(self, timeout)
      return self._stream:get_body_until('\n', true, false, timeout)
    end,
    read_until = function(self, pattern, plain, include_pattern, timeout)
      if type(plain) == 'number' then
        timeout, include_pattern, pattern = plain, false, false
      end
      return self._stream:get_body_until(pattern, plain, include_pattern, timeout)
    end,
    next_chunk = function(self, timeout)
      return self._stream:get_next_chunk(timeout)
    end,
    each_chunk = function(self)
      return self._stream:each_chunk()
    end,
    resume = function(self)
      if self._paused then
        self._paused = false
        self.queue:wrap(function()
          return self:_resume()
        end)
      end
      return self
    end,
    pause = function(self)
      self._paused = true
      return self
    end,
    destroy = function(self)
      self._stream.connection:close()
      return self
    end,
    _resume = function(self)
      while true do
        local chunk, err, errno = self._stream:get_next_chunk()
        if self._paused and chunk then
          local ok
          ok, err, errno = self._stream:unget(chunk)
          if ok then
            break
          end
        end
        if err or chunk == nil then
          self._paused = true
          if err then
            self:emit('error', err, errno)
          end
          break
        end
        self:emit('data', chunk)
        if self._paused then
          break
        end
      end
      if self._stream.state == 'closed' then
        self:emit('end')
        return 
      end
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, stream, queue)
      _class_0.__parent.__init(self)
      self.queue = queue
      self._stream = stream
      self._paused = true
      return self._stream.connection.onidle
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