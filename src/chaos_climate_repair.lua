-- WH3 Chaos Invasion climate repair / diagnostic.
-- Back up your save before setting APPLY_FIX to true.
local APPLY_FIX = false
local PREFIX = "[ChaosClimate] "
local function log(msg)
    out(PREFIX .. tostring(msg))
end

local function check_climate_state()
    if type(climate_change) ~= "table" or type(climate_change.current_changes) ~= "table" then
        log("climate_change.current_changes unavailable")
        return
    end
    if type(episodes_manager) ~= "table" or type(episodes_manager.persistent) ~= "table" then
        log("episodes_manager state unavailable")
        return
    end
    local finished = episodes_manager.persistent.finished_episodes
    local ended = type(finished) == "table" and finished["episode_chaos_invasion"] == true
    log("invasion finished=" .. tostring(ended) .. "; APPLY_FIX=" .. tostring(APPLY_FIX))
    if not ended then
        log("Not changing anything: invasion has not finished")
        return
    end

    local regions = {}
    local all_entries = 0
    for region_key, overrides in pairs(climate_change.current_changes) do
        all_entries = all_entries + 1
        if type(overrides) == "table" then
            for _, key in ipairs(overrides) do
                if key == "chaos_devastation" then
                    regions[#regions + 1] = region_key
                    break
                end
            end
        end
    end
    log("regions with any climate records=" .. all_entries .. "; chaos_devastation=" .. #regions)

    for _, key in ipairs(regions) do
        local region = cm:get_region(key)
        if region and not region:is_null_interface() then
            local settlement = region:settlement()
            local before = settlement:get_climate()
            local original = settlement:get_original_climate()
            log(key .. " current=" .. tostring(before) .. " original=" .. tostring(original))
            if APPLY_FIX then
                climate_change:remove_climate_override(region, "chaos_devastation")
                log(key .. " after=" .. tostring(settlement:get_climate()))
            end
        else
            log("Cannot resolve region " .. key)
        end
    end

    if #regions == 0 then
        log("No orphaned chaos_devastation entries. Do NOT reset all climates: cause is elsewhere.")
    end
end

cm:add_first_tick_callback(function()
    cm:callback(check_climate_state, 2, "chaos_climate_repair_check")
end)
