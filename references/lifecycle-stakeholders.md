# Stakeholder Communication and Lifecycle Management

Use this file when a scenario involves discovery, requirements, success criteria, SLAs, value claims, presenting a decision, documentation and handoff, pilots and rollouts, scope changes, or "which step comes before X".

## Contents
1. Lifecycle phases and gates
2. Discovery: requirements and success criteria first
3. Requirements as gates and the value pillars
4. Audience-tailored communication
5. Transparent reporting and alignment
6. Documentation: ADRs, handoff packages, runbooks
7. Pilots, rollouts, change management
8. Iterate in place or re-enter design
9. Sequencing cheat sheet ("what comes before X")
10. Recurring distractor patterns
11. Where the rules pull against each other

---

## 1. Lifecycle phases and gates

| Phase | Core activities | Gate to leave the phase |
|---|---|---|
| **Discovery** | Elicit goals, actors, triggers, in-scope users, failing journey/decision; stakeholder workshops surfacing latency, accuracy, compliance, cost, audit, data-sensitivity constraints; apply non-discretionary constraints (privilege, HIPAA, GDPR, FedRAMP, approved-CSP list) | Documented, measurable success criteria and failure thresholds, validated with stakeholders |
| **Design** | Four key decisions; decomposition; pattern; reference architecture; model/context/entry point; eval spec (metrics, slices, thresholds); per-step cost and latency modeled; ADRs with alternatives | Design meets every hard requirement on paper; eval framework and reference set exist; ADRs complete |
| **Pilot** | Role boundaries (AI vs human authority) and baseline configuration in place first; limited group on representative traffic; HITL oversight points, sampling and escalation defined beforehand | Evidence review against pre-set criteria (not a single proxy metric) |
| **Rollout** | Refine baseline; docs, runbooks, training; controlled expansion with support and rollback | Handoff package complete; SLOs/error budgets instrumented; runbooks tested |
| **Operate** | Monitoring against SLOs; on-call runbooks; sampled output evals; model ID logged per turn | Ongoing: SLA met; incidents feed back into tests and runbooks |
| **Iterate** | Telemetry + sampled evals + stakeholder feedback → highest-impact change → validate offline against existing baseline → controlled rollout → update docs and known limitations | Change is local → iterate; change crosses an architectural boundary → re-enter Design |

Typical rollout order (for example, rolling Claude Code out to engineering): understand current workflows → set the security and role boundaries → design a baseline configuration → pilot with a small group → review what the pilot showed → adjust the baseline → write docs and train → widen access in stages, with support and a rollback path.

## 2. Discovery: requirements and success criteria first

**Structured discovery over prototyping** — When a sponsor asks for an outcome ("improve customer experience", "fix our escalations") but cannot name the failing journey, decision to support, or target metric, choose facilitated structured discovery over a generic prototype or assumed scope, because an LLM application should start from explicit success criteria and a way to measure them.
- Ask: who escalates, what triggers it, what good resolution looks like, which constraints (latency, cost, audit, data sensitivity) apply.
- Trap: telling the sponsor to come back with requirements (abandons them); committing to scope from your own assumptions or a prior engagement; "prototype and see reactions" (can supplement requirements, never replace them).

**Elicit constraints from outcome owners** — Run stakeholder workshops that surface latency, accuracy and compliance constraints before scoping, and turn them into documented success criteria and failure thresholds that gate production, because evals and deployment gates depend on explicit criteria (specific, measurable, achievable, relevant).
- Trap: choosing a model tier from prior experience before the workload is known; deferring constraints to integration design, after commitments are made.

**Functional vs non-functional** — Functional requirements describe what the system does (extract fields, draft for a reviewer, classify tickets). NFRs describe how well (latency, availability, throughput, cost, privacy, security, recoverability, observability, scalability, compliance). A strong NFR states metric, threshold, measurement method and operating conditions (end-to-end vs API latency, concurrency, input distribution, cache state, region, treatment of failed requests).

**SLA anatomy** — When defining an SLA, choose metric + percentile threshold + evaluation window + breach consequence (e.g. p95 latency < 800 ms over 28 days) over qualitative promises, because only that is measurable and enforceable. Prefer percentiles to averages; percentiles expose the tail.
- Trap: "team feels satisfied"; "fast and reliable"; metric + threshold with no window or breach handling.

SLA vs SLO: the SLA is the external commitment with breach consequence; SLOs and error budgets are the internal targets you specify before instrumenting monitoring.

