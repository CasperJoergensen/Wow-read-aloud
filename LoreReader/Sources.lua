-- Where the lore text comes from. Each source returns the text parts to
-- speak (title, body or just body); any of them may be nil.

local _, ns = ...

local Sources = {}
ns.Sources = Sources

-- Quest offered by an NPC (description only; objectives are skipped).
Sources.questDetail = function()
    return GetTitleText(), GetQuestText()
end

-- Quest turn-in (completion text).
Sources.questReward = function()
    return GetTitleText(), GetRewardText()
end

local function questLogParts(questID)
    if not questID or questID == 0 then
        return
    end
    local title = C_QuestLog.GetTitleForQuestID(questID)
    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    local description = GetQuestLogQuestText(logIndex) -- second return (objectives) is skipped
    return title, description
end

-- Quest log details in the world map side panel.
Sources.questLog = function()
    return questLogParts(QuestMapFrame_GetDetailQuestID and QuestMapFrame_GetDetailQuestID())
end

-- Quest log details popup (opened from the objective tracker).
Sources.questLogPopup = function()
    return questLogParts(QuestLogPopupDetailFrame and QuestLogPopupDetailFrame.questID)
end

-- NPC gossip text; no title.
Sources.gossip = function()
    return C_GossipInfo.GetText()
end

-- Books, plaques and letters: current page only, title on the first page.
Sources.itemText = function()
    local page = ItemTextGetPage() or 1
    if page == 1 then
        return ItemTextGetItem(), ItemTextGetText()
    end
    return ItemTextGetText()
end
