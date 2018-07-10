# lua-quest v0.0.1

HTTP requests for Lua

```lua
local quest = require('quest')

-- 
local req = quest('POST', uri, {
  'content-type' = 'application/json'
})

-- Send a JSON object.
local res = req:send({
  foo: 1,
  bar: 2,
})

-- Receive a JSON object.
res = res.json()
```

By default, `quest` will block the current cqueue
until a response is received and its data consumed.

If you use `quest` outside of a cqueue, your whole
program will be blocked.

Set the `req.queue` property to another cqueue
to prevent the request and response from
blocking the current cqueue.

The response inherits its `queue` from the
request, but you can always set both if
you want to process the response data
on some other cqueue.

When the `req.queue` property is non-nil,
the request will emit "response" and
"error" events.

The "response" event is emitted when
the response headers have been parsed
completely. This only happens once.

When the `res.queue` property is non-nil,
the response will emit "head", "data",
"end", and "error" events.

The "head" event is emitted right after
the request's "response" event. Listeners
are passed the `status` and `headers`.

The "data" event is emitted once per
chunk of the response body. At least one
listener must exist for "data" events to
be emitted. If you remove every listener
or call `res.pause`, the flow of "data"
events will cease. You can call `res.resume`
to emit "data" events until the end of the
response is reached, even if you have no
listeners attached.

The "end" event is emitted once the last
chunk has been processed.

```lua
local cq = require('cqueues')
req.queue = cq.new()

-- The response inherits the request queue.
local res = req:send()

-- The response queue is where data is read.
res.queue = cq.new() -- Changing it is optional.

res:on('head', function(status, headers)
  -- Do something with status and headers.
end)

res:on('data', function(chunk)
  -- Do something with each chunk.
end)

res:on('end', function()
  -- Do something now that all chunks are processed.
end)
```

*TODO: Write more documentation*

