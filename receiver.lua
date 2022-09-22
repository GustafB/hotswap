-- on init
PriorityQueue = {}
PriorityQueue.__index = PriorityQueue

function PriorityQueue.new(comparator)
   local new_queue = {}
   setmetatable(new_queue, PriorityQueue)
   new_queue.comparator = comparator
   new_queue.heap = {}
   return new_queue
end

function PriorityQueue:ShiftDown()

end

-- EVENT utilities
context = aura_env.context
if not context then
    context = {}
    context.priority_list = {}
    context.next_trinket = nil
    aura_env.context = context
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
    self:Debug("SetNext", "iterating over priority_list of size=" .. #context.priority_list)
    local priority_list = context.priority_list
    local next_trinket = nil
    local remaining_icd = nil
    self:Debug("SetNext", "current_timestamp=" .. GetTime())
    for i, trinket_info in ipairs(priority_list) do
        local icd = self:RemainingTime(trinket_info[1], trinket_info[2])
        self:Debug("SetNext", "trinket_id=" .. trinket_info[2] .. " has icd=" .. icd)
        if not remaining_icd or icd < remaining_icd then
            next_trinket = trinket_info[2]
            remaining_icd = icd
        end
    end
    self:Debug(
        "SetNext",
        "shortest remaining icd found trinket_id=" .. next_trinket .. " has icd=" .. remaining_icd
    )
    return next_trinket
end

function context:SetNext(trinket_id)
    if not trinket_id then
        trinket_id = self:GetShortestRemaining()
    end
    self:Debug("SetNext", "setting trinket_id=" .. self:NtoS(tmp_id))
    self.context.next_trinket = trinket_id
end

function context:GetNext()
    local next_trinket = context.next_trinket
    if not next_trinket then
        next_trinket = self:GetShortestRemaining()
    end
    if next_trinket == nil then
        self:Debug("GetNext", "no trinket available")
    elseif next_trinket == self:GetEquipped(14) then
        self:Debug("GetNext", "trinket already equipped, doing nothing")
    else
        self:Debug("GetNext", "trinket_id=" .. next_trinket .. " found")
    end
    return next_trinket
end

function context:ResetNext()
    self:Debug("ResetNext", "setting self.next_trinket=nil")
    self.context.next_trinket = nil
end

function context:GetEquipped(trinket_slot)
    local equipped = GetInventoryItemLink("player", trinket_slot)
    local id = GetItemInfoFromHyperlink(equipped)
    self:Debug("GetEquipped", "currently equipped trinket_id=" .. id)
    return id
end

function context:GetIfReady(trinket_info)
    self:Debug(
        "GetIfReady",
        " comparing " .. GetTime() .. " against " .. trinket_info[1] .. " for trinket_id=" .. trinket_info[2]
    )
    if GetTime() > trinket_info[1] then
        self:Debug("GetIfReady", "trinket_id=" .. trinket_info[2] .. "is ready!")
        return trinket_info[2]
    end
    return nil
end

-- EVENT handler
function context:Trigger(trinket_id, duration, priority, timestamp)
    self:Debug("Trigger", "received trigger instruction for trinket_id=" .. trinket_id)
    if self:NeedsUpdate(priority) then
        self:Debug("Trigger", "updating state for trinket_id=" .. trinket_id)
        self:UpdateTrinket(trinket_id, priority, timestamp + duration)
    end
    local next_trinket = self:NtoS(self:GetNext())
    self:Debug("Trigger", "completed, next_trinket=" .. next_trinket)
    return next_trinket
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
    return nil
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
local next_trinket = aura_env.context:GetNext()
aura_env.context:Debug("Untrigger", "executing")
if next_trinket ~= nil then
	aura_env.context:Debug("Untrigger", "trinket_id=" .. next_trinket .. " being equipped")
	EquipItemByName(next_trinket, 14)
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
