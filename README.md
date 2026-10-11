# claude-domore

A design for a self-hosted supervisor that would run coding tasks unattended through vendor coding CLIs (OpenAI `codex` first; a Claude Code `claude -p` adapter is designed but off by default), check each result with an independent grader, and keep task state that survives crashes.

> **Status: design and host setup (milestone M1a).** No engine code exists yet. The repository contains the design, the diagrams and the first host setup scripts. See [Status](#status).
>
> This is a curated public copy of a private working repository. The research records and the working log are not included. Account names and home paths are placeholders (`admin-user`, `daily-user`).

## Overview

claude-domore is a personal research project. Its goal is an engine that can:

1. take an approved coding task,
2. run it with a vendor coding CLI in an isolated workspace,
3. grade the result with checks that the worker cannot read or change,
4. retry or escalate within a fixed budget, and
5. later, learn from outcomes that the grader has verified.

The central design choice is a **deterministic supervisor**. Ordinary code, not a language model, decides task states, retries, permissions and acceptance. Models only propose work and produce patches. The project does not include its own coding agent. It is designed to drive the vendors' CLIs as they are.

The design builds on [subagent-router](https://github.com/robertanton81/claude-subagent-router), a Claude Code plugin by the same author that routes subagent tasks between Claude models and the Codex CLI.

## Design summary

Everything in this section is planned. None of it is implemented yet. The full design is in [docs/what-we-could-build.md](docs/what-we-could-build.md) and [docs/design/](docs/design/).

**Components.** The supervisor has eight components:

1. Task admission and clarification
2. Durable state and scheduler
3. Provider adapters (`codex exec`; an optional `claude -p` adapter, off by default)
4. Workspace and process supervisor
5. Independent verification
6. Budget and quota control
7. Human approval inbox
8. Learning experiments and artifact registry

**Task states.** `proposed`, `needs_clarification`, `ready`, `running`, `checking`, `verified_candidate`, `awaiting_approval`, `accepted`, plus `retryable`, `blocked`, `cancelled` and `effect_unknown`. Code checks the conditions for every transition.

**Side effects.** Before a side effect (a model launch, a commit, a push), the supervisor records the intent and a stable operation ID. After a crash it compares the record with the observed state (git HEAD, snapshot hashes, lock ownership) instead of repeating the last step. A launch with an unknown outcome moves to `effect_unknown` and is never relaunched automatically. Each task claim carries a fencing token (an increasing ownership number), so results from an older claim are rejected.

**Isolation.** The supervisor and the approver run under separate macOS accounts. Engine state, evidence and hidden checks are outside every path a worker can write. Approvals come only through a channel that models cannot reach: a separate account with a FIDO2 hardware key. Workers are planned to run in VMs (Apple `container`), with a dedicated worker account as the fallback.

**Budgets.** Model work runs on flat-rate subscriptions (Claude Max and ChatGPT), not on pay-per-use APIs. The supervisor tracks the used share of each provider usage window, plus attempts, time and classifier spending. It launches a task only when the window has room for the task and a reserve kept free for interactive work. When the quota is unknown, it does not start unattended work. Whether the vendors' plans allow scripted, unattended runs is not yet confirmed, so runs stay attended until that check is done.

**Classifier signals.** [TypeSafe Jev](https://typesafe.ai), a classifier model that returns probabilities, labels tasks (for example how unclear a task is, or why an attempt failed). Its output is a signal for routing and clarification. It never grants a permission or decides acceptance. When it is unavailable, a fixed decision table in code chooses the fallback. Only repositories on an allow-list send data to it, and only named, size-limited fields that have passed a secret scan.

**Learning.** Learning is planned in six tiers, ordered by risk: observation only, routing numbers, experience retrieval, prompts and skills, workflows, and engine code. Learning may change what the engine tries, never what it is allowed to do. Each change is compared with the current version on the same tasks, after an A/A run that measures noise. Changes to workflows or engine code need a release that the owner approves. A separate unrestricted self-modification track is designed as a disposable lab. It holds no provider logins (only its own classifier key) and stays closed until its listed conditions are met.

**Language.** Python with standard-library SQLite. A small Node bridge is added only if the M1a checks require it.

## Research basis

The design choices are based on a review of 2025 to 2026 papers on coding agents, agent memory and self-improving agents. Findings that shaped the design:

- Learning without a trusted outcome check stalled or made results worse. Learning from verified outcomes gave moderate gains.
- A passing test suite is not proof of a correct patch. Reward hacking (passing a check without doing the work) is common on tasks that cannot be solved.
- Resuming a paused agent run is not safe without explicit design. In one study, concurrent resumes ran the same approved action several times.
- Keep-or-revert decisions based on a single score are noisy.

Details, sources and the limits of each source (many are single-author preprints) are in [docs/design/research-findings.md](docs/design/research-findings.md). A market scan of related tools, dated 2026-09-30, is kept in the private repository.

## Status

As of 2026-10-02:

| Milestone | Scope | State |
|---|---|---|
| M1a | Host setup and feasibility checks (process containment, approval mechanism, OS boundary) | In progress |
| M1b | One attended task on a fixture repository, one fixed route | Not started |
| M1c | Task queue, routing, one supervised live run | Not started |
| M2 | Unattended queue on one repository | Not started |
| M3 | Evaluation harness and baselines | Not started |
| M4 | First learning channel | Not started |
| M5 | Push and pull requests behind approval; review of the lab conditions | Not started |

Acceptance tests for M1 and exit tests for M2 to M5 are in [docs/design/milestone-1.md](docs/design/milestone-1.md). Open design decisions are tracked in [docs/what-we-could-build.md](docs/what-we-could-build.md#decisions-for-the-user) and [docs/design/open-questions.md](docs/design/open-questions.md).

## Repository layout

```
docs/
  what-we-could-build.md   Design overview, options and the decision log
  design/                  Detailed design: architecture, milestones, Jev, learning
  diagrams/                Architecture map (SVG) and an interactive walkthrough (HTML)
setup/
  m1a/                     macOS host setup scripts for milestone M1a
```

## Setup scripts

The scripts in [setup/m1a/](setup/m1a/) prepare a macOS host. They create system accounts, set folder permissions and install pinned runtimes into a root-owned folder. They run with `sudo` and are specific to the author's machine. Read each script before you run it. Each script checks its preconditions and stops when one does not match. Script 03 also checks pinned hashes and signatures.

| Script | Purpose |
|---|---|
| `01-supervisor-account.sh` | Creates the hidden supervisor account and its data folder |
| `02-exchange-folders.sh` | Creates the exchange folders and the socket folder, with ACLs for each account |
| `03-runtime-folder.sh` | Downloads Python (python-build-standalone) and Apple `container`, checks SHA-256 pins and signatures, and installs them into the runtime folder |

## Diagrams

- [docs/diagrams/end-state.svg](docs/diagrams/end-state.svg): the planned system after M5, with accounts, components, task states and the learning tiers.
- [docs/diagrams/index.html](docs/diagrams/index.html): the same map with three step-by-step walkthroughs (a task from draft to accepted patch, an unclear task with a failed attempt, and stop/pause/renew flows). Open it in a browser.

## How the work is done

The design was written with Claude Code. The main design decisions were also reviewed by a second model (OpenAI Codex) and a classifier (TypeSafe Jev). The records of these reviews, including the points where a reviewer disagreed and the design changed, are kept in the private working repository.

## License

No license has been chosen yet. All rights reserved.
