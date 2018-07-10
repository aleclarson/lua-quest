uri_patts = require 'lpeg_patterns.uri'
Incoming = require 'quest.incoming'
Outgoing = require 'quest.outgoing'
util = require 'http.util'
lpeg = require 'lpeg'
cq = require 'cqueues'

EOF = lpeg.P -1
uri_patt = uri_patts.uri * EOF

if rawget(_G, '_DEV') == true
  new = Outgoing
  Outgoing = (...) ->
    ok, req = dbg.call new, ...
    req if ok

quest = (verb, uri, headers) =>
  if type(uri) ~= 'table'
    uri = assert uri_patt\match(uri), 'invalid URI'
  uri.port or= util.scheme_to_port[uri.scheme]
  uri.version or= 1.1
  req = Outgoing uri, headers
  req.for = verb..' '..dbg.pretty uri
  path = uri.query and uri.path..'?'..uri.query or uri.path
  authority = util.to_authority uri.host, uri.port, uri.scheme
  req\set ':authority', authority
  req\set ':scheme', uri.scheme
  req\set ':method', verb
  req\set ':path', path
  return req

quest = setmetatable {},
  __call: quest

quest.fetch = (uri, headers) ->
  quest('GET', uri, headers)\send!

local sock_mt

quest.sock = (path) ->
  assert type(path) == 'string', 'socket path must be a string'
  setmetatable {:path}, sock_mt

sock_request = (verb, path, headers) =>
  if type(path) ~= 'string'
    headers, path, verb = path, verb, 'GET'
  assert type(path) == 'string', '`path` must be a string'
  req = Outgoing {path: @path, version: 1.1}, headers
  req.for = verb..' '..@path..'~'..path
  req.queue = @queue
  req\set ':authority', 'localhost'
  req\set ':scheme', 'http'
  req\set ':method', verb
  req\set ':path', path
  return req

sock_mt =
  request: sock_request
  fetch: (uri, headers) =>
    quest.fetch @request 'GET', uri, headers

sock_mt.__index = sock_mt

return quest
