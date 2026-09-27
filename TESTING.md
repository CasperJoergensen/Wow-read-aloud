# In-game test checklist

The addon was built without access to the game. Text clean-up and the speech queue are covered by offline tests (`lua5.1 tests/run.lua`), but everything touching real frames needs checking in WoW Forever. Items marked ⚠️ are the least certain.

## Basics

- [ ] LoreReader shows in the AddOns list and loads without Lua errors (turn on `/console scriptErrors 1`).
- [ ] `/lore help` prints the commands; `/lr` and `/readaloud` work too.
- [ ] `/lore test` speaks the sample with the default voice.
- [ ] ⚠️ `/lore` opens Options → AddOns → LoreReader with Voice, Speed, Volume and Test voice. If it prints "Couldn't build the options panel", copy the error.
- [ ] Changing speed/volume in the panel changes `/lore test`. Settings survive `/reload` and apply on another character.

## Voices

- [ ] `/lore voices` lists the neural voices after SETUP.md.
- [ ] Pick one in the panel; `/lore test` uses it.
- [ ] Set a nonexistent voice (`/run LoreReaderDB.voice="Nope"`), `/reload`, read something: default voice is used and one warning is printed, not one per reading.

## Quests (NPC quest window)

- [ ] ⚠️ Offer a quest: "Read Aloud" sits between Accept and Decline without overlapping them.
- [ ] It reads the title, a short pause, then the description — **not** the objectives.
- [ ] Button turns into "Stop" while reading; clicking it stops.
- [ ] Click **Accept** while reading → speech continues.
- [ ] Click **Decline** or press Escape while reading → speech stops.
- [ ] Walk away from the NPC while reading (before accepting) → speech stops.
- [ ] Turn in a quest: the reward panel has the button, reads title + completion text.
- [ ] Click **Complete Quest** while reading → speech continues.
- [ ] ⚠️ Accept a quest from an NPC that has more quests (its window reopens by itself) → speech continues. Then open another quest from it after a few seconds → speech stops.
- [ ] Progress panel ("have you done it yet?") and multi-quest greeting have **no** button.

## Quest log

- [ ] ⚠️ Open the map's quest list and click a quest to show its details: the button appears (top-right of the details) and reads title + description.
- [ ] Clicking another quest, going back, or closing the map stops speech.
- [ ] ⚠️ Open quest details from the objective tracker popup: button present and works; closing the popup stops speech.

## Gossip

- [ ] ⚠️ Talk to an NPC with dialogue: button bottom-left, not overlapping Goodbye.
- [ ] Reads the NPC's text only (no options, no title).
- [ ] Clicking a dialogue option that changes the text stops speech.
- [ ] Goodbye / Escape / walking away stops speech.

## Books, plaques, letters

- [ ] ⚠️ Read a book or plaque: button bottom-right of the frame.
- [ ] Page 1 reads the title then the page; later pages read only the page.
- [ ] Turning the page stops speech. ⚠️ If speech stops by itself right after you click Read Aloud without turning the page, the page-turn event is firing unexpectedly: note it.
- [ ] Closing the book stops speech.

## Interrupts and long text

- [ ] Reading a quest, then clicking Read Aloud on a book → quest stops, book starts, no overlap or garbled start.
- [ ] A very long quest text is read to the end without being cut off.
- [ ] Opening a book, gossip or quest while a quest-log reading is playing stops it.

## Retail

- [ ] LoreReader loads in retail without "out of date" (see SETUP.md if it does).
- [ ] Spot-check one quest offer, one gossip NPC and one book: buttons are placed sensibly and reading works.

## If a button is in the wrong place

Positions are in the `LAYOUT` table at the top of `LoreReader/Buttons.lua`: `{ anchorPoint, x, y }` relative to the frame. Adjust and `/reload`.
