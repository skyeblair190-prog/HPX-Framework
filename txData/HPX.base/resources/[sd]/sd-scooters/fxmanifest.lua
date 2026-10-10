fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sd-scooters'
description 'SCOOT rental e-scooters: vehicle model, standing rider animations, the dispensing station props, the rental economy, the phone app and the /scootadmin panel'
author 'samueldev'
version '0.9.10'

-- Every module is listed here in dependency order rather than pulled in by require: escrow only
-- decrypts files the manifest loads, so each module registers itself in package.preload and the
-- require calls resolve from there. A module must appear after everything it requires, or ox_lib
-- falls back to reading it off disk (runs it twice in source, fails outright when encrypted).
-- configs/ and bridge/ ship unencrypted and are still loaded lazily through require.
shared_scripts {
    '@ox_lib/init.lua',
    'shared/log.lua',
    'shared/extras.lua',
    'shared/settings.lua',
}

client_scripts {
    'bridge/client/keys.lua',
    'client/scoot/settings.lua',
    'client/scoot/fleet.lua',
    'client/scoot/clipset.lua',
    'client/scoot/kickstand.lua',
    'client/scoot/rider.lua',
    'client/scoot/bunkers.lua',
    'client/scoot/stations.lua',
    'client/scoot/placer.lua',
    'client/scoot/handling.lua',
    'client/scoot/admin.lua',
    'client/scoot/app.lua',
    'client/scoot/extras.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/scoot/store.lua',
    'server/scoot/bunkers.lua',
    'server/scoot/stations.lua',
    'server/scoot/scooters.lua',
    'server/scoot/battery.lua',
    'server/scoot/rentals.lua',
    'server/scoot/handling.lua',
    'server/scoot/settings.lua',
    'server/scoot/admin.lua',
    'server/scoot/app.lua',
    'server/scoot/extras.lua',
    'server/main.lua',
}

ui_page 'web/build/index.html'

files {
    'configs/config.lua',
    'configs/*.json',
    'textures/scoot_name_atlas.png',
    'web/build/assets/*.wav',
    'configs/shared/**.lua',
    'locales/*.json',
    'web/build/index.html',
    'web/build/app/index.html',
    'web/build/app/icon.svg',
    'web/build/screen/index.html',
    'web/build/assets/*.js',
    'web/build/assets/*.css',
    'web/build/assets/*.glb',
    'web/build/assets/*.png',
    'web/build/assets/*.woff2',
    'data/vehicles.meta',
    'data/handling.meta',
    'data/carvariations.meta',
    'data/vehiclelayouts.meta',
    'data/clip_sets.xml',
}

-- Order matters: the layout and clip set must be registered before vehicles.meta
-- references them, or the model info stores a null layout and CreateVehicle crashes
-- the client (crash hash hotel-five-nevada, seen 2026-09-12).
data_file 'CLIP_SETS_FILE'          'data/clip_sets.xml'
data_file 'VEHICLE_LAYOUTS_FILE'    'data/vehiclelayouts.meta'
data_file 'HANDLING_FILE'           'data/handling.meta'
data_file 'VEHICLE_METADATA_FILE'   'data/vehicles.meta'
data_file 'VEHICLE_VARIATION_FILE'  'data/carvariations.meta'

-- stream/: sd_scoot.yft + _hi (the vehicle, with the stem-fold extras), the rider clip dictionary
-- (.ycd), the station drawables (bunker, slats, ramp, pusher, lights, legacy deck/stem) and the one
-- ytyp that registers all seven archetypes.
data_file 'DLC_ITYP_REQUEST'        'stream/sd_scoot_bunker2.ytyp'

-- Restart rule: never restart this resource with a player connected. Unmounting the vehicle
-- layout / clip set crashes their client, and changed streamed files are only picked up on
-- connect anyway. /scootflush only rebuilds station props and respawns idle scooters.

dependencies { 'ox_lib', 'oxmysql', 'hpx_core' }

-- Separate hinged stand; local cosmetic attachment controlled by kickstand.lua.
data_file 'DLC_ITYP_REQUEST' 'stream/sd_scoot_stand.ytyp'

data_file 'DLC_ITYP_REQUEST' 'stream/sd_scoot_extras.ytyp'

-- Charging stations: the rail + pillar prop, its always-on LED twin and the two per-slot lenses.
data_file 'DLC_ITYP_REQUEST' 'stream/sd_scoot_charger.ytyp'

escrow_ignore {
    '**/*.lua',
    'stream/*',
}
