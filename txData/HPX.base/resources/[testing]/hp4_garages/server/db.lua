DB = { ready = false }

local function run(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then return false, res end
    return true, res
end

function DB.query(q, p) return run(MySQL.query.await, q, p) end
function DB.update(q, p)
    local ok, res = run(MySQL.update.await, q, p)
    return ok and res ~= nil, res
end
function DB.insert(q, p)
    local ok, res = run(MySQL.insert.await, q, p)
    return ok and res ~= nil, res
end
function DB.scalar(q, p) return run(MySQL.scalar.await, q, p) end
function DB.transaction(queries)
    local ok, res = run(MySQL.transaction.await, queries)
    return ok and res == true
end

local function migrate()
    if not DB.update('CREATE TABLE IF NOT EXISTS hp4_meta (k VARCHAR(32) NOT NULL, v INT NOT NULL, PRIMARY KEY (k))') then
        return false
    end
    local sok, current = DB.scalar("SELECT v FROM hp4_meta WHERE k = 'schema'")
    if not sok then return false end
    current = tonumber(current) or 0

    for i, file in ipairs(Config.migrations) do
        if i > current then
            local sql = LoadResourceFile(GetCurrentResourceName(), file)
            if not sql then return false end
            sql = sql:gsub('%-%-[^\n]*', '')
            for raw in sql:gmatch('[^;]+') do
                local stmt = raw:gsub('^%s+', ''):gsub('%s+$', '')
                if #stmt > 0 and not DB.update(stmt) then return false end
            end
            if not DB.update("INSERT INTO hp4_meta (k, v) VALUES ('schema', ?) ON DUPLICATE KEY UPDATE v = VALUES(v)", { i }) then
                return false
            end
        end
    end
    return true
end

function DB.init()
    while not migrate() do
        print('^1[hp4_garages] database unavailable, retrying in 10s^7')
        Wait(10000)
    end
    DB.ready = true
end
