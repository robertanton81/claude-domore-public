# Diagrams

Pictures of the planned engine. They show the design as of 2026-09-30. No engine code is built yet. Where a picture and the design docs differ, the docs win.

## Files

- [end-state.svg](end-state.svg): the end-state map, M1 to M5. It shows the OS accounts (daily, approval, admin, supervisor), the exchange folders, the supervisor's eight components, the VMs, the outside services, the task states, the learning ladder and the parked lab. Numbered circles 1 to 9 follow one task. The list at the bottom left explains each number. The file follows the light or dark setting of your system.
- [lab.svg](lab.svg): the parked lab as fixed by its charter of 2026-09-30 (Decision 10). It shows where each lab process runs, what the learner may change, how a proposal leaves the lab, the protected core, and when the lab may open.
- [index.html](index.html): a page with both maps and three animated journeys from your side of the screen:
  1. **Idea to accepted patch.** You draft a task, approve it with the YubiKey, the engine runs and grades it, and you accept the patch.
  2. **Unclear task, failed attempt.** Jev flags the task as unclear, you answer, the first attempt fails, the one retry fails, and the task is blocked until you decide.
  3. **Stops, pauses, renewals.** You stop the engine from your daily account and restart it with the key. A quota pause ends by itself after the reset. Host conditions pause launches. The unattended authorization expires, and you renew it.

Task names, hashes, times and percentages in the journeys are examples.

## How to open them

- Open `end-state.svg` in any browser, or view it on GitHub.
- Open `index.html` in a browser. From a local file, the map shows as an image. Served over http, the page puts the map inline, so it also follows the page's own theme switch.
- The player: Play or Pause, Back and Next, or the arrow keys. Space plays or pauses when the player has focus. A link with `#idea`, `#unclear` or `#stops` opens that journey.

## How to change them

- Both files are hand-written. No build step and no library.
- Colours are tokens at the top of each file (`--es-*` in both SVGs, which carry identical copies of one style block, and the same values in `index.html`). Change them in all three places.
- The journey steps are data in `window.JOURNEYS` in `index.html`. Each step lists only what changes; the player carries the rest forward.
- When a decision changes something shown here, update the picture in the same commit as the decision record.
