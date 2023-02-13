-- AfterCast 
--
-- Originally created by Iriel
-- iriel@vigilance-committee.org
-- Last revision: v1.1-20000
-- Date: 12-03-2006
--
-- Picked up and updated by Nutbrittle
-- Current verison: v2.01-30200
-- Date: 08-18-2009
--
-- Updated to work on WotLK by Runi
-- Current version v2.02-30300
-- Date: 13-02-2023
--
---------------------------------------------------------------------------

local function ShowArg(label,value)
    if (value ~= nil) then
        DEFAULT_CHAT_FRAME:AddMessage("[" .. label .. "] " .. value);
    end
end

local lastStop = nil; -- Which event type was the last terminal one

local knownEvents = {
    ["start"] = "Start of cast",
    ["done"] = "End of cast",
    ["fail"] = "Failed cast",
    ["interrupt"] = "Interrupted cast",
    ["delayed"] = "Delated cast (first delay)"
};

local castEvents = {};

local function AfterCast_DoEvent(event)
    if (event == nil) then
	    return;
    end

    local eBox = AfterCastEditBox;

    eBox.chatType  = "SAY";
    eBox.chatFrame = DEFAULT_CHAT_FRAME;
--    eBox.language  = ChatFrameEditBox.language;

    eBox:SetText(event);

    ChatEdit_SendText(eBox, nil);
end

local function Error(msg)
    DEFAULT_CHAT_FRAME:AddMessage("AfterCast: " .. msg);
end

local StateObject = {
    state = "Init";
    
    Event = function(self, event, ...)
    
        -- Uncomment this line for Debugging
        -- It will list the AfterCast events as they occur
        -- ShowArg("ACEvent", event);
        
        local terminal = nil;
        if ((event ~= "start") and (event ~= "delayed")) then
            lastStop = event;
            terminal = true;
        end
        local cmd = castEvents[event];
        if (terminal) then
            for k,v in pairs(castEvents) do castEvents[k] = nil; end
        end
        if (cmd) then
            AfterCast_DoEvent(cmd, ...);
        end
    end;

    ResetState = function(self, eventTable)
        if (self.state == "Init") then
            return;
        end
        self:ProcessEvent("__INIT__", eventTable);
        return true;
    end;

    StartTimer = function(self, seconds)
        -- DEFAULT_CHAT_FRAME:AddMessage("  Timer " ..seconds);
        self.fireAt = GetTime() + seconds;
        AfterCastFrame:Show();
    end;

    ProcessEvent = function(self, event, eventTable, fireEntry, ...)
        local oldState = self.state;

        -- Uncomment this line for Debugging
        -- It will list the WoW Events and AfterCast State as they occur
        -- Error("State=" .. oldState .. " Event=" .. (event or "nil"));

        local tbl = eventTable[oldState];
        if (not tbl) then
            Error("Unexpected state " .. oldState);
            if (oldState == 'Init') then
                return;
            end
            self.state = "Init";
            return self:ProcessEvent(event, eventTable, true, ...);
        end

        if (fireEntry and tbl._ENTRY) then
            tbl._ENTRY(self);
        end

        if (not event) then return; end;

        local func = tbl[event];
        if (not func) then
            if (event == "__TIMER__") then
                return;
            end
            func = tbl["*"];
            if (not func) then
                if (event ~= "__INIT__") then
                    Error("Unexpected event " .. event .. " in " .. oldState);
                end
                if (oldState == 'Init') then
                    return;
                end
                self.state = "Init";
                return self:ProcessEvent(event, eventTable, true, ...);
            end
        end

        local noConsume = func(self, ...);
        if (oldState == self.state) then
          	-- We're done
           	return;
        elseif (not noConsume) then
           	event = nil;
        end
        return self:ProcessEvent(event, eventTable, true, ...);
    end;
} -- StateObject


-- each entry function is called as:
--
-- noConsume = func(stateObject)
--
-- stateObject.state = .. <set new state>
-- stateObject:Event(event, args) = Dispatch event
-- stateObject:StartTimer(seconds) = Schedule __TIMER__ event

