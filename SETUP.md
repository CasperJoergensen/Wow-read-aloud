# Setup

## Install

Install Lorecaster from CurseForge, or copy the addon into your AddOns folder by hand. For a manual install, the folder must be named `Lorecaster`, with `Lorecaster.toc` directly inside it:

| Game | Folder |
|---|---|
| WoW Forever (beta) | `World of Warcraft\_classic_beta_\Interface\AddOns\Lorecaster` |
| Retail | `World of Warcraft\_retail_\Interface\AddOns\Lorecaster` |

Lorecaster works right away with the text-to-speech voice selected in WoW's own options (Options → Accessibility → Text to Speech).

## Better voices (optional)

Lorecaster uses the voices your operating system provides, so the quality depends on which voices you have installed. Pick one in Options → AddOns → Lorecaster, or with `/lore voices` and `/lore voice <name>`.

### Windows

The built-in Windows voices (David, Zira) sound robotic. WoW can only use classic "SAPI5" voices, so the newer natural voices in Windows 11 don't appear by default.

The community project [NaturalVoiceSAPIAdapter](https://github.com/gexgd0419/NaturalVoiceSAPIAdapter) makes those natural voices available to SAPI5 programs, including WoW. It is a third-party tool, not part of Lorecaster. Follow its own instructions, and read the notes below first.

- Recent WoW versions only load signed voice DLLs, so the adapter has to be signed on your PC before WoW will show its voices. The adapter's issue tracker describes how ([issue #37](https://github.com/gexgd0419/NaturalVoiceSAPIAdapter/issues/37)). Signing means trusting a certificate you create yourself. Make sure you understand what that involves before doing it.
- WoW patches and Windows updates have broken this setup before. If your chosen voice disappears, Lorecaster switches to the default voice and prints a warning in chat.

### macOS

Open System Settings → Accessibility → Spoken Content → System Voice → Manage Voices, and download a higher-quality voice ("Enhanced" or "Premium"). Restart WoW, and the voice appears in Lorecaster's voice list.

(Mac support hasn't been tested yet. Please report how it goes.)

## Troubleshooting

- **No sound:** check that `/lore test` speaks, and that WoW's own text-to-speech works (Options → Accessibility → Text to Speech → Play Sample).
- **A voice is missing from the list:** restart WoW completely; `/reload` isn't enough. Then check `/lore voices`.
- **Retail shows Lorecaster as "out of date" after a patch:** tick "Load out of date AddOns" until an update is released.
