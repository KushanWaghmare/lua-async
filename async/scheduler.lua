local Scheduler = {}
Scheduler.__index = Scheduler

--- Creates a new Scheduler instance
function Scheduler.new()
  local self = {
    _next_id = 1,
    _pending = {}
  }
  return setmetatable(self, Scheduler)
end

--- Registers the current coroutine and returns a unique job ID
function Scheduler:register()
  local co, is_main = coroutine.running()
  
  -- In Lua 5.1/LuaJIT co is nil on main thread.
  -- In Lua 5.2+ co is thread object and is_main is true.
  assert(co and not is_main, "async operations must be called from within a coroutine")
  
  local id = self._next_id
  self._next_id = self._next_id + 1
  self._pending[id] = co
  
  return id
end

--- Suspends the current coroutine until a result is delivered
function Scheduler:yield()
  -- coroutine.yield() returns whatever values are passed to coroutine.resume()
  -- We expect resume to pass (ok, result_or_error)
  local ok, result = coroutine.yield()
  
  if not ok then
    error(result, 2) -- Propagate the error back to the caller
  end
  
  return result
end

--- Wakes up the coroutine waiting on job 'id'
function Scheduler:deliver(id, ok, val)
  local co = self._pending[id]
  if not co then return false end
  
  self._pending[id] = nil
  
  -- Resume the coroutine. The 'ok' and 'val' will be returned by coroutine.yield()
  local resume_ok, err = coroutine.resume(co, ok, val)
  
  -- If the coroutine itself crashes after waking up, throw the error
  if not resume_ok then
    error("Coroutine error after resume: " .. tostring(err))
  end
  
  return true
end

return Scheduler
