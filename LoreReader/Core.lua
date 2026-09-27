-- Startup, saved settings and slash commands.

local ADDON_NAME, ns = ...

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffc8a86bLoreReader:|r " .. msg)
end

local function initDB()
    LoreReaderDB = type(LoreReaderDB) == "table" and LoreReaderDB or {}
    for key, value in pairs(ns.DEFAULTS) do
        if type(LoreReaderDB[key]) ~= type(value) then
            LoreReaderDB[key] = value
        end
    end
    ns.db = LoreReaderDB
end

local function clamp(n, lo, hi)
    return math.max(lo, math.min(hi, n))
end

local HELP = {
    "/lore - open the options panel",
    "/lore stop - stop reading",
    "/lore test - read a sample",
    "/lore voices - list the voices WoW can see",
    "/lore voice <name|default> - pick a voice",
    "/lore rate <-10..10> - reading speed",
    "/lore volume <0..100> - volume",
}

local function listVoices()
    local voices = C_VoiceChat.GetTtsVoices() or {}
    if #voices == 0 then
        ns.Print("WoW reports no text-to-speech voices.")
        return
    end
    ns.Print("Voices WoW can see:")
    for _, voice in ipairs(voices) do
        local marker = (voice.name == ns.db.voice) and " (selected)" or ""
        ns.Print(("  %d: %s%s"):format(voice.voiceID, voice.name, marker))
    end
    if ns.db.voice == "" then
        ns.Print("Using the WoW default voice.")
    end
end

local function setVoice(query)
    if query == "" or query:lower() == "default" then
        ns.Options:Set("voice", "")
        ns.Print("Using the WoW default voice.")
        return
    end
    local needle = query:lower()
    for _, voice in ipairs(C_VoiceChat.GetTtsVoices() or {}) do
        if tostring(voice.voiceID) == query or voice.name:lower():find(needle, 1, true) then
            ns.Options:Set("voice", voice.name)
            ns.Speech.voiceBroken = false
            ns.Print("Voice set to " .. voice.name .. ".")
            return
        end
    end
    ns.Print("No voice matches \"" .. query .. "\". Try /lore voices.")
end

local function handleSlash(input)
    local cmd, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "" or cmd == "options" or cmd == "config" then
        ns.Options:Open()
    elseif cmd == "stop" then
        ns.Speech:Stop()
    elseif cmd == "test" then
        ns.Options:PlaySample()
    elseif cmd == "voices" then
        listVoices()
    elseif cmd == "voice" then
        setVoice(rest)
    elseif cmd == "rate" and tonumber(rest) then
        ns.Options:Set("rate", clamp(math.floor(tonumber(rest) + 0.5), -10, 10))
        ns.Print("Speed set to " .. ns.db.rate .. ".")
    elseif cmd == "volume" and tonumber(rest) then
        ns.Options:Set("volume", clamp(math.floor(tonumber(rest) + 0.5), 0, 100))
        ns.Print("Volume set to " .. ns.db.volume .. ".")
    else
        for _, line in ipairs(HELP) do
            ns.Print(line)
        end
    end
end

SLASH_LOREREADER1 = "/lore"
SLASH_LOREREADER2 = "/lr"
SLASH_LOREREADER3 = "/readaloud"
SlashCmdList.LOREREADER = handleSlash

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name == ADDON_NAME then
        initDB()
        ns.Options:Init()
    elseif event == "PLAYER_LOGIN" then
        ns.Buttons:TrySetup()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
