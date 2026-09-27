# Handoff — Lorecaster

The state of the project as of 2026-09-27, for continuing locally. Also see [DESIGN.md](DESIGN.md) for the decisions, [TESTING.md](TESTING.md) for the in-game checklist, and [RELEASING.md](RELEASING.md) for publishing.

## What it is

Lorecaster is a WoW addon for **WoW Forever** (Blizzard's "Classic+", beta, retail-based client, Interface `16001`) and **retail** (Interface `120105`). It adds a **Read Aloud** button to lore frames and speaks the text with the game's built-in TTS (`C_VoiceChat.SpeakText`). It needs no external program.

## Getting started locally

```bash
git clone https://github.com/CasperJoergensen/Wow-read-aloud.git   # or the renamed repo, once renamed
cd Wow-read-aloud
git checkout claude/wow-read-aloud-tts-30iltk
lua5.1 tests/run.lua        # offline tests (39 passing)
```

The branch has **not** been merged to `main` yet. To try it in game, link or copy the repo folder as `Interface\AddOns\Lorecaster`:

```powershell
# Run from the repo folder, in an elevated PowerShell. A symlink means edits show up after /reload.
New-Item -ItemType SymbolicLink -Path "C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\Lorecaster" -Target (Get-Location)
```

Turn on `/console scriptErrors 1` while testing.

## Status

| Area | State |
|---|---|
| Addon code | Done, but **never run in the real game**. Only offline tests with stubbed WoW APIs. |
| Docs | README, SETUP (public), DESIGN, TESTING, RELEASING, CURSEFORGE (page text), CHANGELOG |
| Release pipeline | `.pkgmeta` + GitHub Actions (`tests.yml` on push, `release.yml` on `v*` tag via BigWigs packager). Never run. |
| Name | **Lorecaster** (LoreReader was taken). Check that `curseforge.com/wow/addons/lorecaster` is free. |

## Next steps (in order)

1. **Test in game** with `TESTING.md`. The most uncertain parts:
   - button positions (the `LAYOUT` table at the top of `Buttons.lua`)
   - the options panel (modern `Settings` API, wrapped in `pcall`)
   - the quest log button on `QuestMapFrame.DetailsFrame` and `QuestLogPopupDetailFrame`
   - whether `ITEM_TEXT_READY` fires only on page turns
   - the 2-second "keep reading" window after Accept/Complete
2. Fix whatever testing finds. Keep `tests/run.lua` green.
3. **Repo:** rename it to `Lorecaster`, make it public, and merge the branch into `main`. The TOC `X-Website` and doc links already point at `github.com/CasperJoergensen/Lorecaster`.
4. **CurseForge:** create the project (MIT license, description from `CURSEFORGE.md`), add `## X-Curse-Project-ID: <id>` to `Lorecaster.toc`, and add the `CF_API_KEY` secret to GitHub.
5. Tag `v0.1.0-beta.1` and push the tag. Check the Actions tab.

## Code map

| File | Role |
|---|---|
| `Lorecaster.toc` | `## Interface: 16001, 120105`, `SavedVariables: LorecasterDB`, `Version: @project-version@` |
| `Locales.lua` | `ns.L["English"]` falls back to the key. Add translations here. |
| `Text.lua` | Pure Lua: `Clean` strips markup and turns line breaks into sentences; `Chunk` splits on sentence boundaries up to `maxLen`. |
| `Speech.lua` | Queue: speaks one chunk at a time and waits for `VOICE_CHAT_TTS_PLAYBACK_FINISHED` for its own utterance ID. It also handles: the 0.15 s start delay (a client bug when calling Stop then Speak), a 10 s start timeout, halving the chunk size on `MaxCharactersExceeded`, and falling back to the default voice if the chosen voice fails. Voices are stored by **name**. |
| `Sources.lua` | Text getters that return `title, body`. They cover: quest detail, quest reward, quest log (map and popup), gossip (`C_GossipInfo.GetText`), and item text (`ItemTextGetText`, with the title only on page 1). |
| `Buttons.lua` | Buttons, their `LAYOUT`, and the stop rules (see DESIGN.md). Frames are set up lazily, retried on `ADDON_LOADED`. |
| `Settings.lua` | Options → AddOns panel: a voice dropdown, rate from −10 to 10, volume from 0 to 100, and a test button. |
| `Core.lua` | Database defaults and slash commands: `/lore`, `/lc`, `/readaloud` with `stop`, `test`, `voices`, `voice <name>`, `rate <n>`, `volume <n>`. |
| `tests/run.lua` | Offline tests with stubbed WoW APIs. |

## Key decisions (short)

- **Reads:** quest description, completion text, quest log description, gossip, and books (current page). Titles are read first for quests and books.
- **Doesn't read:** objectives, progress text, greetings or mail.
- **Trigger and interrupts:** button only. A new click interrupts the current reading, and the button turns into Stop while reading.
- **When it stops:** it keeps reading after Accept/Complete. It stops on closing the frame, opening a different lore frame, new gossip text, or a page turn.
- **Text:** read verbatim, including the player's name.
- **Settings:** account-wide. If the chosen voice is missing, it falls back to the default and warns once per session.
- **Publishing:** public on CurseForge only, MIT license, English UI but ready for translation, Windows and Mac.
- **Neural voices:** on Windows they are an **optional, link-only** third-party step (NaturalVoiceSAPIAdapter). The public docs deliberately leave out the DLL-signing walkthrough.

## Research findings worth keeping

- **The chat-log idea (the original plan) doesn't work.** Addon `AddMessage` output isn't logged, the log flushes minutes late, and whispering to self is blocked in instances.
- **`C_VoiceChat.SpeakText(voiceID, text, rate, volume, overlap)`** is the current signature (patch 12.0 removed `destination`). Rate ranges from −10 to 10 and volume from 0 to 100. There's a per-call character limit whose size isn't documented.
- **WoW uses SAPI5 voices on Windows.** Since around Aug 2025 it only loads **signed** voice DLLs, so NaturalVoiceSAPIAdapter must be self-signed ([adapter issue #37](https://github.com/gexgd0419/NaturalVoiceSAPIAdapter/issues/37)). Current Store Narrator voice packages don't work with the adapter; use the older ones from the adapter wiki.
- **WoW Forever** runs the retail client and API: Lua 5.1, `WOW_PROJECT_ID` is the same as retail's, and `select(4, GetBuildInfo())` returns `16001`. It installs to `_classic_beta_`. The Forever TOC suffix is `_Camelot`, if per-flavor TOCs are ever needed.
- **BigWigs packager v2.6+** supports Forever and maps `16001` to CurseForge game version 1.60.1. It handles comma-separated interface lists.
- **API reference dumps** for the Forever client: [Thunderz96/forever-addon-kit](https://github.com/Thunderz96/forever-addon-kit) and [imperial64/forever-addon-dev](https://github.com/imperial64/forever-addon-dev). They confirmed `QuestMapFrame`, `QuestLogPopupDetailFrame`, `ItemTextFrame`, `C_GossipInfo.GetText` and `GetQuestLogQuestText` (build 70009).
- **Similar addons:** QuestSpeaker, Forever TTS and Quest TTS use the built-in TTS. Neural Voice TTS is Mac-only with Piper. Forever Voiceover, Spoken Quests and Quest Reader Addon use pre-recorded packs.

## Ideas for later

Roughly in order of value for the effort:

1. **Pronunciation table.** Map lore names and the player's name to phonetic spellings before speaking, in `Text.lua`, with user-editable entries.
2. **A voice to match the speaker.** Separate voices for male and female NPCs, using the `UnitSex("npc")` API, plus a narrator voice for books.
3. **Windows speech markup** for pauses and emphasis (Blizzard's docs say `SpeakText` accepts it on Windows). Verify in game first, including with the adapter.
4. **Text tidying:** expand abbreviations and read Roman numerals as words.
5. **Optional pre-generated voice pack.** Offline Piper or Kokoro audio played with `PlaySoundFile`, falling back to live TTS. It needs a quest-text dump and has to be regenerated when patches change quest text.
6. **Pixel bridge to an external neural TTS engine.** For power users only; the most work of all.
