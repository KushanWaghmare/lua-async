package = "lua-async"
version = "0.1.0-1"
source = {
   url = "https://github.com/KushanWaghmare/lua-async.git",
   tag = "v0.1.0"
}
description = {
   summary = "A generic coroutine-friendly async executor for Lua.",
   detailed = [[
      lua-async makes any blocking Lua library non-blocking. 
      It uses LuaLanes for OS-level threading and libuv (luv) for the event loop, 
      providing a seamless, coroutine-driven API that completely eliminates callback hell 
      while keeping your main server thread 100% unblocked.
   ]],
   homepage = "https://github.com/KushanWaghmare/lua-async",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
   "lanes >= 3.10",
   "luv >= 1.43"
}
build = {
   type = "builtin",
   modules = {
      ["async"] = "async/init.lua",
      ["async.pool"] = "async/pool.lua",
      ["async.scheduler"] = "async/scheduler.lua",
      ["async.drivers.luasql"] = "async/drivers/luasql.lua",
      ["async.drivers.redis"] = "async/drivers/redis.lua"
   }
}
