local noop
noop = function() end
local defaults = {
  JSON = function()
    local load
    load = function()
      return require('json')
    end
    return select(2, xpcall(load, noop))
  end
}
return setmetatable({ }, {
  __index = function(self, key)
    local val = rawget(self, key)
    if val == nil then
      local load = defaults[key]
      if load then
        val = load()
        rawset(self, key, val)
      end
    end
    return val
  end
})