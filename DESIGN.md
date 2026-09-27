# Lorecaster — design

A WoW Forever and retail addon, published on CurseForge, that reads quest, gossip and book lore aloud with the game's text-to-speech.

## Decisions

| Topic | Decision |
|---|---|
| Game | WoW Forever (modern retail client, Interface `16001`, Lua 5.1), and retail WoW (Interface `120105`) since both run the same client and APIs. Windows and macOS (the OS provides the voices). |
| Voice path | In-game only: `C_VoiceChat.SpeakText`. No external program. Better voices are the user's OS voices; on Windows, NaturalVoiceSAPIAdapter is documented as an optional third-party step (link only, no signing walkthrough). |
| What is read | Quest description (offer), quest completion text (turn-in), quest log description (map panel and popup), NPC gossip text, books/plaques/letters (current page). Title first for quests and books. |
| Not read | Objectives, progress text ("have you done it yet?"), quest greetings, mail. |
| Trigger | Button only — a "Read Aloud" button on each frame, which becomes "Stop" while that frame is being read. |
| Interrupt | Clicking Read Aloud anywhere stops the current reading and starts the new one. |
| Stop | Closing the frame (Escape, X, walking away); opening another quest/gossip/book; new gossip text or a book page turn. **Not** on Accept Quest / Complete Quest — the story keeps going while you run off. |
| Text | Read verbatim (including your character's name). Colour codes, hyperlinks, textures and `<stage direction>` brackets are stripped; line breaks become sentence breaks. |
| Settings | Options → AddOns → Lorecaster: voice, speed, volume, test button. Account-wide. Slash commands mirror them. |
| Voice missing | Fall back to WoW's default voice and warn once per session. |
| Slash | `/lore`, `/lc`, `/readaloud`. |
| Languages | Addon labels go through `Locales.lua` (English only for now, falls back to English). Game text is read in the client's language. |
| Distribution | CurseForge only, MIT license, public GitHub repo. Tag `v*` → BigWigs packager uploads for Forever (1.60.1) and retail. |

## Why not the original chat-log design

The first plan printed tagged chunks to the chat frame and had an external program tail `Logs/WoWChatLog.txt`. It doesn't work:

- Text printed locally by an addon (`AddMessage`/`print`) is not written to the chat log — only real chat events are.
- The chat log is buffered: measured flush delays are 1–5+ minutes, so "spoken within a second" is impossible.
- Workarounds (whisper to self) are blocked inside instances by the Midnight-era chat restrictions WoW Forever inherits.

A pixel bridge (addon draws text as coloured pixels, external program screen-captures and decodes it, then runs Piper/Kokoro) would work but is a lot of machinery. Since WoW's own TTS can use neural voices via the SAPI adapter, the external program was dropped. The addon keeps "get text" (`Sources.lua`) separate from "speak text" (`Speech.lua`), so another output could be added later if the adapter route stops working for good.

## Code layout

```
Lorecaster.toc     Interface 16001 (Forever) + 120105 (retail), SavedVariables LorecasterDB
Locales.lua        Translatable UI strings (L["English text"])
Text.lua           Markup clean-up and chunking (pure Lua, unit-tested)
Speech.lua         Queue over C_VoiceChat.SpeakText, voice resolution and fallbacks
Sources.lua        Text getters per frame
Buttons.lua        Buttons, button placement (LAYOUT table), stop rules
Settings.lua       Options panel (modern Settings API)
Core.lua           Saved settings, slash commands, startup
tests/run.lua      Offline tests with stubbed WoW APIs (lua5.1 tests/run.lua)
```

### Speech details

- Text is split into chunks of at most 300 characters on sentence boundaries. WoW has an undocumented per-call limit; if it reports `MaxCharactersExceeded`, the chunk size is halved and the failed chunk re-split.
- Chunks are spoken one at a time. The next is sent on `VOICE_CHAT_TTS_PLAYBACK_FINISHED` for our own utterance ID (captured from `..._STARTED`), so chat TTS or other addons don't advance the queue.
- `StopSpeakingText` followed by `SpeakText` in the same frame breaks playback (known client bug), so a new reading starts 0.15 s after stopping the old one.
- Voices are stored by name, not ID, because IDs can shift when voices are installed or removed.
- If the chosen voice fails, the default voice is used for the rest of the session.

The repo root is the addon folder; `.pkgmeta` excludes docs and tests from the release zip.
