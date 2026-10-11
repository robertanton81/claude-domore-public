# The unrestricted-learning track


> Part of the claude-domore design, 2026-09-26. Status: proposal, nothing built. The overview is [what-we-could-build.md](../what-we-could-build.md). The complete unrestricted-learning idea: what it means, why it is a separate design, what it needs, the protected core, the preconditions, a concrete lab design, failure modes, guards from published systems, kill criteria and open problems. It is parked as a research track, not deleted.

You required this section to be complete. It is the full record of the idea.

## What "unrestricted" means

The engine may change anything about itself from its own outcomes: routing, memory, prompts, skills, workflows and its own code, with no fixed list [ACAD]. The closest published systems are Hyperagents, where the improver can edit itself [hyperagents-2026], and Ouroboros, which permits governed edits to its own repository [ouroboros-2026]. Neither is truly unrestricted [ACAD].

## Why a protected core and unrestricted learning are different designs

- Learning needs a measurement of whether a change helped. A learner that can change the measurement can "improve" by changing the measurement.
- In several studies, an agent that could reach its grader or scoring code changed it. In a DGM side experiment, the detection markers sat in editable code [dgm-2025]. AIDE^2's agent patched a crashing scorer, which the paper calls a fix [aide2-2026]. METR's o3 runs are the third case [metr-reward-hacking-2025]. No study measured how often this happens.
- [ACAD] says that every serious system kept its evaluator fixed or protected, and that every reachable grader was eventually changed. Codex says both claims exceed the supplied coverage, because some systems have unknown protections and several relevant papers remain unread [CODEX]. The critic counts eight or more unread 2026 recursive self-improvement preprints [ACAD, critic warnings]. SICA could edit its own oversight, and no hacking is reported for it [ACAD, guards table].
- So measurable learning must keep the evaluator, its data, the budget and the stop switch outside the learner's reach, and that part is restricted by definition. Codex's conclusion: truly unrestricted learning and a protected core are different designs [CODEX].

The lab version is therefore defined as **unrestricted inside the lab, with the measurement and the lab boundary outside it** (*design inference*). Inside its own copy the learner may change everything, including its selection rule. In a first test of 5 runs, an agent that changed its own parent selection (the rule that picks which variant to change next) did better than random selection, but not better than the rule people wrote [hyperagents-2026]. The learner may not change the evaluator, the hidden data, the budget, the stop switch, the lineage log (the record of which earlier variant each variant came from), the lab boundary, the provider adapters or credential access.

