# Next Actions

- **Lens turret hover label overlaps the mood number.** The lens name shown on hover sits under the turret
  (`LensTurret`, overlay with `.offset(y: size + 4)`) and runs into the big mood number (seen at 6.3,
  "Everyday words"). Move it to the right of the turret instead, vertically centred on the disc.
- **Edit tags by hand in the entry view.** When Auto-tag gets an entry wrong, let the tags be amended in the
  detail panel (`EntryDetailPanel` header chips): add or remove tags from the closed `MoodTag` set, max
  `TagPrompt.maxTags`. Mark hand-edited tags (e.g. `tagModelVersion = "manual"`) so "Auto-tag all" and
  "Re-tag all" don't overwrite them without asking. The corrections double as labelled data for tuning.
