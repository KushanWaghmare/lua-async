local Scheduler = require("async.scheduler")

describe("Scheduler", function()
  local scheduler

  before_each(function()
    scheduler = Scheduler.new()
  end)

  it("should prevent register() from being called on the main thread", function()
    -- coroutine.running() returns nil or the main thread in standard Lua 5.1/5.4
    -- We are on the main thread here, so register should throw an error.
    assert.has_error(function()
      scheduler:register()
    end, "async operations must be called from within a coroutine")
  end)

  it("should successfully register, yield, and deliver values within a coroutine", function()
    local delivered_ok, delivered_val
    local job_id

    local co = coroutine.create(function()
      -- 1. Register the coroutine
      job_id = scheduler:register()
      assert.is_number(job_id)
      
      -- 2. Yield and wait for a result
      local result = scheduler:yield()
      
      -- 4. Assert we got the correct result back
      delivered_val = result
      delivered_ok = true
    end)

    -- Start the coroutine; it will pause at scheduler:yield()
    local ok, err = coroutine.resume(co)
    assert.is_true(ok)
    assert.is_not_nil(job_id)
    assert.equal("suspended", coroutine.status(co))

    -- 3. Deliver the result (simulating the poll loop finding a completed task)
    local deliver_status = scheduler:deliver(job_id, true, "hello from async")
    
    assert.is_true(deliver_status)
    assert.equal("dead", coroutine.status(co))
    assert.is_true(delivered_ok)
    assert.equal("hello from async", delivered_val)
  end)

  it("should propagate errors if the job fails", function()
    local caught_err
    
    local co = coroutine.create(function()
      local job_id = scheduler:register()
      
      -- yield() should throw the error we pass to deliver()
      local ok, err = pcall(function()
        scheduler:yield()
      end)
      
      if not ok then
        caught_err = err
      end
    end)

    coroutine.resume(co)
    
    -- Deliver a failure (simulating a crash in the worker lane)
    scheduler:deliver(1, false, "database connection failed")
    
    assert.is_truthy(caught_err:match("database connection failed"))
  end)
end)