local TRANSITION_TABLE = {

    Init = {
    	
        _ENTRY = function(self)
            self.isDelayed = false;
        end;

        UNIT_SPELLCAST_FAILED = function(self)
            -- Fired when a unit's spellcast fails, including party/raid members or the player
			-- Fail before Start e.g. when out of range, not in line of sight, spell not ready
            self:Event("fail");
        end;

        UNIT_SPELLCAST_SENT = function(self, unit, spell, rank)
            -- Fired when an event is sent to the server.
            self.state = "Sent";
        end;

        ["*"] = function(self) end;
        
    }, -- Init

    Sent = {
    	
        UNIT_SPELLCAST_SENT = function(self, unit, spell, rank)
            -- Fired when an event is sent to the server.
            -- self.state = "Sent";
        end;

        UNIT_SPELLCAST_CHANNEL_START = function(self)
        	-- Fired when a unit begins channeling in the course of casting a spell.
        	-- Received for party/raid members as well as the player.
            self:Event("start");
            self.state = "ChannelCast";
        end;
        
        UNIT_SPELLCAST_CHANNEL_STOP = function(self, unit, spell, rank)
            -- Fired when a unit stops channeling. Received for party/raid members as well as the player.
            self:Event("done")
            self.state = "Init";
        end;

        UNIT_SPELLCAST_FAILED = function(self)
            -- Fired when a unit's spellcast fails, including party/raid members or the player
			-- Fail before Start e.g. when out of range, not in line of sight, spell not ready
            self:Event("fail");
            self.state = "Init";
        end;

        UNIT_SPELLCAST_INTERRUPTED = function(self)
            -- Fired when a unit's spellcast is interrupted, including party/raid members or the player
            self:Event("interrupt");
            self.state = "Init";
        end;

        UNIT_SPELLCAST_START = function(self)
        	-- Fired when a unit begins casting, including party/raid members or the player
            self:Event("start");
            self.state = "NormalCast";
        end;

        UNIT_SPELLCAST_SUCCEEDED = function(self, unit, spell, rank)
            -- Fired when a spell is cast successfully. Event is received even if spell is resisted.
            -- Succeed before Start means it's an instant cast
            self:Event("start", spell);
            self:Event("done");
            self.state = "Init";
        end;

    }, -- Sent

    NormalCast = {
    	
        UNIT_SPELLCAST_DELAYED = function(self)
            -- Fired when a unit's spellcast is delayed, including party/raid members or the player
            if (not self.isDelayed) then
                self.isDelayed = true;
                self:Event("delayed");
            end;
        end;

        UNIT_SPELLCAST_FAILED = function(self)
        -- Fired when a unit's spellcast fails, including party/raid members or the player
        	self:Event("fail");
        	self.state = "Init";
        end;

        UNIT_SPELLCAST_INTERRUPTED = function(self)
            -- Fired when a unit's spellcast is interrupted, including party/raid members or the player
            self:Event("interrupt");
            self.state = "Init";
        end;

        UNIT_SPELLCAST_SENT = function(self, unit, spell, rank)
            -- Fired when an event is sent to the server.
            -- In this case when a new spell is cast before the first one is finished -> ignore
            -- self.state = "Sent";
        end;

        UNIT_SPELLCAST_STOP = function(self)
            -- Fired when a unit stops casting, including party/raid members or the player
            self.state = "StopOrInterrupt";
        end;

        UNIT_SPELLCAST_SUCCEEDED = function(self, unit, spell, rank)
            -- Fired when a spell is cast successfully. Event is received even if spell is resisted.
            self:Event("done");
            self.state = "Init";
        end;

    }, -- Normal Cast

    StopOrInterrupt = {
        _ENTRY = function(self) 
            self:StartTimer(1.0);
        end;

--        __TIMER__ = function(self)
--            -- Normal termination
--            self:Event("done");
--            self.state = "Init";
--        end

--        UNIT_SPELLCAST_INTERRUPTED = function(self)
--            -- Fired when a unit's spellcast is interrupted, including party/raid members or the player
--            self:Event("interrupt");
--            self.state = "Init";
--        end
        
        ["*"] = function(self)
            -- Normal termination
--            self:Event("done");
			self.Event("interrupt");
            self.state = "Init";
--            return true; -- No consume
        end;

    }, -- StopOrInterrupt

    ChannelCast = {
    	
        UNIT_SPELLCAST_CHANNEL_STOP = function(self, unit, spell, rank)
            -- Fired when a unit stops channeling. Received for party/raid members as well as the player.
            self:Event("done")
            self.state = "Init";
        end;

        UNIT_SPELLCAST_DELAYED = function(self)
            -- Fired when a unit's spellcast is delayed, including party/raid members or the player
            if (not self.isDelayed) then
                self.isDelayed = true;
                self:Event("delayed");
            end;
        end;

        UNIT_SPELLCAST_SENT = function(self, unit, spell, rank)
            -- Fired when an event is sent to the server.
            -- In this case when a new spell is cast before the first one is finished -> ignore
            -- self.state = "Sent";
        end;

        UNIT_SPELLCAST_SUCCEEDED = function(self, unit, spell, rank)
            -- Fired when a spell is cast successfully. Event is received even if spell is resisted.
            -- self:Event("done")
            -- self.state = "Init";
        end;

    } -- ChannelCast
    
} -- TRANSITION_TABLE

