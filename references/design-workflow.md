# Design workflow — the ordered decision sequence

Solution design starts as four key decisions taken in order:
1. What should Claude own?
2. What shape is the work?
3. Which reference architecture are you committing to?
4. Where does the work interact with Claude?

A full design assembles five: entry point, pattern, work split, model/context, and human-in-the-loop posture. Governance, evaluation and lifecycle sit on top. This file merges all of these into a nine-step sequence.

**Why order matters:** every decision constrains the next. In the illustrative law-firm example below, the only sound option is the one where all five decisions hold together. Two of the alternatives each get four decisions right and fail on one; the third (open agent + Opus) fails on two, pattern and model.

## Contents
- Step 0 — Intake questions
- Steps 1–9 — what to decide, how, and the trap to avoid at each step
- Sequencing rules ("what comes before what")
- Deliverable checklist
- Worked example (compressed): contract review for a law firm

---

## Step 0 — Intake questions

Ask only the ones whose answer would change a decision. Assume the rest and say so.

| Question | Decision it drives |
|---|---|
| Who are the users? Are they engineers? | Entry point (audience) |
| What volume (calls/day), and is it user-facing with a latency deadline? | Pattern, model tier, context strategy, cost |
| What does a wrong output cost: retry, audit, or lawsuit? Is the action reversible? | Pattern (error cost), HITL gates |
| What existing systems of record, rule engines, APIs and documents exist? | Decomposition, live-state vs retrieval |
| What data sensitivity or regulation applies (privilege, PHI/HIPAA, GDPR/residency, FedRAMP, internal policy)? | Eliminates entry points and routes first |
| What cloud commitments exist (AWS/GCP/Azure EA), and what identity system? | Delivery route |
| What does success look like, as a measurable target with a baseline? | Eval plan, value case, go/no-go |
| Who must be able to audit, approve, or answer for outcomes? | HITL, logging, governance/control |

---

## Step 1 — Frame the problem

- State the users, the work, the volume, the success criteria (measurable, with a baseline), and the hard constraints.
- Treat stated requirements as **gates**. A hard SLA miss, a regulatory exclusion or a stated stakeholder priority eliminates an option *before* any trade-off weighing. A measured quality drop can't be waved away as noise.
- Separate "must" from "nice to have". Generic rules of thumb lose to explicitly stated priorities.

**Trap:** jumping to a pattern or tool, e.g. "we'll use an agent" or "let's use Claude Code", before naming the user and the work.

## Step 2 — Decompose: Claude / existing systems / humans

For each step of the work, assign an owner and give a *property reason* (see `decomposition.md`).
- **Claude**: language-shaped work, such as reading, extracting, classifying against given criteria, summarizing, drafting, and planning tool use.
- **Existing systems**: anything the partner has already paid to make reliable, such as deterministic rules and thresholds, live state, computation, systems of record, access control, and sending or executing.
- **Humans**: judgment, exceptions, approvals, and irreversible or high-stakes actions where accountability must sit with a person.
- Produce a **delegation map**: AI-appropriate, human-retained, or collaborative (Claude drafts, a person decides). Justify each by reversibility, stakes and accountability.
- Split compound steps. "Email the adjuster" splits into draft (Claude), send (email system) and approve above a threshold (human).

**Trap:** a deterministic rule moved into the prompt "to keep it in one step" (deterministic drift: in an illustrative case, 41 of 14,000 claims were misrouted).

## Step 3 — Choose the pattern

Walk the five factors **in order**: predictability → error cost → observability → latency → cost. The first factor that rules out a pattern is the deciding one; this is the same procedure as "the binding constraint decides" (the first factor that eliminates options is the binding one). When error cost is binding, error cost picks the pattern. Pick the simplest pattern that meets error tolerance and observability, and escalate only when measurement shows a shortfall.
- **Augmented LLM**: one bounded, verifiable job in one pass.
- **Workflow**: the steps can be determined in advance, and error cost or observability matters. Choose the sub-patterns:
  - chaining, for stage handoffs
  - routing, when inputs vary in kind
  - parallelization, for independent units
  - evaluator-optimizer, when quality is verifiable but one attempt isn't reliable enough
