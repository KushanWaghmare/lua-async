local Driver = {}

function Driver.setup(config)
  local luasql = require("luasql." .. config.driver)
  local env    = luasql[config.driver]()
  
  local conn
  if config.driver == "sqlite3" then
    conn = env:connect(config.db)
    
    -- Helper to safely execute pragmas and close their cursors immediately
    local function pragma(sql)
      local cur = conn:execute(sql)
      if type(cur) == "userdata" then cur:close() end
    end
    
    pragma("PRAGMA busy_timeout=5000")
    pragma("PRAGMA journal_mode=WAL")
    pragma("PRAGMA synchronous=NORMAL")
  else
    conn = env:connect(config.db, config.user, config.pass, config.host, config.port)
  end
  
  assert(conn, "luasql driver: failed to connect")

  return { env = env, conn = conn }
end

function Driver.call(state, method, args)
  if method == "execute" then
    local cur, err = state.conn:execute(args[1])
    if not cur then error(err) end

    -- INSERT/UPDATE/DELETE returns affected row count (number)
    if type(cur) == "number" then
      return { affected = cur, rows = {} }
    end

    -- SELECT returns a cursor — MUST fetch all rows here
    -- Cursor is C userdata, cannot cross lane boundary
    local rows = {}
    local row = cur:fetch({}, "a")
    while row do
      table.insert(rows, row)
      row = cur:fetch({}, "a")
    end
    cur:close()
    return { rows = rows }
  end

  error("unknown method: " .. tostring(method))
end

function Driver.teardown(state)
  if state.conn then state.conn:close() end
  if state.env then state.env:close() end
end

return Driver
