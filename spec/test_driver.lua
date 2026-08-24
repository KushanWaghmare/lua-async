local async = require("async.init")

describe("LuaSQL Driver via async.wrap()", function()
  local db
  local db_file

  before_each(function()
    db_file = "spec_test_" .. tostring(math.random(100000, 999999)) .. ".db"
    async.start()
    db = async.wrap("async.drivers.luasql", {
      driver = "sqlite3",
      db = db_file
    }, { workers = 2 })
  end)

  after_each(function()
    async.stop()
    os.remove(db_file)
    os.remove(db_file .. "-wal")
    os.remove(db_file .. "-shm")
  end)

  it("should create table, insert rows, and select data asynchronously", function()
    local done = false
    local result_rows

    local co = coroutine.create(function()
      -- 1. Create Table
      db:execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)")

      -- 2. Insert records (returns affected count)
      local r1 = db:execute("INSERT INTO users (name, email) VALUES ('Alice', 'alice@test.com')")
      local r2 = db:execute("INSERT INTO users (name, email) VALUES ('Bob', 'bob@test.com')")
      assert.equal(1, r1.affected)
      assert.equal(1, r2.affected)

      -- 3. Query records (returns plain table array of rows)
      local res = db:execute("SELECT * FROM users ORDER BY id ASC")
      result_rows = res.rows
      done = true
    end)

    coroutine.resume(co)

    -- Step event loop until coroutine completes
    while not done do
      async.run("nowait")
    end

    assert.is_true(done)
    assert.is_not_nil(result_rows)
    assert.equal(2, #result_rows)
    assert.equal("Alice", result_rows[1].name)
    assert.equal("Bob", result_rows[2].name)
  end)

  it("should handle multiple queries across parallel worker lanes", function()
    local done = false
    local count_result

    local co = coroutine.create(function()
      db:execute("CREATE TABLE items (id INTEGER PRIMARY KEY, val INTEGER)")
      for i = 1, 10 do
        db:execute(string.format("INSERT INTO items (val) VALUES (%d)", i * 10))
      end

      local res = db:execute("SELECT COUNT(*) AS total FROM items")
      count_result = tonumber(res.rows[1].total)
      done = true
    end)

    coroutine.resume(co)

    while not done do
      async.run("nowait")
    end

    assert.is_true(done)
    assert.equal(10, count_result)
  end)

  it("should propagate SQL syntax errors into the calling coroutine", function()
    local caught_err
    local done = false

    local co = coroutine.create(function()
      local ok, err = pcall(function()
        db:execute("INVALID SQL STATEMENT SYNTAX")
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
    assert.is_truthy(caught_err)
  end)
end)
