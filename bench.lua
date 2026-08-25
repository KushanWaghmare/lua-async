local async = require("async.init")
local luasql_raw = require("luasql.sqlite3")

local DB_FILE = "bench.db"
local NUM_QUERIES = 200
local NUM_WORKERS = 4

local function cleanup()
  os.remove(DB_FILE)
  os.remove(DB_FILE .. "-wal")
  os.remove(DB_FILE .. "-shm")
end

local function setup_db()
  cleanup()
  local env = luasql_raw.sqlite3()
  local conn = env:connect(DB_FILE)
  
  local function pragma(sql)
    local cur = conn:execute(sql)
    if type(cur) == "userdata" then cur:close() end
  end
  
  pragma("PRAGMA journal_mode=WAL")
  pragma("PRAGMA synchronous=NORMAL")
  
  assert(conn:execute("CREATE TABLE records (id INTEGER PRIMARY KEY, data TEXT)"))
  for i = 1, NUM_QUERIES do
    assert(conn:execute(string.format("INSERT INTO records VALUES (%d, 'Payload data for %d')", i, i)))
  end
  conn:close()
  env:close()
end

print("=========================================================")
print(string.format("  BENCHMARK: Synchronous LuaSQL vs lua-async (%d queries)", NUM_QUERIES))
print("=========================================================")

setup_db()

-----------------------------------------------------------------
-- 1. Synchronous Benchmark (Baseline)
-----------------------------------------------------------------
local env = luasql_raw.sqlite3()
local conn = env:connect(DB_FILE)

local sync_start = os.clock()
for i = 1, NUM_QUERIES do
  local cur, err = conn:execute(string.format("SELECT * FROM records WHERE id = %d", (i % NUM_QUERIES) + 1))
  assert(cur, tostring(err))
  local row = cur:fetch({}, "a")
  cur:close()
end
local sync_duration = (os.clock() - sync_start) * 1000
conn:close()
env:close()

print(string.format("  [1] Synchronous LuaSQL: %.2f ms (%.1f queries/sec)", 
  sync_duration, (NUM_QUERIES / (sync_duration / 1000))))

-----------------------------------------------------------------
-- 2. Asynchronous Benchmark (lua-async)
-----------------------------------------------------------------
async.start()
local db = async.wrap("async.drivers.luasql", {
  driver = "sqlite3",
  db = DB_FILE
}, { workers = NUM_WORKERS })

local completed = 0
local async_start = os.clock()

for i = 1, NUM_QUERIES do
  local co = coroutine.create(function()
    local res = db:execute(string.format("SELECT * FROM records WHERE id = %d", (i % NUM_QUERIES) + 1))
    completed = completed + 1
  end)
  coroutine.resume(co)
end

while completed < NUM_QUERIES do
  async.run("nowait")
end

local async_duration = (os.clock() - async_start) * 1000
async.stop()
cleanup()

print(string.format("  [2] lua-async (%d workers): %.2f ms (%.1f queries/sec)", 
  NUM_WORKERS, async_duration, (NUM_QUERIES / (async_duration / 1000))))
print("=========================================================")