**Name the user before the entry point** — Choosing an entry point before the user is named is one of the most common avoidable design errors. Discovery output must include who the users are.

## 3. Requirements as gates and the value pillars

**Hard requirement is a gate, not a weight** — When an option violates a stated hard requirement (SLA, residency, network boundary, privilege), eliminate it first, then run multi-pillar analysis on the survivors, because "optimize after deployment" is not evidence of compliance. "Let the constraint eliminate options before preferences do."
- Example shape: higher-quality option at 4.2 s vs SLA < 3 s is eliminated; the remaining option is judged on efficiency, cost (annual delta) and whether its quality gap materially harms the workflow.
- Trap: choosing on cost alone, quality alone, "pick it and fix the SLA later", or an unanalysed hybrid.

**Five value pillars** — keep them distinct, because each needs a different architectural response and a different measurement. Classify a claimed benefit by applying each pillar's one-line test:

| Pillar | One-line test | Example |
|---|---|---|
| **Efficiency** | Is the same unit of work done faster, or more of it per person, within the existing process? | Summary time 47 → 6 min; 3× orders processed per analyst per day |
| **Productivity** | Has organizational output or outcome actually increased, beyond per-task speed? | Associates save time but billable output unchanged → productivity not yet realized |
| **Transformation** | Has a role or process been structurally redesigned? | Manual data-entry role eliminated, staff redeployed |
| **Solution cost** | Is spend tracking against the approved cost model? | API costs 40% over per-transaction budget; +22% infra from redundant retries |
| **Performance SLA** | Does a measured metric meet a committed threshold? | Batch latency 11 s vs 5 s SLA |

Common confusion: per-person throughput (more orders per analyst) is **efficiency**, not productivity. Productivity is only claimed when that saved time turns into realized organizational output; if the process is restructured rather than sped up, it is transformation.

**Net, don't gross** — When attributing value, net correction and review effort against gross speed gains (e.g. attorney corrections adding ~8 min/doc partially offset the efficiency gain), because measuring generation speed alone overstates realized value. Prefer metrics like net cycle time, cost per accepted output, correction rate.

**One proxy metric is not readiness** — High first-response acceptance with frequent specialist overrides signals an input-scope gap and an outcome-validity gap; readiness needs multidimensional, outcome-focused criteria. See evaluation-testing.md.

**Model cost in design, not at the bill** — In an illustrative Opus-everywhere case, cost reviewed monthly rather than determined during development moved the conversation "from design into change management." Put per-step cost and latency in the design doc; "the absence of a deliberate choice is not neutral."

## 4. Audience-tailored communication

The decision and rationale stay the same; depth and evidence change with the audience's responsibilities and decision rights.

| Audience | Give them | Not |
|---|---|---|
| Executive sponsor | Decision first, business outcomes, accepted trade-offs, high-level risks | Component detail, threat models |
| Mixed exec committee (CFO / GC / CIO) | Decision first, then a section per concern — CFO: cost, savings, exposure; GC: confidentiality, privilege, retention, human legal review; CIO: integration, security, scalability, ownership. Technical detail in appendices | Leading with diagrams or cost tables |
| Exec sponsor + engineering leads together | Layered disclosure: decision, outcomes, trade-offs, then technical rationale, alternatives, implementation implications | One uniform narrative at equal depth |
| Security / compliance reviewer | Threat model, control mappings, residual-risk acceptance criteria, residual-risk register, audit traceability | Schedules, roadmap |
| Product manager / roadmap owner | Delivered capabilities, scope, feature-level dependencies | Risk-governance artifacts |
| Delivery / engineering team | Component responsibilities, interface contracts, sequence diagrams of dominant flows, config parameters with defaults, runbooks | Executive overview |

**Lead with the decision** — When presenting to executives, choose decision-first framing over building up from architecture, because each decision-maker needs the answer before the supporting detail.
- Trap: deep implementation first (loses the sponsor); decision with no rationale (looks arbitrary, blocks governance); undifferentiated narrative (everyone digs for relevance).

**Name the deciding trade-off out loud** — A right recommendation paired with the wrong reason is not correct; naming the trade-off tells everyone later when to switch. Name the load-bearing control for any configuration.

## 5. Transparent reporting and alignment

**Evidence, then joint renegotiation** — When stakeholder concern escalates (e.g. latency mid-development), present measured p50/p95 under representative load against the agreed SLA, then revise SLA, scope or cost together if targets are unachievable, because alignment needs transparent data and jointly approved trade-offs.
- Trap: pausing all development before knowing cause or severity; calling latency an uncontrollable LLM limit (model choice, prompt length, caching, streaming and retrieval depth all move it); swapping in an unevaluated model.

