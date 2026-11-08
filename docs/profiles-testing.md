# Testing profiles per system

A system "works with profiles" when everything a player would not want to lose lands under `/userdata/profiles/<profile>/`: in-game
saves (SRAM, memory cards, disk images), save states, and anything the emulator keeps next to them. Reading code finds most
problems (see `docs/profiles-v2.md`, section 3); only a play session proves a system. This page is how to do that session.

## One system, about five minutes
1. On the PROFILES screen, switch to the profile to test (a named one, not the main one) and start a game of that system.
2. `scripts/trace-saves.sh start` on the server (it reads the board's clock; it writes nothing on the board).
3. Play until the game can save. Save **in the game**. Make a **save state** too if the system allows it. Quit the game.
4. `scripts/trace-saves.sh report`. Every save-like file must be under **INSIDE the active profile**. Anything under **OUTSIDE** that is a
   save, a memory card or a state is shared by every profile: write it down with the system, emulator and core.
   Files under `/userdata/system/configs/...` are settings, not saves.
5. Switch to a second profile, start the same game: the first profile's save and state must **not** be there.
6. Switch back: the first profile's save loads.

## What counts as covered
- **Tested:** steps 1 to 6 done on a real device for that system, with the game named.
- **By code only:** the generator builds its paths from `batoceraPaths.SAVES`, or the core hands its memory to RetroArch (which writes the
  `.srm` into the profile's folder). Not run.
- **Not covered:** everything else. Say so in the notes; do not guess.

## Order
Start with the systems people actually play: NES, SNES, Game Boy / Color / Advance, Mega Drive, N64, DS, PlayStation, PSP, Dreamcast,
arcade (MAME and FBNeo; also check high scores), then PC-style cores that write their own files (DOSBox Pure, ScummVM, Amiga).
