# Going back to an older version (or another Batocera) after using profiles

**Short version:** your saves are not lost. They are in `/userdata/profiles/<name>/saves` and `/userdata/profiles/<name>/states`, and after the
first profile switch the original folders are kept as `/userdata/saves.migrated` and `/userdata/states.migrated`. An older version that does not
know about profiles looks only in `/userdata/saves` and `/userdata/states`, so it will not *see* them until you copy them back.

## Why
In OctaneOS the game launcher reads the active profile (`/userdata/system/.batocera-profiles.current`) and uses that profile's folders. The
first time you switch profile, your old flat `saves` and `states` are copied into the main profile (hidden folder `.default`), checked, and
only then renamed to `*.migrated`. Nothing is deleted. An older version, or stock Batocera, never reads `/userdata/profiles`.

The menu never offers a downgrade (see `docs/update-signing.md`): going back needs `batocera-upgrade --allow-downgrade` or a fresh flash, so it
is always something you chose to do.

## Before you go back
1. Back up `/userdata/profiles` (copy it off the card; it also holds each profile's RetroAchievements login in plain text, so keep it private).
2. Decide whose saves the old version should use. A flat folder has room for one profile. For the main profile use `.default`; for another
   use its name.

## Copy one profile's saves back (SSH into the board)
```
P=.default            # or the profile's folder name
mkdir -p /userdata/saves /userdata/states
cp -a /userdata/profiles/$P/saves/.  /userdata/saves/
cp -a /userdata/profiles/$P/states/. /userdata/states/
```
`cp -a` copies and leaves the profile untouched. If `/userdata/saves.migrated` exists you can use it instead for the saves you had before
profiles, but it will not have anything you saved since.

## Coming forward again
After the first switch a marker (`/userdata/profiles/.flat-folders-migrated`) stops the move from happening twice, so a newer version does
**not** pick up saves made in `/userdata/saves` while you were on the old version. Copy them into the profile you want:
```
cp -a /userdata/saves/.  /userdata/profiles/.default/saves/
cp -a /userdata/states/. /userdata/profiles/.default/states/
```
(`cp -a` overwrites a file with the same name, so if both sides changed the same save, pick the newer one yourself.)

## What is tested
The two copy commands are plain `cp -a`; they were run in a scratch test against a fake `/userdata` and brought the saves back (that test is not part of this change).
Not tested: an actual older image on a board reading the copied files (needs the test card).