**Problems with options** — When scope grows mid-flight, acknowledge the need, state scope/timeline implications openly, and offer options (defer, descope something else, extend timeline) for the stakeholder to choose; document revised criteria, risk, cost, owner.
- Trap: hiding it from the team, refusing outright, silently absorbing it (scope creep, surprise delays).

**Feedback sessions with traceability** — Focused agenda, artifacts circulated in advance, decisions and follow-ups captured in writing, owners and due dates confirmed. Artifacts handed out at the session leave no preparation time.

**Alignment is ongoing** — Choose a recurring cadence for revisiting expectations and assumptions plus explicit, documented reconciliation of divergent positions (decision, owner, trade-off, reconsideration trigger) over one-time approval. Escalate to the sponsor only for material deadlocks; recording sessions aids access but does not create alignment.

**Be honest about AI involvement** — Disclose AI involvement proportionately and provide a path to a human; transparency does not require revealing prompts or security controls.

## 6. Documentation: ADRs, handoff packages, runbooks

**ADR over slides** — When a decision must be auditable and support onboarding, choose a version-controlled ADR with context, decision, alternatives considered, consequences, date, authors over slides, code comments or verbal notes. Link it to requirements and implementation; assign an owner; review when assumptions change.

**ADR quality = substance + lifecycle** — Strong decision records carry alternatives with the evaluation criteria, plus named ownership and a review trigger/cadence. Meeting mechanics and template uniformity are cosmetic. Omitting rejected alternatives invites their re-proposal without new evidence. For a Claude system, record chosen model and integration pattern, rejected alternatives, eval evidence, security implications, reconsideration triggers.
- When a peer's ADR lacks alternatives and trade-offs, ask them to complete it before publishing (not approve as-is, delete it, or swap the decision).

**Handoff package** — When moving from design to implementation, choose the full documented package over slides, a verbal walkthrough or source code alone, because routine implementation and support must not depend on knowledge held by one person, and model behavior varies with prompts, context and inputs.

| Component | Why it is there |
|---|---|
| Architecture overview + component-level diagrams | Structure |
| ADRs / decision log with rationale and rejected alternatives | Separates deliberate choices from omissions |
| Integration contracts, config schemas, per-component I/O shapes | Stops teams inventing incompatible assumptions |
| Sequence diagrams of dominant flows; config parameters with defaults | Buildable |
| Eval framework + reference set | Lets the team confirm quality, safety, latency, cost thresholds still hold |
| Operational runbooks + on-call playbook | Operable |
| Known-limitations register | Stops unsupported behavior being mistaken for defects |

- Trap: high-level narrative only; architect contact info as "sufficiency"; a list of evaluated models with no selection or rationale.

**Plan docs before drafting** — Start from who will read the guide and what they need it to tell them, then outline sections (overview, components, contracts, flows, runbooks, limitations); translation, team validation and version-control setup come later.

**Runbook chain** — When writing runbooks, include alert → triage → escalation → rollback, with references to dashboards and logs, because on-call must get from alert to controlled resolution. Cover the failure classes an LLM system actually has: bad model output, slow responses, hitting rate limits, a tool or dependency going down, a prompt change that regresses quality, unexpected spend, and data-handling incidents. Exercise them and update after incidents.
- Trap: any partial subset (dashboards only; alerts + triage only; escalation + rollback only).

## 7. Pilots, rollouts, change management

**Design and configure before the pilot** — Before a small-group pilot, map which workflow steps benefit from AI and where human authority stays, and configure the baseline (project-scope MCP servers, permissions, subagents, CLAUDE.md; managed vs project scope decided). Full runbooks, org-wide training, broad sign-off and iteration come after, because a pilot must test a deliberately designed, consistently configured workflow.
- Trap: "iterate on pilot findings" (post-pilot by definition); "formal sign-off from every manager" (overly broad unless governance requires it); "roll out to more teams".

**HITL design before the HITL pilot** — Locate oversight points by impact and reversibility and define sampling and escalation criteria at each, before piloting on representative traffic; reviewer onboarding and SLA docs follow.

**Ship the simpler thing and measure** — In triage, deploy and measure the routed workflow before an agent variant; escalate pattern complexity only when measurement shows the simpler pattern falling short.

