-- Offline tests with stubbed WoW APIs. Run from the repo root:
--   lua5.1 tests/run.lua

local failures, passed = 0, 0
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
    else
        failures = failures + 1
        print("FAIL " .. name .. (detail and (": " .. tostring(detail)) or ""))
    end
end
local function eq(name, got, want)
    check(name, got == want, ("got %q, want %q"):format(tostring(got), tostring(want)))
end

---------------------------------------------------------------------------
-- WoW stubs
---------------------------------------------------------------------------
local now = 0
local timers = {}
local spoken, stopCalls = {}, 0
local printed = {}
local eventFrames = {}
local voices = { { voiceID = 0, name = "Microsoft David" }, { voiceID = 7, name = "Microsoft Aria (Natural)" } }

function GetTime() return now end
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end }
local function advance(dt)
    now = now + dt
    local due = {}
    for i = #timers, 1, -1 do
        if timers[i].at <= now then
            table.insert(due, 1, table.remove(timers, i))
        end
    end
    for _, t in ipairs(due) do t.fn() end
end

C_VoiceChat = {
    GetTtsVoices = function() return voices end,
    SpeakText = function(voiceID, text, rate, volume, overlap)
        spoken[#spoken + 1] = { voiceID = voiceID, text = text, rate = rate, volume = volume }
    end,
    StopSpeakingText = function() stopCalls = stopCalls + 1 end,
}
Enum = { TtsVoiceType = { Standard = 0 }, VoiceTtsStatusCode = { MaxCharactersExceeded = 4, InvalidEngineType = 1 } }
C_TTSSettings = { GetVoiceOptionID = function() return 0 end }
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) printed[#printed + 1] = msg end }

function CreateFrame()
    local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(_, fn) self.onEvent = fn end
    eventFrames[#eventFrames + 1] = f
    return f
end
local function fire(event, ...)
    for _, f in ipairs(eventFrames) do
        if f.events[event] and f.onEvent then f.onEvent(f, event, ...) end
    end
end

---------------------------------------------------------------------------
-- Load addon files that don't need real frames
---------------------------------------------------------------------------
local ns = {}
for _, file in ipairs({ "Locales.lua", "Text.lua", "Speech.lua" }) do
    local chunk = assert(loadfile(file))
    chunk("LoreReader", ns)
end
ns.Print = function(msg) printed[#printed + 1] = msg end
ns.db = { voice = "", rate = 0, volume = 100 }
local Text, Speech = ns.Text, ns.Speech

---------------------------------------------------------------------------
-- Text.Clean
---------------------------------------------------------------------------
eq("clean colours", Text.Clean("Bring me |cffffd200Hogger's|r claw"), "Bring me Hogger's claw.")
eq("clean hyperlink", Text.Clean("Take |cff1eff00|Hitem:1234::::|h[Gnoll Paw]|h|r to him"), "Take Gnoll Paw to him.")
eq("clean texture", Text.Clean("Gold |TInterface\\Icons\\coin:0|t reward"), "Gold reward.")
eq("clean paragraphs", Text.Clean("First line\n\nSecond line!\nThird"), "First line. Second line! Third.")
eq("clean |n", Text.Clean("One|nTwo"), "One. Two.")
eq("clean stage direction", Text.Clean("<The dwarf sighs.>\nWell then."), "The dwarf sighs. Well then.")
eq("clean nil", Text.Clean(nil), "")
eq("clean whitespace", Text.Clean("  lots   of   space  "), "lots of space.")
eq("clean named colour", Text.Clean("|cnGREEN_FONT_COLOR:Done|r now"), "Done now.")

---------------------------------------------------------------------------
-- Text.Chunk
---------------------------------------------------------------------------
local chunks = Text.Chunk("One. Two! Three? Four.", 10)
eq("chunk count", #chunks, 3)
eq("chunk 1", chunks[1], "One. Two!")
eq("chunk 3", chunks[3], "Four.")
chunks = Text.Chunk("Short one. Short two.", 300)
eq("chunk packs", #chunks, 1)
chunks = Text.Chunk("aaaa bbbb cccc dddd eeee", 10)
eq("chunk long sentence words", chunks[1], "aaaa bbbb")
local ok = true
for _, c in ipairs(Text.Chunk(("word "):rep(200), 50)) do ok = ok and #c <= 50 end
check("chunk max len respected", ok)
eq("chunk empty", #Text.Chunk("", 50), 0)
eq("chunk giant word", Text.Chunk(("x"):rep(25), 10)[3], "xxxxx")

---------------------------------------------------------------------------
-- Speech queue
---------------------------------------------------------------------------
local changes = 0
Speech:OnChange(function() changes = changes + 1 end)

-- Title + body are separate utterances, spoken in order.
Speech:Play("questDetail", "Wanted: Hogger", "A huge gnoll. He must die.")
check("active after play", Speech:IsSpeaking("questDetail"))
eq("nothing spoken before delay", #spoken, 0)
advance(0.2)
eq("title spoken first", spoken[1] and spoken[1].text, "Wanted: Hogger.")
fire("VOICE_CHAT_TTS_PLAYBACK_STARTED", 11)
fire("VOICE_CHAT_TTS_PLAYBACK_FINISHED", 99) -- someone else's utterance
eq("foreign finish ignored", #spoken, 1)
fire("VOICE_CHAT_TTS_PLAYBACK_FINISHED", 11)
eq("body spoken second", spoken[2] and spoken[2].text, "A huge gnoll. He must die.")
fire("VOICE_CHAT_TTS_PLAYBACK_STARTED", 12)
fire("VOICE_CHAT_TTS_PLAYBACK_FINISHED", 12)
check("idle after last chunk", not Speech:IsSpeaking())

-- Interrupt: a new Play stops the old one and cancels its pending start.
spoken = {}
Speech:Play("gossip", "Old text.")
Speech:Play("questDetail", nil, "New text.")
advance(0.2)
eq("only new text spoken", #spoken, 1)
eq("new text", spoken[1] and spoken[1].text, "New text.")
check("interrupt called StopSpeakingText", stopCalls >= 1)

-- StopIf only stops matching sources.
Speech:StopIf("gossip")
check("StopIf other source keeps speaking", Speech:IsSpeaking("questDetail"))
Speech:StopIf("gossip", "questDetail")
check("StopIf matching source stops", not Speech:IsSpeaking())

-- Chosen voice resolves by name.
spoken = {}
ns.db.voice = "Microsoft Aria (Natural)"
Speech:Play("gossip", "Hello.")
advance(0.2)
eq("chosen voice id", spoken[1] and spoken[1].voiceID, 7)

-- Chosen voice fails -> fall back to default and keep going.
fire("VOICE_CHAT_TTS_PLAYBACK_FAILED", 21, 1)
advance(0.2)
eq("fallback voice id", spoken[2] and spoken[2].voiceID, 0)
check("still speaking after fallback", Speech:IsSpeaking("gossip"))
Speech:Stop()
Speech.voiceBroken = false

-- Missing voice -> default voice, warn once.
spoken, printed = {}, {}
ns.db.voice = "Nonexistent Voice"
Speech:Play("gossip", "One.")
advance(0.2)
Speech:Play("gossip", "Two.")
advance(0.2)
eq("missing voice uses default", spoken[1] and spoken[1].voiceID, 0)
local warnings = 0
for _, m in ipairs(printed) do if m:find("isn't available") then warnings = warnings + 1 end end
eq("missing voice warned once", warnings, 1)
Speech:Stop()
ns.db.voice = ""

-- MaxCharactersExceeded -> re-split and retry.
spoken = {}
Speech.maxLen = 300
local long = ("This is a sentence of lore. "):rep(8)
Speech:Play("itemText", long)
advance(0.2)
local firstLen = #spoken[1].text
fire("VOICE_CHAT_TTS_PLAYBACK_FAILED", 31, 4)
advance(0.2)
check("retry uses smaller chunk", #spoken[2].text < firstLen, #spoken[2].text)
eq("maxLen halved", Speech.maxLen, 150)
Speech:Stop()

-- Start timeout stops a reading the game never starts.
spoken, printed = {}, {}
Speech:Play("gossip", "Silent.")
advance(0.2)
advance(11)
check("timeout stops", not Speech:IsSpeaking())

-- Empty text.
printed = {}
Speech:Play("gossip", nil)
check("empty text not active", not Speech:IsSpeaking())
check("empty text message", printed[1] and printed[1]:find("no text"))

check("listeners notified", changes > 0)

print(("%d passed, %d failed"):format(passed, failures))
os.exit(failures == 0 and 0 or 1)
