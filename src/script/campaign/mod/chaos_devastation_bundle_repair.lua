-- One-shot cleanup of orphaned Chaos Invasion devastation effect bundles.
-- Use ONLY on a backup save after completing the Chaos Invasion finale.
-- This does not change settlement climates or other devastation systems.
local PREFIX = "[ChaosBundleRepair] "
local BUNDLE = "wh3_dlc29_episodes_chaos_invasion_devastated_province"

local function log(message)
    out(PREFIX .. tostring(message))
end

local function repair()
    if type(episodes_manager) ~= "table"
        or type(episodes_manager.persistent) ~= "table"
        or type(episodes_manager.persistent.finished_episodes) ~= "table"
    then
        log("SKIPPED: episode completion state unavailable")
        return
    end

    if episodes_manager.persistent.finished_episodes["episode_chaos_invasion"] ~= true then
        log("SKIPPED: Chaos Invasion finale is not recorded as completed")
        return
    end

    local region_list = cm:model():world():region_manager():region_list()
    if not region_list or region_list:is_null_interface() then
        log("SKIPPED: region list unavailable")
        return
    end

    local count = 0
    for i = 0, region_list:num_items() - 1 do
        local region = region_list:item_at(i)
        if region and not region:is_null_interface() then
            -- The devastation manager applied this PROVINCE-named bundle to REGIONS.
            cm:remove_effect_bundle_from_region(BUNDLE, region:name())
            count = count + 1
        end
    end

    log("Cleanup requested for " .. count .. " regions; key=" .. BUNDLE)
    log("This count is regions checked, NOT bundles confirmed removed")
end

-- The campaign mod loader calls a global function named after the Lua filename.
-- Defining it here ensures initialization when multiple scripts share a .pack.
function chaos_devastation_bundle_repair()
    log("entry point invoked")
    cm:callback(function()
        log("repair callback entered")
        local ok, err = pcall(repair)
        if not ok then
            log("LUA ERROR: " .. tostring(err))
        end
    end, 2, "chaos_devastation_bundle_repair_once")
    log("callback scheduled")
end

log("file evaluated")
