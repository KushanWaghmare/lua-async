lua-async
=========

A generic, coroutine-friendly asynchronous executor for Lua. Makes any blocking Lua library (like LuaSQL, Redis, or HTTP clients) non-blocking using LuaLanes for OS-level worker threads and libuv (luv) for the event loop.

Quick Start
-----------

* Report an issue: [https://github.com/KushanWaghmare/lua-async/issues](https://github.com/KushanWaghmare/lua-async/issues)
* Latest release: [https://github.com/KushanWaghmare/lua-async/releases](https://github.com/KushanWaghmare/lua-async/releases)
* Installation:
  ```bash
  luarocks install lua-async
  ```

### 1. Stateless CPU Work
```lua
local async = require("async")
async.start()

local co = coroutine.create(function()
    local sum = async.spawn(function(a, b)
        -- Runs inside a worker thread
        return a + b
    end, 10, 20)
    print("Result:", sum)
end)

coroutine.resume(co)
async.run()
```

### 2. LuaSQL Database Queries
```lua
local async = require("async")
async.start()

local db = async.wrap("async.drivers.luasql", {
    driver = "sqlite3",
    db     = "app.db"
}, { workers = 4 })

local co = coroutine.create(function()
    db:execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    db:execute("INSERT INTO users (name) VALUES ('Alice')")
    
    local res = db:execute("SELECT * FROM users")
    for _, row in ipairs(res.rows) do
        print("User:", row.name)
    end
end)

coroutine.resume(co)
async.run()
```

### 3. Redis Cache
```lua
local async = require("async")
async.start()

local cache = async.wrap("async.drivers.redis", {
    host = "127.0.0.1",
    port = 6379
}, { workers = 2 })

local co = coroutine.create(function()
    cache:set("session:1", "active")
    print("Session:", cache:get("session:1"))
end)

coroutine.resume(co)
async.run()
```

Essential Overview
------------------

* **Core Engine**:
  - `async.scheduler`: Registers and yields calling coroutines, resuming them without blocking the main thread.
  - `async.pool`: Manages worker OS threads (`lanes.gen`) and non-blocking Linda message queues (`tasks` / `results`).
  - `async.init`: Polls for finished jobs via a 1ms libuv timer (`luv`) and delivers results back to coroutines.
* **Driver Adapters (`async/drivers/`)**:
  - `async.drivers.luasql`: Bridges standard LuaSQL connections and serialises C result cursors into plain Lua tables.
  - `async.drivers.redis`: Bridges `redis-lua` client calls.
* **Writing Custom Drivers**:
  - Any blocking C or Lua library can become async with a 3-method adapter: `setup(config)`, `call(state, method, args)`, and `teardown(state)`.
* **License**: MIT