- **Agent**: only when the path genuinely can't be enumerated *and* an unexpected output is acceptable and recoverable. Bound it with narrow tools, per-turn budgets, explicit permissions and stopping criteria.
- **Multi-agent**: only when the work genuinely exceeds one context. Design the decomposition, the result structure, conflict resolution, coverage reconciliation, retry/gap-flag handling, orchestrator checkpointing, and a shared trace ID.
- **Reliability ladder:** prompt, then tools/retrieval, then evaluator-optimizer, then (rarely) fine-tuning.

**Trap:** choosing an agent because the task *feels* open-ended. In one illustrative case, mined traces showed only four paths, which a router plus four chains would have handled.

## Step 4 — Commit to a reference architecture

Choose from **Agent, RAG, Document processing pipeline (evaluator-optimizer), Routing, Coding agent** (see `patterns-and-architectures.md`).
- Compose two only when the parts of the problem break in different ways that are worth managing separately. Composition roughly doubles the surface area and needs separate eval contracts. "When in doubt, pick one."
- **Live-state check:** for every data source, ask whether it is stable knowledge (use retrieval) or live state owned by a system (use a tool call).
- For RAG: choose chunking per document type by its structure, and indexing for the corpus by its query mix (hybrid + RRF for mixed queries). Name the load-bearing constraint, and plan a labeled retrieval eval.

## Step 5 — Model & context strategy

(see `models-context-cost.md`)
- Tier **per step**. Sonnet is the default. Move to Haiku for classification and routing only when an eval confirms the result. Move to Opus only where an eval shows Sonnet misses the bar.
- Extended (adaptive) thinking stays off until a measured gap remains after prompt work.
- Context: progressive is the default for multi-turn work, agents and staged workflows. Use a monolithic stable prefix for caching, retrieval for large or changing corpora, and compaction for long sessions (preserving identifiers, numbers and decisions). Budget the window as "a ceiling, not a target".
- **Estimate cost and latency** at expected volume. Name the binding budget and the load-bearing control.
- **Eval gate:** a curated stratified test set, a grading function, and a delta/rollback threshold set in advance. Pin model versions.

## Step 6 — Prompting layer

(see `prompting-and-skills.md`)
- System prompt = role/scope + constraints + output contract. Use a template with fixed scaffolding, so filling a slot can't remove a guardrail.
- Encode high-consequence guardrails **structurally** in the output contract or in code, not as a sentence in the role text.
- Use the lightest technique that works: zero-shot, then few-shot, then chain-of-thought.
- Caching goes static-before-dynamic. Check whether call frequency and prefix size actually amortize the cache write.
- Packaging: a versioned Skill for a stable procedure that crosses teams and needs governance, a prompt library for team-local tweaking, and MCP or tools when live calls are needed.

## Step 7 — Entry point, then build-time interface, then delivery route

(see `entry-points-integration.md`)
1. Apply **non-discretionary constraints first**: privilege leads to audit ownership in the partner's infrastructure, HIPAA to a BAA covering the specific configuration, GDPR to region pinning, FedRAMP to an authorized environment, and internal policy to the approved CSP list.
2. **Entry point** by audience and work: Claude.ai/Projects for knowledge workers, Claude Code for engineers, Cowork, Chrome or Excel for their niches, and a custom app on the API/SDK for embedded product experiences.
3. **Interface**: one request/one response uses the SDK (the default) or the API. Tools reused across two or more Claude clients go through MCP. A multi-turn agent inside the partner's product uses the Agent SDK.
4. **Route**: follow the existing cloud commitment (Bedrock, Vertex or Foundry). Use Anthropic first-party if there's no commitment or day-one features are needed.
5. State the **deciding tradeoff**: audience, integration depth, governance/control, regulatory residency, or latency.

## Step 8 — Governance, evaluation, lifecycle

(see `governance-safety.md`, `evaluation-testing.md`, `lifecycle-stakeholders.md`, `claude-code-enablement.md`)
- **Controls enforced outside the model:**
  - authN/authZ before retrieval
  - least-privilege, per-role tool allow-lists
  - per-user scoped credentials
  - output validation before any action
  - deny-first permissions, hooks, sandboxing and egress allow-lists
  - audit logging at the server boundary, including the model ID
