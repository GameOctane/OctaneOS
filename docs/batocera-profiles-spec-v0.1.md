# Batocera Lightweight Profiles — RA / SRAM / Save States

**Status:** Draft v0.2
**Author:** Jason (GameOctane)
**Scope:** Minimal viable per-user profile switching for Batocera

## Problem

Batocera has no concept of multiple users. On a shared device, everyone
plays under the same RetroAchievements login and the same save/state
files. Two people can't have separate progress in the same game, and
achievements get attributed to whichever account happens to be logged
in — usually wrong, or nobody bothers logging in at all.

This has been requested for years (see [RetroArch #4749](https://github.com/libretro/RetroArch/issues/4749),
opened 2017, still open). A general-purpose solution has repeatedly
stalled in the RetroArch community over scope — what's shared vs.
exclusive per profile, permission tiers, live mid-session switching.
That debate is out of scope here. This spec deliberately does not try
to solve it.

There's also an active RetroArch PR ([#19067](https://github.com/libretro/RetroArch/pull/19067))
building native profile support inside RetroArch itself. If/when that
merges, it may replace or simplify parts of this approach. This spec
is not blocked on that PR — it works today, independent of whether
#19067 ever lands.

## Non-Goals (v1)

Explicitly out of scope, based on where prior attempts stalled:

- Shader / control-remap / display-setting profiles
- Admin / Standard / Guest permission classes
- Live mid-session profile switching
- Recently-played / playlist scoping (candidate for v2, not v1)
- Any change to RetroArch itself — this operates entirely at the
  Batocera config layer

## Goal (v1 scope)

Three things scoped per profile, selected before a play session starts:

1. **RetroAchievements credentials** — achievements attribute to the
   correct person
2. **SRAM (in-game saves)** — two people can have independent progress
   in the same game
3. **Save states** — RetroArch save states, same mechanism as SRAM

## Design

### Profile = name + directory

Each profile is a named folder under a profiles root, e.g.:

```
/userdata/profiles/
  jason/
    retroarch.cfg.override
    saves/
    states/
  amish/
    retroarch.cfg.override
    saves/
    states/
```

### Switching mechanism

On profile selection (pre-launch, not live):

1. Read the profile's `retroarch.cfg.override` — contains that
   profile's `cheevos_username` / `cheevos_password` (or token)
2. Write/merge those values into the active `retroarch.cfg`
3. Point `savefile_directory` at `<profile>/saves/`
4. Point `savestate_directory` at `<profile>/states/`
5. Launch normally — RetroArch reads the rewritten config as if it
   were always configured that way

No daemon, no live switching, no RetroArch source changes. This is a
config-rewrite script that runs once per profile selection.

## UI

A new EmulationStation system, not a menu bolted onto Ports and not a
custom in-script picker. Batocera's local HTTP API
(`es-app/src/services/HttpServerThread.cpp`) was checked directly —
`/messagebox` is a dismiss-only modal (`GuiMsgBox`), `/notify` is a
non-modal toast, and nothing in the API offers a multi-choice prompt.
So the picker isn't built as a dialog at all — it's a dedicated ES
system, reusing EmulationStation's own native list navigation.

Batocera supports adding a whole new system without touching the
shipped `es_systems.cfg` or the ES submodule: drop
`/userdata/system/configs/emulationstation/es_systems_users.cfg` as an
overlay file. Batocera merges any `es_systems_<custom_name>.cfg` into
the system list automatically at ES startup, and — because it's
additive rather than an edit to a shipped file — it survives Batocera
updates.

```xml
<systemList>
  <system>
    <name>users</name>
    <fullname>Users</fullname>
    <path>/userdata/roms/users</path>
    <extension>.sh</extension>
    <command>%ROM%</command>
    <theme>ports</theme>
  </system>
</systemList>
```

This produces a dedicated **"Users"** tile in the system carousel,
separate from Ports — native D-pad/A-button list navigation, zero ES
source changes. One `.sh` script per profile lives in
`/userdata/roms/users/` (same install pattern
`board/batocera/allwinner/a733/fsoverlay/etc/init.d/S13octane-init`
already uses to install Ports entries — `mkdir -p`, `cp` from squashfs,
`chmod +x` — just looped once per profile instead of once per feature).
Selecting a profile runs its script, which does the config-rewrite (see
Design, above) and then restarts EmulationStation
(`/etc/init.d/S31emulationstation start` — the same restart call
`labwc-launch` already documents as supported).

`<theme>ports</theme>` reuses Ports' existing icon/styling as a
pragmatic default so the new system doesn't render broken on day one; a
dedicated "Users" icon/theme is a nice-to-have, not a blocker.

First-run flow creates a default profile automatically so single-user
setups are unaffected.

## Why this scope

- Matches the "most important" list from the original RetroArch
  discussion (achievements, save files, SRAMs) almost exactly
- Small enough to actually ship — avoids the shared/exclusive settings
  debate that has stalled broader attempts for 9 years
- Works regardless of whether RetroArch #19067 merges; if it does
  merge, this could later be simplified to use RetroArch's native
  profile system instead of config-rewriting, but isn't blocked
  waiting for it

## Open Questions

- Config merge strategy — full overwrite of `retroarch.cfg` vs.
  selective key injection? (Leaning selective: `sed` out the existing
  `cheevos_username`/`cheevos_password`/`savefile_directory`/
  `savestate_directory` lines and append the profile's values, rather
  than overwriting the whole file — full overwrite risks losing
  unrelated hand-tuned settings, and collides with RetroArch's own
  "save configuration on exit" potentially writing the active
  profile's values back into what's supposed to be the shared base.)
- Does RA session/login need to be explicitly re-authenticated per
  switch, or is username/token swap in config sufficient for RetroArch
  to pick it up cleanly? (Likely sufficient — RA login happens fresh at
  RetroArch launch/core-load when achievements are enabled, not as a
  persistent session token, and this design always relaunches
  RetroArch fresh per profile switch rather than live-switching
  mid-session.)
