# LoreReader

A World of Warcraft addon that reads quest, dialogue and book lore aloud, using the game's built-in text-to-speech. It works in **WoW Forever** and **retail**.

Click **Read Aloud** on a quest, an NPC's dialogue or a book, and LoreReader reads the story: the title and description, not the objectives or reward lists. Accept the quest and keep playing while it finishes reading.

- **Install:** get it from CurseForge, or copy this repository into `Interface/AddOns/LoreReader`.
- **Better voices:** see [SETUP.md](SETUP.md).
- **Commands:** `/lore help`.
- **Bugs and ideas:** [open an issue](https://github.com/CasperJoergensen/LoreReader/issues).

## Development

- [DESIGN.md](DESIGN.md): how it works and why.
- [TESTING.md](TESTING.md): in-game test checklist.
- [RELEASING.md](RELEASING.md): publishing to CurseForge.
- Offline tests: `lua5.1 tests/run.lua`.

Translations of the addon's own labels go in `Locales.lua`.

## License

MIT, see [LICENSE](LICENSE).
