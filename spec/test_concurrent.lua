local async = require("async.init")

describe("High-Concurrency Stress & Throughput", function()
  local db
  local db_file

  before_each(function()
    db_file = "stress_test_" .. tostring(math.random(100000, 999999)) .. ".db"
    async.setup({ workers = 4 })
    async.start()
    db = async.wrap("async.drivers.luasql", {
      driver = "sqlite3",
      db = db_file
    }, { workers = 4 })
  end)

  after_each(function()
    async.stop()
    os.remove(db_file)
    os.remove(db_file .. "-wal")
    os.remove(db_file .. "-shm")
  end)

  it("should handle 50 concurrent stateless computations across lanes", function()
    local total = 50
    local completed = 0
    local results = {}

    for i = 1, total do
      local co = coroutine.create(function()
        local res = async.spawn(function(n)
          -- CPU work inside worker lane
          local sum = 0
          for j = 1, 1000 do sum = sum + j end
          return n * 2
        end, i)
        results[i] = res
        completed = completed + 1
      end)
      coroutine.resume(co)
    end

    while completed < total do
      async.run("nowait")
    end

    assert.equal(total, completed)
    for i = 1, total do
      assert.equal(i * 2, results[i])
    end
  end)

  it("should handle 20 concurrent coroutines executing database queries", function()
    -- Initialize schema
    local setup_co = coroutine.create(function()
      db:execute("CREATE TABLE accounts (id INTEGER PRIMARY KEY, balance INTEGER)")
      for i = 1, 20 do
        db:execute(string.format("INSERT INTO accounts (id, balance) VALUES (%d, %d)", i, i * 100))
      end
    end)
    coroutine.resume(setup_co)
    while coroutine.status(setup_co) ~= "dead" do
      async.run("nowait")
    end

    -- Run 20 parallel coroutines reading from DB
    local total = 20
    local completed = 0
    local balances = {}

    for i = 1, total do
      local co = coroutine.create(function()
        local res = db:execute(string.format("SELECT balance FROM accounts WHERE id = %d", i))
        balances[i] = tonumber(res.rows[1].balance)
        completed = completed + 1
      end)
      coroutine.resume(co)
    end

    while completed < total do
      async.run("nowait")
    end

    assert.equal(total, completed)
    for i = 1, total do
      assert.equal(i * 100, balances[i])
    end
  end)
end)
