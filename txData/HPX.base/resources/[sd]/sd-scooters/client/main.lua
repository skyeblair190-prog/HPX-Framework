---@type table sd_scoot config root (configs/config.lua).
local config = require 'configs.config'
---@type table Console log helper (shared/log.lua): tagged, colour-coded prints.
local log = require 'shared.log'

---Every client/scoot module is loaded by fxmanifest.lua, in dependency order, before this file.
---They register in package.preload instead of being pulled in here, because escrow only decrypts
---files the manifest loads directly; require would read the encrypted bytes off disk.
lib.locale(config.Locale)

log.debug(nil, 'client loaded')
