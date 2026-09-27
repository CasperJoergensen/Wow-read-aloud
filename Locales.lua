-- Translations for Lorecaster's own labels and messages. Quest, gossip and
-- book text is read in whatever language the game client uses; this only
-- covers the addon's UI.
--
-- Keys are the English strings. A missing translation falls back to English.
-- To add a language, add a block like:
--
--   if locale == "deDE" then
--       L["Read Aloud"] = "Vorlesen"
--   end

local _, ns = ...

local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
ns.L = L

local locale = GetLocale and GetLocale() or "enUS"
