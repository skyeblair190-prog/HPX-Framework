---@type table Log module; the table returned at end of file.
local log = {}

---@type string Console scope prefix: the running resource's name, so the dev twin and the real
---resource are told apart in the console without editing this file.
local RESOURCE = GetCurrentResourceName()

---@type table<string, string> Severity-to-console-colour prefixes (^2 green, ^3 yellow, ^1 red, ^5 cyan).
local COLORS = { info = '^2', warn = '^3', error = '^1', debug = '^5' }

---Print one tagged console line: '<colour>[sd_scoot:<tag>]^0 <message>'. The message is
---fmt:format(...) only when args are present, so a plain message with a stray % is safe.
---@param level string 'info' | 'warn' | 'error' | 'debug'
---@param tag string|nil bracket suffix ('bunkers' -> [sd_scoot:bunkers]); nil -> [sd_scoot]
---@param fmt string message or string.format pattern
---@param ... any format arguments
local function emit(level, tag, fmt, ...)
    local msg = select('#', ...) > 0 and fmt:format(...) or fmt
    local scope = tag and (RESOURCE .. ':' .. tag) or RESOURCE
    print(('%s[%s]^0 %s'):format(COLORS[level], scope, msg))
end

---Green info line for normal lifecycle events.
---@param tag string|nil bracket suffix; nil for the bare resource tag
---@param fmt string message or string.format pattern
---@param ... any format arguments
function log.info(tag, fmt, ...) emit('info', tag, fmt, ...) end

---Yellow warning line for degraded-but-continuing situations.
---@param tag string|nil bracket suffix; nil for the bare resource tag
---@param fmt string message or string.format pattern
---@param ... any format arguments
function log.warn(tag, fmt, ...) emit('warn', tag, fmt, ...) end

---Red error line for failures.
---@param tag string|nil bracket suffix; nil for the bare resource tag
---@param fmt string message or string.format pattern
---@param ... any format arguments
function log.error(tag, fmt, ...) emit('error', tag, fmt, ...) end

---@type table|nil config root, required lazily on the first debug call so this module carries no
---load-order dependency on configs/config.lua.
local config

---Cyan debug line for development diagnostics. Prints only while config.Debug is on, so call
---sites never need their own gate.
---@param tag string|nil bracket suffix; nil for the bare resource tag
---@param fmt string message or string.format pattern
---@param ... any format arguments
function log.debug(tag, fmt, ...)
    config = config or require 'configs.config'
    if not config.Debug then return end
    emit('debug', tag, fmt, ...)
end

---Register the module so `require 'shared.log'` returns this table.
---@return table
package.preload['shared.log'] = function() return log end
