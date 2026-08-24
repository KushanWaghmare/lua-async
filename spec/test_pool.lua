local Pool = require("async.pool")

describe("Pool (OS Threads / LuaLanes)", function()
  local pool

  after_each(function()
    if pool then
      pool:shutdown()
      pool = nil
    end
  end)

  it("should execute a stateless function on a worker lane and return the result", function()
    pool = Pool.new(nil, nil, 2)

    pool:dispatch({
      type = "stateless",
      id = 101,
      fn = function(a, b)
        return a + b
      end,
      args = { 15, 27 },
      argn = 2
    })

    -- Poll with a 2-second timeout to receive result from linda
    local key, res = pool._linda:receive(2.0, "results")
    assert.equal("results", key)
    assert.is_not_nil(res)
    assert.equal(101, res.id)
    assert.is_true(res.ok)
    assert.equal(42, res.data)
  end)

  it("should execute a string source code job on a worker lane", function()
    pool = Pool.new(nil, nil, 2)

    pool:dispatch({
      type = "stateless",
      id = 102,
      fn = "local x, y = ...; return x * y",
      args = { 6, 7 },
      argn = 2
    })

    local key, res = pool._linda:receive(2.0, "results")
    assert.equal("results", key)
    assert.is_not_nil(res)
    assert.equal(102, res.id)
    assert.is_true(res.ok)
    assert.equal(42, res.data)
  end)

  it("should safely catch errors with pcall and keep the lane alive", function()
    pool = Pool.new(nil, nil, 1)

    -- 1. Send a job that fails
    pool:dispatch({
      type = "stateless",
      id = 103,
      fn = function()
        error("Worker task failed intentionally")
      end
    })

    local key1, res1 = pool._linda:receive(2.0, "results")
    assert.equal("results", key1)
    assert.is_not_nil(res1)
    assert.equal(103, res1.id)
    assert.is_false(res1.ok)
    assert.is_truthy(res1.err:match("Worker task failed intentionally"))

    -- 2. Verify the worker lane is still alive and processes the next job
    pool:dispatch({
      type = "stateless",
      id = 104,
      fn = function()
        return "lane is still alive!"
      end
    })

    local key2, res2 = pool._linda:receive(2.0, "results")
    assert.equal("results", key2)
    assert.is_not_nil(res2)
    assert.equal(104, res2.id)
    assert.is_true(res2.ok)
    assert.equal("lane is still alive!", res2.data)
  end)

  it("should process multiple concurrent jobs across worker lanes", function()
    local num_workers = 4
    local num_jobs = 8
    pool = Pool.new(nil, nil, num_workers)

    for i = 1, num_jobs do
      pool:dispatch({
        type = "stateless",
        id = i,
        fn = function(n)
          return n * 10
        end,
        args = { i },
        argn = 1
      })
    end

    local received_results = {}
    for _ = 1, num_jobs do
      local _, res = pool._linda:receive(3.0, "results")
      assert.is_not_nil(res)
      assert.is_true(res.ok)
      received_results[res.id] = res.data
    end

    for i = 1, num_jobs do
      assert.equal(i * 10, received_results[i])
    end
  end)
end)
