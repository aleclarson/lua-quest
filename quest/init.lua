local JSON, uri_patts, Incoming, Outgoing, util, lpeg, cq, EOF, uri_patt, quest, sock_bind, sock_request, sock_mt
JSON = require('quest.inject').JSON
uri_patts = require('lpeg_patterns.uri')
Incoming = require('quest.incoming')
Outgoing = require('quest.outgoing')
util = require('http.util')
lpeg = require('lpeg')
cq = require('cqueues')
EOF = lpeg.P(-1)
uri_patt = uri_patts.uri * EOF
quest = function(self, verb, uri, headers)
  if type(uri) ~= 'table' then
    uri = assert(uri_patt:match(uri), 'invalid URI')
  end
  uri.port = uri.port or util.scheme_to_port[uri.scheme]
  local req = Outgoing(uri, headers)
  local authority = util.to_authority(uri.host, uri.port, uri.scheme)
  req:set(':authority', authority)
  req:set(':scheme', uri.scheme)
  req:set(':method', verb)
  req:set(':path', uri.path)
  return req
end
quest = setmetatable({ }, {
  __call = quest
})
quest.fetch = function(uri, headers)
  local req
  if type(uri) ~= 'table' or uri.__class ~= Outgoing then
    req = quest('GET', uri, headers)
  else
    req = uri
  end
  assert(req and req.__class == Outgoing, 'bad fetch argument')
  for name, value in req.headers:each() do
    log.blue(name, '=>', value)
  end
  req.queue = req.queue or cq.running()
  return req:send()
end
quest.sock = function(path)
  return setmetatable({
    path = path
  }, sock_mt)
end
sock_bind = function(name)
  return function(self, ...)
    return quest[name](self:request('GET', ...))
  end
end
sock_request = function(self, verb, path, headers)
  if type(path) == 'table' then
    headers, path, verb = path, verb, 'GET'
  end
  assert(type(path) == 'string', '`path` must be a string')
  local req = Outgoing({
    path = self.path
  }, headers)
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
    return quest.fetch(self:request(uri, headers))
  end
}
sock_mt.__index = sock_mt
return quest