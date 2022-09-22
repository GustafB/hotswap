-- Trigger 1
-- CLEU:SPELL_AURA_APPLIED
function untrigger(...)
	local _, timestamp, _, _, sourceGUID, _, _, _, targetGUID, _, _, _, spellId = ...
	pid = UnitGUID("player")
	if targetGUID ~= pid and sourceGUID ~= pid then
		return
	end
	if spellId == aura_env.config.buff then
		WeakAuras.ScanEvents(
			"CAFEUI_TRINKET_ICD_TRIGGER",
			aura_env.config.trinket,
			aura_env.config.duration,
			aura_env.config.priority,
			GetTime()
		)
	end
	return false
end

-- Untrigger
function untrigger()
	return true
end

-- on init
sender_context = aura_env.sender_context

if not sender_context then
    sender_context = {}
    aura_env.sender_context = sender_context
end

function sender_context:Debug(func, msg, ...)
    if aura_env.config.debug_mode == true then
        print("[" .. func .. "] " .. msg)
    end
end

function sender_context:NtoS(value)
    return value or "nil"
end

function sender_context:ItemReadyAt(item_id)
    local ready_at = 0
    if GetItemSpell(item_id) then
        local start_time, total_cd = GetItemCooldown(item_id)
        if start_time ~= 0 then
            ready_at = GetTime() - start_time + total_cd
        end
    end
    self:Debug("ItemReadyAt", "item_id=" .. item_id .. " is not yet usable ready_at=" .. ready_at)
    return ready_at
end

function sender_context:LoadStore()
    local trinket_id = aura_env.config["trinket"]
    local duration = aura_env.config["duration"]
    local priority = aura_env.config["priority"]
    if trinket_id and duration and priority then
        sender_context:Debug("LoadStore", "loading trinket_id=" .. trinket_id)
        WeakAuras.ScanEvents(
            "CAFEUI_TRINKET_ICD_LOAD",
            trinket_id,
            duration,
            priority,
            self:ItemReadyAt(trinket_id)
        )
    end
end

sender_context:LoadStore()
