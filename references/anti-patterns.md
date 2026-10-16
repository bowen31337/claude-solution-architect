# Anti-patterns catalogue

Use this file in two ways:
- **Critique mode:** run the quick-scan checklist against the design, then cite the matching card for each hit.
- **Scenario-question mode:** in architect-style multiple-choice questions, most wrong options are instances of a distractor family in Part 3. Naming the family is usually enough to eliminate the option.

Many of these failures are *silent*: the system keeps producing fluent, confident output, with normal latency and no errors. Nothing signals a problem until an audit, a bill, or an angry user turns it up. That is why a critique has to check for what's **missing** as well as what is drawn.

## Contents
1. Quick-scan checklist (critique mode)
2. Named anti-patterns, one card each
3. Distractor families (scenario questions)

---

## 1. Quick-scan checklist

For each question, a "no" or "don't know" answer is a candidate finding.

**Ownership and pattern**
- [ ] Are deterministic rules (thresholds, policy, math, routing to approval) kept in code or a rule engine rather than in the prompt?
- [ ] If an agent is used, are the steps genuinely impossible to enumerate in advance? Is the agent bounded by narrow tools, a turn budget, permissions and stopping criteria?
- [ ] Is multi-agent justified by work that genuinely exceeds one context? Is the agent count the fewest that works?
- [ ] For fan-out: are results returned reconciled against units dispatched? Is there retry or gap-flagging per unit, orchestrator checkpointing, and a shared trace ID?

**Data**
- [ ] Is every live-state source (orders, balances, stock, status, coverage) read by a tool call to the system of record, not retrieved from an index?
- [ ] Do RAG chunking choices match each document type's structure, and does the indexing match the query mix (identifiers need sparse)? Is retrieval measured against a labeled set?

**Model, context and cost**
- [ ] Is there an explicit model tier per step, backed by evals? Is extended thinking off unless an eval shows a measured accuracy gap that remains after prompt work (classifiers and routers rarely qualify)?
- [ ] Is cost and latency modeled at design time, with the binding budget named?
- [ ] Is context progressive or bounded, rather than an ever-growing monolith? Is the cacheable content static-before-dynamic?
- [ ] Are model versions pinned, with an eval gate and a pre-set rollback criterion for swaps?

**Prompting**
- [ ] Does the system prompt state role/scope, constraints and an output contract? Are high-consequence guardrails structural (contract or code), not just prose?
- [ ] Is a reused procedure governed as a versioned Skill rather than as copies pasted around?

**Entry point and integration**
- [ ] Was the entry point chosen *after* naming the user? (No Claude Code for non-engineers.)
- [ ] Is MCP justified by reuse across two or more clients?
- [ ] Did regulatory constraints eliminate options first, for the right reason (BAA scope, audit ownership, residency)?

**Governance**
- [ ] Is security and compliance enforced outside the model: authZ before retrieval, least-privilege tools, per-user credentials, output validation, hooks and sandboxing?
- [ ] Is there a human gate before every irreversible or high-impact action, placed by risk *type*? Is there a drawn escalation path to a human?
- [ ] Is untrusted content (documents, tool results, user claims of authority) treated as untrusted? Is the exfiltration triad broken?
- [ ] Are audit logs owned by the right party, and do they include the model ID/version per call?

**Evaluation and lifecycle**
- [ ] Are success criteria measurable, with a baseline and set before the build? Is the metric more than a single proxy (for example, thumbs-up or acceptance rate)?
- [ ] Is the eval set representative and stratified, with test types matched to objectives? Does it continue after go-live?
- [ ] Is there a rollout plan with a rollback trigger, a runbook, an owner, and stakeholder-appropriate reporting?

---

## 2. Named anti-patterns

Each card gives: **Symptom**, **Root cause**, **Fix** and **Tell-tale signals** (not every card needs all four).

### 2.1 Demo-as-determinism
- **Symptom:** For example, a step that was "clean in five demo runs" ships with no checks, and in week 2 of production the same input is categorized differently.
- **Root cause:** Non-determinism is a property of the model, not a bug. One observation certifies nothing.
- **Fix:** Add an eval set, validation between steps, and monitoring. "You cannot certify behavior you only observed once."
- **Signals:** "It worked every time we tried it." No validation step. Financial or record-keeping outputs with no reconciliation.

