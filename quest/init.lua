local uri_patts = require('lpeg_patterns.uri')
local Incoming = require('quest.incoming')
local Outgoing = require('quest.outgoing')
local util = require('http.util')
local lpeg = require('lpeg')
local cq = require('cqueues')
local EOF = lpeg.P(-1)
local uri_patt = uri_patts.uri * EOF
if rawget(_G, '_DEV') == true then
  local new = Outgoing
  Outgoing = function(...)
    local ok, req = dbg.call(new, ...)
    if ok then
      return req
    end
  end
end
local quest
quest = function(self, verb, uri, headers)
  if type(uri) ~= 'table' then
    uri = assert(uri_patt:match(uri), 'invalid URI')
  end
  uri.port = uri.port or util.scheme_to_port[uri.scheme]
  uri.version = uri.version or 1.1
  local req = Outgoing(uri, headers)
  req["for"] = verb .. ' ' .. dbg.pretty(uri)
  local path = uri.query and uri.path .. '?' .. uri.query or uri.path
  local authority = util.to_authority(uri.host, uri.port, uri.scheme)
  req:set(':authority', authority)
  req:set(':scheme', uri.scheme)
  req:set(':method', verb)
  req:set(':path', path)
  return req
end
quest = setmetatable({ }, {
  __call = quest
})
quest.fetch = function(uri, headers)
  return quest('GET', uri, headers):send()
end
local sock_mt
quest.sock = function(path)
  assert(type(path) == 'string', 'socket path must be a string')
  return setmetatable({
    path = path
  }, sock_mt)
end
local sock_request
sock_request = function(self, verb, path, headers)
  if type(path) ~= 'string' then
    headers, path, verb = path, verb, 'GET'
  end
  assert(type(path) == 'string', '`path` must be a string')
  local req = Outgoing({
    path = self.path,
    version = 1.1
  }, headers)
  req["for"] = verb .. ' ' .. self.path .. '~' .. path
  req.queue = self.queue
  req:set(':authority', 'localhost')
  req:set(':scheme', 'http')
  req:set(':method', verb)
  req:set(':path', path)
  return req
end
sock_mt = {
  request = sock_request,
  fetch = function(self, uri, headers)
    return quest.fetch(self:request('GET', uri, headers))
  end
}
sock_mt.__index = sock_mt
return quest