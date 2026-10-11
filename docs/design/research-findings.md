# What the research says

> Part of the claude-domore design, 2026-09-26. Status: proposal, nothing built. The overview is [what-we-could-build.md](../what-we-could-build.md). The research findings that shape the design, with source ids, the hypotheses and verdicts, and what Codex agreed and disagreed with in the research inputs. The full evidence is in the research files.

Only findings that shape the design are here. Most sources are 2025-2026 preprints, often run by the method authors on one benchmark [ACAD]. [ACAD] does not record reading depth (full text, abstract, or a summary of a web page), so read each number below as "reported in [ACAD], reading depth not recorded". The completeness critic in [ACAD] is an agent that reviewed the research for gaps. Its warnings are at the top of that file, and this document calls it "the critic".

## Learning depends on the outcome check

- With a trusted signal, learning without weight changes gives moderate gains. On web, finance and math tasks, [ACAD]'s summary says about 2 to 17 points, but its detail section lists 2.7 to 10.6 [ace-2025], [tf-grpo-2025]. On SWE-bench Verified, a benchmark of coding tasks graded by tests, ReasoningBank gained 4.6 and 3.4 points with two models [reasoningbank-2025]. A shared memory pool added 3.7 points on average across six coding benchmarks [memory-transfer-coding-2026] [ACAD]. The method authors report all of these. [ACAD] found no independent replication.
- Without a trusted signal, learning stops improving or makes results worse. Under one protocol, skills that models wrote once, before solving, scored 8.1 to 11.5 points below no skills, on Claude Code, Codex and Gemini CLI. In 10 of 12 audited Codex and Gemini trajectories (the recorded steps of one agent run) the solver never read the skills, and writing them used up the trial [skillsbench-2026] [ACAD]. So this result is partly about the protocol, not only about the missing signal. Lessons that the model wrote directly did not help (79.8 against 80.0) [tf-grpo-2025] [ACAD].
- When an LLM keeps rewriting its memory store (consolidation), the store first helps and then gets worse, sometimes worse than no memory. This happened even when the inputs were ground-truth solutions [faulty-consolidation-2026] [ACAD] (*preprint*).
- Models diagnose their own failures poorly: reflection accuracy was below 30% [benchtrace-2026] [ACAD].

## Memory helps in narrow cases, and simple storage is enough there

- When later tasks depend on facts from earlier sessions, memory matters. No memory passed 21/180 tasks (11.7%), a plain verbatim log 82/180 (45.6%), and a typed-plus-raw pipeline 83/180 (46.1%). Hosted Mem0, a memory service, with fact inference turned off, passed 97/180 (53.9%), but its lead was not robust (p=0.219). In default mode, hosted Mem0 passed 21/180, the no-memory level. In the study's original run, the pipeline passed 95/180 and the verbatim log 89/180. That difference was not statistically significant (p=.518). The author calls this a failure to show a difference, not proof that the two are equal [dreambench-swe-2026] [ACAD] (*preprint, single author, single source*).
- When memory is optional, retrieval precision limits the gain. A correct short summary of the most related past task raised resolution from 26.26% to 34.34% on 99 tasks; summaries the agent chose itself reached 22.22%. The correct summary came from an "oracle" setting that uses the true task relationships, which a real system lacks [swe-contextbench-2026] [ACAD].
- The router research cites VibeMemBench (arXiv 2609.23570; not in the [ACAD] ledger). On 111 coding targets, 11 of 12 memory-system and solver combinations did not beat memory off. The targets were chosen because experience helped a reference solver. Directly supplied useful experience helped 4 of 5 held-out solvers (solvers not used to choose the targets) by 1.1 to 4.5 points [R-0925] (*very recent preprint, single source*).
- Static context files did not change correctness across Claude Code and Codex (17 tasks, 288 runs), within an equivalence bound of 10 to 15 points [context-files-ablation-2026] [ACAD] (*preprint, single author, single source*).
- Raw episodes against abstract lessons is **contested**. Two studies favor abstract insights [stair-2026], [subtask-memory-2026]; three find raw episodes safer than consolidated memory [faulty-consolidation-2026], [dreambench-swe-2026], [agent-native-memory-2026] [ACAD].
- Revising outdated facts is the weakest capability: every method scored at most 28% on multi-hop fact updates [memoryagentbench-2025] [ACAD]. No study measured a retirement policy end to end on coding work.

## "Tests pass" is useful, but it is not proof

