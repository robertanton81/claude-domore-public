# The five options in detail


> Part of the claude-domore design, 2026-09-26. Status: proposal, nothing built. The overview is [what-we-could-build.md](../what-we-could-build.md). It holds the options table, the verdicts and the hybrid of options 1 and 2. This file gives each option in detail: what it is, its gain, its cost, what breaks, where Jev sits, and the verdict. Source tags and labels in italics are explained in the overview's ["Sources"](../what-we-could-build.md#sources-and-how-this-document-was-made) section.

## Option 1: a deterministic supervisor (recommended)

A long-running program owns the task queue, the state machine, side effects, budgets and approvals. "Deterministic" means that ordinary code decides every state change and every permission; a model never does. Models propose work and produce artifacts such as patches; code decides what happens next [CODEX].

- **Gain.** It bills to the subscriptions. It avoids token interception (taking the login token from the real program to use it in other code). It also avoids the credential ban (Anthropic's rule against collecting or passing on claude.ai logins and tokens). It does both on purpose, because only the unmodified binaries run with your own logins [FIT]. Permission is explicit only for scripted `codex exec` on the plans that list it. For continuous unattended Claude use, permission is unclear. So the recommended setup runs unattended work through Codex, once [Decisions 8 and 27](../what-we-could-build.md#decisions-for-the-user) allow it, and keeps the `claude -p` adapter off by default [FIT], [CODEX]. It adds no second model loop (your position in the session of 2026-09-26). It reuses tested router parts (see the [reuse table](architecture.md#what-we-reuse-from-the-router)). You control the learning gate completely [FIT].
- **Cost.** You build and maintain the queue, state store, resume, approval inbox and effect reconciliation [FIT]. Effect reconciliation means checking, after a crash, which side effects really happened, such as a commit or a model launch. Codex corrected the fit check here: the router has useful execution parts, but not the central task state, effect reconciliation, promotion and learning control [CODEX]. Promotion means making a tested learned change the new default. This is new work. With `claude -p` off, unattended coding is Codex only; Claude codes only when you work in the interactive session.
- **What breaks.** Nothing in the credential ban. Permission for continuous automation is unresolved. Security depends on your own code, which must handle the technical traps. Both are described in ["Subscriptions and policy"](architecture.md#subscriptions-and-policy) [FIT].
- **Jev.** Called by the supervisor, pinned to one version, and fail safe: on a Jev failure the engine takes the fallback that the [decision table](jev.md#decision-table-jev-answers-and-failures) fixes for each job, and no fallback grants a permission. Its answers feed admission and failure triage, and code decides.
- **Verdict.** Recommended.

## Option 2: an interactive Claude Code session as the driver

One long session runs the loop. The tools for this have limits [PLAT]:
- A Stop hook (a script that runs when Claude wants to stop) can block the stop and give Claude a reason to continue.
- Claude Code ignores the Stop hook after 8 blocks in a row without progress. Scripts check `stop_hook_active`.
- `/loop` repeats a prompt locally. The minimum interval is 1 minute, and recurring tasks expire 7 days after creation.
- Cloud routines draw subscription usage. They have a daily cap and a 1-hour minimum interval.
- Desktop scheduled tasks run only while the app runs and the computer is awake.

These limits slow unattended runs but do not strictly cap them. The Stop-hook override applies only without progress, and an expired `/loop` task could be created again (*design inference*).

- **Gain.** No new runtime. An interactive session uses the Max plan limits today, and it would still use them if the paused billing change comes back. That is why the router's orchestrator is one [R-DEC]. Claude Code's planner, subagents and skills come with it, and Claude does the coding.
- **Cost and what breaks.** The session holds the work in its context. The session can close, or Claude Code can compact its context (shorten the old conversation to free space). Then the task state must still be valid elsewhere, so this option needs the same durable store as option 1 [CODEX]. When Max is used up, the session stops and no hook runs [R-DEC]. Do not script an interactive terminal session in order to avoid the open question of whether Anthropic's terms allow unattended (headless) use [CODEX]. A session driven unattended has the same unclear permission as `claude -p`, Claude Code's headless mode (one scripted run with no interactive screen).
- **Jev.** A `PreToolUse` hook (a script that Claude Code runs before a tool call), as in the router, but changed to fail safe.
- **Verdict.** Use it as the planning and clarification front-end. For the first live run, the session starts the run through the supervisor's commands; the supervisor owns state, and you approve through the human-only channel. The session never owns durable state [CODEX]. The hybrid in the overview lets it drive work through the supervisor.

## Option 3: LangGraph in Python as the workflow layer

LangGraph is LangChain's runtime for durable execution: a run can stop and continue later. It also supports pauses that wait for a person (human-in-the-loop). It needs no model. Its nodes could start `claude` and `codex`, with checkpoints (saved run state), retries, interrupts and resume by thread id [FIT].

- **Gain.** Ready checkpoint and resume machinery. Its interrupts could map onto the `needs_clarification` and `awaiting_approval` states (*design inference*). In Python the SQLite checkpointer uses the standard library, not a native module [FIT, correction section]. This is unverified: the correction cites no page, and the JS docs call the SQLite checkpointer a tool for development [FIT]. Check the Python package's dependencies and docs.
- **Cost.** An outside dependency that needs vetting [FIT]. It re-ran recorded side effects after a real crash in one study [resume-means-resume-2026] (*single author*). Codex adds two points. One study does not prove every correctly configured graph unsafe. And LangGraph does not remove your reconciliation work [CODEX]. That work is the same as in option 1, and option 1's hand-written resume is also untested (*design inference*). The self-hosted production server (`langgraph-api`) uses the Elastic-2.0 license and needs LangSmith and license keys; the library alone does not [FIT].
- **What breaks.** Nothing in the credential ban, if nodes start only the real binaries. Permission for continuous unattended Claude use is the same open question as in option 1.
- **Jev.** Nodes call Jev directly by HTTP. TypeSafe's LangChain middlewares are not needed. They are alpha in Python, and `@langchain/typesafe` 0.0.1 in JS has no npm provenance (no signed record that CI built it from its repository) [FIT].
- **Verdict.** A credible later alternative, especially with Python [CODEX]. Under [Decision 5](../what-we-could-build.md#decisions-for-the-user)'s recommendation (standard library only in M1), M1 does not use LangGraph. The reason is the cost of checking a new dependency, not a test result. You can still compare it fairly with one spike (a short throwaway build that tests one question). The spike must run before M1's state layer is written, and only after the dependency check your rules require. In it, LangGraph Python with a SQLite checkpointer runs [acceptance tests 4, 5 and 10](milestone-1.md#the-12-acceptance-tests) with stand-ins (small fake programs that replace `codex` and the Jev API in tests). Without the spike, the option comes back only after M1. That later comparison is unfair, because it compares a finished engine with one that is not built.
  - **Update (session 2):** your [Decision 5](../what-we-could-build.md#before-m1-before-any-code) dropped the spike. The tools research answered its question: no tool reattaches to a running `codex exec` after a crash, and LangGraph's docs call the SQLite checkpointer "Ideal for experimentation and local workflows" (a private research record). If a workflow library is reconsidered after M1, DBOS is the first candidate.

## Option 4: Deep Agents as the runtime

Deep Agents is LangChain's open source agent harness on LangGraph. A harness is the loop, prompts and tools around a model. The versions are Python 0.7.19 and JS 1.14.1, both released 2026-09-24. It adds a virtual filesystem, a `task` tool for subagents, a `write_todos` list, `SKILL.md` skills, self-editable `AGENTS.md` memory, background consolidation (a second worker that rewrites the memory), context offloading (moving large tool results out of the model's context into files) and interrupts [FIT].

- **Gain.** A ready planner loop with all of the above, in an active project [FIT].
- **Cost.** The supervisor loop needs a tool-calling chat model. On subscriptions only, there are three choices [FIT]:
  - An unofficial ChatGPT OAuth model (a model client that signs in with your ChatGPT login), in Python only. It calls chatgpt.com directly, not the Codex CLI. Whether OpenAI permits this is unclear (see ["Subscriptions and policy"](architecture.md#subscriptions-and-policy)).
  - A weaker local model through Ollama (a program that runs models on this machine). *(Session 2: [Decision 22](../what-we-could-build.md#before-m1-before-a-later-phase-of-m1) rules this choice out for the main engine. Local models are not approved for the main engine. They are reconsidered only through a separate decision.)*
  - For Claude Max, nothing.

  Claude and Codex would run only as tools under a second loop [FIT].

  *(Session 2.)* "Subscriptions only" is no longer an assumption. Your [Decision 22](../what-we-could-build.md#before-m1-before-a-later-phase-of-m1) (option A as amended by Codex) confirmed it for claude-domore. Model work runs only on your Claude Max and ChatGPT plans. No pay-per-use model API is used. TypeSafe Jev stays the one paid classifier API. Decision 22 does not approve spending the bought Codex credits. A subscription login alone does not stop a run from using credits, so [Decision 8](../what-we-could-build.md#decisions-for-the-user) still decides that separately. Decision 22 also does not settle the provider-permission questions in Decisions 6 and 27.
- **What breaks.** A self-built chat model around a Claude subscription token would conflict with the credential ban [FIT]. LangChain issue #40132 suggests it would not work anyway. The security model is "trust the LLM", with no Seatbelt or bubblewrap backend. Deep Agents Code (`dcode`), its terminal coding agent, grades goals and rubrics with a model [FIT]. The library itself has no executable-grader feature, but it does not force an LLM grader [FIT], [CODEX]. The agent edits its own memory and skills with no verified-outcome gate [FIT].
- **Jev.** Your own code. TypeSafe's middleware is alpha in Python, unpublished in JS, and does not reach subagents [FIT].
- **Verdict.** Do not adopt. Codex adds that Deep Agents is blocked only in the setup this project needs (a supported Claude-subscription model), not in every possible configuration [CODEX]. ~~Reconsider if a supported Claude-subscription chat model appears that Anthropic's rules clearly allow [FIT].~~ Your [Decision 28](../what-we-could-build.md#before-m1-before-any-code) (session 2) replaced this condition: reconsider only if you also give up the deterministic supervisor, because Deep Agents is a model loop and a supported chat model would not change that. Deep Agents as a worker below the supervisor is a separate question; see [Decision 28](../what-we-could-build.md#before-m1-before-any-code) (session 2 review).
  - **Borrow** these patterns [FIT]: path-routed storage (scratch space plus a durable area); moving tool results over a token threshold to files; pointers first, then a summary, when context fills; read-only shared policy; resume from a checkpoint.
  - **Reject** its scheduled consolidation by a second worker, because consolidation decays [faulty-consolidation-2026] [ACAD].
  - One untested use remains: an isolated instance on local Ollama as a test bed in the unrestricted lab [FIT].
  - *(Session 2.)* [Decision 22](../what-we-could-build.md#before-m1-before-a-later-phase-of-m1) makes a free local model eligible for this parked lab track only. This is not permission to open the lab. All lab preconditions and the separate decision to open the lab still apply. Local runs still get limits on calls, time, memory and disk.
  - *(Session 2.)* The lab is credential-free in a precise sense. The learner and candidate processes hold no credentials. No subscription (provider) login enters the lab. The protected lab controller holds its own separate Jev key, outside the learner's boundary (see "Credentials" in [unrestricted-learning.md](unrestricted-learning.md#a-concrete-lab-design)).
  - *(Session 2.)* A gain on a weaker local model is never evidence by itself. Every lab proposal must beat the unchanged baseline on the real Claude and Codex workers. This happens in the separate validation stage, on held-out tasks, within the approved regression limits. Lab scores alone never authorize adoption.

## Option 5: OpenWiki as the knowledge layer

langchain-ai/openwiki is a TypeScript CLI and MCP server. MCP, the Model Context Protocol, is the standard way an agent calls outside tools. OpenWiki maintains a linked Markdown wiki of a repository for coding agents. Version 0.6.0 came out 2026-09-23, with 40,554 weekly downloads and 16,790 stars. It needs Node 22.22.0 or newer [FIT].

- **Gain.** Grounded claims: every fact points to a versioned range of source lines and is marked for recheck when those lines change. A durable page queue. Local search ranked by BM25, a standard relevance formula, with no model calls. LangChain's own WikiBench test found that a wiki plus the source code gave the best answers. It tested only native mode, where OpenWiki's own agent does the work, and only old versions (0.2.5 and 0.3.0) [FIT] (*vendor*).
- **Cost and what breaks.** Every run edits the root `AGENTS.md` and `CLAUDE.md`, with no opt-out (#556). Init creates a daily CI workflow that needs a provider API key. Telemetry (usage data sent to the vendor) is on by default. It pins `deepagents` 1.13.2. That version is older than 1.14.1, which fixed a symlink path escape in the JS filesystem backend [FIT]. It overlaps your own onboarding skill, which keeps a wiki under `.claude/wiki/` [FIT]. It cannot pick tasks, verify, budget or learn [FIT].
- **Jev.** Around it: whether a diff needs a wiki refresh, reranking, and claim re-checks ([Jev job 8](jev.md#jobs-for-jev)) [FIT].
- **Verdict.** Borrow four ideas [FIT]:
  - grounded claims for experience records;
  - the claim states: stale, confirm, revise, retract;
  - the finish rule: a step counts as done only when all its files are saved;
  - a replay test over git history, like OpenWiki's LEDGER, that checks whether stored facts stay correct.

  A wiki is navigation context, not authority [CODEX]. Try the tool only later, in a throwaway copy, after vetting [FIT]. Use host mode only, with `--project` and telemetry off. Never use native ChatGPT-login mode. It stores OAuth tokens in `~/.openwiki/.env`. It also runs an unsandboxed host shell unless `.openwikiignore` has an active rule; issue #877 reports a run that listed `$HOME` [FIT]. Measure the tool against source-only runs on the same tasks before adopting it [CODEX].

