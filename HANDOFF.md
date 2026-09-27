# Handoff — Piper voices for Lorecaster

Goal: let Lorecaster speak with **Piper** neural voices instead of the robotic Windows voices, or the fragile Microsoft voice adapter. This doc is for continuing that work locally. Addon background is in [DESIGN.md](DESIGN.md). The branch is `claude/wow-read-aloud-tts-30iltk`, not merged into `main` yet.

> Nothing here has been built or tried yet. Facts marked (unverified) come from web research and need checking.

## Piper in 60 seconds

- **What it is:** an offline, free neural TTS engine from the Rhasspy / Home Assistant voice-assistant project. It runs on a plain CPU, many times faster than real time.
- **How it works:** it turns text into phonemes (with espeak-ng), turns those into phoneme IDs, then a VITS neural model generates the audio.
- **Voices:** each voice is an `.onnx` file (20–100 MB) plus a `.onnx.json` config. Quality levels run `x_low`, `low`, `medium`, `high`. Many languages, including English and Danish.
- **Licensing (unverified):** development moved from `rhasspy/piper` (MIT) to `OHF-Voice/piper1-gpl` (GPL). **Each voice has its own license** from its training data. Check each voice's model card before shipping any generated audio.
- **Quick try:**
  ```bash
  pip install piper-tts
  python -m piper.download_voices en_US-lessac-medium      # command may differ by version; check the README
  echo "Greetings, traveler." | piper -m en_US-lessac-medium.onnx -f hello.wav
  ```
- **Pronunciation:** it comes from espeak-ng, so fantasy names can come out wrong. Planned fix: a phonetic-spelling table applied in `Text.lua` before speaking, which benefits every route below.

## The constraint

WoW addons can't run programs, write files at runtime, or send audio anywhere. They can only:
- call `C_VoiceChat.SpeakText`, which uses the OS's **SAPI5** voices on Windows, and
- play audio files **shipped inside an addon folder** with `PlaySoundFile`.

So Piper can reach the game only through one of three routes.

## Route A — Piper as a SAPI5 voice (try first)

Wrap Piper so Windows sees it as an ordinary voice. WoW then lists it, and Lorecaster needs **no code changes**: pick it with `/lore voice <name>`.

- **Candidates (unverified, early-stage, never reported working in WoW):**
  - [Lej77/windows-text-to-speech](https://github.com/Lej77/windows-text-to-speech): a Rust SAPI5 engine with a Piper variant (`windows_tts_engine_piper.dll`), 32- and 64-bit, MIT/Apache.
  - [willwade/SherpaOnnxAzureSAPI-installer](https://github.com/willwade/SherpaOnnxAzureSAPI-installer): sherpa-onnx/Piper as SAPI5. x64 only, a proof of concept with one voice.
- **Steps:**
  1. Build or install the engine DLL and register it, both 32- and 64-bit.
  2. Check it in a plain SAPI5 program, e.g. PowerShell `System.Speech`:
     ```powershell
     Add-Type -AssemblyName System.Speech
     (New-Object System.Speech.Synthesis.SpeechSynthesizer).GetInstalledVoices().VoiceInfo.Name
     ```
  3. **Self-sign the DLL.** Since about Aug 2025, WoW only loads signed voice DLLs. Use the same approach as NaturalVoiceSAPIAdapter [issue #37](https://github.com/gexgd0419/NaturalVoiceSAPIAdapter/issues/37).
  4. Restart WoW, run `/lore voices`, then `/lore voice <piper voice>` and `/lore test`.
- **Watch for:**
  - how long it takes to start speaking (Lorecaster speaks one chunk of up to 300 characters at a time, so a slow start is noticeable), and
  - whether WoW's playback events (`VOICE_CHAT_TTS_PLAYBACK_STARTED` / `FINISHED`) fire. The queue in `Speech.lua` depends on them, and has a 10 s timeout if STARTED never comes.
- **Verdict:** best for your own PC. It's a poor fit for public users, who would need to build, register and sign DLLs.

## Route B — pre-generated Piper voice pack (best for public users)

Generate audio offline for known lore texts and ship it as an optional addon, e.g. `Lorecaster_VoicePack_<voice>`. Lorecaster plays the recording when one exists and falls back to live TTS when it doesn't. Players install nothing extra.

**Pipeline:**
1. **Collect texts.** Quest text comes from the server, so it's probably not in the client's data files (unverified). The practical source is to harvest it while playing: add a harvest mode to Lorecaster that saves `{questID, kind, cleanedText}` into SavedVariables. They're written to disk on logout or `/reload`. Scraping sites like Wowhead may break their terms of service, so avoid it.
2. **Key each clip** by `kind + id + short hash of the cleaned text`, where kind is questDetail, questReward, gossip or itemText. If a patch rewrites a text, the hash misses and live TTS is used, so a clip never plays audio that doesn't match the text on screen.
   - Quests: `GetQuestID()` (quest window) or the quest log's questID.
   - Gossip: NPC ID from `UnitGUID("npc")`.
   - Books: item name or ID.
3. **Generate.** Run a small Python script over the harvested file:
   - clean the text the same way `Text.Clean` does (port it, or run `Text.lua` with `lua5.1`),
   - apply the pronunciation table,
   - run Piper and save WAV files, then convert to Ogg with ffmpeg,
   - write a manifest Lua file mapping key → `{ file, duration }`.
4. **Package** the Ogg files and manifest as the voice-pack addon. Keep `## Dependencies: Lorecaster`, or make the pack optional through `C_AddOns.IsAddOnLoaded`.

**Addon changes needed:**
- **`Speech.lua`:** add a playback backend for audio files next to the TTS backend. Play with `PlaySoundFile(path, "Dialog")`, which returns a sound handle; stop with `StopSound(handle)`.
- **Detecting the end of a clip:** use the `SOUNDKIT_FINISHED` event for the handle, if it fires for file playback (unverified), otherwise a timer based on the manifest's `duration`. The rest of the queue logic (Stop button, interrupts, stop rules) stays the same.
- **`Sources.lua`:** return the key parts (IDs) alongside the text.
- **A setting:** "Use voice pack when available".

**Costs:**
- **Size:** roughly 0.5–1 MB per minute of Ogg. Thousands of quests means hundreds of MB, so consider splitting packs per zone or level range.
- **Upkeep:** patches that change quest text need a harvest and regeneration pass.
- **Licensing:** only use Piper voices whose license allows redistributing the generated audio.

## Route C — pixel bridge to an external Piper program (not recommended)

The addon draws the text as a strip of coloured pixels, and an external program screen-captures it, decodes the text and plays it with Piper live. It covers all text with no pre-generation, but it's by far the most work: an encoder, a capture loop, and handling DPI and window position. It also needs a companion program, which is a harder sell on CurseForge. Park it unless A and B both fail.

## Suggested order

1. **One evening:** install Piper and pick a voice you like (listen to several). Build the pronunciation table idea while you're there.
2. **Try Route A** on your PC. If it works in WoW, you personally are done.
3. For public users, **prototype Route B:**
   - the harvest mode,
   - the generation script for a handful of quests,
   - the file-playback backend in `Speech.lua`.
   - Then measure the size and quality before committing to full packs.

## Open questions

- Which Piper voice, and is its license OK for redistribution?
- Does Route A work in WoW at all? Check that the DLL gets signed and loaded, and that the playback events fire.
- Does `SOUNDKIT_FINISHED` fire for `PlaySoundFile` handles on the Forever client?
- Is any quest text in the client's data files (would make harvesting unnecessary), or is it server-only?
- How big would a full voice pack be, and should it be split per zone?