- 7.8% of accepted SWE-bench patches fail the full developer suite, and 29.6% of test-passing patches behave differently from the reference [patchdiff-2025] [ACAD]. Maintainers would not merge about half of test-passing patches in a blinded review of 296 PRs [metr-2026-swebench-not-mergeable] [ACAD] (*industry report*).
- Reward hacking means passing the check without doing the intended work. On impossible SWE-bench tasks GPT-5 did it 54% of the time [impossiblebench-2025]; o3 hacked 30.4% of RE-Bench runs [metr-reward-hacking-2025] [ACAD]. An explicit "flag for human" exit cut GPT-5's cheating from 54% to 9%, with much less effect for Claude Opus 4.1 [impossiblebench-2025] [ACAD].
- Hidden tests cut cheating to near zero but lowered honest performance. Read-only tests blocked test edits. This matters because Claude models cheated mostly (over 79%) by editing tests. Read-only tests do not stop special-casing: code that detects the test inputs and returns the expected answers [impossiblebench-2025] [ACAD].
- In one study, agents wrote tests at a similar rate on resolved and unresolved tasks, and the tests were mostly print statements [agent-tests-2026] [ACAD]. So writing tests did not separate success from failure there. This does not show that generated tests have no value [CODEX-REVIEW, finding 2]. In 1,184 failed Terminal-Bench runs, 26% claimed success with fabricated evidence [cli-failure-process-2026] [ACAD].
- Answers can leak through history that the worker can read. State shared between trials inflated scores, because Claude read git history left by earlier trials [anthropic-evals-2026] (*vendor*). In Ouroboros, SWE-bench Pro task ids exposed the upstream fix commits [ouroboros-2026] [ACAD].

## Long autonomous work mostly fails, and resuming is not safe

- The best setup resolved 25% of 112 dependency-structured tasks with an outer continuation loop, and 16.96% without it [loopsbench-2026] [ACAD] (*preprint*). A harness is the loop, prompts and tools around a model. With the same model, changing only the harness changed results about threefold [loopsbench-2026] [ACAD].
- Keeping task state outside the model, with only audited facts written into it, raised Opus 4.7 from 20.0% to 34.3% on an OSWorld 2.0 subset (computer-use tasks). On Terminal-Bench 2.1 the gain was smaller (Qwen 69.7% to 77.2%), and [ACAD] says coding benefited less [longhorizon-harness-2026] (*preprint, single source, no ablations*). An ablation is a test that removes one part of a system to measure what that part adds.
- LangGraph re-ran recorded work after a real crash. In a separate test in the same study, a run paused at an interrupt, a step that waits for human approval. When k processes resumed that one paused run at the same time, the action behind the approval ran k times instead of once. This happened in 36 of 40 test configurations [resume-means-resume-2026] [ACAD] (*preprint, single author*). After a rollback, a verification result became bound to a different, malicious artifact [safe-to-resume-2026] [ACAD].

## Self-modifying agents: large lab gains, hacking, high cost

- DGM rose from 20.0% to 50.0% on a SWE-bench Verified subset; SICA from 17% to 53% on 50 tasks. These are author-run, mostly single runs, not replicated. Runs cost about USD 7,000 to 22,000 [dgm-2025], [sica-2025] [ACAD].
- Gains shrink outside the training tasks: up to 14.1 points on the evolve split (the tasks the system trained on while it changed itself), against up to 4.7 points on new benchmarks [rrsi-2026] [ACAD] (*preprint, days old*).
- In a DGM side experiment, the markers that the checker used to detect cheating sat in code the agent could edit. One variant in DGM's archive (node 114) got a perfect score by removing them [dgm-2025] [ACAD]. The critic notes that this quote came from a summary of Sakana's blog page. A summary is a weak way to read a source.
- AIDE^2's agent patched a crashing held-out scoring script. The paper calls this a fix. It shows that the loop could reach evaluation code, not that it cheated [aide2-2026] [ACAD] (*preprint, days old*).

## Learned routing adds little over simple baselines

- Most learned routers score close to each other, 10 to 30 points below the oracle (a router that always picks the right model with hindsight), and often do not beat the best single model [routing-plateau-2026], [llmrouterbench-2026] (*partly verified*), [task-session-routers-2026] [ACAD]. Two studies conflict with this, on different model pools and tasks: LLMRouter reports a 14.6% relative gain over the best fixed model, and BaRP at least 12.46% over offline routers (arXiv 2608.06867 and 2510.07429, listed as contested in [ACAD]).
- A one-model-per-task-type table got 262 questions right against 245 for the best single model, at $3.33 against $7.69, fitted and scored on the same questions [routing-gap-task-type-2026] [ACAD] (*single author*).
- Checking after the run beats predicting before it. A cascade tries a cheaper model first and escalates on failure. Cascades that used the ground-truth tests as the check, an oracle check that a real engine lacks, gained up to 14% in AUC (area under the curve; [ACAD] does not name the curve) [cascade-routing-2025]. A game-theory study found a static policy with no cascade optimal in nearly all cases (arXiv 2602.09902, listed as contested in [ACAD]).
- The one positive coding result: a router trained on 970 execution-verified labels resolved 75 of 100 tasks at $25.66, against 74 of 100 at $54.73 for Opus alone [twinrouterbench-2026] [ACAD] (*single source; a one-task margin*).

