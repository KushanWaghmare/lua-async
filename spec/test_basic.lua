local async = require("async.init")

describe("async.spawn() end-to-end", function()
  before_each(function()
    async.setup({ workers = 2 })
    async.start()
  end)

  after_each(function()
    async.stop()
  end)

  it("should spawn a stateless function from a coroutine and receive result", function()
    local done = false
    local result_val

    local co = coroutine.create(function()
      result_val = async.spawn(function(a, b)
        return a + b
      end, 19, 23)
      done = true
    end)

    coroutine.resume(co)

    -- Drive the event loop until the coroutine finishes
    while not done do
      async.run("nowait")
    end

    assert.is_true(done)
    assert.equal(42, result_val)
  end)

  it("should spawn multiple coroutines concurrently", function()
    local total_jobs = 4
    local completed = 0
    local results = {}

    for i = 1, total_jobs do
      local co = coroutine.create(function()
        local r = async.spawn(function(n)
          return n * 100
        end, i)
        results[i] = r
        completed = completed + 1
      end)
      coroutine.resume(co)
    end

    while completed < total_jobs do
      async.run("nowait")
    end

    assert.equal(total_jobs, completed)
    for i = 1, total_jobs do
      assert.equal(i * 100, results[i])
    end
  end)

  it("should propagate errors thrown inside the worker lane into the coroutine", function()
    local caught_err
    local done = false

    local co = coroutine.create(function()
      local ok, err = pcall(function()
        async.spawn(function()
          error("Simulated worker error")
        end)
      end)
      if not ok then
        caught_err = err
      end
      done = true
    end)

    coroutine.resume(co)

    while not done do
      async.run("nowait")
    end

    assert.is_true(done)
    assert.is_truthy(caught_err:match("Simulated worker error"))
  end)
end)
