# Next Actions

- **Lens turret hover label overlaps the mood number.** The lens name shown on hover sits under the turret
  (`LensTurret`, overlay with `.offset(y: size + 4)`) and runs into the big mood number (seen at 6.3,
  "Everyday words"). Move it to the right of the turret instead, vertically centred on the disc.
- **Bring the README up to date as a whole, not just the version number.** It doesn't mention on-device AI
  tagging (Gemma 4 E2B, model at `~/Models`, Auto-tag one or all, tag chips, re-tagging when the prompt version
  changes), the Database section is missing the `tags` and `tagModelVersion` columns and the `periodStart`
  table, and Features, Requirements, Tech stack (LLM.swift / llama.cpp) and Project structure (`AI/`,
  `Lens/`) need checking against the code. Read every section against the current source before editing.