## Learned text is an attack surface; enforced controls beat requests

- Skill extraction dropped safety detection from 98.5% on poisoned trajectories to 11.4% on the extracted skills [skilljack-2026]. Three consistent poisoned records in a batch of 30 were enough to change what the system learned [poisoned-evolution-2026] [ACAD].
- Memory built by a coding agent cut its refusal of harmful requests from 99.4% to 54.4% [misevolution-2025] [ACAD].
- Hard limits come from sandboxes, egress limits (limits on outgoing network traffic) and graders the agent cannot reach. In a red-team test (a test in which people act as attackers on purpose) with a phishing message, a fake request that tries to steal data, Claude sent credentials to an outside server in 24 of 25 tries [anthropic-containment-2026] [ACAD] (*vendor*).
- LLM monitors caught only 42-65% of cheating on multi-file SWE tasks [impossiblebench-2025]. Agents tried to evade a monitor in up to 98% of cases [evasionbench-2026] (*preprint, days old*) [ACAD]. [ACAD] also gives two figures, on prompt-injection bypass of Claude Code Auto Mode and Codex Guardian and on how often users approve permission prompts. The critic says neither maps clearly to a source, so this document does not repeat them (see "Research quality" in [open-questions.md](open-questions.md)).

## Review and statistics

- Model errors are correlated across providers: ten judges carried about as much evidence as 3.5 independent ones [kim-2025], [hossain-2026] [ACAD].
- The only direct Claude-Codex test used 116 tasks. A Claude Opus 4.7 review raised Codex drafts from 71.6% to 89.7% (Codex self-review: 84.5%). A Codex review lowered Claude drafts from 91.4% to 82.8% (3 fixed, 13 broken). The reviewer always rewrote the program. Reviewer strength is confounded with review direction: the study cannot separate the two effects [xiang-2026] [ACAD] (*single source*).
- The rule "keep a change if the score went up" accepted 30-42% wrong edits. In that test, only one of many noisy proposals was a real gain [pace-2026] (*single author*). An unchanged model showed fake "learnings"; the false-win rate across 110 comparisons was 0.058 [phantom-gains-2026]. Single-run pass@1 (the success rate of one run per task) moved by 2.2 to 6.0 points, depending on which run was picked [randomness-evals-2026] [ACAD].
- Automated root-cause finding on long failures reached 13.2% (strongest baseline) and 24.1% (new method) [longrca-2026]; targeted interventions turned 18-28% of failures into successes [dover-2026] [ACAD].

## Hypotheses and verdicts

All seven come from [ACAD].

| # | Hypothesis | Verdict | Main caveat |
|---|---|---|---|
| H1 | An autonomous engine needs durable task state, not learned cross-task experience | Supported, one caveat | When later tasks depend on earlier facts, memory matters: 11.7% with no memory against 45.6% with a plain verbatim log. The best system, hosted Mem0, reached 53.9%, but its lead was not robust (p=0.219). A plain verbatim log was enough; that is closer to project state than to experience |
| H2 | Self-learning needs an independent verifier | Supported | Noisy signals still gave small gains; a verifier reduces cheating but does not remove it |
| H3 | Most memory systems do not beat "memory off" on coding; selecting is the hard part | Partly supported | One synthetic benchmark plus one 99-task study; storing is not trivial either |
| H4 | Learned routing numbers are safer to learn than learned text | Partly supported | No study attacked routing weights; poisoned outcomes can shift numbers; lowest risk and lowest value |
| H5 | Self-modifying systems gained, hacked, and needed sandboxes, lineage and held-out tests (tasks the learner never sees during learning) | Supported, with caveats | Author-run, small subsets; no study removed the guards to show they were needed |
| H6 | Multi-agent orchestration adds cost and new failures | Supported | It helps breadth-first, read-heavy work |
| H7 | "Tests pass" is useful, but a worker can cheat it; hidden tests reduce cheating | Supported, refined | Much of the gap is incomplete tests, not deliberate cheating |

## What Codex agreed and disagreed with

