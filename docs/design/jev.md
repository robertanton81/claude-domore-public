# TypeSafe Jev in claude-domore


> Part of the claude-domore design, 2026-09-26. Status: proposal, nothing built. The overview is [what-we-could-build.md](../what-we-could-build.md). How TypeSafe Jev is used in every option: the jobs, what Jev must never decide, what each Jev answer or failure does, the rules for every call, and calibration against matching labels.

## Jev is in every option

| Option | Where Jev runs |
|---|---|
| 1 Supervisor | The supervisor's own HTTP client: a Python port of the router's wrapper, or the router's wrapper under Node. The key never enters the bridge process or a worker |
| 2 Interactive session | A `PreToolUse` hook, changed to fail safe |
| 3 LangGraph | Graph nodes, plain HTTP |
| 4 Deep Agents | Your own code; the middleware misses subagents |
| 5 OpenWiki | Around the tool |
| Unrestricted lab | The lab controller, with a separate key (see "Jev in the lab" in [unrestricted-learning.md](unrestricted-learning.md#a-concrete-lab-design)) |

Jev (`jev-1.13.0`) is a "System One" decision model from TypeSafe: TypeSafe's name for a model that gives fast typed judgements and probabilities instead of writing text or code. It answers typed questions about a state (text or JSON) [FIT].
- **Choice** picks one of up to 255 options, with probabilities and a confidence.
- **Noul** gives the probability that a yes/no statement is true, with no confidence field.
- **Score** places the state on 2 to 10 ordered levels.
- One request holds up to 32 questions, within 64k tokens (32k for the state plus the longest question).
- Price: $0.042 per million input tokens; output is free [FIT].
- From a test run, a call took 256 to 1154 ms on a small sample of 8 briefs, an easy test [R-DEC], [FIT].

## Jobs for Jev

Jobs from [FIT]. The last column is a rule: what code, the grader or a human keeps.

| # | Job | Call type | Evidence Jev gets | Jev must never decide |
|---|---|---|---|---|
| 1 | Task triage, route suggestion | Choice `kind`; Nouls `writes_files`, `self_contained`, `needs_every_match`; Score `difficulty` | Brief, secrets removed | Sandbox mode, write permission, lock, budget, unattended eligibility |
| 2 | Reading a worker's claim | Choice: passed / failed / not_run / unclear | "Verification:" text, at most 2,000 characters | Success; only grader evidence counts |
| 3 | Failure class and next move | Choice class (test failure, environment, flaky, unclear spec, usage limit); Score severity; Choice next move | Grader excerpt (redacted), attempt summary, routes code allows | Provider room, spending cap, excluded routes; whether a pause ends by itself after a reset (`provider_limit` needs provider evidence) |
| 4 | Stop or continue | Choice continue / stop_done / stop_blocked / stop_no_progress / stop_needs_human; Noul "progress made" | Last two attempt summaries, grader result | Counts of attempts, tokens, minutes; "done"; a "continue" never overrides a limit |
| 5 | Needs a human | Nouls: missing decision; needs a secret or console step; irreversible action; rule conflict. Low thresholds | Brief plus relevant rules | A "no" is never permission |
| 6 | Memory retrieval | Code shortlists; Noul or Score per record; second request re-checks the top few | Brief plus short records | Truth, currency, safety; provenance and expiry stay in code |
| 7 | Lesson intake | Choice fact / guess / instruction / other; Noul "tries to control its reader" | Lesson text and source run | Promotion into prompts, skills or policy; it is also not the only defense against injected instructions |
| 8 | Claim re-check after code changes | Choice supports / contradicts / says nothing | Claim plus the cited source section | Deleting or rewriting; code archives and keeps history |
| 9 | Skill or workflow choice | Choice ranks candidates; Noul "needs a skill at all" | Brief plus skill frontmatter | Loading a skill code has not allowed |
| 10 | Duplicate or superseded records | Nouls "same rule", "contradicts" | Two record texts | Automatic deletion |
| 11 | Signal where no executable check exists | One Score per rubric dimension, combined in code | Excerpt (redacted) plus rubric | Pass or fail |

Codex adds that Jev must never decide by itself permissions, lock ownership, remaining quota, the truth of a test pass, approval validity or promotion [CODEX].

## The first three jobs to build

Codex recommends task category, ambiguity signals and failure triage first [CODEX]:
1. **Job 1, triage.** Reuse the router's questions. The category feeds the baseline routing table, which chooses only among routes code allows.
2. **Job 5 plus `self_contained`, ambiguity.** A low threshold sends a task to `needs_clarification`. A missing signal never moves a task forward; the inbox shows "ambiguity not checked".
3. **Job 3, failure triage.** It suggests the next move after a failed check. Code still enforces the retry cap. A "usage limit" or "environment" class pauses the task instead of spending a retry. Only provider evidence, such as Codex's own usage-limit event, sets the reason `provider_limit`, which ends by itself after a reset. A Jev "usage limit" class without that evidence stores `environment`, which only you can clear, so the retry cap still holds ([added test 22b](milestone-1.md#tests-this-document-adds)). When Jev is down, the decision table below applies.

Job 2 already exists in the router's log hook [R-README]; claude-domore keeps it as a logged signal with no authority.

## Decision table: Jev answers and failures

An earlier version of this design said that a Jev failure leads to "the most cautious path". That phrase had no defined order across routes, cost, reservations and states. It also conflicted with the retry rule of job 3 [CODEX-REVIEW, finding 8]. This table replaces it. It fixes, for each of the first three jobs and each kind of Jev answer, what happens (*design inference*).

**Permissions never depend on Jev.** In every row, the sandbox mode, the allowed paths, the write set, the claim and its fencing token, and the budget limits are exactly the same as with no Jev answer. This is permission invariance, and [acceptance test 8](milestone-1.md#the-12-acceptance-tests) checks it. Route selection, retry and cost are separate questions, and the table answers them.

The kinds of answer:
- **Unavailable:** a timeout, HTTP 429 or 529 after the bounded retries, another server error, or a refusal because of a zero prepaid balance. *Added in session 2 ([Decision 14](../what-we-could-build.md#before-m1-before-a-later-phase-of-m1) and the Jev cap of [Decision 23](../what-we-could-build.md#before-m1-before-a-later-phase-of-m1)):* three more cases.
  - Any response other than success, 429 or 529. It gets no retry. TypeSafe documents no code for an empty balance, so a refusal at an empty balance falls under this case.
  - A counter limit of the Jev cap. No HTTP request is made.
  - A send that the supervisor blocks itself: the repository is not on the allow-list, the secret scan found something, or the sanitizer failed. No HTTP request is made.
- **Malformed:** the response does not match the expected schema. The whole response is discarded.
- **Extra fields:** the response is valid but carries fields outside the schema, such as an injected "approved" field. Code reads only the schema fields, so the extra fields have no effect, and the call is logged as suspicious.
- **Valid, including extreme probabilities:** a valid answer, even with a probability of 0 or 1. It is used like any other valid answer, inside the limits that code enforces.

| Job | Unavailable or malformed | Valid answer (also extreme, or with extra fields) | Budget effect |
|---|---|---|---|
| 1, triage | The default route: in M1b the one fixed route, later the baseline route for tasks with no category. The inbox shows "triage not run". The task state is unchanged | The routing table picks among the routes that code allows. An extreme probability can select another allowed route. It never adds a route | The reservation of the route that was chosen. Jev cannot raise the budget limits |
| 5 plus `self_contained`, ambiguity | The task does not move forward on its own: it stays `proposed`, and the inbox shows "ambiguity not checked". Moving to `ready` still needs your approval | Above the low threshold: `needs_clarification`. Below it: the task waits for your approval, as always | None before launch |
| 3, failure triage | A rule in code decides by the grader status alone. `failed`: `retryable`, then a retry on the default route within the launch limit, and the inbox shows "failure not triaged". `error` or provider evidence of a usage limit: `blocked` with its reason, as in the state table | The suggested next move is used only among the routes that code still allows and within the launch limit. A "usage limit" or "environment" class pauses the task: `provider_limit` needs provider evidence, and otherwise the reason is `environment` | A retry uses the fixed allowance of one attempt, and it counts toward the launch limit |

Every Jev failure is visible in the inbox or in the log. No row lets Jev move a task past a human approval, raise the launch limit or reach a permission.

## Rules for every call

- **Pin the version.** Use `jev-1.13.0`, not `jev-latest`, and log the `model` field of each response [FIT]. The router still defaults to `jev-latest` [R-README].
- **Fail safe, not fail open.** The router runs a call as written when Jev fails [R-DEC]. An unattended engine takes the fallback that the [decision table](#decision-table-jev-answers-and-failures) fixes for each job instead: the default route, no step past a human approval, and a visible inbox or log entry. Retry with backoff, a bounded number of times, on HTTP 429 (too many requests) and 529 (overloaded). Any other response that is not a success counts as "Jev is down", without a retry (session 2, Jev cap). A refusal at a zero prepaid balance falls under this rule: TypeSafe's API page documents only the codes 401, 422, 429 and 529, and no code for an empty balance (checked 2026-09-27). Credits expire after 12 months, and there is no SLA (service-level agreement, a written promise of uptime) [FIT].
- **Minimal data.** Send only the fields each question needs. Diffs, whole files and raw worker output are never sent (session 2, Decision 14 below). Every outgoing text field is sanitized and scanned for secrets; redaction is a best effort, not a guarantee. TypeSafe does not train weights on your data without consent, but may produce and freely use "Telemetry" from it. Retention is "as long as necessary", and zero retention is enterprise-only [FIT] (*vendor terms*).
- **Opt-in per repository.** Only repositories on an allow-list, empty by default, may send data. This is stricter than the router, which has one global switch, off by default [R-DEC].
  - **Decided (session 2, 2026-09-27; [Decision 14](../what-we-could-build.md#before-m1-before-a-later-phase-of-m1), option A as amended by Codex).** The allow-list is in the supervisor's own state. For M1b it holds only the fixture repository, added before the first real Jev call. Adding a repository is a high-impact action under [Decision 26c](../what-we-could-build.md#before-m1-before-a-later-phase-of-m1): a touch plus the PIN. The fixture repository is added the same way. The approval screen says that summaries and excerpts can reveal confidential content even when no secret is recognized. The planning session may only propose an entry, as a draft. A removal is a request from your daily account through the input socket (see ["OS accounts"](architecture.md#os-accounts)) and takes effect at once. It cannot delete what TypeSafe already holds.
  - **Every text field is scanned.** Before any send, every outgoing text field passes the sanitizer of [Decision 13](../what-we-could-build.md#before-m1-before-any-code) and a secret scan: the brief, the rules, the attempt summaries, the grader excerpts and the worker's verification text. A field name alone does not stop a worker from copying code or a secret into its summary or its claim (Codex, in the consult record). A scan hit or a sanitizer failure means that no HTTP request is made. The row "unavailable" of the decision table applies, and the event is logged.
  - **Limits per field.** Each job sends only the fields that the job table names. Each field gets a character limit when the job is built; M1b sets the limits for jobs 1 to 5. Today only job 2's limit (2,000 characters) is written down. Diffs, whole files and raw worker output are never sent. In M1's jobs, excerpts come only from grader output. Jobs 6 to 11 name other evidence, for example job 8's cited source section and job 11's excerpt where no grader exists. Before such a job sends text from a repository, its data rule is checked against Decision 14 and decided.
  - **Checked at the send.** The supervisor checks the allow-list again right before every send and every retry.
  - **Record.** Each call's evidence records the field names, their sizes and a hash of what was sent.
  - **Attempt summary.** Jobs 3 and 4 receive an "attempt summary", which this design does not define yet. M1b defines who writes it. Until then it counts as untrusted worker text.
  - **Tests.** A dummy secret planted in each field separately; a sanitizer failure; a removal from the list between two retries. Each case must produce no HTTP request. These tests reduce the risk. They cannot prove that all confidential content is detected.
- **Key storage.** *(Session 2: [Decision 21](../what-we-could-build.md#decisions-for-the-user) chose option A as amended by Codex.)* The supervisor runs under its own OS account, the supervisor account (see ["OS accounts"](architecture.md#os-accounts)). No worker runs as that account.
  - **A separate engine key (session 2).** The engine has its own Jev key. It is never the router's key. It is never the consult key that you keep in your daily account's Keychain for Claude's consults (you confirmed that the consult key in your Keychain is the same key as the router's key; it shares the organization's balance with the router). It is never the lab controller's key.
  - **A file, not a Keychain (session 2).** The key is a file with mode 0600. The file sits in a mode-700 subfolder of the supervisor's data folder, for example `secrets/`. The supervisor account owns the file and the subfolder. No ACL entry (an extra access rule) grants access to anyone else. The supervisor reads the file at start.
  - **Installation (session 2).** The admin account installs the key in its own login session. It uses trusted code from the root-owned runtime folder and a prompt that does not echo the input. The key never appears on a command line, in a log, in shell history or in chat.
  - **Backups (session 2).** Only the secret subfolder is excluded from Time Machine, with `tmutil addexclusion`. The whole data folder is never excluded. It also holds the source archive and the hidden tests, which [Decision 13](../what-we-could-build.md#before-m1-before-any-code) keeps for the life of the project. If a backup ever holds the key, that backup needs restricted, encrypted access and a tested way to revoke the key.
  - **Spending (session 2).** A separate key is not a separate balance. The key needs a spending limit that TypeSafe enforces. TypeSafe's public documentation says nothing about per-key limits or balances (checked 2026-09-27), and its Master Customer Agreement names no limit per key either (section 2.4; see "Checked after the decision" below). So you check the TypeSafe dashboard before you create the key ([open-questions.md](open-questions.md)). If the dashboard offers no balance or enforced spending cap per key, the engine key is created in a separate TypeSafe account with its own $5 balance. *Result (2026-09-27): no cap per key; the key waits for TypeSafe's written answer (Decision 21, "the engine key's account", option C; see "Status after the console check" below).* The supervisor's own counter (the Jev cap of Decisions 8 and 23) limits the engine's use. It cannot limit use of a stolen key somewhere else.
  - **The Jev cap (session 2, 2026-09-27; [Decision 23](../what-we-could-build.md#before-m1-before-a-later-phase-of-m1), option A as amended by Codex).** Two layers. The provider side is the hard limit: the smallest prepaid balance that TypeSafe allows, at most $10, with automatic top-up off. Before the first real call, you confirm in the dashboard that automatic top-up is off and that the key or account cannot spend more than its balance. If you cannot confirm it, or the smallest purchase is above $10, no real Jev call happens and the question comes back to you. (For the result, $5, and the checks in their order, see the next item. Check 1 found no balance or cap per key, and check 2 is confirmed for the current organization (2026-09-27). Check 3 cannot be confirmed in the dashboard and needs TypeSafe's written answer.) The supervisor side is enforced in code: at most 12 requests per task and 200 per local calendar day; each request at most 48,000 characters, its state at most 32,000. These are starting limits, not measured needs. Each counter is written to the database before the send, so retries and lost answers count. At a limit the call is not sent and the row "unavailable" applies. The inbox gets one entry for the limit, in addition to the row's own inbox text. The tests are listed under M1b in [milestone-1.md](milestone-1.md#scope). Each call logs the input tokens from the response's `usage` field.
  - **Checked after the decision (2026-09-27).** You checked the purchase options in the dashboard: the smallest purchase is $5. So you bought $5 on 2026-09-27, about 119 million input tokens. Taxes may be added (section 8.4). Promotional credits (today a free monthly credit; see the status below) are added to the $5 and are used first. Check 1 later found no balance or cap per key (console check, 2026-09-27; see the status below). Once checks 2 and 3 below pass, the money at risk is the purchased credit of the account or organization that finally holds the engine key, $5 plus tax.
    - TypeSafe's [Master Customer Agreement](https://typesafe.ai/legal/mca) (read 2026-09-27; the page says "Last updated Sep 23, 2026"), section 8.2(a): automatic refills (the automatic top-up above) happen only if you turn them on. With them, TypeSafe adds the chosen refill amount when the balance reaches zero or falls below a threshold. Without them, TypeSafe "may decline to generate Output" once the credits are used up. "May decline" is not a promise to refuse. So the supervisor never relies on a refusal at a zero balance. Its own counters stay the limit on calls.
    - The agreement's body describes no charge for use beyond the bought credits. But the fees are whatever the Order (the agreement's word for the purchase terms of your account) says (section 8.1). Section 8.2(a) applies only "Unless otherwise set forth in the Order", and the Order wins in a conflict (section 16.14). So the check "cannot spend more than its balance" stays open as check 3.
    - Section 2.4 mentions API keys only as access credentials. The agreement names no limit per key, and the dashboard offers none either (console check, 2026-09-27).
    - Section 8.2(b) forbids an extra account made to receive more promotional credits or to avoid a restriction or obligation of the agreement. A separate account that only keeps the engine's spending apart does not seem to serve either purpose (Claude's reading, not legal advice). The console check later found a free $5 "Monthly credit" on your organization, which looks like a recurring promotional credit, so this reading is not enough; TypeSafe is asked in writing (Decision 21, "the engine key's account", option C).
    - Your checks, in this order:
      1. Before you create the engine key (part of the M1a setup, Decision 21): check whether the TypeSafe dashboard offers a balance or an enforced spending cap per key. If it does, set the engine key's own balance or cap to the smallest amount allowed. If it does not, create the engine key in a separate TypeSafe account with its own $5. *(Done 2026-09-27: no cap per key. Under Decision 21, "the engine key's account", option C, no engine key is created until TypeSafe answers in writing; see the status below.)*
      2. Before the first real Jev call: confirm that automatic refills (top-up) are off for the account that holds the engine key.
      3. Before the first real Jev call: confirm that this account's billing is prepaid credits only, with no plan or Order that charges for use beyond the bought credits. This is the check "cannot spend more than its balance".
    - If you cannot confirm check 2 or check 3, no real Jev call happens, and the question comes back to you.
    - **Status after the console check (2026-09-27):** check 1 found no balance or enforced cap per key. Check 2 is confirmed for your current organization: auto-recharge (the console's name for automatic refills) is off; it is repeated for the account that finally holds the engine key, before the first real Jev call. Check 3 is open: you asked TypeSafe in writing on 2026-09-27; the answer is pending, and no real Jev call happens before TypeSafe confirms it in writing. No engine key is created until TypeSafe answers (Decision 21, "the engine key's account", option C). M1a's test 14b uses a dummy secret, and the choice is reviewed before M1b. Keys are organization-scoped. A second account may fall under the ban in section 8.2(b), because it would probably receive its own monthly promotional credit; whether it is allowed is asked of TypeSafe in writing (Codex: credits received by the way do not alone prove a breach; the purpose counts). The balance is $9.94: $4.94 left of a free monthly credit of $5 (expires 2026-10-18) and your purchased $5 (expires 2027-09-27). The console record is under Decision 23, and option C with the questions to TypeSafe is under Decision 21, in the overview.
  - **Rejected options (session 2).** The supervisor account's login Keychain (B) and the System keychain (C) were rejected. No one has checked that they work for an account that starts at boot with no login session. An `age` file bound to the Secure Enclave (D) was rejected too. The supervisor runs headless (with no person at the keyboard), so it must use the key without a prompt. So D would protect only copies of the file. It would also tie the key to this one Mac.
  - **Test 14b (session 2).** [Added test 14b](milestone-1.md#tests-this-document-adds) becomes an end-to-end test with a dummy secret. After a boot with no one logged in as the supervisor account, the supervisor reads the dummy secret. Your daily account, the approval account and the worker VMs fail to read it. No evidence export, exchange-folder file or log contains it. The test also checks the owner, the mode and the ACL entries of the file and its subfolder. If any read by another account succeeds, the key does not go into use until the cause is fixed. The test does not protect against compromised supervisor code or against root.
  - A Keychain item or a launcher variable of the same user that the worker runs as would not be safe, because the worker may read either (see "What it does not cover" in [architecture.md](architecture.md#verification-and-what-the-containment-really-covers)). The supervisor never reads the key from a project `.env` or any file in a target repository. The router rejected a project `.env` because a cloned repository could supply its own key and receive the briefs [R-DEC]. The key never goes to a worker, the Node bridge or a log.
- **Numbers in code.** Counts, dates, budgets, diff sizes and time windows stay in code; Jev cannot count and reads dates as text [FIT].
- **Thresholds per question.** A threshold tuned on a Noul does not apply to a Choice, and two opposite Nouls can sum to more than 1. Test Czech briefs before relying on them [FIT].

## Calibration against matching labels

Calibration means checking that "0.8" comes true about 80% of the time on your own tasks. Thresholds must come from your own data, and Jev cannot be fine-tuned [FIT]. Codex's key rule: calibrate each question against its **matching label**. Task success does not show whether a task was ambiguous or whether a failure diagnosis was right; human judgement or controlled tests must supply those labels [CODEX].

| Question | Matching label | Source of the label (*design inference*) |
|---|---|---|
| Task kind | The kind a human assigns | A human judges a sample of cases |
| Ambiguity, needs a human | Whether clarification was really needed | An audit of samples from both escalated and non-escalated tasks, judged against the specification that applied; planted ambiguous briefs. Your answer to an escalation alone is not the label: answering a question does not show that it was needed, and escalations alone miss the ambiguity that Jev did not flag [CODEX-REVIEW, finding 10] |
| Failure class | The real cause | Planted failures of known class; a human judges the real cause |
| Worker claim | Whether the claim matched the grader | Grader evidence |
| Claim re-check | Whether the claim still holds | Sampled human checks; later retractions |

The steps [FIT]:
1. Log every call with the pinned model id, state hash, question id, probabilities, confidence and the action taken.
2. Join each call with its matching label.
3. Measure per question and per version with a reliability table (probability bins against observed rates) and a Brier score (the mean squared difference between probability and the real 0/1 outcome; lower is better).
4. Set thresholds from that data. A small calibration map may combine Jev's probabilities with code features.
5. Train only on verified outcomes. Training a local copy of Jev on Jev's own answers is forbidden by TypeSafe's contract, section 2.3(b).
6. Recalibrate on each version change.
7. Also log the scheduler's actual selection probabilities [CODEX]. When routing is deterministic, one task type always goes to the same route, so the logs cannot show how another route would have done [partial-testimony-logs-2026].

## Jev is a signal, never a permission

- TypeSafe says Jev does not treat input as hostile, so injected text can move its answer. In one reported test, a fake "user approved" field lowered the block probability for `rm -rf ~/.ssh` from 0.76 to 0.48, past a 0.5 gate [FIT] (*secondary source: Octomind via VentureBeat*).
- Calibration holds over groups of answers, not for a single answer [FIT].
- The real boundaries stay the OS sandbox, fencing tokens, code allow-lists and the executable grader. Locks follow what a worker is **allowed** to do, not Jev's `writes_files` guess as in the router [FIT].
- Jev alone may move the engine only toward caution: stop, escalate, ask. It may move the engine toward action only inside limits that code enforces, such as allowed routes, the retry cap and the budget [FIT]. Caution still counts against the budget, because extra reviews and escalations can use up both subscriptions or stop all work [CODEX].

