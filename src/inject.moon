
noop = ->
defaults =

  JSON: ->
    load = -> require 'json'
    select 2, xpcall load, noop

return setmetatable {}, __index: (key) =>
  val = rawget self, key
  if val == nil
    load = defaults[key]
    if load
      val = load!
      rawset self, key, val
  return val