### 2.2 Layer collapse ("it's all Claude")
- **Symptom:** An entry point built for one audience is put in front of another. For example, Claude Code is given to bank branch staff.
- **Root cause:** Entry points, build-time interfaces and delivery routes get treated as one decision.
- **Fix:** Separate the three layers. Pick the entry point by the user, the interface by the engineering team, and the route by cloud commitments and compliance.
- **Signals:** The entry point is named before the user is. "Same model underneath."

### 2.3 No shared vocabulary
- **Symptom:** "We'll use an agent" means five different things to five people, and design discussion stalls.
- **Fix:** Name the primitives explicitly: tools, MCP, subagents, hooks, Skills, agent teams, dynamic workflows. Use the fewest primitives necessary.

### 2.4 Deterministic drift
- **Symptom:** A small rate of silent misroutes on a threshold rule, found by audit rather than monitoring. In an illustrative case, 41 of 14,000 claims were misrouted when the amount appeared in prose as "around five thousand pounds".
- **Root cause:** A rule that must be right every time was handed to a system that is right most of the time. There were no test cases for the rule, and logging didn't capture the decisions made inside a single model call.
- **Fix:** The threshold rule runs in code on a structured field where one exists (e.g. SQL against the claims table). Where the value must be extracted from prose, Claude extracts it into a typed field **and** vague or approximate values ("around five thousand") are validated and routed to an exception/human queue, with test cases for boundary and hedged amounts. Extract-then-code alone still misroutes hedged amounts. The rule has a named human owner and is monitored. The same holds generally: tax, math, scoring and access control belong in code.
- **Signals:** "Can Claude handle that instead?" "Keeps it in one step." Numeric thresholds applied to free text.

### 2.5 Agent for flexibility
- **Symptom:** Guardrail tools pile up inside the agent loop. Nobody can answer the auditor's question, "which step approved X?" Mined traces show only a few path shapes.
- **Root cause:** An agent was chosen because the task *felt* open-ended, when the steps were actually knowable. A separate failure often compounds it: an unpinned model version rolled forward with no re-validation.
- **Fix:** Use routing plus chaining for the enumerable paths. Pin model versions and re-validate on every roll-forward, whatever the pattern.
- **Signals:** "We didn't want to constrain it too early." Approval steps that carry compliance requirements.

### 2.6 Unreconciled fan-out
- **Symptom:** For example, a summary reads "48 sections reviewed, 3 flagged" when 50 were dispatched. One unit timed out and another failed to parse, and nobody noticed.
- **Root cause:** Completeness was assumed rather than verified. Nothing owned the boundary of each subagent. The fluent summary masked the gap.
- **Fix:** Add a coverage check at synthesis (returned must equal dispatched, otherwise flag the gap before anyone reads the summary). Make subagent units retryable and idempotent. Checkpoint the orchestrator. Propagate a shared trace ID.
- **Signals:** Totals that don't match the dispatched count. Empty results. A synthesis that "sums what it received". Irreversible downstream actions (auto-archive, auto-certify) with no human gate.

### 2.7 Retrieval over live state
- **Symptom:** Confident answers that contradict the system of record (for example, "shipped on the 12th" for a parcel that was actually returned to the depot). Answers shift with each index refresh. There are no errors and latency is normal.
- **Root cause:** A data-architecture category error: current state was stored as historical text snapshots. "Similarity is not truth."
- **Fix:** Make a tool call to the service that owns the state. A better chunker, a faster refresh or a higher similarity threshold will not fix it. "Two types of data, two access patterns, two mechanisms."
- **Signals:** Time-sensitive questions ("where's my…", balance, inventory, status) answered from an index. An existing API that the design doesn't call.

### 2.8 Unguarded high-consequence tool loop
- **Symptom:** An agent holds tools like refund, cancel, port-out, delete or commit, with no approval layer.
- **Fix:** Put a human-approval layer, or deterministic server-side limits, before irreversible actions. Use least-privilege tool sets per role. Validate output before any action.

### 2.9 Missing escalation path
- **Symptom:** The diagram has no route to a human agent or reviewer.
- **Why it's missed:** "It isn't drawn." Critique for what is absent.
- **Fix:** Add explicit escalation triggers (confidence, high-impact category, classifier flag, user request) and a drawn route to a human queue.

