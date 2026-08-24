# lua-async

A generic, coroutine-friendly asynchronous executor for Lua. 

`lua-async` makes any blocking Lua library completely non-blocking. It uses **LuaLanes** to offload blocking work (like database queries or HTTP requests) to OS threads, and **luv (libuv)** to poll for results without blocking the main event loop. 

Instead of dealing with callback hell, `lua-async` pauses your coroutine and resumes it the exact moment the background thread finishes the job, allowing you to write highly concurrent Lua servers with beautiful, synchronous-looking code.

## Installation

```bash
luarocks install lua-async
```

*(Note: `lua-async` does not force you to install specific drivers. If you want to use the LuaSQL or Redis adapters, simply install them natively via `luarocks install luasql-sqlite3` or `luarocks install redis-lua`)*.

---

## 1. Quick Start (Stateless CPU Work)

Offload heavy CPU tasks to background threads without freezing your server:

```lua
local async = require("async")
async.start() -- Start the luv poll timer

-- Create a coroutine
local co = coroutine.create(function()
    print("Sending heavy task to worker lane...")
    
    local result = async.spawn(function(a, b)
        -- This runs in a parallel OS thread!
        local sum = 0
        for i = 1, 1000000 do sum = sum + (a * b) end
        return sum
    end, 5, 10)
    
    print("Result received:", result)
end)

coroutine.resume(co)
async.run() -- Run the event loop
```

---

## 2. Using LuaSQL (Asynchronously)

The `async.wrap()` function takes any existing synchronous library and returns a magic proxy object. 

```lua
local async = require("async")
async.start()

-- Create a pool of 4 parallel SQLite database connections
local db = async.wrap("async.drivers.luasql", {
    driver = "sqlite3",
    db = "production.db"
}, { workers = 4 })

local co = coroutine.create(function()
    -- 1. Create a table (Non-blocking)
    db:execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")

    -- 2. Insert records (Non-blocking)
    db:execute("INSERT INTO users (name) VALUES ('Alice')")

    -- 3. Query records (Non-blocking!)
    local res = db:execute("SELECT * FROM users")
    for _, row in ipairs(res.rows) do
        print("Found User:", row.name)
    end
end)

coroutine.resume(co)
async.run()
```

---

## 3. Using Redis (Asynchronously)

```lua
local async = require("async")
async.start()

-- Pool of 2 parallel Redis connections
local cache = async.wrap("async.drivers.redis", {
    host = "127.0.0.1",
    port = 6379
}, { workers = 2 })

local co = coroutine.create(function()
    cache:set("user:1", "Kushan")
    local val = cache:get("user:1")
    print("Redis returned:", val)
end)

coroutine.resume(co)
async.run()
```

---

## How to Write a Custom Driver

`lua-async` is completely agnostic. You can make **any** Lua library async by writing a 30-line adapter.

Create a file in `async/drivers/custom.lua`:

```lua
local Driver = {}

-- 1. Setup runs ONCE per worker thread
function Driver.setup(config)
    local my_sync_lib = require("my_sync_lib")
    local conn = my_sync_lib.connect(config.url)
    return { conn = conn } -- Save state for this thread
end

-- 2. Call runs for EVERY job sent to the thread
function Driver.call(state, method, args)
    local fn = state.conn[method]
    local result = fn(state.conn, table.unpack(args))
    
    -- MUST return standard Lua types (tables, strings, numbers)
    -- Do not return C Userdata!
    return result 
end

-- 3. Teardown runs when the pool shuts down
function Driver.teardown(state)
    state.conn:disconnect()
end

return Driver
```

Then use it in your app: `async.wrap("async.drivers.custom", { url = "..." })`

---

## Architecture Requirements
* **Lua 5.1, 5.2, 5.3, 5.4, or LuaJIT**
* **LuaLanes** (For OS threads and Linda message queues)
* **luv** (For the 1ms non-blocking event loop timer)

*Developed for the Lua community.*