function AfterCast_OnUpdate(self, interval)
    local at = StateObject.fireAt;
    if (not at) then
        self:Hide();
        return;
    end
    if (GetTime() < at) then
        return;
    end
    self:Hide();
    StateObject.fireAt = nil;
    StateObject:ProcessEvent("__TIMER__", TRANSITION_TABLE);
end

function AfterCast_OnEvent(self, event, ...)
    local unit, arg2, arg3, arg4 = ...;

    if (unit ~= "player") then return; end

    --ShowArg("event", event);
    --ShowArg("time", GetTime());
    --ShowArg("arg2", arg2);
    --ShowArg("arg3", arg3);

    StateObject:ProcessEvent(event, TRANSITION_TABLE, false, ...);
end

function AfterCast(doneEvent,failEvent)
    StateObject:ResetState(TRANSITION_TABLE);
    for k,v in pairs(castEvents) do castEvents[k] = nil; end
    castEvents["done"] = doneEvent;
    castEvents["fail"] = failEvent;
end

function AfterCastOn(type, event)
    if (StateObject:ResetState(TRANSITION_TABLE)) then
    for k,v in pairs(castEvents) do castEvents[k] = nil; end
    end
    castEvents[type] = event;
end

function AfterCastLastStop(clearFlag)
    local ret = lastStop;
    if (clearFlag) then
	    lastStop = nil;
    end
    return ret;
end

local function AfterCast_Command(msg)
    local err = nil;
    local s,e,etype,event = string.find(msg, "^%s*[+]([^%s]+)%s+(.*)$");
    if (s) then
        etype = string.lower(etype);
        if (knownEvents[etype]) then
            AfterCastOn(etype, event);
            return;
        else
            err = true;
            DEFAULT_CHAT_FRAME:AddMessage("AfterCast: Invalid event type '" .. etype .. "'");
        end
    end

    if (not err) then
        s,e,event = string.find(msg, "^%s*([^%s+].*)$");
        if (s) then
            AfterCast(event);
            return;
        end;
    end

    DEFAULT_CHAT_FRAME:AddMessage("AfterCast: [+eventType] <command>");
    local etlist = "";
    for k, v in pairs(knownEvents) do
        if (etlist ~= "") then
            etlist = etlist .. ", ";
        end
        etlist = etlist .. k;
    end
    DEFAULT_CHAT_FRAME:AddMessage("           eventTypes: " .. etlist);
end -- AfterCast_Command

function AfterCast_OnLoad(self)
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START");
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP");
    self:RegisterEvent("UNIT_SPELLCAST_DELAYED");
    self:RegisterEvent("UNIT_SPELLCAST_FAILED");
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED");
    self:RegisterEvent("UNIT_SPELLCAST_START");
    self:RegisterEvent("UNIT_SPELLCAST_STOP");
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");
    self:RegisterEvent("UNIT_SPELLCAST_SENT");

    SLASH_AFTERCAST1 = "/aftercast";
    SLASH_AFTERCAST2 = "/ac";
    SlashCmdList["AFTERCAST"] =
    function(msg)
        AfterCast_Command(msg);
    end
end -- AfterCast_OnLoad

function AfterCastDebug()
    for k, v in pairs(knownEvents) do
        AfterCastOn(k, "/script ChatFrame1:AddMessage(\"" .. k .. "\")");
    end
end

local frame = CreateFrame("Frame", "AfterCastFrame");
frame:Hide();
frame:SetScript("OnEvent", AfterCast_OnEvent);
frame:SetScript("OnUpdate", AfterCast_OnUpdate);
AfterCast_OnLoad(frame);
