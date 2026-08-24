local lanes = require("lanes").configure()

local Pool = {}
Pool.__index = Pool

--- The function that runs entirely inside the worker OS threads
local function worker_loop(linda, worker_id, driver_module, config)
  local unpack = table.unpack or unpack
  local load_code = loadstring or load

  local driver, state
  if driver_module then
    driver = require(driver_module)
    if driver.setup then
      state = driver.setup(config)
    end
  end

  while true do
    local _, job = linda:receive(nil, "tasks")
    if job.type == "quit" then break end

    local ok, result = pcall(function()
      if job.type == "stateless" then
        local fn = type(job.fn) == "string" and assert(load_code(job.fn)) or job.fn
        return fn(unpack(job.args or {}, 1, job.argn or (job.args and #job.args or 0)))
      elseif job.type == "q" and driver then
        return driver.call(state, job.method, job.args or {})
      else
        error("Unknown job type or missing driver")
      end
    end)

    linda:send("results", {
      id   = job.id,
      ok   = ok,
      data = ok and result or nil,
      err  = not ok and tostring(result) or nil,
    })
  end

  if driver and driver.teardown then
    driver.teardown(state)
  end
end

--- Creates a new Pool instance
function Pool.new(driver_module, config, num_workers)
  local self = {
    _linda = lanes.linda(),
    _lanes = {},
    _workers = num_workers or 4
  }

  local generator = lanes.gen("*", worker_loop)
  for i = 1, self._workers do
    self._lanes[i] = generator(self._linda, i, driver_module, config)
  end

  return setmetatable(self, Pool)
end

--- Sends a job to an available worker
function Pool:dispatch(job)
  self._linda:send("tasks", job)
end

--- Gracefully shuts down all workers and waits for cleanup
function Pool:shutdown()
  for _ = 1, self._workers do
    self._linda:send("tasks", { type = "quit" })
  end
  for _, lane in ipairs(self._lanes) do
    pcall(function() lane:join(1.0) end)
  end
  self._lanes = {}
end

return Pool
