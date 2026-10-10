---@type table Store module; the table returned at end of file. Dumb by design: it runs SQL and
---returns rows, and the bunkers/scooters modules own validation and caching.
local store = { bunkers = {}, stations = {}, scooters = {}, rentals = {}, handling = {}, audit = {}, settings = {} }

---Create both tables when missing and back-fill columns added after first release, so the
---resource is drop-in with no .sql to import. Run once at boot.
function store.ensureSchema()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS sd_scoot_bunkers (
            id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
            name        VARCHAR(48)  NOT NULL,
            x           FLOAT        NOT NULL,
            y           FLOAT        NOT NULL,
            z           FLOAT        NOT NULL,
            heading     FLOAT        NOT NULL DEFAULT 0,
            enabled     TINYINT(1)   NOT NULL DEFAULT 1,
            created_by  VARCHAR(64)  NULL,
            created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
    local hasStock = MySQL.scalar.await([[
        SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sd_scoot_bunkers' AND COLUMN_NAME = 'stock'
    ]])
    if (tonumber(hasStock) or 0) == 0 then
        MySQL.query.await('ALTER TABLE sd_scoot_bunkers ADD COLUMN stock INT NOT NULL DEFAULT 5 AFTER enabled')
    end
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS sd_scoot_scooters (
            id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
            plate       VARCHAR(8)   NOT NULL,
            colour      TINYINT      NOT NULL DEFAULT 1,
            bunker_id   INT UNSIGNED NULL,
            x           FLOAT        NOT NULL,
            y           FLOAT        NOT NULL,
            z           FLOAT        NOT NULL,
            heading     FLOAT        NOT NULL DEFAULT 0,
            status      VARCHAR(16)  NOT NULL DEFAULT 'available',
            created_by  VARCHAR(64)  NULL,
            created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY plate (plate),
            KEY bunker_id (bunker_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
    local hasExtras = MySQL.scalar.await([[SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sd_scoot_scooters' AND COLUMN_NAME = 'customization']])
    if (tonumber(hasExtras) or 0) == 0 then MySQL.query.await('ALTER TABLE sd_scoot_scooters ADD COLUMN customization LONGTEXT NULL') end
    local hasBattery = MySQL.scalar.await([[SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sd_scoot_scooters' AND COLUMN_NAME = 'battery']])
    if (tonumber(hasBattery) or 0) == 0 then
        MySQL.query.await('ALTER TABLE sd_scoot_scooters ADD COLUMN battery TINYINT UNSIGNED NOT NULL DEFAULT 100 AFTER status, ADD COLUMN station_id INT UNSIGNED NULL AFTER battery, ADD COLUMN slot TINYINT UNSIGNED NULL AFTER station_id')
    end
    local hasTarget = MySQL.scalar.await([[SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sd_scoot_scooters' AND COLUMN_NAME = 'charge_target']])
    if (tonumber(hasTarget) or 0) == 0 then
        MySQL.query.await('ALTER TABLE sd_scoot_scooters ADD COLUMN charge_target TINYINT UNSIGNED NULL AFTER slot')
    end
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS sd_scoot_stations (
            id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
            name        VARCHAR(48)  NOT NULL,
            x           FLOAT        NOT NULL,
            y           FLOAT        NOT NULL,
            z           FLOAT        NOT NULL,
            heading     FLOAT        NOT NULL DEFAULT 0,
            enabled     TINYINT(1)   NOT NULL DEFAULT 1,
            created_by  VARCHAR(64)  NULL,
            created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
    local hasColour = MySQL.scalar.await([[SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sd_scoot_stations' AND COLUMN_NAME = 'colour']])
    if (tonumber(hasColour) or 0) == 0 then
        MySQL.query.await('ALTER TABLE sd_scoot_stations ADD COLUMN colour TINYINT UNSIGNED NOT NULL DEFAULT 1')
    end
    local hasSlots = MySQL.scalar.await([[SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sd_scoot_stations' AND COLUMN_NAME = 'slots']])
    if (tonumber(hasSlots) or 0) == 0 then
        MySQL.query.await('ALTER TABLE sd_scoot_stations ADD COLUMN slots TINYINT UNSIGNED NOT NULL DEFAULT 4 AFTER heading')
    end
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS sd_scoot_rentals (
            id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
            scooter_id  INT UNSIGNED NOT NULL,
            renter      VARCHAR(64)  NOT NULL,
            started_at  INT UNSIGNED NOT NULL,
            ended_at    INT UNSIGNED NULL,
            minutes     INT UNSIGNED NOT NULL DEFAULT 0,
            cost        INT UNSIGNED NOT NULL DEFAULT 0,
            paid        TINYINT(1)   NOT NULL DEFAULT 0,
            PRIMARY KEY (id),
            KEY renter (renter),
            KEY scooter_id (scooter_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
    local hasRideDetail = MySQL.scalar.await([[SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sd_scoot_rentals' AND COLUMN_NAME = 'renter_name']])
    if (tonumber(hasRideDetail) or 0) == 0 then
        MySQL.query.await([[
            ALTER TABLE sd_scoot_rentals
                ADD COLUMN renter_name VARCHAR(64) NULL AFTER renter,
                ADD COLUMN plate VARCHAR(8) NULL AFTER scooter_id,
                ADD COLUMN bunker_id INT UNSIGNED NULL AFTER plate,
                ADD COLUMN start_x FLOAT NULL, ADD COLUMN start_y FLOAT NULL,
                ADD COLUMN end_x FLOAT NULL, ADD COLUMN end_y FLOAT NULL,
                ADD COLUMN ended_by VARCHAR(16) NULL,
                ADD COLUMN refunded INT UNSIGNED NOT NULL DEFAULT 0,
                ADD KEY started_at (started_at)
        ]])
        MySQL.query.await('UPDATE sd_scoot_rentals r JOIN sd_scoot_scooters s ON s.id = r.scooter_id SET r.plate = s.plate WHERE r.plate IS NULL')
    end
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS sd_scoot_admin_log (
            id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
            actor       VARCHAR(64)  NOT NULL,
            actor_id    VARCHAR(64)  NULL,
            verb        VARCHAR(32)  NOT NULL,
            message     VARCHAR(255) NOT NULL,
            at          INT UNSIGNED NOT NULL,
            PRIMARY KEY (id),
            KEY at (at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS sd_scoot_settings (
            path        VARCHAR(64)  NOT NULL,
            value       VARCHAR(255) NOT NULL,
            updated_by  VARCHAR(64)  NULL,
            updated_at  INT UNSIGNED NOT NULL,
            PRIMARY KEY (path)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS sd_scoot_handling_profiles (
            id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
            name        VARCHAR(48)  NOT NULL,
            `values`    LONGTEXT     NOT NULL,
            active      TINYINT(1)   NOT NULL DEFAULT 0,
            created_by  VARCHAR(64)  NULL,
            updated_by  VARCHAR(64)  NULL,
            created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS sd_scoot_handling_log (
            id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
            profile_id  INT UNSIGNED NOT NULL,
            actor       VARCHAR(64)  NOT NULL,
            changes     LONGTEXT     NOT NULL,
            at          INT UNSIGNED NOT NULL,
            PRIMARY KEY (id),
            KEY profile_id (profile_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
end

---Every handling profile, oldest first. `values` is still JSON text; the handling module decodes it.
---@return table[]
function store.handling.all()
    return MySQL.query.await('SELECT id, name, `values`, active, updated_by AS updatedBy, UNIX_TIMESTAMP(updated_at) AS updatedAt FROM sd_scoot_handling_profiles ORDER BY id') or {}
end

---Insert a handling profile and return its id.
---@param name string
---@param valuesJson string
---@param by string
---@return integer id
function store.handling.insert(name, valuesJson, by)
    return MySQL.insert.await('INSERT INTO sd_scoot_handling_profiles (name, `values`, created_by, updated_by) VALUES (?, ?, ?, ?)', { name, valuesJson, by, by })
end

---Overwrite a profile's values.
---@param id integer
---@param valuesJson string
---@param by string
function store.handling.setValues(id, valuesJson, by)
    MySQL.update.await('UPDATE sd_scoot_handling_profiles SET `values` = ?, updated_by = ? WHERE id = ?', { valuesJson, by, id })
end

---Rename a handling profile.
---@param id integer
---@param name string
function store.handling.setName(id, name)
    MySQL.update.await('UPDATE sd_scoot_handling_profiles SET name = ? WHERE id = ?', { name, id })
end

---Make one profile the active one (0 clears it, so handling.meta applies unmodified).
---@param id integer
function store.handling.setActive(id)
    MySQL.update.await('UPDATE sd_scoot_handling_profiles SET active = (id = ?)', { id })
end

---Delete a handling profile and its change log.
---@param id integer
function store.handling.delete(id)
    MySQL.update.await('DELETE FROM sd_scoot_handling_log WHERE profile_id = ?', { id })
    MySQL.update.await('DELETE FROM sd_scoot_handling_profiles WHERE id = ?', { id })
end

---Record one save's field changes and prune the profile's log to `keep` rows.
---@param profileId integer
---@param actor string
---@param changesJson string
---@param keep integer
---@return integer id
function store.handling.log(profileId, actor, changesJson, keep)
    local id = MySQL.insert.await('INSERT INTO sd_scoot_handling_log (profile_id, actor, changes, at) VALUES (?, ?, ?, ?)', { profileId, actor, changesJson, os.time() })
    MySQL.update.await([[
        DELETE FROM sd_scoot_handling_log WHERE profile_id = ? AND id NOT IN (
            SELECT id FROM (SELECT id FROM sd_scoot_handling_log WHERE profile_id = ? ORDER BY id DESC LIMIT ?) AS keep_rows
        )
    ]], { profileId, profileId, keep })
    return id
end

---The newest log rows across every profile.
---@param limit integer
---@return table[]
function store.handling.history(limit)
    return MySQL.query.await('SELECT id, profile_id AS profileId, actor, changes, at FROM sd_scoot_handling_log ORDER BY id DESC LIMIT ?', { limit }) or {}
end

---One handling log row by id.
---@param id integer
---@return table|nil
function store.handling.logEntry(id)
    return MySQL.single.await('SELECT id, profile_id AS profileId, actor, changes, at FROM sd_scoot_handling_log WHERE id = ?', { id })
end

---Rides with no end time (left open by a restart).
---@return table[] { id, scooterId, renter, startedAt }
function store.rentals.open()
    return MySQL.query.await('SELECT id, scooter_id AS scooterId, renter, started_at AS startedAt, cost FROM sd_scoot_rentals WHERE ended_at IS NULL') or {}
end

---Open a ride with its one-time fare, already paid when the scooter was unlocked, and return its id.
---@param r table { scooterId, plate, bunkerId?, renter, renterName, startedAt, fare, x?, y? }
---@return integer
function store.rentals.insert(r)
    return MySQL.insert.await('INSERT INTO sd_scoot_rentals (scooter_id, plate, bunker_id, renter, renter_name, started_at, cost, paid, start_x, start_y) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?)', {
        r.scooterId, r.plate, r.bunkerId, r.renter, r.renterName, r.startedAt, r.fare, r.x, r.y,
    })
end

---Close a ride: how long it lasted, its fare and where it ended.
---@param id integer
---@param minutes integer
---@param cost integer
---@param paid integer 1|0
---@param detail table|nil { x?, y?, endedBy? }
function store.rentals.close(id, minutes, cost, paid, detail)
    detail = detail or {}
    MySQL.update.await('UPDATE sd_scoot_rentals SET ended_at = ?, minutes = ?, cost = ?, paid = ?, end_x = ?, end_y = ?, ended_by = ? WHERE id = ?', {
        os.time(), minutes, cost, paid, detail.x, detail.y, detail.endedBy, id,
    })
end

---@type string Columns every admin ride query returns.
local RIDE_COLUMNS = [[r.id, r.scooter_id AS scooterId, COALESCE(r.plate, s.plate) AS plate, r.bunker_id AS bunkerId, r.renter,
    r.renter_name AS renterName, r.started_at AS startedAt, r.ended_at AS endedAt, r.minutes, r.cost, r.paid, r.refunded,
    r.ended_by AS endedBy, r.start_x AS startX, r.start_y AS startY, r.end_x AS endX, r.end_y AS endY]]

---LIKE pattern for a search box, with the wildcards typed by the admin stripped.
---@param query string
---@return string
local function likePattern(query)
    return '%' .. query:gsub('[%%_]', '') .. '%'
end

---Closed rides, newest first, optionally filtered by renter name / identifier / plate.
---@param query string|nil
---@param limit integer
---@param offset integer
---@return table[] rows, integer total
function store.rentals.search(query, limit, offset)
    local where, args = 'r.ended_at IS NOT NULL', {}
    if query and query ~= '' then
        local like = likePattern(query)
        where = where .. ' AND (r.renter_name LIKE ? OR r.renter LIKE ? OR COALESCE(r.plate, s.plate) LIKE ?)'
        args = { like, like, like }
    end
    local total = MySQL.scalar.await(('SELECT COUNT(*) FROM sd_scoot_rentals r LEFT JOIN sd_scoot_scooters s ON s.id = r.scooter_id WHERE %s'):format(where), args)
    local page = { table.unpack(args) }
    page[#page + 1] = limit
    page[#page + 1] = offset
    local rows = MySQL.query.await(('SELECT %s FROM sd_scoot_rentals r LEFT JOIN sd_scoot_scooters s ON s.id = r.scooter_id WHERE %s ORDER BY r.id DESC LIMIT ? OFFSET ?'):format(RIDE_COLUMNS, where), page)
    return rows or {}, tonumber(total) or 0
end

---One renter's rides, newest first (open ones included).
---@param renter string
---@param limit integer
---@return table[]
function store.rentals.byRenter(renter, limit)
    return MySQL.query.await(('SELECT %s FROM sd_scoot_rentals r LEFT JOIN sd_scoot_scooters s ON s.id = r.scooter_id WHERE r.renter = ? ORDER BY r.id DESC LIMIT ?'):format(RIDE_COLUMNS), { renter, limit }) or {}
end

---One ride by id, with the scooter plate.
---@param id integer
---@return table|nil
function store.rentals.get(id)
    return MySQL.single.await(('SELECT %s FROM sd_scoot_rentals r LEFT JOIN sd_scoot_scooters s ON s.id = r.scooter_id WHERE r.id = ?'):format(RIDE_COLUMNS), { id })
end

---Set a ride's running refund total.
---@param id integer
---@param refunded integer total refunded so far
function store.rentals.setRefunded(id, refunded)
    MySQL.update.await('UPDATE sd_scoot_rentals SET refunded = ? WHERE id = ?', { refunded, id })
end

---Ride count, revenue collected (paid minus refunds), unpaid total and minutes since a time.
---@param since integer unix seconds; 0 for all time
---@return table { rides, revenue, unpaid, minutes }
function store.rentals.totals(since)
    local row = MySQL.single.await([[
        SELECT COUNT(*) AS rides,
               COALESCE(SUM(CASE WHEN paid = 1 THEN cost - refunded ELSE 0 END), 0) AS revenue,
               COALESCE(SUM(CASE WHEN paid = 0 THEN cost ELSE 0 END), 0) AS unpaid,
               COALESCE(SUM(minutes), 0) AS minutes
        FROM sd_scoot_rentals WHERE ended_at IS NOT NULL AND started_at >= ?
    ]], { since }) or {}
    return { rides = tonumber(row.rides) or 0, revenue = tonumber(row.revenue) or 0, unpaid = tonumber(row.unpaid) or 0, minutes = tonumber(row.minutes) or 0 }
end

---Rides and revenue per start bunker since a time.
---@param since integer
---@return table[] { bunkerId, rides, revenue }
function store.rentals.byBunker(since)
    return MySQL.query.await([[
        SELECT bunker_id AS bunkerId, COUNT(*) AS rides, COALESCE(SUM(CASE WHEN paid = 1 THEN cost - refunded ELSE 0 END), 0) AS revenue
        FROM sd_scoot_rentals WHERE ended_at IS NOT NULL AND started_at >= ? GROUP BY bunker_id ORDER BY revenue DESC
    ]], { since }) or {}
end

---Rides and revenue per hour bucket since a time (bucket = floor(started_at / 3600)).
---@param since integer
---@return table[] { hour, rides, revenue }
function store.rentals.hourly(since)
    return MySQL.query.await([[
        SELECT FLOOR(started_at / 3600) AS hour, COUNT(*) AS rides, COALESCE(SUM(CASE WHEN paid = 1 THEN cost - refunded ELSE 0 END), 0) AS revenue
        FROM sd_scoot_rentals WHERE started_at >= ? GROUP BY FLOOR(started_at / 3600)
    ]], { since }) or {}
end

---Start and end points of recent rides, for the map activity layer.
---@param limit integer
---@return table[] { sx, sy, ex, ey }
function store.rentals.points(limit)
    return MySQL.query.await('SELECT start_x AS sx, start_y AS sy, end_x AS ex, end_y AS ey FROM sd_scoot_rentals WHERE start_x IS NOT NULL ORDER BY id DESC LIMIT ?', { limit }) or {}
end

---Record one admin action (not awaited).
---@param actor string
---@param actorId string|nil
---@param verb string
---@param message string
function store.audit.insert(actor, actorId, verb, message)
    MySQL.insert('INSERT INTO sd_scoot_admin_log (actor, actor_id, verb, message, at) VALUES (?, ?, ?, ?, ?)', { actor:sub(1, 64), actorId, verb:sub(1, 32), message:sub(1, 255), os.time() })
end

---Admin actions, newest first, optionally filtered by actor or message text.
---@param query string|nil
---@param limit integer
---@param offset integer
---@return table[] rows, integer total
function store.audit.list(query, limit, offset)
    local where, args = '1 = 1', {}
    if query and query ~= '' then
        local like = likePattern(query)
        where, args = '(actor LIKE ? OR message LIKE ?)', { like, like }
    end
    local total = MySQL.scalar.await(('SELECT COUNT(*) FROM sd_scoot_admin_log WHERE %s'):format(where), args)
    local page = { table.unpack(args) }
    page[#page + 1] = limit
    page[#page + 1] = offset
    local rows = MySQL.query.await(('SELECT id, actor, verb, message, at FROM sd_scoot_admin_log WHERE %s ORDER BY id DESC LIMIT ? OFFSET ?'):format(where), page)
    return rows or {}, tonumber(total) or 0
end

---Every stored setting override.
---@return table[] { path, value, updatedBy, updatedAt }
function store.settings.all()
    return MySQL.query.await('SELECT path, value, updated_by AS updatedBy, updated_at AS updatedAt FROM sd_scoot_settings') or {}
end

---Insert or update one setting override.
---@param path string
---@param value string JSON-encoded value
---@param by string
function store.settings.set(path, value, by)
    MySQL.update.await('INSERT INTO sd_scoot_settings (path, value, updated_by, updated_at) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE value = VALUES(value), updated_by = VALUES(updated_by), updated_at = VALUES(updated_at)', { path, value, by, os.time() })
end

---Remove a setting override so the file value applies again.
---@param path string
function store.settings.clear(path)
    MySQL.update.await('DELETE FROM sd_scoot_settings WHERE path = ?', { path })
end

---A renter's latest closed rides, newest first, with the scooter plate.
---@param renter string
---@param limit integer
---@return table[]
function store.rentals.history(renter, limit)
    return MySQL.query.await([[
        SELECT r.id, r.scooter_id AS scooterId, COALESCE(r.plate, s.plate) AS plate, r.started_at AS startedAt, r.ended_at AS endedAt, r.minutes, r.cost, r.paid
        FROM sd_scoot_rentals r LEFT JOIN sd_scoot_scooters s ON s.id = r.scooter_id
        WHERE r.renter = ? AND r.ended_at IS NOT NULL ORDER BY r.id DESC LIMIT ?
    ]], { renter, limit }) or {}
end

---Every bunker row, oldest first. `enabled` comes back as 0/1; the caller turns it into a boolean.
---@return table[]
function store.bunkers.all()
    return MySQL.query.await([[
        SELECT id, name, x, y, z, heading, enabled, stock, created_by AS createdBy
        FROM sd_scoot_bunkers ORDER BY id ASC
    ]]) or {}
end

---Insert one bunker and return its new id.
---@param b table { name, x, y, z, heading, enabled, createdBy }
---@return integer id
function store.bunkers.insert(b)
    return MySQL.insert.await(
        'INSERT INTO sd_scoot_bunkers (name, x, y, z, heading, enabled, stock, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { b.name, b.x, b.y, b.z, b.heading, b.enabled and 1 or 0, b.stock or 5, b.createdBy }
    )
end

---Rename a bunker.
---@param id integer
---@param name string
function store.bunkers.setName(id, name)
    MySQL.update.await('UPDATE sd_scoot_bunkers SET name = ? WHERE id = ?', { name, id })
end

---Move a bunker.
---@param id integer
---@param x number
---@param y number
---@param z number
---@param heading number
function store.bunkers.setPosition(id, x, y, z, heading)
    MySQL.update.await('UPDATE sd_scoot_bunkers SET x = ?, y = ?, z = ?, heading = ? WHERE id = ?', { x, y, z, heading, id })
end

---Set a bunker's stock.
---@param id integer
---@param stock integer
function store.bunkers.setStock(id, stock)
    MySQL.update.await('UPDATE sd_scoot_bunkers SET stock = ? WHERE id = ?', { stock, id })
end

---Enable or disable a bunker.
---@param id integer
---@param enabled boolean
function store.bunkers.setEnabled(id, enabled)
    MySQL.update.await('UPDATE sd_scoot_bunkers SET enabled = ? WHERE id = ?', { enabled and 1 or 0, id })
end

---Delete a bunker row.
---@param id integer
function store.bunkers.delete(id)
    MySQL.update.await('DELETE FROM sd_scoot_bunkers WHERE id = ?', { id })
end

---Every charging station row, oldest first. `enabled` comes back as 0/1.
---@return table[]
function store.stations.all()
    return MySQL.query.await([[
        SELECT id, name, x, y, z, heading, slots, colour, enabled, created_by AS createdBy
        FROM sd_scoot_stations ORDER BY id ASC
    ]]) or {}
end

---Insert one station and return its new id.
---@param s table { name, x, y, z, heading, slots, colour, enabled, createdBy }
---@return integer id
function store.stations.insert(s)
    return MySQL.insert.await(
        'INSERT INTO sd_scoot_stations (name, x, y, z, heading, slots, colour, enabled, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { s.name, s.x, s.y, s.z, s.heading, s.slots, s.colour, s.enabled and 1 or 0, s.createdBy }
    )
end

---Set a station's colour.
---@param id integer
---@param colour integer 1-based index into Config.Stations.Colours
function store.stations.setColour(id, colour)
    MySQL.update.await('UPDATE sd_scoot_stations SET colour = ? WHERE id = ?', { colour, id })
end

---Move a station.
---@param id integer
---@param x number
---@param y number
---@param z number
---@param heading number
function store.stations.setPosition(id, x, y, z, heading)
    MySQL.update.await('UPDATE sd_scoot_stations SET x = ?, y = ?, z = ?, heading = ? WHERE id = ?', { x, y, z, heading, id })
end

---Set a station's slot count.
---@param id integer
---@param slots integer
function store.stations.setSlots(id, slots)
    MySQL.update.await('UPDATE sd_scoot_stations SET slots = ? WHERE id = ?', { slots, id })
end

---Rename a station.
---@param id integer
---@param name string
function store.stations.setName(id, name)
    MySQL.update.await('UPDATE sd_scoot_stations SET name = ? WHERE id = ?', { name, id })
end

---Enable or disable a station.
---@param id integer
---@param enabled boolean
function store.stations.setEnabled(id, enabled)
    MySQL.update.await('UPDATE sd_scoot_stations SET enabled = ? WHERE id = ?', { enabled and 1 or 0, id })
end

---Delete a station row.
---@param id integer
function store.stations.delete(id)
    MySQL.update.await('DELETE FROM sd_scoot_stations WHERE id = ?', { id })
end

---Every scooter row, oldest first.
---@return table[]
function store.scooters.all()
    return MySQL.query.await([[
        SELECT id, plate, colour, customization, bunker_id AS bunkerId, x, y, z, heading, status, battery, station_id AS stationId, slot, charge_target AS chargeTarget, created_by AS createdBy
        FROM sd_scoot_scooters ORDER BY id ASC
    ]]) or {}
end

---The percent a docked scooter is paid to charge to, or nil when nothing was bought. Not awaited.
---@param id integer
---@param target integer|nil
function store.scooters.setChargeTarget(id, target)
    MySQL.update('UPDATE sd_scoot_scooters SET charge_target = ? WHERE id = ?', { target, id })
end

---Battery write-back. Not awaited: it runs from the battery tick, where nothing waits on it.
---@param id integer
---@param battery integer 0..100
function store.scooters.setBattery(id, battery)
    MySQL.update('UPDATE sd_scoot_scooters SET battery = ? WHERE id = ?', { battery, id })
end

---Park a scooter in a station slot, or free it (both nil).
---@param id integer
---@param stationId integer|nil
---@param slot integer|nil
function store.scooters.setDock(id, stationId, slot)
    MySQL.update.await('UPDATE sd_scoot_scooters SET station_id = ?, slot = ? WHERE id = ?', { stationId, slot, id })
end

---Free every scooter parked at a station that is going away.
---@param stationId integer
function store.scooters.detachStation(stationId)
    MySQL.update.await('UPDATE sd_scoot_scooters SET station_id = NULL, slot = NULL, status = ? WHERE station_id = ?', { 'available', stationId })
end

---Insert one scooter and return its new id.
---@param s table { plate, colour, bunkerId|nil, x, y, z, heading, status, createdBy }
---@return integer id
function store.scooters.insert(s)
    return MySQL.insert.await(
        'INSERT INTO sd_scoot_scooters (plate, colour, bunker_id, x, y, z, heading, status, created_by, customization) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { s.plate, s.colour, s.bunkerId, s.x, s.y, s.z, s.heading, s.status or 'available', s.createdBy, json.encode(s.customization) }
    )
end

---Position write-back. Deliberately not awaited: it runs from the sync timer and from
---onResourceStop, where waiting on the database would stall teardown.
---@param id integer
---@param x number
---@param y number
---@param z number
---@param heading number
function store.scooters.setPosition(id, x, y, z, heading)
    MySQL.update('UPDATE sd_scoot_scooters SET x = ?, y = ?, z = ?, heading = ? WHERE id = ?', { x, y, z, heading, id })
end

---Set a scooter's colour.
---@param id integer
---@param colour integer 1-based index into Config.Scooters.Colours
function store.scooters.setColour(id, colour)
    MySQL.update.await('UPDATE sd_scoot_scooters SET colour = ? WHERE id = ?', { colour, id })
end

---Set a scooter's status.
---@param id integer
---@param status string 'available' | 'rented' | 'disabled'
function store.scooters.setStatus(id, status)
    MySQL.update.await('UPDATE sd_scoot_scooters SET status = ? WHERE id = ?', { status, id })
end

---Assign a scooter to a bunker, or free it.
---@param id integer
---@param bunkerId integer|nil nil makes the scooter free-standing
function store.scooters.setBunker(id, bunkerId)
    MySQL.update.await('UPDATE sd_scoot_scooters SET bunker_id = ? WHERE id = ?', { bunkerId, id })
end

---Delete a scooter row.
---@param id integer
function store.scooters.delete(id)
    MySQL.update.await('DELETE FROM sd_scoot_scooters WHERE id = ?', { id })
end

---Free every scooter whose home bunker is going away.
---@param bunkerId integer
function store.scooters.detachBunker(bunkerId)
    MySQL.update.await('UPDATE sd_scoot_scooters SET bunker_id = NULL WHERE bunker_id = ?', { bunkerId })
end

---Highest numeric suffix in use for a plate prefix, 0 when none. Reads the table rather than the
---cache so a plate freed by a delete is never handed out twice in one boot.
---@param prefix string e.g. 'SCOOT'
---@return integer
function store.scooters.highestPlateNumber(prefix)
    return MySQL.scalar.await(
        'SELECT MAX(CAST(SUBSTRING(plate, ?) AS UNSIGNED)) FROM sd_scoot_scooters WHERE plate LIKE ?',
        { #prefix + 1, prefix .. '%' }
    ) or 0
end

---Register the module so `require 'server.scoot.store'` returns this table.
---@return table
package.preload['server.scoot.store'] = function() return store end
