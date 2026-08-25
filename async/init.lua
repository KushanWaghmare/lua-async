local luv = require("luv")
local Scheduler = require("async.scheduler")
local Pool = require("async.pool")

local async = {
  _scheduler = Scheduler.new(),
  _pool = nil,
  _pools = {}
}

--- Set up the default stateless pool
function async.setup(opts)
  opts = opts or {}
  if not async._pool then
    async._pool = Pool.new(nil, nil, opts.workers or 4)
    table.insert(async._pools, async._pool)
  end
end

--- Start the poll loop on the main thread
function async.start()
  local timer = luv.new_timer()
  luv.timer_start(timer, 0, 1, function()
    for _, pool in ipairs(async._pools) do
      local _, r = pool._linda:receive(0, "results")
      while r do
        async._scheduler:deliver(r.id, r.ok, r.ok and r.data or r.err)
        _, r = pool._linda:receive(0, "results")
      end
    end
  end)
  async._timer = timer
end

--- Stop the poll loop and shut down all worker pools
function async.stop()
  if async._timer then
    luv.timer_stop(async._timer)
    luv.close(async._timer)
    async._timer = nil
  end
  for _, pool in ipairs(async._pools) do
    pool:shutdown()
  end
  async._pools = {}
  async._pool = nil
end

--- Run the luv event loop ('default', 'once', or 'nowait')
function async.run(mode)
  return luv.run(mode or "default")
end

--- Convenience helper to wrap a function in a coroutine and start it
function async.go(fn, ...)
  local args = {...}
  local argn = select("#", ...)
  local co = coroutine.create(function()
    fn(table.unpack(args, 1, argn))
  end)
  local ok, err = coroutine.resume(co)
  if not ok then
    io.stderr:write(string.format("\n[lua-async] ERROR: Unhandled error in async.go coroutine: %s\n", tostring(err)))
  end
  return co
end

--- Spawns a stateless one-off job
function async.spawn(fn_or_code, ...)
  assert(async._pool, "lua-async: async.setup() must be called before using async.spawn()")
  local id = async._scheduler:register()
  async._pool:dispatch({ 
    type = "stateless", id = id,
    fn = fn_or_code, args = {...}, argn = select("#", ...) 
  })
  return async._scheduler:yield()
end

--- Wraps a stateful driver
function async.wrap(driver_module, config, opts)
  assert(async._timer, "lua-async: async.start() must be called before using wrapped drivers")
  opts = opts or {}
  local pool = Pool.new(driver_module, config, opts.workers or 4)
  table.insert(async._pools, pool)

  return setmetatable({}, {
    __index = function(_, method_name)
      return function(_, ...)
        local id = async._scheduler:register()
        pool:dispatch({ 
          type = "q", id = id,
          method = method_name, args = {...} 
        })
        return async._scheduler:yield()
      end
    end
  })
end

return async