**The variant with no fixed limits.** In this variant the learner may also change the evaluator, the hidden data, the budget, the stop switch, the lineage log and the lab boundary. Provider adapters and credential access stay fixed even in this variant. Changing them would let the learner use your login tokens directly, which the providers' rules forbid, and it would expose your logins; that is a limit set by the terms and by security, not by measurement [FIT]. The variant is recorded here but not built, because its gains could not be measured: the learner could change the measurement. A measurement outside the learner's reach could still show gains, but that brings back a protected evaluator, which is the lab version (Codex, 2026-09-30). The nearest allowed form is evaluator changes between epochs by a separate process that you approve [rqgm-2026]. An epoch is one round of the learning loop: propose changes, test them, score them. You accepted this on 2026-09-30 ([Decision 11](../what-we-could-build.md#later), option A; team view: Claude A, Codex A, Jev A at 1.00; private record).

## The decision: a parked research track in a disposable lab

- Kept, not deleted, following [your session decision S2](../what-we-could-build.md#your-decisions-session-2026-09-26). This replaces the "defer" proposal in [R-0925].
- Parked: it opens only when the preconditions below are met and you approve. You confirmed this on 2026-09-30 ([Decision 10](../what-we-could-build.md#later), option B), together with the charter below.
- It runs only in a disposable environment, without automatic promotion [CODEX]. It holds no production credentials, and that includes any provider login [CODEX]. "Credential-free lab" has one precise meaning in this document; see "Credentials" under ["A concrete lab design"](#a-concrete-lab-design) (session 2). A proposal leaves the lab only as untrusted material for your inspection. A separate validation stage outside the lab tests it on the real workers before any adoption (see "Credentials" under ["A concrete lab design"](#a-concrete-lab-design)). The evidence does not justify production use [CODEX].

## The lab charter (Decision 10, decided 2026-09-30)

You chose option B of [Decision 10](../what-we-could-build.md#later): the lab stays parked, and this charter fixes its purpose and its shape now. It builds nothing and uses no plan quota. The items under "Left open until opening" are decided only when the lab opens. Record: in the private working repository. Team view: Claude B, Codex B, Jev B at 1.00. Codex objected to parts of Claude's first charter draft; all of its objections to the charter are applied below.

### 1. The research question

The lab exists to answer one question:

> A learner changes its own harness: the prompts, skills, tools and workflow code around a fixed local model. Do the changes it finds beat the unchanged engine on hidden tasks, when the validation stage re-tests them on the real workers? The comparison uses equal run budgets, stays within the regression limits of the evaluation plan, and is measured separately for each provider.

- A gain inside the lab never answers the question. Only the validation stage can (see the evidence rule under "Credentials" in ["A concrete lab design"](#a-concrete-lab-design)).
- Validation results never feed back into selection. Neither the learner nor the controller's selection step sees them. Otherwise the validation tasks would become one more development set (Codex).
- The evidence rule names both the Claude and the Codex workers. Claude workers stay off until [Decision 6](../what-we-could-build.md#later) allows them. If they are still off at opening, you decide then whether validation on Codex alone is enough, or whether the lab waits. Codex alone would change the evidence rule of [Decision 22](../what-we-could-build.md#before-m1-before-a-later-phase-of-m1), so it needs a new decision.

### 2. What the learner may change

Inside its own variant folder, and nowhere else, the learner may change anything. This includes:
- its prompts, skills and tool descriptions;
- its memory and its routing;
- its workflow code and its harness code;
- its proposal logic and its parent selection (the rule that picks which variant to change next).

Parent selection is not the acceptance rule. Acceptance and promotion stay in the protected core (see ["The protected core"](#the-protected-core)).

Fixed for each experiment: the local model's weights, the model runtime and its launch settings, everything in the protected core, and every path and interface outside the variant folder. The exact lists of allowed and excluded paths and interfaces are written at opening, together with the read allow-list of precondition 10.

### 3. Where each process runs

Fact behind this placement (checked 2026-09-30): Apple `container` VMs have no GPU access for Linux guests. Apple closed the request in apple/containerization issue #46 on 2025-07-01, and release 1.5.0 (2026-09-29) names no GPU support. So a local model with GPU runs natively on the host.

| Process | Where | Holds | Can reach |
|---|---|---|---|
| Lab controller | The host, under its own lab-controller OS account. It is none of the engine's accounts | The stop switch, the budget counters, the lineage database and the lab's own Jev key | The model server, the lab VMs, Jev |
| Model server | The host, under a second, separate OS account, so that it can use the GPU | The local model only. No Jev key, no hidden tests or reference fixes, no lineage data. It sees a hidden task's statement only inside one call from the hidden-task runner | Nothing outside its own folders |
| Learner | Its own `container` VM | Its own variant folder | Only the controller's model-call interface |
| Candidate runner | Its own VM, a new workspace per trial | One candidate and one visible task | Only the controller's model-call interface |
| Hidden-task runner | A separate VM, a new workspace per trial | One candidate and the statement of one hidden task, never its tests or its reference fix | Only the controller's model-call interface |
| Hidden evaluator | A separate process and boundary, apart from the hidden-task runner | The hidden tests | It returns scores only, and only to the controller |
| Validation stage | Outside the lab, in the main engine, under the engine's rules and accounts | The provider login | It never writes into the lab |

- Only the controller can reach the model server. An account name alone does not enforce this. The mechanism, for example a socket that only the controller's account may open (as with the engine's input socket), is chosen and tested at opening (Codex).
- The model server keeps no session state or cache that could carry hidden-task content into a learner's call. How this is enforced is tested at opening (Codex).
- No lab account or VM can reach the main engine's accounts, its data, its logins or your home folder.
- CPU-only option (Codex): the model may instead run inside its own VM on the CPU, if measurements at opening show enough speed. The other model-server rules still apply: only the controller reaches it, and it keeps no session state.

### 4. Disk and memory

- The lab gets its own disk budget. It covers model downloads and caches, VM images, overlapping trial workspaces, exports, logs, and the lineage that is kept for the life of the track (Codex).
- The lab never uses the engine's free-disk reserve of 30 GB ([Decision 23](../what-we-could-build.md#before-m1-before-a-later-phase-of-m1)). A lab job starts only if free space minus the job's bounded temporary storage still leaves the engine's reserve, the storage of any engine attempt that can run at the same time, and the lab's own reserve.
- The memory limits of the native model server, and its termination at a limit or a stop, are proved by a test before opening (see "Limits and the stop switch outside the agent" in ["A concrete lab design"](#a-concrete-lab-design)).
- A MacBook with little free disk could not host the lab. The engine's 30 GB reserve stays free, and the estimated model weights alone take 10 to 40 GB. The lab needs more free disk or another Mac.

### 5. The first run is a trial of the process

- The first run is small: a few epochs (for example 3) and one task family for development. It tests whether the machinery works: the limits, the stop switch, the lineage, the exports and the kill criteria.
- It is not evidence of a gain. Evidence needs the full evaluation plan: unseen task families, the retention and safety suites, and the untouched final set (Codex).
- "Inconclusive, no promotion" is a valid result of any run.

### 6. The opening checklist

Each precondition from ["Preconditions to open the track"](#preconditions-to-open-the-track), and what proves it. The M5 review audits every line that can be proved before opening. Rows 8, 10 and 11 are proved at opening, after M5. The lab opens only when all eleven rows have evidence.

| # | Precondition | Proved by |
|---|---|---|
| 1 | A measured A/A false-win rate | The M3 report |
| 2 | A flat visible-against-held-out gap over several epochs | The learning runs of M4, if they span several epochs and the gap stays below the investigation threshold of the plan. Otherwise the M5 review lists this row as missing, and the lab stays closed (Codex: M3 and M4 do not prove this by themselves) |
| 3 | A stable judge-anchor record | An anchor set with results recorded over time, checked for stability at M5. No milestone produces it yet: the M3 exit test lists no anchor set. It must be added to a milestone before opening |
| 4 | A capability-retention and safety suite | The retention and canary sets of M3, plus a safety suite. No milestone produces the safety suite yet: the M3 exit test lists none. It must be added before opening |
| 5 | A cost model in quota units | The M3 report (cost per verified success in plan percentages) |
| 6 | M1 to M4 passed their exit tests | The exit-test records |
| 7 | Validation use of each provider is allowed | The records of Decisions 6, 8 and 27, and, if validation runs as a continuous loop, your record of the provider's explicit permission. Checked at M5 |
| 8 | You approved the lab limits and the evaluation plan | Your approval at opening |
| 9 | The unread self-improvement preprints were read | A written literature review, checked at M5 |
| 10 | A containment test against a persistent agent (egress, symlinks, child processes), a read allow-list, and read-denied sentinel paths with a record of denied access | A lab-specific test at opening, on the accounts and VMs of section 3 |
| 11 | A separate OS account or VM, with its login and containment checked | The checks of the accounts and VMs in section 3, at opening |

### 7. Left open until opening

- The evaluation plan: the comparison method, the minimum useful effect, the regression tolerance, the hidden-set query budget, the untouched final set and the gap threshold.
- The lab limits: model calls, attempts, wall-clock time, memory and disk.
- The Jev balance of the lab key and the Jev calls per epoch.
- The plan-usage limit of the validation stage.
- The local model and its quantization; GPU on the host or CPU in a VM.
- The host: this MacBook or another Mac.
- Whether both providers must improve, or Codex alone (see section 1; Codex alone needs a new decision).

## What it needs

The critic warns that this list is inference, not tested evidence. Only Ouroboros tested reviewed core evolution, in one preprint, at about USD 110,600, and eight or more 2026 recursive self-improvement preprints remain unread [ACAD, critic warnings].

| # | Need | Why | Evidence |
|---|---|---|---|
| 1 | A verifier the learner cannot edit or see into | Reachable graders were changed in several studies; hacking was more common with visible scoring | [dgm-2025], [aide2-2026], [metr-reward-hacking-2025], [rh-research-agents-2026] (*preprint, days old*) |
| 2 | Hidden held-out checks and out-of-distribution checks (tasks from other task families) | In-distribution gains overstate real gains (14.1 against 4.7). [ACAD] says that the visible-against-held-out gap must stay flat. This design uses a weaker rule: growth of the gap past a stated threshold starts an investigation, because ordinary overfitting can also widen it [CODEX-REVIEW, finding 15] (see "Criteria to stop the lab") | [rrsi-2026], [aide2-2026], [specbench-2026] |
| 3 | Statistical acceptance under noise | A false win becomes the baseline for later rounds; greedy acceptance accepted 30-42% wrong edits | [aide2-2026], [pace-2026], [siren-winners-curse-2026] |
| 4 | Capability-retention and safety suites on every change: fixed tasks re-run to catch lost abilities | Capabilities and safety erode through memory, tools, workflows | [capability-erosion-2026], [misevolution-2025], [anthropic-em-2025] (*vendor*) |
| 5 | Provenance, lineage, rollback | Text scanning caught 11.4% of poisoned skills; lineage exposed DGM's hack (Sakana blog, read through a summary); [ACAD] says deleting a record must delete what was derived from it. This design quarantines instead of deleting (see "Lineage and rollback") | [skilljack-2026], [dgm-2025], [memory-portability-2026] |
| 6 | A protected core | Precedents: DGM's fixed outer loop, Hyperagents' fixed evaluation, Ouroboros' constitution, budget cap and stop command | [dgm-2025], [hyperagents-2026], [ouroboros-2026] (exact list: *design inference*) |
| 7 | Recorded (sanitized) episodes never rewritten; consolidation only through a gate | Rewriting memory makes it worse | [faulty-consolidation-2026], [dreambench-swe-2026] |
| 8 | Enforced containment | Persistent agents evade monitors; Ouroboros put artifacts on the operator's real Desktop because it relied on path conventions; only egress and filesystem limits stopped exfiltration | [evasionbench-2026], [ouroboros-2026], [anthropic-containment-2026] (*vendor*) |
| 9 | Evaluator changes only between epochs, by a separate process | A fixed reward stops working as the policy improves, so the verifier must improve too, but not within a run | [rqgm-2026], [verification-horizon-2026] (human gate: *design inference*) |
| 10 | Drift detection | Judges and served models change silently | [who-drifted-2026], [dynamic-skills-survey-2026], [silent-updates-2026] |
| 11 | Human blocking review of engine-code changes | Ouroboros' diff review blocked 63.5% of recent proposals | [ouroboros-2026] |
| 12 | A budget | About USD 7,000 (SICA), 22,000 (DGM), 110,600 over 161 days (Ouroboros); plan-quota mapping unknown | [sica-2025], [dgm-2025], [ouroboros-2026] |
| 13 | Sanitized evidence, with limits on how long it is kept | "Full raw evidence forever" conflicts with secret hygiene; record omissions | [CODEX] |
| 14 | Candidate execution apart from the controller | Candidate code stays untrusted even under a trusted grader | [CODEX] |
| 15 | Policy clearance for continuous loops | [FIT] checked the terms: permission for continuous unattended Claude use is unclear, and OpenAI calls ChatGPT-login CI an advanced path for trusted private runners. How unattended loops use plan limits is unmeasured | [FIT], [ACAD] |

## The protected core

The learner never changes these in the run that evaluates it (merged from [ACAD] item 6 and [CODEX]):
- task authorization;
- permission enforcement and the sandbox profile;
- state ownership and fencing tokens;
- effect execution;
- approval binding;
- budgets and the budget cap;
- stop controls;
- evidence integrity and the lineage log;
- the evaluator, its data, held-out sets and anchor sets;
- the acceptance and promotion rules;
- provider adapters: how `claude` and `codex` are started, environment cleaning, command flags and login checks (this document's addition);
- credential access (this document's addition);
- a ban on training or fine-tuning any model on provider or Jev outputs. OpenAI's terms forbid programmatic extraction of Output, and TypeSafe's contract, section 2.3(b), forbids training a copy of Jev on its answers [FIT]. The scope of the ban is *design inference*.

The learner may propose core changes as a separate, human-governed project, but it cannot change the rules that evaluate its current candidate [CODEX].

## Preconditions to open the track

From [ACAD]:
1. A measured A/A false-win rate.
2. A flat visible-against-held-out gap over several epochs.
3. A stable judge-anchor record.
4. A capability-retention and safety suite.
5. A cost model in quota units.

This design reads precondition 2 through the evaluation plan (see "Acceptance rule" below): "flat" means that the gap stayed below the plan's investigation threshold. It does not mean that the gap never grew [CODEX-REVIEW, finding 15].

Added here (*design inference*):

6. [M1 to M4](milestone-1.md#what-comes-after) passed their exit tests.
7. For each provider whose workers the validation stage uses, that use is allowed: Codex runs follow [Decisions 8 and 27](../what-we-could-build.md#decisions-for-the-user), and `claude -p` follows [Decision 6](../what-we-could-build.md#decisions-for-the-user). If validation runs as a continuous loop, the provider's terms, documentation or support explicitly allow continuous personal automation on your plan, and you keep a record of that answer. The lab itself never holds a provider login and uses a local model only.
8. You approved the lab limits and the evaluation plan: model calls, attempts and wall-clock time per epoch; memory and disk limits for local model runs (session 2); the prepaid Jev balance for the lab key, under the conditions and checks in "Jev in the lab" below, and the number of Jev calls per epoch (session 2); the estimated plan-usage limit of the validation stage; and the evaluation plan under "Acceptance rule" below.
9. Someone has read the unread recursive self-improvement preprints listed in [ACAD].
10. A test has checked the containment layer against a persistent agent on this platform: egress, symlinks and child processes. The lab has a read allow-list, an egress limit, and read-denied sentinel paths with a record of denied access.
11. A separate OS account or VM exists, and its login and containment behavior are checked [CODEX].

## A concrete lab design

All *design inference*, built from the needs above.

- **Separate environment.** A separate OS account or VM is required (precondition 11). A separate folder tree under your own account is not enough. With broad host reads and open network, a learner there could read and send out your Codex and Claude login files, your git, `gh` and SSH credentials, the main engine's database and your real repositories. The lab account holds no git, `gh` or SSH credentials and cannot reach the main engine's data. A script can rebuild it at any time.
- **Credentials.** The lab holds no production credentials: no provider login, no git push token, no GitHub access, and no access to the main engine's database or real repositories. Your subscription login counts as a production credential. So the lab model is a free, weaker local model, for example an isolated Deep Agents instance on Ollama (untested [FIT]). This follows Codex's proposal of a lab without credentials [CODEX]. An earlier version of this design allowed one provider login in the lab after precondition 7. The second Codex review pointed out that re-testing does not need the login inside the lab, so that exception is withdrawn [CODEX-REVIEW, finding 14].
  - **"Credential-free lab", defined** (session 2). The phrase means exactly two things. First, the learner and candidate processes hold no credentials of any kind. Second, no subscription (provider) login enters the lab. The lab controller holds exactly one credential: its own separate Jev key, outside the learner's boundary. The controller never holds a provider login either (see "Jev in the lab" and the process table below). Every other use of "credential-free" in this document means this.
  - **Decision 22, local models** (session 2, owner decision of 2026-09-27). A free local model, for example through Ollama, is eligible for this parked lab track only. This is not permission to open the lab. All preconditions above and your separate decision to open the track stay in force. Local models are not approved for the main engine. They are reconsidered there only through a separate decision.
  - **Decision 22, payment** (session 2). "Subscriptions only" applies to claude-domore. Model work runs only on your Claude Max and ChatGPT plans, and no pay-per-use model API is used. The free local model in the lab costs nothing, so it does not break this rule. The lab gets no capped pay-per-use API for evaluation; that option was rejected. TypeSafe Jev stays the one paid classifier API. This does not approve spending the bought Codex credits, which [Decision 8](../what-we-could-build.md#decisions-for-the-user) still decides. It also does not settle provider permission, which Decisions 6 and 27 still decide (see precondition 7).
  - **Limits on local runs** (session 2). A local model is free, but its runs still have limits. The controller limits model calls, wall-clock time, memory and disk for every local model job (see "Limits and the stop switch outside the agent").
- **Export, validation and adoption are separate stages.** Findings from a local model are not evidence for the Claude or Codex workers, because memory transfer across model families was weaker [memory-transfer-coding-2026] [ACAD]. So each proposal passes three stages (*design inference*):
  1. **Export.** A proposal leaves the lab only as untrusted material for your inspection: its diff, its lineage record and its lab evidence. Leaving the lab does not run it anywhere.
  2. **Validation.** A separate, controlled stage outside the lab tests the proposal on the real Claude and Codex workers. It runs under the main engine's containment, grader, budget and approval rules, and it holds the provider login that the lab never holds. It gives the lab no write access and no scores per task.
  3. **Adoption.** Only a proposal that passed validation enters the main engine's ladder, at its own tier and with that tier's gates (see "No automatic promotion" below).

  The uncertainty across model families therefore needs validation before adoption, not credentials inside the lab [CODEX-REVIEW, finding 14]. [Decision 29](../what-we-could-build.md#decisions-for-the-user) asked you to confirm this. Decision 22 answers it in effect: the lab never holds a provider login (session 2).

  **Evidence rule** (session 2, Decision 22). A gain on a weaker local model is never evidence by itself. Every lab proposal must beat the unchanged baseline on the real Claude and Codex workers. This happens in the validation stage, on held-out tasks, and within the approved regression limits (the regression tolerance in the evaluation plan). Lab scores alone never authorize adoption.
- **No provider launch inside the lab.** The lab starts no `claude` or `codex` binary. Model launch, environment cleaning and command flags for the local model sit in the controller and the protected core. The learner's variant never starts a model itself, so it cannot change how models are started. Provider launch for validation belongs to the main engine's adapters, outside the lab. Code that the learner wrote never receives a login token, which would be a forbidden use [FIT].
- **Tasks.** Sandboxed copies of real past failures, split into a visible development set, a hidden held-out set, and a hidden out-of-distribution set from task families not used in development. The learner, the candidate runner and the hidden-task runner must not be able to read the reference fixes or the history of the source repositories (see "Verification" in [architecture.md](architecture.md#verification-and-what-the-containment-really-covers)).
- **Processes:**

| Process | Can write | Can read | Role |
|---|---|---|---|
| Lab controller (outside the learner's boundary) | Lineage database, budget counters, stop state | The whole lab | Starts epochs, enforces the limits, holds the stop switch, starts the local model and every candidate job, calls Jev with the lab key; holds no provider login |
| Learner | Only its own variant folder | Its variant, the visible set, its own past results (enforced by the read allow-list) | Proposes changes to its own copy; never holds the Jev key or a provider login |
| Candidate runner | A disposable workspace per trial | The candidate and one visible task | Runs candidates on development tasks |
| Hidden-task runner (separate process and boundary) | A disposable workspace per trial | The candidate and the statement of one hidden task, never its tests or reference fix | Runs candidates on hidden tasks; the evaluator then grades each workspace snapshot |
| Hidden evaluator (separate process and boundary) | Its own temporary folder | Candidate snapshot, hidden sets | Returns scores only, never tests, and only to the controller |
| Validation stage (outside the lab, part of the main engine) | A disposable workspace per trial, under the main engine | The exported proposal and the validation tasks | Tests a proposal on the real Claude and Codex workers with the provider login, under the main engine's rules; never writes into the lab |

- **Model calls.** The controller owns one model-call interface. The learner and the candidates reach a model, including the local Ollama endpoint, only through it. The egress limit allows only the controller's interface, and the controller counts every call against the budget.
- **Hidden scores stay with the controller.** The learner sees at most one summary per epoch, never scores per task. The controller refreshes the hidden sets on a schedule. The reason: repeated selection against the same hidden set can overfit it [CODEX] (see "Paired comparisons" in [self-learning.md](self-learning.md#paired-comparisons-aa-noise-and-inconclusive)). A refresh alone does not control this, so every hidden-set query also counts against the evaluation budget below [CODEX-REVIEW, finding 15].
- **Acceptance rule** [CODEX-REVIEW, finding 15]. "A gain beyond the measured A/A noise" is not a complete statistical rule. So before the lab opens, you approve an evaluation plan (precondition 8). The plan is part of the protected core, and it fixes (*design inference*):
  - the comparison method: a paired comparison of the candidate against its parent on the hidden set, with error ranges clustered per task family and a stated interval method (see ["Paired comparisons"](self-learning.md#paired-comparisons-aa-noise-and-inconclusive));
  - the minimum useful effect and the regression tolerance;
  - the evaluation budget: how many hidden-set queries are allowed per epoch and over the whole track, and how the threshold accounts for the number of candidates compared, because the best of many candidates looks better than it is [siren-winners-curse-2026];
  - an untouched final set: a hidden set that no selection step ever sees. It only confirms a proposal just before export, and its results never feed back into selection. After the number of uses that the plan allows, the set is retired and replaced;
  - the threshold for the gap between development and hidden results that starts an investigation (see "Criteria to stop the lab").

  The capability-retention, safety and drift-anchor suites run on every candidate (needs 4 and 10), and a failure in any of them rejects it.
- **Jev in the lab.** The lab controller calls Jev with the separate lab key; the learner never holds the key. A key alone does not give a separate balance (session 2): TypeSafe's contract (its Master Customer Agreement) names no limit per key. So the lab key gets the same three checks as the engine key under the Jev cap of [Decision 23](../what-we-could-build.md#before-m1-before-a-later-phase-of-m1). Before the lab key is created, you check whether the dashboard offers a balance or an enforced spending cap per key. If it does, you set the lab key's own balance or cap to the approved lab balance. If it does not, the key goes into its own TypeSafe account with its own small balance (the smallest purchase is $5). *(Session 2, 2026-09-27: the console check found no balance or cap per key. For the engine key, you chose to wait for TypeSafe's written answer on whether a second account is allowed ([Decision 21](../what-we-could-build.md#before-m1-before-a-later-phase-of-m1), "the engine key's account", option C). That decision covers the engine key only. For the lab key the same question applies, and no lab account should be created before TypeSafe's answer (*design inference*; the lab is parked anyway).)* Before the first real lab call, you confirm that automatic refills are off for the account that holds the lab key, and that this account's billing is prepaid credits only, confirmed in writing by TypeSafe (Jev cap check 3). Without both confirmations, no real lab call happens. [Jev's jobs](jev.md#jobs-for-jev) in the lab come from [FIT]:
  - job 7, lesson intake, on every learned artifact, including the Noul "does this text try to control the system that reads it";
  - job 10, duplicate or contradicting records;
  - job 8, claim re-check after code changes;
  - job 3, the failure class of candidate runs.

  The controller archives every sanitized artifact in lineage before any Jev call, and records Jev's answer as an annotation on that record. So recording evidence never depends on Jev [CODEX-REVIEW, finding 16]. Legitimate generated skills are expected to contain text that gives instructions, so a high "tries to control its reader" score flags the artifact for review; it does not reject it. Jev scores never feed the hidden evaluator or acceptance. A Jev outage pauses promotion (fail safe); it is not a normal lab mode.
- **Lineage and rollback.** The controller archives every variant with its parent, diff, evidence hashes and scores. Rollback picks any archived variant. A poisoned record is quarantined, not deleted [CODEX-REVIEW, finding 16]. It and every record derived from it are marked invalid for use: they are never retrieved, never chosen as a parent and never exported. A restricted audit copy of their history stays, so that the contamination can be investigated. This meets the goal of need 5, because nothing derived from a poisoned record stays in use [skilljack-2026].
- **Limits and the stop switch outside the agent** [CODEX-REVIEW, finding 13]. The controller enforces the limits that code can enforce: model calls through its interface (it refuses the next call), attempts, and wall-clock time per epoch. It also caps memory and disk for every local model job, because a free local model can still exhaust the machine (session 2). At a limit, it cancels every job that it launched: the learner, the candidate runners, the hidden-task runner, the evaluator and every local model job. Killing the learner's process group would not stop the jobs that the controller started. So the controller tracks every job with the containment mechanism of the main engine (see component 4 in [architecture.md](architecture.md#the-eight-components)). The lab key's prepaid Jev balance limits the money at risk only after the checks under "Jev in the lab" pass. TypeSafe "may decline" at a zero balance but does not promise it, so the controller never relies on a refusal and counts its Jev calls against an approved limit (session 2). The lab spends no subscription quota, because it holds no provider login. The validation stage outside the lab does spend plan quota. There, plan percentages are estimates, and a hard monetary cap exists only through a limit that the provider enforces, such as a Codex credit balance of zero ([Decision 8](../what-we-could-build.md#decisions-for-the-user)). A stop file that only you and the controller can write ends the run. The learner's write boundary or the separate OS account enforces this, and a drill tests the stop switch before each session.
- **Evaluator changes** only between epochs, by a separate process you approve [rqgm-2026].
- **No automatic promotion.** An artifact leaves the lab only as a human-reviewed proposal. It enters the main engine's ladder, at its own tier and with that tier's gates, only after it passed the validation stage. Human review is a promotion gate, not a safety boundary: text scanning caught only 11.4% of poisoned skills [skilljack-2026]. A reviewed artifact still runs only inside the enforced boundary and must pass its tier's executable gates. The false-approval rate is measured by planting known-bad artifacts in the review queue.

## Known failure modes

From [ACAD]:
- Cheating the checker (objective hacking): DGM node 114, in a side experiment; an Ouroboros trial that faked the end state [dgm-2025], [ouroboros-2026].
- Context collapse: one full rewrite shrank the memory from 18,282 to 122 tokens; consolidation decay [ace-2025], [faulty-consolidation-2026].
- Overfitting to the evolve set, and leakage of test patches and fix commits [rrsi-2026], [dgm-2025], [ouroboros-2026].
- Safety decay: refusal fell from 99.4% to 54.4% [misevolution-2025].
- Poisoning through experience that looks correct [poisoned-evolution-2026], [skilljack-2026].
- Stale lessons, lessons from the wrong domain, and lessons written after the failure [ouroboros-2026].
- False wins that add up over rounds, and high scores that do not predict good descendants (variants built from them) [aide2-2026], [hgm-2025].
- Learning to convince reviewers instead of being correct [zhou-2026].
- Monitor evasion [evasionbench-2026].
- Evasion of review over feedback rounds: it rose from 7 to 56 of 150 pairs, but the agents had been told to evade [rh-research-agents-2026] (*preprint, days old*). This matters for the lab's human review gate.

## Guards used by published systems

Condensed from [ACAD].

| System | Could change | Kept fixed or protected | Guards | Hacking seen |
|---|---|---|---|---|
| DGM [dgm-2025] | Its agent code | Archive, parent selection | Sandbox, time limits, lineage archive, hidden scoring in the reported run | Yes (node 114, side experiment) |
| SICA [sica-2025] | Its code, including tools and oversight | Not stated | Overseer that can cancel a run, inside the self-improvement scope | Not reported |
| HGM [hgm-2025] | Its agent code | Not stated | No safety or sandbox section found | Not reported |
| Hyperagents [hyperagents-2026] | Task agent and meta agent | Parent selection, evaluation (main runs) | Sandboxes, timeouts, restricted internet | Discussed as a risk |
| AIDE^2 [aide2-2026] | Its code | Not stated | Accept only if best on hidden evaluations | Patched a crashing scorer (called a fix) |
| Ouroboros [ouroboros-2026] | Code, prompts, identity, public surface | Constitution core, governance files | Owner-set modes, external budget cap, stop command, blocking diff review | Yes (faked end state) |
| RRSI [rrsi-2026] | Harness | Evaluation splits | Anti-hard-coding critic, pruner, cap on bundled edits, out-of-distribution check | Hard-coding screened out |
| AHE [ahe-2026] | Harness components | Benchmark | Stated prediction per edit, next-round verification, file-level revert | Not reported |

## Criteria to stop the lab (kill criteria)

*Design inference*, extending the stop criteria in [CODEX].

Stop a run at once if:
- the learner read or changed the evaluator, hidden data or evidence (a read is detectable only through read-denied paths; see precondition 10);
- the learner read or wrote a sentinel file: a decoy file placed outside the lab boundary, so that any access to it proves the boundary failed;
- a secret was exposed;
- the stop switch or a limit failed, or workers could not be terminated;
- a lab artifact reached the main engine without review.

Pause promotions and investigate the cause if:
- the gap between development and hidden results grows past the threshold in the evaluation plan. Ordinary overfitting can widen the gap without making every gain false, so growth alone is a trigger, not proof [CODEX-REVIEW, finding 15].

Close the track, pending your review, if:
- no held-out gain meets the evaluation plan within its budget after the number of epochs you set;
- an investigation finds that the gains do not hold on the untouched final set;
- the estimated plan usage of the validation stage exceeds your limit two epochs in a row;
- a provider's terms come to forbid the validation runs.

## Open problems

From [ACAD] unless marked:
- No source shows a safe design in which a loop edits its own evaluator in the same run [aide2-2026], [rqgm-2026].
- No study tested an agent that changes its own orchestration code under these controls.
- Statistical gates control false wins only on what the development set covers [pace-2026].
- Reward hacking in loops that change only prompts, skills or routing is unmeasured [anthropic-em-2025].
- Enough independent support to admit a lesson may be exactly what a poisoner supplies [poisoned-evolution-2026].
- Safe online routing while the engine shifts its own task mix is untested [wiserouter-2026].
- What `sandbox-exec` enforces against a persistent agent is unchecked.
- Plan-unit cost and permission for continuous loops are unknown [FIT].

