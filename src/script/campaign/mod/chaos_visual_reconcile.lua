-- Conservative, world-wide reconciliation of orphaned campaign-map devastation visuals.
-- Path in PACK: script/campaign/mod/chaos_visual_reconcile.lua
-- Back up save first. This cannot query whether an event area is currently active;
-- it considers chasm/crater areas and refuses to clear any with known ongoing claims.
local PREFIX = '[ChaosVisualReconcile] '
local APPLY_FIX = true  -- Set true after reviewing dry run.
local function log(s) out(PREFIX .. tostring(s)) end

local function finished_chaos_invasion()
    return type(episodes_manager) == 'table'
        and type(episodes_manager.persistent) == 'table'
        and type(episodes_manager.persistent.finished_episodes) == 'table'
        and episodes_manager.persistent.finished_episodes['episode_chaos_invasion'] == true
end

local function still_claimed(region)
    local checks = {
        {'vermintide', episode_vermintide},
        {'chaos_invasion', episode_chaos_invasion},
        {'nagash_endgame', episode_nagash_endgame},
        {'land_of_the_dead', land_of_the_dead},
        {'archaon_narrative', archaon_narrative},
        {'thanquol', thanquol_chaotic_plans_token_payloads},
    }
    for _, entry in ipairs(checks) do
        local name, manager = entry[1], entry[2]
        if type(manager) == 'table' then
            if type(manager.should_region_be_devastated) ~= 'function' then
                return true, name .. ':missing_predicate'
            end
            local ok, result = pcall(function()
                return manager:should_region_be_devastated(region)
            end)
            if not ok then return true, name .. ':error:' .. tostring(result) end
            if result then return true, name .. ':active' end
        end
    end
    return false, nil
end

local function reconcile()
    log('callback started APPLY_FIX=' .. tostring(APPLY_FIX))
    if not finished_chaos_invasion() then
        log('ABORT: Chaos Invasion is not confirmed finished')
        return
    end
    local ok, regions = pcall(function()
        return cm:model():world():region_manager():region_list()
    end)
    if not ok or not regions then
        log('ERROR getting global region list: ' .. tostring(regions))
        return
    end
    local count_ok, count = pcall(function() return regions:num_items() end)
    if not count_ok then
        log('ERROR obtaining count: ' .. tostring(count))
        return
    end
    log('world_regions=' .. tostring(count))

    -- Gather *all* regions sharing each event area before making a decision.
    local areas = {}
    local errors = 0
    for i = 0, count - 1 do
        local success, err = pcall(function()
            local region = regions:item_at(i)
            if not region or region:is_null_interface() then return end
            local area = region:event_area_name()
            if type(area) ~= 'string' or area == '' then return end
            -- Narrow to map transformations known to have been used by this invasion.
            if not (area:match('_chasm$') or area:match('_crater$')) then return end
            if not areas[area] then areas[area] = {regions={}, reason=nil} end
            table.insert(areas[area].regions, region:name())
        end)
        if not success then
            errors = errors + 1
            log('SCAN_ERROR index=' .. tostring(i) .. ' ' .. tostring(err))
        end
    end
    -- Failing to scan the complete world makes cleanup unsafe.
    if errors > 0 then
        log('ABORT: ' .. tostring(errors) .. ' region scan errors; no deactivations')
        return
    end

    local candidates, protected, requests = 0, 0, 0
    for area, data in pairs(areas) do
        local reason
        for _, key in ipairs(data.regions) do
            local reg_ok, region = pcall(function() return cm:get_region(key) end)
            if not reg_ok or not region or region:is_null_interface() then
                reason = 'region_lookup_failed:' .. key
                break
            end
            local claim_ok, claimed, why = pcall(function() return still_claimed(region) end)
            if not claim_ok or claimed then
                reason = claim_ok and why or ('claim_check_error:' .. tostring(claimed))
                break
            end
            -- Respect surviving registered devastation, especially from another system.
            local saved = type(devastation_manager) == 'table'
                and type(devastation_manager.persistent) == 'table'
                and devastation_manager.persistent[key]
            if type(saved) == 'table' then
                local culture = saved.devastation_culture
                if culture ~= 'wh_main_chs_chaos' then
                    reason = 'recorded_devastation:' .. tostring(culture)
                    break
                end
            end
            -- Also protect surviving non-Chaos climate claims, if any.
            local changes = type(climate_change) == 'table'
                and type(climate_change.current_changes) == 'table'
                and climate_change.current_changes[key]
            if type(changes) == 'table' then
                for _, change in ipairs(changes) do
                    if change == 'vermintide_devastation' or change == 'land_of_the_dead'
                        or change == 'vampire_corpses' then
                        reason = 'other_climate_override:' .. change
                        break
                    end
                end
                if reason then break end
            end
        end
        if reason then
            protected = protected + 1
            log('PROTECTED area=' .. area .. ' reason=' .. tostring(reason))
        else
            candidates = candidates + 1
            log('CANDIDATE area=' .. area .. ' regions=' .. #data.regions)
            if APPLY_FIX then
                local done, err = pcall(function()
                    cm:deactivate_campaign_map_event_area(area)
                end)
                if done then
                    requests = requests + 1
                    log('DEACTIVATION_REQUESTED area=' .. area)
                else
                    log('DEACTIVATION_ERROR area=' .. area .. ' ' .. tostring(err))
                end
            end
        end
    end
    log('DONE world_regions=' .. count .. ' candidate_areas=' .. candidates ..
        ' protected_areas=' .. protected .. ' requests=' .. requests ..
        ' dry_run=' .. tostring(not APPLY_FIX))
end

function chaos_visual_reconcile()
    log('entry invoked')
    cm:callback(reconcile, 1, 'chaos_visual_reconcile_callback')
    log('callback scheduled')
end
log('file evaluated')
