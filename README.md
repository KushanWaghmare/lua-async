lua-async
=========

The lua-async package is an asynchronous executor for Lua. It makes blocking
libraries non-blocking using LuaLanes for OS worker threads and libuv for
the event loop.

Quick Start
-----------

* Report an issue: https://github.com/KushanWaghmare/lua-async/issues
* Get the latest release: https://github.com/KushanWaghmare/lua-async/releases
* Source repository: https://github.com/KushanWaghmare/lua-async
* Install package: luarocks install lua-async

Essential Documentation
-----------------------

All users should be familiar with:

* Architecture: async/scheduler.lua, async/pool.lua, async/init.lua
* Drivers: async/drivers/luasql.lua, async/drivers/redis.lua
* License: See LICENSE
