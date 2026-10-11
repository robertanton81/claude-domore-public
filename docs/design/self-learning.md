# Self-learning: the ladder


> Part of the claude-domore design, 2026-09-26. Status: proposal, nothing built. The overview is [what-we-could-build.md](../what-we-could-build.md). The learning channels in their default order, with entry and exit conditions, what to measure, the keep-or-revert statistics and the stop criteria.

The rule: learning may change what the engine tries, never what it is allowed to do (your position in the session of 2026-09-26). No learned artifact touches sandbox modes, permissions, locks, budgets or the definition of success [FIT]. Every tier needs versioned artifacts, source evidence, rollback, a budget, and a baseline without the adaptation [CODEX].

| Tier | Channel | Entry condition | Promotion and exit | Jev role | Evidence |
|---|---|---|---|---|---|
| 0 | Observe only | M1 passed: reliable state and verification | Record successes, failures, unknowns, human corrections; no adaptation. Exit when these exist: baselines; A/A noise (how often the unchanged engine seems to beat itself); a retention set (fixed tasks re-run after each change to catch lost abilities); a canary set (a small fixed task set re-run after each CLI or model update to catch silent changes) | Log jobs 1, 3 and 5 with matching labels | [H1, H2](research-findings.md#hypotheses-and-verdicts); [phantom-gains-2026], [anthropic-evals-2026] (*vendor*) |
| 1 | Routing numbers and escalation thresholds, including Jev thresholds | Repeated eligible task categories; trustworthy outcomes; logged selection probabilities | Shadow first (record what the change would do, without applying it); compare with the fixed route under equal budgets; revert on quality loss or quota misuse | Jobs 1 and 3; thresholds calibrated per question | Low value [routing-plateau-2026]; a coarse task-type table carried most value [routing-gap-task-type-2026]; escalate after a failed check, though that result used an oracle check and is contested [cascade-routing-2025]; [twinrouterbench-2026] |
| 2 | Experience retrieval | Related tasks exist; records have provenance | Compare no experience, sanitized verbatim records, selected lessons; quarantine stale or harmful records | Jobs 6, 8 and 10 | Largest gains when tasks depend on each other and retrieval is precise [dreambench-swe-2026], [swe-contextbench-2026]. Other author-run SWE-bench studies report about 3 to 5 points without that dependency: 4.7 to 5.2, possibly contaminated [subtask-memory-2026], [stair-2026], and 3.4 to 4.6 [reasoningbank-2025]. Itemized records, never rewrite the store [ace-2025]; poisoning [skilljack-2026] |
| 3 | Prompts, skills, tool descriptions | A specific repeated problem; enough evaluation budget | Paired comparison, retention and safety checks, per-model validation; otherwise keep the current version (the incumbent) | Jobs 7 and 9 | Self-written skills hurt under one protocol [skillsbench-2026]; GEPA is cheap but untested on coding agents [gepa-2025]; earlier capabilities got worse as skills and workflows changed [capability-erosion-2026] |
| 4 | Workflows, harness components | Stable lower-level execution; a measurable bottleneck | Unseen task families plus crash, cancellation and permission invariants; reaches components 1 to 7 only through a human-approved release | Job 11, as a signal only | Gains shrink out of distribution, that is, on tasks unlike the training tasks [rrsi-2026]; [ahe-2026] |
| 5 | Engine code | Proven recovery, protected evaluation, a separate experimental environment | Human-approved release only; never change the supervisor's code while it runs | Job 11, as a signal only | [ouroboros-2026], [dgm-2025] |

Tiers and conditions come from [CODEX] and the suggested order in [ACAD]. The human-approved release for Tier 4 is this document's addition; the consult left this question unspecified [CODEX-REVIEW, finding 1]. You confirmed it on 2026-09-30 ([Decision 30](../what-we-could-build.md#later)). [Decision 9](../what-we-could-build.md#later) set the same rule for engine code (Tier 5): a learned change reaches the engine only as a proposal, in a release you approve. See component 8 in [architecture.md](architecture.md#the-eight-components). Jev is never an acceptance input at any tier.

**A default order, not a strict one.** The tiers show rising risk, not a queue. A narrowly useful experience record may be worth testing before a learned router, and each channel needs its own evidence [CODEX]. What is strict is each tier's own entry condition.

**Grounded experience records.** A Tier 2 record points to the commit and path it came from, and code marks it stale when that code changes, as in OpenWiki's grounded claims [FIT].

**Automatic application.** [FIT] proposed that more careful learned changes may apply automatically. Codex said this needs limits, because caution costs budget and availability [CODEX]. This design takes a middle rule (*design inference*): a more cautious change applies automatically only while its measured extra cost stays inside a caution budget you set, and only while it does not stop all work. A change that grants more autonomy needs your approval and a minimum sample size you set [FIT]. The learned policy is a versioned file with provenance [FIT].

## What to measure

From the implications in [ACAD]:
- Cost per verified success, with failed runs counted.
- The gap between visible and held-out results, as a hacking signal [specbench-2026].
- Every memory design against no memory and a plain verbatim log, over time [dreambench-swe-2026], [faulty-consolidation-2026].
- A fixed retention set, re-run on each learned change [capability-erosion-2026].
- Judge drift: whether an LLM judge changes its verdicts over time, measured against a fixed set of examples with known answers (an anchor set) [who-drifted-2026].
- Worker drift: whether a worker changes after a CLI or model update, measured on the canary set [silent-updates-2026] (the canary set is *design inference*).
- Reviewer false passes, false blocks, useful findings, and the cost in time and plan usage, per review direction [xiang-2026]. The reviewer gives findings only and never rewrites code, so the study's "fixes against regressions" does not apply here ([Decision 19](../what-we-could-build.md#before-m1-before-a-later-phase-of-m1), session 2). Only blind reviews, made before the reviewer can see the grader verdict, measure a reviewer's own false passes. The M2 review trial labels the others "not blind" and counts them only as data about the whole workflow.
- pass^k next to pass@1. pass^k is the chance that all k trials succeed; at 75% per trial, pass^3 is about 42% [anthropic-evals-2026] (*vendor*).
- Long-term code health: size-normalized static-analysis changes and 90-day reverts [cynthia-2026-post-merge-quality], [kraishan-2026-five-agents-post-merge] (*single author*).

**Task families.** Error ranges and [M3's exit test](milestone-1.md#what-comes-after) need task families. The starting list comes from [R-0925]: narrow edit, bug fix, complete search, cross-file change, security-sensitive change, and a requirement that changes between sessions. The lab's hidden out-of-distribution set is drawn from families not used in development.

## What to avoid

From [ACAD]'s "What to avoid" list:
- Hosted memory services. On coding tasks they sat at or below the no-memory level in default mode, and they send repository data to a third party [mem0-2025].
- Hidden answers in proposer prompts. DGM's diagnosis prompt contained the private test patch [dgm-2025].
- Reviewer or monitor verdicts used as the reward the engine optimizes [zhou-2026], [baker-cot-obfuscation-2025].
- Parallel writers on coupled code without an integration check [scaling-agent-systems-2025], [cognition-dont-build-multi-agents-2025].

## Paired comparisons, A/A noise, and "inconclusive"

- **Paired comparison:** the incumbent and the candidate run on the same tasks. Error ranges are computed per task family (clustered), because tasks in one family tend to succeed or fail together. In one evaluation, clustered error ranges were 3.05 times wider than ranges that treat every task as independent [miller-2024].
- **Plan first:** set the minimum useful improvement, the acceptable regression and the maximum experiment budget before running. There is no universal trial count [CODEX].
- **A/A first:** run the unchanged engine against itself to measure how often noise looks like a win (0.058 in one audit [phantom-gains-2026]).
- **Small samples:** below a few hundred data points, use Wilson or Beta-Bernoulli intervals (methods that give an honest error range for a success rate on a small sample), and paired Bayesian methods for differences [bowyer-2025].
- **Inconclusive is valid:** if the budget cannot separate the candidates, do not promote [CODEX].
- **Sequential tests are candidates, not requirements.** PACE takes the tasks where exactly one version is right and feeds them into a betting e-process, a test that stays valid when you check it after every run [pace-2026].
- Check PACE's assumptions and cost first. Repeated selection against the same hidden set can overfit that set [CODEX].
- The best of many candidates looks better than it is (the winner's curse) [siren-winners-curse-2026].
- Do not judge routes by replaying logs. Only 3% of replayed states were valid [replay-gap-2026].

## Stop criteria

From [CODEX]:
- **Disable a channel at once** on unauthorized access or effect, grader or evidence tampering, confirmed secret exposure, a failed rollback or workers that cannot be terminated, or a safety or retention failure.
- **Stop all promotions until the cause is fixed** on model drift, stale evidence, exhausted budgets or inconclusive comparisons.
- **Disable channels** that repeatedly cost more without useful gains.

