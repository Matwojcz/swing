# Plan: Swing on iPhone

Status: **Draft for review** · Nov 2026

## Goal

Log the day on the iPhone when the Mac isn't at hand, and see the same diary on both. Free only: no paid
Apple Developer Program, no TestFlight, no App Store, no web app. Diary text never goes to a server of ours
(there isn't one).

This moves the iPhone part of the mobile plan ahead of v2.0. Android stays after v2.0.

## 1. Installing and keeping it running

A free Apple ID can install its own apps, but each install expires after 7 days. Two free tools re-sign
the app before then:

- **SideStore (recommended).** A fork of AltStore that re-signs on the phone itself through a local VPN app,
  in the background. The Mac is needed once, to install SideStore and create a pairing file; after that
  refreshes don't need the Mac at all, which fits being away from home.
- **AltStore Classic (fallback).** Refreshes over Wi-Fi from AltServer running on the Mac, so only when
  the phone and the Mac are on the same network. Simpler setup, but tied to home. (AltStore PAL is EU only.)

Either way: if a refresh is missed, the app stops opening until it's re-signed, but its data is kept.
Free Apple ID limits: a few sideloaded apps at a time (reports differ: the store itself counts), and new
app IDs are limited per week, so keep one bundle ID for the phone app and don't churn it.

Each new build: archive in Xcode as an .ipa, open it in SideStore (AirDrop or Files), done.

## 2. Keeping the Mac and the phone in step (the big decision)

Today the diary is one SQLite file on the Mac. The phone needs its own copy that stays in step.

**Not possible for free:** CloudKit and the iCloud app container. Apple's developer forums confirm that
free personal teams can't use iCloud capabilities. (This also rules out the earlier "move the database into
iCloud" backup plan, if the Mac app is signed by the free team too.)

**Option A: a shared iCloud Drive folder (recommended).** Any app may read and write a folder the user
picks in the Files picker, with no special entitlement. Pick a folder like `iCloud Drive/Swing` once on
each device. Each device writes its changes to its own file there (`<device>.jsonl`, append-only:
"entry X now has these values", "entry Y deleted"), and reads the others' files to catch up. No device
ever writes another's file, so iCloud never has to merge two edits of the same file, which is what
corrupts a shared SQLite file.

- Works anywhere both devices have internet; doubles as the iCloud backup that was planned.
- Diary text sits in your iCloud Drive (encrypted end to end if Advanced Data Protection is on).

**Option B: sync over home Wi-Fi.** The Mac app and the phone app find each other on the local network
(Bonjour) and swap changes directly. Nothing touches iCloud, but the phone only catches up at home, and
there's no off-Mac backup.

**Either way the database needs, per entry:** a stable ID that's the same on both devices (a UUID column;
today's numeric ID is per database), an "updated at" time, and deletions kept as markers rather than
removed rows. Same for period start days. Conflict rule: the most recent edit of an entry wins. Swing has
one entry per day, so if both devices log the same day before syncing, keep the later one and say so.

## 3. Code layout

Move everything that isn't Mac UI into a shared package, `SwingCore`, used by both apps:

- Models (`MoodEntry`, `MoodTag`, `MoodScale`, `MoodState`, lenses, cycle calendar, episodes, search)
- Persistence (GRDB, migrations, stores) and the new sync code
- Tagging (`TagPrompt`, classifier, controller), import and export

The Mac app keeps its views. The iPhone app gets its own views built on the same core. Mac-only bits to keep
out of the core: `NSFont` measuring in `MoodTagChips`, keyboard handlers, hover magnification.
`project.yml` (XcodeGen) gains an iOS target.

## 4. The iPhone app

Three tabs, phone-sized:

- **Log:** the gauge (dragging works with a finger), flavour slider, title, note, Log entry. The lens turret
  stays beside the mood word.
- **History:** the list with search (tags and mood bands included), tag chips. Tap opens the entry.
- **Diagram:** week / month / year.

The entry opens as a sheet with an Edit button (no double-click on a phone): mood, flavour, title, note,
tags (same editor, up to four), period start in the PMDD lens, delete.

## 5. Tagging on the phone

- **First version: no model on the phone.** Entries logged on the phone sync to the Mac, which tags them
  (Auto-tag on the panel or Auto-tag all) and syncs the tags back. Manual tag editing works on the phone
  from day one.
- **Later: Gemma 4 E2B on the phone.** It's built for phones and runs through the same llama.cpp package
  (LLM.swift supports iOS). Two things to check first:
  - **Memory:** the model file is about 3 GB. iOS caps an app's memory unless it has the "increased memory
    limit" entitlement. Community reports say SideStore can add it for free-signed apps, but Apple doesn't
    document that, so it needs testing on your phone.
  - **Getting the model on:** it can't sit at `~/Models`. This is the same "download the model on first
    tag" feature planned for v2.0, so build it once for both apps.

## 6. Phases

0. **Spikes (one session).** A throwaway iOS app signed with the free team that opens a GRDB database;
   installed and refreshed through SideStore; picks an iCloud Drive folder, keeps access after a relaunch,
   and writes a file the Mac can see. Settles section 1 and Option A before any real work.
1. **Shared core.** Move the code into `SwingCore`; the Mac app behaves exactly as before (a 1.2.x release).
2. **Sync, Mac side.** Database migration (UUIDs, updated-at, deletion markers), the change files, merging.
   Tested with two copies of the database on the Mac before any phone is involved.
3. **iPhone app.** Log, history, search, entry sheet, lenses, manual tags, sync. On your phone via SideStore.
4. **Tagging on the phone.** Model download, memory check, then Gemma on device.

## Decisions (5 Nov 2026)

- Phone: iPhone 15 Pro (A17 Pro, 8 GB RAM), latest iOS. Enough for Gemma 4 E2B if the memory entitlement works.
- Sync: Option A, the shared iCloud Drive folder.
- v1.2 isn't released yet: search needs tightening first.
