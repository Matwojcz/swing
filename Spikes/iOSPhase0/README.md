# Phase 0 spike: Swing on iPhone

A throwaway iOS app that answers the four questions the iPhone port depends on, before any real work.
It is a separate XcodeGen project; the Mac app is untouched. Delete this folder once the spike is done.

Plan: `docs/IOS_PORT_PLAN.md`, phase 0.

## Build and install

1. On the Mac: `./make_ipa.sh` (needs XcodeGen). It builds an **unsigned** `SwingSpike.ipa`.
2. AirDrop the .ipa to the iPhone, open it with SideStore. SideStore signs it with your Apple ID.

(Faster for the first try: `xcodegen generate`, open `SwingSpike.xcodeproj`, run straight onto the phone
with your free team. That covers checks 2–4 but not the SideStore part of check 1.)

## Prepare iCloud Drive

Make a folder `iCloud Drive/Swing/sync-spike`. From the Mac, put a file in it:

```bash
echo '{"device":"mac","at":"'"$(date -u +%FT%TZ)"'"}' >> \
  ~/Library/Mobile\ Documents/com~apple~CloudDocs/Swing/sync-spike/mac-spike.jsonl
```

## The four checks

Write down pass/fail for each; that's the result of the spike.

1. **Installs and survives a refresh (SideStore).**
   Install through SideStore. Later, let SideStore refresh it (or press Refresh in SideStore) and open the app.
   Pass: it opens, and the "Opened N time(s)" count kept counting up (data survived the re-sign).

2. **GRDB works.**
   Pass: "Opened N time(s) since …" shows, and N goes up each time you close (swipe away) and reopen.

3. **Folder access survives relaunch.**
   Tap Pick folder, choose `iCloud Drive/Swing/sync-spike`. Swipe the app away, reopen.
   Pass: the folder shows with "Access restored on launch" and its files are listed, with no picker.
   Also try after a phone restart and after a SideStore refresh.

4. **Read and write through iCloud, including files not on the phone yet.**
   - Tap "Write a line". On the Mac, within a minute or so, `iphone-spike.jsonl` appears in the folder with
     the line. Pass if the Mac sees it.
   - `mac-spike.jsonl` is listed on the phone with the Mac's line. Pass if read OK.
   - Append another line on the Mac (run the command again), then pull to refresh on the phone.
     Pass if the line count goes up.
   - The important one: in the Files app on the phone, long-press `mac-spike.jsonl` → **Remove Download**.
     Back in the spike, refresh. Pass if it says "Before reading: not on the phone …" **and** "read OK"
     with the right line count, meaning the app fetched it from iCloud by itself.
   - Same with the phone in Airplane Mode: it should report a read failure or wait, not crash, and recover
     once back online.

Send back the four results (and a screenshot of anything that failed, with the Log section showing).
