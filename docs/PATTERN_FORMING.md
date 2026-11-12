# Proposal: pattern forming

Status: **Built** · Nov 2026

## The gap it fills

The diagram shades an episode only once it is complete: four days at 6.5 or above for an elevated run, fourteen
days below 3.5 for a depressive one. Until the last of those days is logged, the diagram shows nothing, so the
moment a run is easiest to notice (two or three days in) is the moment the app is silent.

Pattern forming shows a run that is on its way but not there yet.

## What counts as forming

The same rules as a full episode, stopped early. Nothing new is invented:

- The run starts on a day past the threshold and is still open today: no day on the other side of baseline,
  and no more than two unlogged or near-baseline days in a row.
- At least 70% of its days so far are past the threshold.
- It is shorter than a full episode but long enough to mean something:

| Run        | Full episode | Shown as forming from |
|------------|--------------|-----------------------|
| Elevated   | 4 days       | 2 days                |
| Depressive | 14 days      | 7 days                |

One high day is not forming. Two in a row is.

A forming run ends in one of two ways. It reaches full length and becomes a normal shaded episode, or the mood
moves away and it disappears. A run that faded leaves no trace: the diagram never keeps "almost" marks, so a
near miss can't read as a judgement afterwards.

## How it looks

- On the diagram: the same band as an episode, but outlined with a dashed line and not filled, in the run's
  colour. It grows a day at a time, and fills in the day it completes.
- A short caption under the diagram while a run is forming: "Day 3 of an elevated run" or "Day 9 of a low run".
- In the Bipolar lens the caption uses that lens's words ("Day 3 in the hypomania range"). Everyday and PMDD
  lenses keep the neutral words.
- Only the current run is ever shown. History shows completed episodes only.

## What it doesn't do

- No notifications, badges, sounds or colour changes elsewhere. It is something you see when you look.
- No advice and no prediction ("likely to become…"). It counts days, nothing more.
- No claim about cause. Same tone rule as the rest of the app: descriptive, never diagnostic.

## How it would have behaved on the diary so far

Replaying the diary day by day (10 May to 10 Nov 2026) with these numbers:

- Elevated: shown once, from 14 July. It became the 14 to 24 July episode.
- Depressive: shown once, in May. It became the 12 May to 1 June episode.
- Shown and then faded: none.

So it would have appeared twice in six months, both times ahead of a full episode. Two cases is too few to
say how often it will fade, and that is the main thing to watch once it is in use.

## Decisions (11 Nov 2026)

1. Starting points stay as proposed: elevated from day 2 of 4, depressive from day 7 of 14.
2. The caption names the state, not the target: "Day 3 of an elevated run", "Day 9 of a low run"
   (Bipolar lens: "Day 3 in the hypomania range"). No "of 4", so it doesn't read as a countdown.
3. The MCP server reports a forming run too (in `range_summary` and `mood_episodes`), so the diary chat sees it.

## Size

Small. `EpisodeDetector` already does the scan: it needs to return the open run at the end of the data, and
the diagram needs one more band style and the caption. No database change.