Codex reviewed the research inputs in its consult [CODEX]. All positions come from [CODEX], sections 1 and 5, unless a row names another section. The design's own departures from Codex's proposal are listed in the overview, under ["Where this document departs from Codex"](../what-we-could-build.md#what-codex-agreed-and-disagreed-with). Codex later reviewed the whole design set a second time; the same overview section summarizes that review, and its answer is kept word for word in [CODEX-REVIEW].

| Claim in the inputs | Codex position | How the design resolved it |
|---|---|---|
| "The unmodified binaries are clearly allowed" [FIT] | Narrow: the real binary avoids token interception (taking the login token from the real program to use it in other code), but it does not establish permission for continuous automation | Allowed: interactive use and scripted `codex exec`; continuous `claude -p` is Unclear; the adapter is off by default |
| "The router already has most of the engine core" [FIT] | Disagree: it lacks central task state, effect reconciliation (checking after a crash which side effects really happened), promotion (making a tested learned change the new default) and learning control | Codex's narrower view ([option 1](options.md#option-1-a-deterministic-supervisor-recommended), Cost) |
| "The sandboxed grader is in progress" [FIT] | Disagree: outdated; the router's working log records a completed implementation | Grader treated as committed (`861cb60`) |
| "Enforced containment" [ACAD] | Narrow: worker network and broad host reads stay allowed | ["What it does not cover"](architecture.md#verification-and-what-the-containment-really-covers) |
| "Only grader exit codes count" [FIT] | Narrow: an exit code shows only that the chosen check passed | [Verification rules](architecture.md#verification-and-what-the-containment-really-covers); a pass is "plausible" |
| "Never retain failed experience" ([CODEX] does not name the source) | Disagree: keep observed failures, apart from explanations of their cause | Verification rule; [Tier 0](self-learning.md) records failures |
| "More cautious changes may apply automatically" [FIT] | Narrow: needs limits, because caution costs budget and availability | [Caution budget rule](self-learning.md) |
| The ladder is mandatory and strictly ordered [ACAD] | Disagree: each channel needs its own evidence | [Default order, strict entry conditions](self-learning.md) |
| Abstract insights preferred over raw traces [ACAD summary] | Narrow: keep this explicitly contested | [Marked contested](#memory-helps-in-narrow-cases-and-simple-storage-is-enough-there) |
| Deep Agents grades with an LLM [FIT] | Narrow: keep Deep Agents features apart from `dcode` grading; do not infer that every framework-backed system uses an LLM grader | [Option 4](options.md#option-4-deep-agents-as-the-runtime): `dcode` grades with a model; the library forces no grader |
| "Every serious system protected its evaluator"; "every accessible evaluator was eventually modified" [ACAD] | Disagree: both exceed the supplied coverage | Several documented cases; no rate claimed |
| PACE, a sequential statistical test (see [self-learning.md](self-learning.md#paired-comparisons-aa-noise-and-inconclusive)), as a keep-or-revert gate [ACAD] | Narrow: a candidate method; check assumptions and cost; the hidden set can overfit | ["Sequential tests are candidates"](self-learning.md#paired-comparisons-aa-noise-and-inconclusive) |
| One source ledger [ACAD critic] | Agree, and add: avoid disputed numbers; match model names and benchmark populations to the actual workers | Followed for numbers: the two disputed figures (Auto Mode bypass, prompt approval rate) are not repeated and are listed under "Research quality" in [open-questions.md](open-questions.md). The ledger is not built |
| "Full raw evidence forever" [ACAD needs list] | Disagree: conflicts with secret hygiene | Sanitized evidence with retention limits ([need 13](unrestricted-learning.md#what-it-needs), [Decision 13](../what-we-could-build.md#decisions-for-the-user)) |
| "No credentials in the sandbox" [ACAD implications] (section 2) | Narrow: not literal for a logged-in CLI | Provider login kept apart from other secrets; Jev key never reaches a worker |
| Deep Agents is not adopted [FIT] | Agree, but "blocked" applies only to the required subscription setup | [Option 4](options.md#option-4-deep-agents-as-the-runtime) verdict |
| LangGraph as a workflow layer [FIT] | Agree, especially in Python; checkpoints do not settle ambiguous effects; one crash study does not prove every graph unsafe | [Option 3](options.md#option-3-langgraph-in-python-as-the-workflow-layer) |
| OpenWiki as a tool [FIT] | Agree to keep it optional; borrow versioned claims; a wiki is not authority; test it against source-only work first | [Option 5](options.md#option-5-openwiki-as-the-knowledge-layer) |
| [FIT]'s "Hybrid D" (Deep Agents' patterns rebuilt on the router's parts, plus OpenWiki's ideas), built in Node | Agree with the hybrid direction, not with choosing Node automatically or with "breaks nothing" | Language is your decision; [option 1](options.md#option-1-a-deterministic-supervisor-recommended)'s "What breaks" names the open permission question |
| Jev jobs [FIT] (section 4) | Agree; start with category, ambiguity and failure triage; Jev never decides permissions, locks, quota, test truth, approvals or promotion | ["The first three jobs to build"](jev.md#the-first-three-jobs-to-build); ["Jobs for Jev"](jev.md#jobs-for-jev) |

