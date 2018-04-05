local co = coroutine

local function read_dir(dir)
  local fh = io.open(dir)
  if fh == nil then
    return function() end
  else
    fh:close()
    fh = io.popen('ls -a "' ..dir.. '"')
    local next = fh:lines()
    return function()
      local line
      while true do
        line = next()
        if line == nil then
          fh:close()
          break
        end
        if line:sub(1, 1) ~= '.' then
          return line
        end
      end
    end
  end
end

local function extname(path)
  local idx = path:find('%.[^%.]+$')
  if idx then
    return path:sub(idx)
  end
end

-- The spec directory can be customized.
local SPEC_DIR = os.getenv('SPEC_DIR') or 'spec'

-- Enable the debugger with DEBUG=1
_G.DEBUG = os.getenv('DEBUG') ~= ''
if DEBUG then require('debugger') end

-- Try loading moonscript.
local moon
pcall(function()
  moon = require('moonscript.base')
end)

-- Expose a colorful logger.
_G.log = require('huey').install()

local global_mt = {
  __index = _G,
}

-- Load a file as a function.
function load_file(name)
  local path = SPEC_DIR .. '/' .. name
  local load = loadfile
  if extname(name) == '.moon' then
    if moon then
      load = moon.loadfile
    else
      log.pale_red('\'moonscript\' is not installed')
      os.exit(1)
    end
  end
  return load(path)
end

-- An iterator of tests. Returns (test_name, test_fn)
function each_test(env)
  setmetatable(env, global_mt)
  local tests = co.create(function()
    local next = read_dir(SPEC_DIR)
    local file = next()
    if file == nil then
      log.pale_red('No tests exist! 🤢\n')
      os.exit(1)
    end
    while file ~= nil do
      local load = load_file(file)
      setfenv(load, env)
      xpcall(load, function(err)
        if DEBUG then dbg() end
        log.pale_red(err)
        log(debug.traceback())
      end)
      file = next()
    end
  end)
  return function()
    if co.status(tests) ~= 'dead' then
      return select(2, co.resume(tests))
    end
  end
end

-- Create the test harnass.
function new_harnass()
  -- NOTE: `test` and `done` are implicit
  return {
    async = function()
      test.async = true
    end,
    assert = function(...)
      local a, b = ...
      if select('#', ...) < 2 then
        if a then return end
        log.red(tostring(a) ..' ~= true')
      else
        if a == b then return end
        log.red(tostring(a) ..' ~= '.. tostring(b))
      end
      if test.passed == nil then
        if DEBUG then dbg() end
        test.passed = false
        done()
      end
    end,
    pass = function()
      if test.passed == nil then
        test.passed = true
        done()
      end
    end,
    fail = function(msg)
      if msg then log.red(msg) end
      if test.passed == nil then
        if DEBUG then dbg() end
        test.passed = false
        done()
      end
    end,
  }
end

-- Run the tests in a coroutine.
co.wrap(function()
  local env = setmetatable({}, global_mt)
  local root = co.running()
  local passed, failed = 0, 0

  -- Called for every finished test.
  env.done = function()
    local test = env.test
    if test.passed then
      log.pale_green('+', test.name)
      passed = passed + 1
    else
      log.pale_red('✕', test.name)
      failed = failed + 1
    end
    if test.async then
      co.resume(root)
    end
  end

  function catch(err)
    log.pale_red(err)
    log(debug.traceback(), '\n')
    if DEBUG then dbg() end
    env.test.passed = false
    env.done()
  end

  -- Create the test runner.
  local runner = co.create(function()
    while true do
      xpcall(co.yield(env), catch)
    end
  end)
  co.resume(runner)

  -- The test harnass is reused between tests.
  local harnass = setfenv(new_harnass, env)()
  setmetatable(harnass, global_mt)

  -- Check the working directory for dependencies.
  package.path = '?.lua;?/init.lua;' .. package.path

  -- Implicit variables while loading tests.
  local load_env = {
    test = co.yield,
    xtest = function() end,
    step = function(fn)
      env.step = fn
    end
  }

  -- Run each test in a yieldable loop.
  for name, run in each_test(load_env) do
    env.test = {name = name}
    local res = select(2, co.resume(runner, setfenv(run, harnass)))

    -- Yield for async tests.
    if env.test.async then
      if env.step then
        -- Step until the test passes.
        while env.test.passed == nil do
          env.step()
        end
      -- Tests may step manually.
      elseif env.test.passed == nil then
        co.yield() -- TODO: add `parallel` option
      end
    else -- Tests may yield the runner.
      while res ~= env do
        if DEBUG then log.coal('(yield)') end
        res = select(2, co.resume(runner))
      end
      if env.test.passed == nil then
        -- The test neither passed nor failed.
        log.pale_yellow('?', name)
      end
    end
  end
  log()

  local count = passed + failed
  if count == 0 then
    log.pale_red('No tests passed or failed! 🤢\n')
  elseif failed > 0 then
    log.pale_red(failed..' / '..count..' tests failed! 💀\n')
  else
    log.pale_yellow(passed..' / '..count..' tests passed! 😇\n')
  end
end)()