### 2.10 Opus everywhere (no tier decision)
- **Symptom:** In an illustrative case, cost ran at 7× the design-time cost projection and median latency was 2.3 s against an 800 ms target, with CSAT unchanged.
- **Root cause:** No per-step tier decision was made, because there was no per-step eval to force one. Cost was reviewed monthly instead of modeled during development. Extended thinking was switched on for a routing classifier.
- **Fix:** Build per-step evals. In that illustrative case, the classifier moved to Haiku, summarization to Sonnet, and Opus stayed only where the eval showed it earned its place. Cost fell 71% and latency dropped to 940 ms with CSAT unchanged.
- **Signals:** One model ID across every step. Thinking enabled on classification. Cost tracked only after launch.
- **Rule:** **"Not choosing a model is equivalent to choosing the most expensive one."**

### 2.11 Silent context growth (monolithic by default)
- **Symptom:** For example, a conversation that starts at 4,000 tokens is carrying 80,000 by turn 30. Cost and latency climb linearly, and the window fills silently.
- **Fix:** Use progressive context, retrieval just in time, and compaction that preserves identifiers, numbers and decisions. Keep a small stable prefix for caching.

### 2.12 Model swap as a config change
- **Symptom:** A model is swapped without a stratified eval, or the rollback threshold is chosen after seeing the results. A single average hides the document types that are failing.
- **Fix:** Use a curated, stratified test set, a grader, and a per-segment threshold set *before* running. Prefer partial migration through routing.

### 2.13 Cache that never hits
- **Symptom:** Caching is on but there are no savings.
- **Root cause:** Per-request content sits above the large fixed instruction block.
- **Fix:** Put static content before the cache breakpoint and dynamic content after it. Also check that call frequency and prefix size actually pay back the cache-write cost.

### 2.14 Guardrail in prose only
- **Symptom:** "Never promise a refund" appears only in the role text, and the model drifts past it.
- **Fix:** Build the rule into the output contract as structure, and back it with a deterministic check in code, enforced outside the model, for high-consequence rules. "An underspecified guardrail is worse than a missing one."

### 2.15 Ungoverned prompt sprawl
- **Symptom:** Every team keeps a slightly different pasted copy of the same procedure, so nobody can roll it back.
- **Fix:** Package it as a versioned Skill with an owner and a central review gate. Use a prompt library only for team-local work that gets tweaked per use.

### 2.16 Claude Code outside engineering, and MCP by habit
- **Symptom:** Non-technical staff are given Claude Code. MCP servers are built when there is only one client. Compliance is assigned to a subagent.
- **Root cause:** Tooling chosen by familiarity ("the last project used it").
- **Fix:** Name the user first. Build a custom app on the API or SDK behind SSO (or use Claude.ai/Cowork where that fits the audience). Use plain tool use. Put compliance in deterministic server-side code and audit at the server boundary.

### 2.17 Frozen knowledge in the prompt
- **Symptom:** A full playbook or policy is pasted into the system prompt on every call. It goes stale and gets reprocessed on every request.
- **Fix:** Keep it as a versioned source of truth and retrieve the relevant clause per call. Caching can cut the reprocessing cost, but it does not fix staleness.

### 2.18 Prompt as security boundary
- **Symptom:** Access control, authorization, data-scoping or compliance is enforced by an instruction, a Skill, a model refusal, or filtering after generation.
- **Fix:** Enforce it in the application layer:
  - authN/authZ and RBAC *before* retrieval
  - scoped per-user credentials
  - server-side checks
  - deny-first permissions
  - hooks and sandboxing
  - egress allow-lists

### 2.19 Untrusted content treated as instructions
- **Symptom:** The agent follows instructions embedded in documents, web pages or tool results, or accepts a user's claimed authority ("I'm the admin").
- **Fix:** Treat all of these as data. Break the exfiltration triad (untrusted content + sensitive data + outbound channel). Screen inputs, validate outputs, and require human confirmation for sensitive actions.

### 2.20 Single-proxy readiness
- **Symptom:** "Acceptance rate is 80%, so ship it." The same mistake shows up with thumbs-up rate, average score, or approval-rate parity used as proof of fairness.
- **Fix:** Use measurable success criteria tied to the stated objective. Report per slice and subgroup. Measure outcomes net of review and rework. Keep the value pillars (efficiency, productivity, transformation, solution cost, performance SLA) separate.