- **HITL:** gates sit before irreversible or high-impact actions, placed by risk *type*. Define explicit escalation triggers, a drawn escalation path, risk-weighted review sampling, and a named accountable human.
- **Untrusted input:** treat user content, documents and tool results as untrusted. Watch the exfiltration triad (untrusted content + sensitive data + outbound channel).
- **Evals:** representative data reported by subgroup, test types matched to objectives, regression and adversarial sets pinned per model version, and production failures turned into new test cases.
- **Lifecycle:** success criteria and SLAs, pilot after the baseline configuration and security boundaries are set, staged rollout with a rollback trigger, runbooks (alert → triage → escalate → rollback), ADRs that record alternatives, and audience-tailored stakeholder communication.

## Step 9 — Anti-pattern sweep

Run the final design against `anti-patterns.md`. In critique mode, this sweep *is* the main method. Look especially for what is **absent**: escalation path, human gate, coverage check, eval set, rollback criterion, audit owner.

---

## Sequencing rules ("what must come BEFORE X")

Order questions recur in design reviews and scenario-style questions. In each chain below, foundational steps come before the steps that depend on them. The tempting wrong choice is the later step, presented as if it came first.

- Goals, constraints, success criteria **before** stakeholder validation, design, or build.
- Hypothesis, metric and minimum detectable effect **before** running an experiment.
- Asset inventory and threat actors **before** threat assessment, which comes **before** mitigations.
- Regulation applicability / scoping **before** clause-by-clause mapping.
- Workflows, role/security boundaries and baseline config **before** a pilot. Pilot findings come before iteration.
- Quality bar, SLOs and specification **before** shortlisting, which comes before testing or piloting.
- Eval set, grader and threshold **before** a model swap or optimization. Rollback criterion **before** the data.
- Evidence (repro, last-known-good diff, raw output) **before** changing config.
- Least-destructive diagnostic **before** a destructive one (for MCP: list status, then reconnect, before reinstalling).
- Decision/outcome **before** details when presenting to executives.

## Deliverable checklist

Scale the deliverable to the question — omit sections that don't bear on a decision.

- [ ] Every decision has a **Deciding tradeoff:** line
- [ ] Decomposition table with a property reason per step
- [ ] Per-step model tier plus a cost/latency estimate with the binding budget named
- [ ] Each data source labelled stable knowledge (retrieval) or live state (tool)
- [ ] Deterministic rules, security and compliance enforced in code/infra, not in prompts
- [ ] HITL gates and the escalation path drawn on the diagram
- [ ] Eval plan with a pre-set threshold and rollback criterion
- [ ] Entry point/route justified, with regulatory eliminations stated
- [ ] Cost estimate uses token counts consistent with the inputs (scans, photos and long histories are large) and routes only the steps that actually call Claude
- [ ] Production readiness, where it applies:
  - a fail-safe fallback for every external call
  - idempotent actions under retry
  - slow work kept off the latency path
  - peak load checked against quotas
  - cited evidence verified against the source in code
  - no reliance on model self-reported confidence
  - multi-intent or multi-document input handled
- [ ] Opens with a decision summary; per-step detail lives in tables
- [ ] Mermaid diagram
- [ ] Key risks (only those that apply), each with its mitigation

## Worked example (compressed): contract review for a mid-market law firm

**Illustrative brief:** 180 lawyers. Associates spend 12–18 h/week checking 35-page contracts against the firm playbook. Documents live in iManage. There is a CIO-approved LLM gateway, and privilege excludes consumer tools. The goal is −60% associate time, with a senior associate remaining the final reviewer.

| Decision | Choice | Deciding tradeoff |
|---|---|---|
| Entry point | Thin internal web app on API/SDK, firm SSO, through the approved gateway | Governance/control — the firm must *own* the audit trail (privilege) |
| Pattern | Parallelized workflow, section by section, plus an evaluator pass enforcing a strict flagged-clause schema | Predictability — the work decomposes cleanly; an agent's flexibility would never be used |
| Split | Claude: extract, classify against playbook, draft redlines · Systems: playbook as a versioned source of truth retrieved per clause; iManage fetch · Human: senior associate | A full playbook in the prompt would go stale and be reprocessed on every call |
| Model/context | Sonnet, progressive; extended thinking per clause type only where evals justify it | Cost — Opus-everywhere is the "bill-arrived" failure |
| HITL | Associate signs off on every output; low-confidence clauses flagged | Stakes and accountability sit with the lawyer |

The tempting alternatives: Claude.ai + Project fails on one row (entry point: privilege), and playbook-in-prompt fails on one row (split: knowledge staleness). Open agent + Opus fails on two rows: pattern (flexibility that would never be used) and model (cost).
