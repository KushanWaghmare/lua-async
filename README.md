lua-async
=========

A generic, coroutine-friendly asynchronous executor for Lua. Makes any blocking Lua library (LuaSQL, Redis, HTTP) non-blocking using LuaLanes for OS-level threads and libuv for the event loop.

Quick Start
-----------

* Report an issue: [https://github.com/KushanWaghmare/lua-async/issues](https://github.com/KushanWaghmare/lua-async/issues)
* Latest release: [https://github.com/KushanWaghmare/lua-async/releases](https://github.com/KushanWaghmare/lua-async/releases)
* Source repository: [https://github.com/KushanWaghmare/lua-async](https://github.com/KushanWaghmare/lua-async)

Installation
------------

```bash
luarocks install lua-async
```

Synopsis
--------

```lua
local async = require("async")
async.start()

-- 1. Stateless one-off task
coroutine.wrap(function()
    local res = async.spawn(function(a, b) return a + b end, 10, 20)
    print("Result:", res)
end)()

-- 2. LuaSQL driver
local db = async.wrap("async.drivers.luasql", {
    driver = "sqlite3",
    db     = "app.db"
}, { workers = 4 })

coroutine.wrap(function()
    local res = db:execute("SELECT * FROM users")
    for _, row in ipairs(res.rows) do
        print("User:", row.name)
    end
end)()

async.run()
```

Essential Overview
------------------

* Architecture:
  - `async.scheduler`: Coroutine registrar and non-blocking yield/resume manager.
  - `async.pool`: OS thread pool using `lanes.gen` with Linda FIFO task queues.
  - `async.init`: Main thread dispatcher running on a 1ms `luv` timer.
* Drivers (`async/drivers/`):
  - `luasql`: Thread-safe LuaSQL connector with cursor-to-table serialisation.
  - `redis`: Non-blocking Redis client adapter.
* License: MIT (See LICENSE)
