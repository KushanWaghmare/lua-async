local Driver = {}

function Driver.setup(config)
  local redis = require("redis")
  
  -- Connect to Redis server
  local client = redis.connect(config.host or "127.0.0.1", config.port or 6379)
  
  if config.password then
    client:auth(config.password)
  end
  
  if config.db then
    client:select(config.db)
  end
  
  -- Test connection
  local ok, err = pcall(function() client:ping() end)
  assert(ok, "redis driver: failed to connect - " .. tostring(err))

  return { client = client }
end

function Driver.call(state, method, args)
  local fn = state.client[method]
  if not fn then 
    error("unknown redis method: " .. tostring(method)) 
  end
  
  -- Call the redis method (e.g. client:get("key"))
  -- The table.unpack works because we ensured `args` is always passed as a table from the pool
  local unpack = table.unpack or unpack
  local res = fn(state.client, unpack(args))
  
  -- redis-lua returns strings, numbers, or tables, all of which safely cross the Linda boundary!
  return res
end

function Driver.teardown(state)
  if state.client then 
    pcall(function() state.client:quit() end)
  end
end

return Driver
