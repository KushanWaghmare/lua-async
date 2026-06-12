 lua-async
 =========

A coroutine-friendly async executor for blocking Lua libraries.
Runs blocking calls on worker lanes (LuaLanes) and resumes
the calling coroutine when the result is ready.

Installation
 *luarocks install lua-async

 Quick start
local async  = require("async")
local luasql = require("luasql.sqlite3")

local db = async.wrap(luasql.sqlite3(), "test.db", { workers=4 })
async.start()

local co = coroutine.create(function()
  local rows = db:execute("SELECT * FROM users")
  print(#rows .. " users")
end)
coroutine.resume(co)
async.run()