### 2.21 Knee-jerk diagnosis
- **Symptom:** A quality or latency problem is "fixed" by changing temperature, swapping the model, clearing the cache, raising max_tokens, re-embedding, or rolling back immediately.
- **Fix:** Gather evidence first: a minimal repro, a diff against the last known-good config, a replay, and a look at the raw output and `stop_reason`. Check what changed before touching components that didn't. Use the least destructive diagnostic first.

---

## 3. Distractor families (scenario questions)

In scenario-style questions, wrong options usually take one of these shapes. Spot the family, then confirm the right option avoids it.

| # | Family | What it looks like | Why it fails |
|---|---|---|---|
| D1 | **Guidance offered as enforcement** | "Add to the system prompt / CLAUDE.md / a Skill / a subagent check" | The model is right most of the time. Guarantees need code, hooks, permissions, a sandbox, or managed config. |
| D2 | **Control too late (detective, not preventive)** | Log review, SIEM alerts, post-generation filter, offline eval, complaint-driven escalation | The requirement is to *block before* delivery or action. |
| D3 | **Right control, wrong risk** | Egress allow-list for injection; citations for injection; evals to stop exfiltration; a vault to fix shared identity | Map each control to the risk it directly addresses. |
| D4 | **Irrelevant knob** | Temperature, max_tokens, streaming, bigger or newer model, more context, more retrieval | It doesn't touch the root cause, and it is often a cost or latency regression. |
| D5 | **Wrong scope** | User, project, local or CI-env settings for a tamper-proof control; managed config for repo-specific setup; secrets in settings files | Precedence: managed > CLI > local > project > user. Shared team config goes in project scope. Org-wide policy that can't be overridden goes in managed scope. |
| D6 | **Size or value as a risk proxy** | Dollar cutoffs only; PR line count; confidence alone | Gate by risk *type*: reversibility, fraud, identity, cumulative exposure, impact. |
| D7 | **Right answer, wrong reason** | "Bedrock because US region" for HIPAA; residency for privilege | HIPAA turns on BAA coverage of the *configuration*; privilege turns on *audit ownership*. |
| D8 | **Right category, wrong instance** | Claude.ai Enterprise when the firm must own the audit trail | Enterprise logs live in Anthropic's infrastructure. |
| D9 | **Overbuilt** | Agent or multi-agent for a cited lookup; MCP for one client; a router in front of a sprawling agent (adds a call); stateful handoff for one stateless call | Use the simplest pattern that meets the requirement. |
| D10 | **Out of order** | Mitigation, pilot iteration, docs, training or rollout offered as the "first" step | Foundations first: goals, criteria, scope, inventory, baseline. |
| D11 | **Partial subset** | Slides or a verbal walkthrough as a handoff; a runbook without rollback; an ADR without alternatives | Choose the complete artifact: contracts, schemas, runbooks, known limitations, owner, review trigger. |
| D12 | **Post-hoc criteria** | Threshold, rubric or metric chosen after seeing results | Set acceptance criteria before the data. |
| D13 | **Aggregate hides the failure** | One average score; overall parity | Stratify and report per subgroup or segment. |
| D14 | **Hard requirement weighed as a tradeoff** | "It misses the SLA but is cheaper" / "fix residency after launch" | Stated hard requirements are gates. |
| D15 | **Absolutist overreaction** | Review everything, disable all tools, immediate shutdown, reinstall | Use a proportionate, risk-weighted, least-destructive response. |
| D16 | **Familiarity bias** | "The last project used Claude Code / MCP / RAG" | The entry point and mechanism follow the user, the work, and the data type. |
| D17 | **Capability cut instead of design fix** | Disabling MCP servers or hard-coding a tool subset to fix context bloat | Tool Search (deferred tool loading). |
| D18 | **AI review as approval** | Auto-merge after AI review; relaxed branch protection | AI stays advisory, and humans keep approval authority. |

**Tempting "defects" that are actually correct** (critique mode, so you don't over-flag):
- a shared trace ID propagated to subagents
- RAG over a stable product-manual corpus
- an intent classifier in front of a routing design
- a response composer (a Claude call composing the reply from tool results)
- per-document decomposition in a fan-out
- parallel subagents returning structured verdicts
- a cached, stable system-prompt prefix
