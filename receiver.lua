-- EVENT utilities
context = aura_env.context
if not context then
	context = {}
	context.priority_list = {}
	context.next_set = nil
	aura_env.context = context
end

-- Helpers
local function GetNextSlot(set, toggles)
	if set[13] == nil and toggles[13] then
		return 13
	elseif set[14] == nil and toggles[14] == true then
		return 14
	end
end

local function CreateEmptySet(toggles)
	local set = {}
	if toggles[13] == true then
		set[13] = nil
	end
	if toggles[14] == true then
		set[14] = nil
	end
	return set
end

local function SetIncomplete(set, toggles)
	local status = (set[13] == nil and toggles[13] == true) or (set[14] == nil and toggles[14] == true)
	return status
end

local function trinket_comp(trinket_a, trinket_b)
	if trinket_a[1] < trinket_b[1] then
		return true
	elseif trinket_b[1] < trinket_a[1] then
		return false
	else
		if trinket_a[2] <= trinket_b[2] then
			return true
		else
			return false
		end
	end
end

local function ShallowCopy(tbl)
	local copy = {}
	for i, v in pairs(tbl) do
		copy[#copy + 1] = v
	end
	return copy
end

-- Debugging
context.debug_mode = aura_env.config.debug_mode

function context:Debug(func, msg, ...)
	if context.debug_mode == true then
		print("[" .. func .. "] " .. msg)
	end
end

function context:DumpTable(table)
	if context.debug_mode then
		UIParentLoadAddOn("Blizzard_DebugTools")
		DisplayTableInspectorWindow(table)
	end
end

-- Utilities
function context:NeedsUpdate(priority)
	local priority_list = context.priority_list
	local trinket_info = priority_list[priority]
	if not trinket_info then
		return true
	else
		return GetTime() > trinket_info[1]
	end
end

function context:RemainingTime(timestamp, trinket_id)
	local remaining_icd = 0
	local now = GetTime()
	if timestamp > 0 and timestamp > now then
		remaining_icd = math.abs(now - timestamp)
	end
	self:Debug(
		"RemainingTime",
		"trinket_id="
			.. trinket_id
			.. " current_time="
			.. now
			.. " timestamp="
			.. timestamp
			.. " remaining_icd="
			.. remaining_icd
	)
	return remaining_icd
end

function context:NtoS(value)
	return value or "nil"
end

-- Getters/Setters
function context:UpdateTrinket(trinket_id, priority, timestamp)
	self:Debug("UpdateTrinket", "trinket_id=" .. trinket_id .. " with timestamp=" .. timestamp)
	local priority_list = context.priority_list
	priority_list[priority] = { timestamp, trinket_id }
	self:Debug("UpdateTrinket", " loaded into store trinket_id=" .. trinket_id .. " with timestamp=" .. timestamp)
end

function context:GetShortestRemaining()
	local priority_list = context.priority_list
	if context.debug_mode then
		self:Debug("GetShortestRemaining", "============ printing queue ==========")
		for i, v in ipairs(priority_list) do
			print(v[2] .. " --- " .. v[1])
		end
	end

	local queue = ShallowCopy(priority_list)
	table.sort(queue, trinket_comp)
	local current_equipped = self:GetCurrentSet()
	local toggles = {
		[13] = aura_env.config.trinket_1_enabled,
		[14] = aura_env.config.trinket_2_enabled,
	}
	local planned_set = CreateEmptySet(toggles)
	if context.debug_mode then
		self:Debug("GetShortestRemaining", "============ printing queue ==========")
		for i, v in pairs(queue) do
			print(v[2] .. " --- " .. v[1])
		end
	end

	for i, trinket_info in ipairs(queue) do
		if SetIncomplete(planned_set, toggles) == false then
			break
		end
		local trinket_id = trinket_info[2]
		self:Debug("GetShortestRemaining", " checking trinket_id=" .. trinket_id .. " with icd=" .. trinket_info[1])
		local slot = current_equipped[trinket_id]
		if slot ~= nil and toggles[slot] == true then
			planned_set[slot] = trinket_id
		elseif current_equipped[trinket_id] == nil then
			slot = GetNextSlot(planned_set, toggles)
			if slot then
				planned_set[slot] = trinket_id
			end
		else
		end
	end
	return planned_set
end

function context:SetNext(next_set)
	if not next_set then
		next_set = self:GetShortestRemaining()
	end
	self.next_set = next_set
end

function context:GetNext()
	self:Debug("GetNext", "called")
	local next_set = context.next_set
	if not next_set then
		next_set = self:GetShortestRemaining()
	end
	return next_set
end

function context:ResetNext()
	self:Debug("ResetNext", "setting self.next_trinket=nil")
	self.next_set = nil
end

function context:GetCurrentSet()
	self:Debug("GetCurrentSet", "called")
  local trinket_1 = self:GetEquipped(13)
  local trinket_2 = self:GetEquipped(14)
	local current_set = {
		[trinket_1] = 13,
		[trinket_2] = 14,
	}
	self:DumpTable(current_set)
	return current_set
end

function context:GetEquipped(trinket_slot)
	local equipped = GetInventoryItemLink("player", trinket_slot)
  if equipped ~= nil then
     local id = GetItemInfoFromHyperlink(equipped)
     self:Debug("GetEquipped", "currently equipped trinket_id=" .. id)
     return id
  end
end

-- EVENT handler
function context:Trigger(trinket_id, duration, priority, timestamp)
	self:Debug("Trigger", "received trigger instruction for trinket_id=" .. trinket_id)
	if self:NeedsUpdate(priority) then
		self:Debug("Trigger", "updating state for trinket_id=" .. trinket_id)
		self:UpdateTrinket(trinket_id, priority, timestamp + duration)
	end
end

function context:Load(trinket_id, duration, priority, timestamp)
	if not context.priority_list then
		print("SOMETHING IS WORNG")
		return
	end
	if not trinket_id then
		self:Debug("Load", "invalid trinket_id received")
		return
	end
	self:Debug("Load", "received for trinket_id=" .. trinket_id)
	if self:NeedsUpdate(priority) then
		self:UpdateTrinket(trinket_id, priority, timestamp)
	end
end

function context:DispatchEvent(event, ...)
	self:Debug("DispatchEvent", event .. " received")
	if event == "CAFEUI_TRINKET_ICD_LOAD" then
		return self:Load(...)
	elseif event == "CAFEUI_TRINKET_ICD_TRIGGER" then
		return self:Trigger(...)
	else
		return nil
	end
end

-- on hide
local next_set = aura_env.context:GetNext()
aura_env.context:Debug("Untrigger", "executing")
if next_set ~= nil then
    for slot, trinket_id in pairs(next_set) do
        if slot and trinket_id then
            aura_env.context:Debug("Untrigger", "trinket_id=" .. trinket_id .. " being equipped in slot=" .. slot)
            EquipItemByName(trinket_id, slot)
        end
    end
end

-- Trigger 1
-- CAFEUI_TRINKET_ICD_TRIGGER,CAFEUI_TRINKET_ICD_LOAD
function(...)
    aura_env.context:Debug("Receiver", "==============Start==============")
    aura_env.context:DispatchEvent(...)
    aura_env.context:Debug("Receiver", "==============End==============")
end

-- Trigger 2
-- PLAYER_REGEN_ENABLED,PLAYER_REGEN_DISABLE
function(event)
    return event == "PLAYER_REGEN_DISABLED"
end

-- Trigger 3
-- Every frame
function()
    if aura_env.config.no_combat_swap and (not aura_env.last or aura_env.last < GetTime() - aura_env.config.poll_frequency) then
        aura_env.last = GetTime()
        return true
    end
    return false
end