**Model swaps are releases** — A swap looks like a one-line config change but rewrites product behavior; downgrading after launch carries change-management cost. Pin versions; re-validate on roll-forward.

## 8. Iterate in place or re-enter design

**Re-enter design when a boundary moves** — When the architecture cannot meet new requirements without changing component responsibilities, interface contracts, data flows or security boundaries, choose a new design cycle (discovery, impact analysis, review, regression planning) over local iteration. Runbook clarifications, alert-threshold tuning, UI copy edits are local; iterate in place.

**Evidence-driven iteration** — In post-deployment iteration, choose a targeted change chosen from telemetry, sampled evals and stakeholder feedback and validated against the existing eval baseline over redesign or ending measurement.

**Continuity across phases** — Carry the eval framework and reference set forward and capture lessons learned per phase; don't notify everyone at every transition, archive everything, or lock early decisions. Decisions are documented and governed, and reopened on new evidence.

**Signals that re-entry is due** — Mined traces collapse into a few fixed shapes, guardrail tools accumulate inside the agent loop, or an auditor asks "which step approved X" and the answer is a model turn: the work was enumerable and belongs in a workflow.

## 9. Sequencing cheat sheet ("what comes before X")

| Before X | Do first | Comes after X |
|---|---|---|
| Validating requirements with stakeholders | Goals, success criteria, in-scope users; NFR constraints | ADRs, traceability docs, rollout milestones |
| Designing anything | Structured discovery → measurable criteria | Model choice, prompting |
| Empirical model test | Quality bar, latency, volume; shortlist | Pick cheapest passing model; periodic retest; rollout sign-off |
| Running an eval | Metrics + slices; curate/label data; thresholds | Scoring, dashboards, gates, SME rubric review |
| Running an A/B test | Hypothesis, primary metric, MDE, sample size | Analysis, decision, write-up |
| Instrumenting monitoring | Metrics, slices, SLOs, error budgets | Alert thresholds, dashboards, runbooks |
| Small-group pilot | Role boundaries; baseline config | Iteration, full runbooks, org-wide training, expansion |
| HITL pilot | Oversight points by impact/reversibility; sampling + escalation | Reviewer onboarding, SLA docs, iteration |
| Drafting a guide | Audience + questions; outline | Validation, translation, version-control cadence |
| Mapping data flows to regulatory clauses | Applicability; inventory existing compliance affordances | Gap comparison, documentation, remediation |
| Assessing threat likelihood/impact | Asset inventory + sensitivity; threat actors/vectors | Mitigations, residual risk, documentation |
| Weighing cost/ops savings | Non-negotiable constraint check (residency, boundary, SLA) | Multi-pillar comparison |

## 10. Recurring distractor patterns

- Prototype or assumed scope in place of discovery; picking a model before the workload is known.
- Qualitative SLA ("fast and reliable") or average latency instead of percentile + window + breach consequence.
- Treating a hard requirement as one factor to weigh, or "fix the SLA after launch".
- One proxy metric (acceptance, gross speed) presented as readiness or realized value; pillars conflated (e.g. per-person throughput labelled productivity).
- Leading with implementation detail for executives; uniform-depth narrative for a mixed audience; giving risk artifacts to product or roadmaps to security.
- Unilateral action on misalignment (pause everything, blame the LLM, swap models unevaluated); hiding or silently absorbing scope.
- Slides, verbal walkthrough, code alone, or contact info as a handoff; ADRs without alternatives or owner.
- Partial runbooks; post-pilot activities (iteration, training, expansion) offered as pre-pilot steps.
- Redesign every cycle, stopping evaluation after launch, or locking early decisions forever.

## 11. Where the rules pull against each other

- **Where the design starts.** One framing opens with "what part of the work should Claude own?" and says decomposition "comes before architecture"; another opens earlier, with structured discovery and measurable success criteria before any design. Reconcile: discovery and success criteria first, then the four key decisions starting with decomposition.
- **Trade-off lens.** One lens evaluates every decision with Cost · Complexity · Risk; another classifies outcomes with five value pillars (efficiency, productivity, transformation, solution cost, performance SLA). Reconcile: use C/C/R when defending a design choice and the pillars when reporting realized business value.
- **Locking decisions.** One rule stresses committing early ("name the reference architecture you're committing to", "not choosing is choosing the most expensive"); another rejects "lock early decisions" and wants them reopened on new evidence via owners and review triggers. Reconcile: decide explicitly and early, record it in an ADR, revisit on evidence.
