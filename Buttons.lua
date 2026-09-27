-- "Read Aloud" buttons on the lore frames, and the rules for when speech stops
-- on its own.
--
-- Stop rules:
--   * Closing the frame being read stops it (Escape, close button, walking away).
--   * Accept Quest / Complete Quest also close the quest frame, but the reading
--     keeps going so you can run off while the story finishes.
--   * Opening a different quest, gossip or book stops any reading, except in
--     the short window right after Accept/Complete (the NPC often reopens its
--     dialogue by itself then).
--   * Turning a book page or getting new gossip text stops reading that frame,
--     since the text on screen no longer matches.

local _, ns = ...
local L = ns.L

local Speech, Sources = ns.Speech, ns.Sources
local Buttons = { list = {} }
ns.Buttons = Buttons

local KEEP_WINDOW = 2 -- seconds after Accept/Complete during which frame changes don't stop speech
local keepUntil = 0

local function inKeepWindow()
    return GetTime() < keepUntil
end

-- Button positions, relative to each frame. Tweak here if a button overlaps
-- something in the WoW Forever UI.
local LAYOUT = {
    quest       = { "BOTTOM", 0, 4 },
    gossip      = { "BOTTOMLEFT", 8, 4 },
    itemText    = { "BOTTOMRIGHT", -8, 6 },
    questLog    = { "TOPRIGHT", -4, -4 },
    questLogPop = { "TOP", 0, -30 },
}

local READ_LABEL, STOP_LABEL = L["Read Aloud"], L["Stop"]

-- getKey() returns the source key for what the frame currently shows, or nil
-- to hide the button.
local function makeButton(name, parent, layout, getKey)
    local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    button:SetSize(100, 22)
    button:SetPoint(layout[1], parent, layout[1], layout[2], layout[3])
    button:SetFrameLevel(parent:GetFrameLevel() + 10)
    button.getKey = getKey

    button:SetScript("OnClick", function(self)
        local key = self.getKey()
        if not key then
            return
        end
        if Speech:IsSpeaking(key) then
            Speech:Stop()
        else
            Speech:Play(key, Sources[key]())
        end
    end)

    function button:Refresh()
        local key = self.getKey()
        if not key then
            self:Hide()
            return
        end
        self:SetText(Speech:IsSpeaking(key) and STOP_LABEL or READ_LABEL)
        self:Show()
    end

    button:SetScript("OnShow", button.Refresh)
    Buttons.list[#Buttons.list + 1] = button
    button:Refresh()
    return button
end

function Buttons:RefreshAll()
    for _, button in ipairs(self.list) do
        if button:GetParent():IsShown() then
            button:Refresh()
        end
    end
end

Speech:OnChange(function()
    Buttons:RefreshAll()
end)

local function hookIfExists(funcName, fn)
    if type(_G[funcName]) == "function" then
        hooksecurefunc(funcName, fn)
    end
end

-- Each setup runs once its frame exists; some frames live in load-on-demand
-- Blizzard addons, so setups are retried on ADDON_LOADED.
local setups = {}

setups.quest = function()
    if not QuestFrame then
        return false
    end
    local button = makeButton("LorecasterQuestButton", QuestFrame, LAYOUT.quest, function()
        if QuestFrameDetailPanel and QuestFrameDetailPanel:IsShown() then
            return "questDetail"
        elseif QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown() then
            return "questReward"
        end
    end)
    for _, panel in ipairs({ QuestFrameDetailPanel, QuestFrameRewardPanel, QuestFrameProgressPanel, QuestFrameGreetingPanel }) do
        panel:HookScript("OnShow", function() button:Refresh() end)
    end

    hookIfExists("AcceptQuest", function() keepUntil = GetTime() + KEEP_WINDOW end)
    hookIfExists("GetQuestReward", function() keepUntil = GetTime() + KEEP_WINDOW end)

    QuestFrame:HookScript("OnHide", function()
        if not inKeepWindow() then
            Speech:StopIf("questDetail", "questReward")
        end
    end)
    return true
end

setups.gossip = function()
    if not GossipFrame then
        return false
    end
    makeButton("LorecasterGossipButton", GossipFrame, LAYOUT.gossip, function()
        return "gossip"
    end)
    GossipFrame:HookScript("OnHide", function()
        if not inKeepWindow() then
            Speech:StopIf("gossip")
        end
    end)
    return true
end

setups.itemText = function()
    if not ItemTextFrame then
        return false
    end
    makeButton("LorecasterItemTextButton", ItemTextFrame, LAYOUT.itemText, function()
        return "itemText"
    end)
    ItemTextFrame:HookScript("OnHide", function()
        Speech:StopIf("itemText")
    end)
    return true
end

setups.questLog = function()
    local details = QuestMapFrame and QuestMapFrame.DetailsFrame
    if not details then
        return false
    end
    makeButton("LorecasterQuestLogButton", details, LAYOUT.questLog, function()
        return "questLog"
    end)
    details:HookScript("OnHide", function()
        Speech:StopIf("questLog")
    end)
    -- Opening another quest's details replaces the text on screen.
    hookIfExists("QuestMapFrame_ShowQuestDetails", function()
        Speech:StopIf("questLog")
    end)
    return true
end

setups.questLogPopup = function()
    if not QuestLogPopupDetailFrame then
        return false
    end
    makeButton("LorecasterQuestLogPopupButton", QuestLogPopupDetailFrame, LAYOUT.questLogPop, function()
        return "questLogPopup"
    end)
    QuestLogPopupDetailFrame:HookScript("OnHide", function()
        Speech:StopIf("questLogPopup")
    end)
    hookIfExists("QuestLogPopupDetailFrame_Show", function()
        Speech:StopIf("questLogPopup")
    end)
    return true
end

function Buttons:TrySetup()
    for name, setup in pairs(setups) do
        if setup() then
            setups[name] = nil
        end
    end
end

-- Frame-change events that mean "something else is now on screen".
local events = CreateFrame("Frame")
for _, event in ipairs({
    "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING",
    "GOSSIP_SHOW", "ITEM_TEXT_BEGIN", "ITEM_TEXT_READY", "ADDON_LOADED",
}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "ADDON_LOADED" then
        Buttons:TrySetup()
    elseif event == "ITEM_TEXT_READY" then
        -- Fires on page turns: the page being read is gone.
        Speech:StopIf("itemText")
        Buttons:RefreshAll()
    elseif not inKeepWindow() then
        Speech:Stop()
    end
end)
