local *

{:JSON} = require 'quest.inject'
uri_patts = require 'lpeg_patterns.uri'
Incoming = require 'quest.incoming'
Outgoing = require 'quest.outgoing'
util = require 'http.util'
lpeg = require 'lpeg'
cq = require 'cqueues'

EOF = lpeg.P -1
uri_patt = uri_patts.uri * EOF

quest = (verb, uri, headers) =>
  if type(uri) ~= 'table'
    uri = assert uri_patt\match(uri), 'invalid URI'
  uri.port or= util.scheme_to_port[uri.scheme]
  req = Outgoing uri, headers
  authority = util.to_authority uri.host, uri.port, uri.scheme
  req\set ':authority', authority
  req\set ':scheme', uri.scheme
  req\set ':method', verb
  req\set ':path', uri.path
  return req

quest = setmetatable {},
  __call: quest

quest.fetch = (uri, headers) ->
  local req

  -- Allow an OutgoingMessage to be passed.
  if type(uri) ~= 'table' or uri.__class ~= Outgoing
    req = quest 'GET', uri, headers
  else req = uri
  assert req and req.__class == Outgoing, 'bad fetch argument'

  for name, value in req.headers\each!
    log.blue name, '=>', value

  -- Defaul to using the current queue.
  req.queue or= cq.running!
  req\send! -- The request is sent in the next loop.

quest.sock = (path) ->
  setmetatable {:path}, sock_mt

sock_bind = (name) -> (...) =>
  quest[name] @request 'GET', ...

sock_request = (verb, path, headers) =>
  if type(path) == 'table'
    headers, path, verb = path, verb, 'GET'
  assert type(path) == 'string', '`path` must be a string'
  req = Outgoing {path: @path}, headers
  req.queue = @queue
  req\set ':authority', 'localhost'
  req\set ':scheme', 'http'
  req\set ':method', verb
  req\set ':path', path
  return req

sock_mt =
  request: sock_request
  fetch: (uri, headers) =>
    quest.fetch @request uri, headers

sock_mt.__index = sock_mt

return quest
