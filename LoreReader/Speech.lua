-- Speech queue on top of the game's built-in TTS (C_VoiceChat.SpeakText).
-- Text is spoken one chunk at a time; the next chunk is sent when the game
-- reports the previous utterance finished. Only one reading is active at a
-- time: starting a new one stops the old one.

local _, ns = ...

local Speech = {
    active = false,
    source = nil,        -- key of the frame being read, e.g. "questDetail"
    queue = {},
    index = 0,
    gen = 0,             -- bumped on every start/stop to cancel stale timers
    awaitingStart = false,
    utteranceID = nil,
    maxLen = 300,        -- shrinks if the game reports MaxCharactersExceeded
    voiceBroken = false, -- chosen voice failed this session; use the default
    warnedMissing = false,
    listeners = {},
}
ns.Speech = Speech

local START_DELAY = 0.15   -- StopSpeakingText + SpeakText in the same frame breaks playback
local START_TIMEOUT = 10   -- give up if the game never starts speaking
local MIN_CHUNK = 40

local STATUS_MAX_CHARS = 4
-- Codes that describe queueing, not failure.
local IGNORED_STATUS = { [0] = true, [6] = true, [9] = true }

local function statusName(code)
    if Enum and Enum.VoiceTtsStatusCode then
        for name, value in pairs(Enum.VoiceTtsStatusCode) do
            if value == code then
                return name
            end
        end
    end
    return tostring(code)
end

function Speech:OnChange(fn)
    self.listeners[#self.listeners + 1] = fn
end

function Speech:Notify()
    for _, fn in ipairs(self.listeners) do
        fn()
    end
end

function Speech:IsSpeaking(source)
    return self.active and (source == nil or self.source == source)
end

local function defaultVoiceID()
    if C_TTSSettings and C_TTSSettings.GetVoiceOptionID and Enum and Enum.TtsVoiceType then
        local ok, id = pcall(C_TTSSettings.GetVoiceOptionID, Enum.TtsVoiceType.Standard)
        if ok and id then
            return id
        end
    end
    local voices = C_VoiceChat.GetTtsVoices() or {}
    return voices[1] and voices[1].voiceID or 0
end

-- Returns voiceID, usingChosenVoice.
function Speech:ResolveVoice()
    local wanted = ns.db.voice
    if wanted and wanted ~= "" and not self.voiceBroken then
        for _, v in ipairs(C_VoiceChat.GetTtsVoices() or {}) do
            if v.name == wanted then
                return v.voiceID, true
            end
        end
        if not self.warnedMissing then
            self.warnedMissing = true
            ns.Print(("Voice \"%s\" isn't available, using the default voice. See SETUP.md if the neural voices disappeared."):format(wanted))
        end
    end
    return defaultVoiceID(), false
end

-- ... is the text parts, e.g. title, body. Each part is spoken as its own
-- utterance(s), which gives a natural pause after the title. Parts may be nil.
function Speech:Play(source, ...)
    self:Stop()

    local queue = {}
    for i = 1, select("#", ...) do
        for _, chunk in ipairs(ns.Text.Chunk(ns.Text.Clean(select(i, ...)), self.maxLen)) do
            queue[#queue + 1] = chunk
        end
    end
    if #queue == 0 then
        ns.Print("There's no text to read here.")
        return
    end

    self.active = true
    self.source = source
    self.queue = queue
    self.index = 1
    local gen = self.gen
    self:Notify()
    C_Timer.After(START_DELAY, function()
        if gen == self.gen then
            self:SpeakCurrent()
        end
    end)
end

function Speech:SpeakCurrent()
    local chunk = self.queue[self.index]
    if not chunk then
        self:Finish()
        return
    end
    local voiceID, chosen = self:ResolveVoice()
    self.usingChosenVoice = chosen
    self.awaitingStart = true
    self.utteranceID = nil

    local gen, index = self.gen, self.index
    C_VoiceChat.SpeakText(voiceID, chunk, ns.db.rate, ns.db.volume, false)

    C_Timer.After(START_TIMEOUT, function()
        if gen == self.gen and index == self.index and self.awaitingStart then
            ns.Print("Text-to-speech didn't respond. Check your voice setup with /lore voices.")
            self:Stop()
        end
    end)
end

function Speech:Finish()
    self.gen = self.gen + 1
    self.active = false
    self.source = nil
    self.queue = {}
    self.awaitingStart = false
    self.utteranceID = nil
    self:Notify()
end

function Speech:Stop()
    if not self.active then
        return
    end
    self:Finish()
    C_VoiceChat.StopSpeakingText()
end

-- Stop only if the current reading came from one of the given sources.
function Speech:StopIf(...)
    if not self.active then
        return
    end
    for i = 1, select("#", ...) do
        if self.source == select(i, ...) then
            self:Stop()
            return
        end
    end
end

local function isOurs(self, utteranceID)
    return self.active and (utteranceID == self.utteranceID or (self.awaitingStart and self.utteranceID == nil))
end

function Speech:OnStarted(utteranceID)
    if self.active and self.awaitingStart then
        self.awaitingStart = false
        self.utteranceID = utteranceID
    end
end

function Speech:OnFinished(utteranceID)
    if self.active and not self.awaitingStart and utteranceID == self.utteranceID then
        self.index = self.index + 1
        self:SpeakCurrent()
    end
end

function Speech:OnFailed(utteranceID, status)
    if IGNORED_STATUS[status] or not isOurs(self, utteranceID) then
        return
    end
    local gen = self.gen
    local retry = function()
        C_Timer.After(START_DELAY, function()
            if gen == self.gen then
                self:SpeakCurrent()
            end
        end)
    end

    if status == STATUS_MAX_CHARS and self.maxLen > MIN_CHUNK then
        -- Split the failed chunk smaller and keep going.
        self.maxLen = math.max(MIN_CHUNK, math.floor(self.maxLen / 2))
        local pieces = ns.Text.Chunk(self.queue[self.index], self.maxLen)
        table.remove(self.queue, self.index)
        for i = #pieces, 1, -1 do
            table.insert(self.queue, self.index, pieces[i])
        end
        retry()
    elseif self.usingChosenVoice then
        self.voiceBroken = true
        ns.Print(("Voice \"%s\" failed (%s), using the default voice for the rest of this session."):format(ns.db.voice, statusName(status)))
        retry()
    else
        ns.Print(("Text-to-speech failed: %s."):format(statusName(status)))
        self:Stop()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("VOICE_CHAT_TTS_PLAYBACK_STARTED")
events:RegisterEvent("VOICE_CHAT_TTS_PLAYBACK_FINISHED")
events:RegisterEvent("VOICE_CHAT_TTS_PLAYBACK_FAILED")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "VOICE_CHAT_TTS_PLAYBACK_STARTED" then
        Speech:OnStarted(...)
    elseif event == "VOICE_CHAT_TTS_PLAYBACK_FINISHED" then
        Speech:OnFinished(...)
    elseif event == "VOICE_CHAT_TTS_PLAYBACK_FAILED" then
        Speech:OnFailed(...)
    end
end)
