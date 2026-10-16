# Decomposition: what Claude owns, what systems own, what humans own

Decomposition is the move that comes before architecture. Split the work into three buckets before picking a pattern, a model or an entry point. The split follows from how the model behaves on each piece. Skip it and you either push Claude into work another system does cheaper and more reliably, or ask it to work without context a human would give a colleague.

**Central reframe:** don't ask "where can Claude help?" Ask **"where do the four properties argue for Claude over the system that already does this right?"**

## Contents
1. The four properties of Claude (capability / limitation / mitigation)
2. Property → design consequence
3. The platform map (three layers, brief)
4. The seven AI primitives
5. The three owners and the delegation map
6. Reversibility, stakes, accountability
7. Worked sorting patterns (claims triage, field service, logistics, invoice pipeline)
8. Deterministic drift (Watch Out)
9. Decision rules: what belongs in code/infrastructure vs the model
10. Sequencing
11. Recurring distractor patterns
12. Where the rules pull against each other

---

## 1. The four properties

The properties are not flaws to fix. They are forces you design around, the way a structural engineer designs around the materials. Each pairs a capability with a limitation and a mitigation.

| Property | Capability (lean on it) | Limitation (design around it) | Mitigation |
|---|---|---|---|
| **Next-token prediction** | Common-pattern work: summarizing, reformatting, explaining well-established concepts | Precision on specifics. Produces plausible-but-wrong text, and the risk concentrates on **names, dates, citations, statistics** | Citations, uncertainty signaling, **generator-verifier loops**. Route specific factual lookups through tools or authoritative sources |
| **Knowledge** | Topics that are common, recent and consistent in training data | Rare, niche, contested, **private** or fast-changing topics. Stale or incomplete facts come out in the same confident tone | Web search, retrieval (RAG), tool use, MCP. **The external system is the source of truth.** When freshness or authority matters, supply the data yourself |
| **Working memory** | Anything that fits in the active context window | The context window is a **hard edge**. The model can't see anything outside it | Progressive context loading, chunking, **front-loading critical info**, projects for extended work, summarizing across turns |
| **Steerability** | Short, concrete, verifiable instructions: defined formats, explicit length limits, clear roles | Abstract or ambiguous instructions, long reasoning chains, precise numeric or logical computation. **May follow the letter of an instruction while drifting from its intent** | System prompts, structured outputs, **code execution** for logical precision. Deterministic tools own high-stakes numbers. **Restate the goal alongside the instruction** |

Working-memory edge: don't conflate two different errors.
- An *oversized request* is rejected before generation starts. Over the token limit you get `400 invalid_request_error` ("prompt is too long"). Over the raw byte limit you get `413 request_too_large`.
- If the *prompt fits but generation hits the ceiling*, the stop reason is `model_context_window_exceeded` and the output is truncated.
- To prevent both, check `usage` on every response and use the token-counting API before sending. (Verify error names against current Anthropic docs.)

**Anti-pattern: demo-as-determinism.** In an illustrative case, a demo ran cleanly five times, so the team shipped a financial reconciliation pipeline with no checks. In week two, re-processing the same statement produced a different categorization, and an analyst only found it by chance. A demo is not evidence of determinism. The properties are present whether the architecture acknowledges them or not, and the system drifts quietly.

## 2. Property → design consequence

| Force | Why it exists in the architecture |
|---|---|
| Non-determinism | **Evaluation frameworks**: you can't certify behavior you observed only once |
| Context as a finite resource | **Context strategy** is a design decision: what goes in, in what order, what's left out |
| Confidence is not correctness | **Human-in-the-loop placement and verification** are architectural choices, not afterthoughts |
| Knowledge and capability boundaries | **Retrieval, tools, web search, MCP**: reliable on common/recent/consistent topics, unreliable on rare/private/fast-changing ones |

These pairings are easy to cross. Confidence-vs-correctness maps to **HITL**, not evals. Non-determinism maps to **evals**, not HITL.

A related split: separate *model-behavior failures* (over-refusal, ungrounded generation) from *infrastructure failures* (TLS expiry, DB timeout, load-balancer misroute). Model-behavior failures need grounding, citations, permission to say "insufficient evidence", verification and model-specific evals. Infrastructure failures need monitoring and retries. A prompt change won't fix infrastructure, and an infrastructure fix won't fix behavior.

## 3. The platform map (brief)

There are three layers. They are **not alternatives**, because every deployment involves all three. Collapsing them is the most common source of muddled architecture conversations.

| Layer | Question it answers | Examples | Chosen for |
|---|---|---|---|
| **Entry points** | *Who* reaches Claude | Claude.ai (web/mobile/desktop), Claude Code, custom app on the API | the user and the work |
| **Build-time interfaces** | *How code* reaches Claude | Direct API, SDKs, MCP, Agent SDK | the engineering team and the integration |
| **Delivery routes** | *Where the request runs* | Anthropic first-party, AWS Bedrock, GCP Vertex AI, Microsoft Foundry | cloud commitments and compliance posture |

A decision in one layer rarely dictates the others. Classification traps: Claude Code is an *entry point*, even though engineers use it. Direct API is a *build-time interface*, while Anthropic-direct is the *route*. MCP and the Agent SDK are not entry points. **Name the user before choosing the entry point.** For example, "it's all Claude" reasoning that puts Claude Code in front of bank branch staff is the typical failure. Full entry-point, route and regulated-elimination detail is in `entry-points-integration.md`.

## 4. The seven AI primitives

Every pattern and reference architecture is assembled from these. Give each one its one-word job.

| Primitive | Job | What it is |
|---|---|---|
| **Tools** | **Act** | A function the model can call to take an action or fetch a result from your code |
| **MCP** | **Connect** | A protocol that exposes a set of tools so multiple Claude clients can reach them |
| **Subagents** | **Isolate / parallelize** | Hand a scoped sub-task to a separate context |
| **Hooks** | **Guarantee** | Deterministic code firing on defined events; **enforces a rule the model cannot skip** |
| **Skills** | **Package a procedure** | A versioned reusable unit (instructions plus optional scripts) |
| **Agent Teams** | **Coordinate peers** | Multiple agents as coordinated peers, each owning part of a larger goal |
| **Dynamic Workflows** | **Compose at runtime** | A workflow whose steps are assembled at runtime instead of fixed in advance |

The patterns as assemblies: an **augmented call** is model plus tools. A **workflow** is steps wired in your code, often using tools. An **agent** is a model choosing its own sequence of tool calls. A **multi-agent system** is an orchestrator delegating to subagents.

- Of these, **only hooks enforce deterministically**: a hook enforces a rule the model cannot skip. Skills guide behavior and are not a security boundary.
- **Use the fewest primitives that meet the requirement.** A heavier primitive than needed is paid for in latency, tokens and operational surface on every request. Each primitive is another part to build, observe and govern.
- Name primitives explicitly in design conversations. If you just say "we'll use an agent", five people will hear five different architectures.

## 5. The three owners and the delegation map

| Owner | What belongs there |
|---|---|
| **Claude** | Work that benefits from language understanding, summarization, planning, drafting or tool-mediated action |
| **Existing systems** | Anything the partner has **already paid to make reliable**: order-status service, policy engine, rules table, database of record, OCR, search index, calculation engine |
| **Humans** | Judgment calls, exception paths, approvals, and moments where **being right matters more than being fast** |

Over-assigning to Claude almost always makes the process more expensive, slower and harder to debug. It is the most common and most expensive early mistake.

**Delegation** is the first of the four AI Fluency competencies. Decomposition produces a **delegation map**: for each part, decide not just whether Claude *can* do it but whether it *should own* it.
- **AI-appropriate**: Claude owns it.
- **Human-retained**: a person owns it.
- **Collaborative**: Claude drafts and a person decides.

Split verbs that bundle two owners. "Email the adjuster" breaks into *draft* (Claude), *send* (email system) and *approve above threshold* (human).

## 6. Reversibility, stakes, accountability

Justify every delegation-map entry, and every grant of pattern autonomy, on three axes:
- **Reversibility**: can a wrong call be undone?
- **Stakes**: what does a wrong call cost?
- **Accountability**: who must answer for it?

Apply the same lens to the pattern itself: does it give Claude decision authority that is appropriate for the risk profile, or excessive? Choose an autonomous agent only when stakes and reversibility justify the autonomy.

Sharpen the axes by stratifying on **risk type**: fraud exposure, reversibility, identity sensitivity, cumulative/aggregate exposure, policy edge. Don't stratify by size alone. A blanket dollar cutoff, or a "PRs under 50 lines skip review" rule, is a poor proxy, because a small refund can still be fraud and a one-line auth change can outweigh a large docs edit.

## 7. Worked sorting patterns

Use these as templates. Every item moved away from Claude moves for a **property reason**: a deterministic threshold, live state, precise computation, or stakes. It never moves because Claude "couldn't attempt it".

**Claims triage.** Read claim → Claude (pattern-rich language work; a constrained output schema puts next-token prediction and steerability in your favor). Decide priority → **rule engine** (a deterministic rule the partner defines; Claude calls it). Look up policy coverage → **system of record via tool/MCP** (higher stakes, policies change, and the model can't know its version is stale). Email adjuster → Claude drafts, the email system sends, and a **human approves above a value threshold**. The human gate exists because if Claude decides alone, its working-memory and steerability limitations both become risks. Routing priority-by-rule to Claude would add an unnecessary knowledge limitation on top.

**Field-service knowledge assistant.**

| Item | Owner | Reason |
|---|---|---|
| Summarize case notes into a handover | Claude | summarization: capability zone |
| Current stock of SKU 78-A at nearest warehouse | Existing system | live state |
| Approve refund above £2,000 | Human | stakes, accountability |
| Extract part number from a label photo | Claude | extraction/perception |
| Total billable time across three tickets | Existing system | numeric computation: steerability limit |
| Draft delay follow-up email | Claude | drafting |
| Does warranty apply to this serial? | Existing system | authoritative record-of-truth lookup |
| Escalate a safety incident? | Human | judgment, stakes |

Tempting misroutes: billable-time arithmetic ("simple math"), warranty ("sounds like reasoning"), and safety escalation, all wrongly sent to Claude.

**Logistics shipping exceptions.** Read the carrier's free-text note → Claude. Decide refund qualification under published policy → existing system (deterministic rule, even though the policy is prose). Look up contract tier → existing system (live state). Draft the customer notification → Claude. Issue the refund → **Human** (money out, irreversible; "automatic" does not mean the system should own it).

**Invoice pipeline stages.** Only language-understanding work (classify invoice type, extract fields) goes in the **model stage**. **Pre-processing** is deterministic: OCR, PII redaction, file validation, malware scan, normalization. **Post-processing** is also deterministic: schema validation, *then* persistence to the system of record, after any human review. Never persist before validating.

**Use-case fit: is Claude the primary solution?** Claude is the primary solution for language-intensive work: first-pass reports from semi-structured logs, long-context clause extraction and deviation flags, routing into many categories with reasoning. It is not the primary solution for sub-50 ms streaming fraud scoring (keep inference off a hard real-time path) or for replacing a vector index over millions of documents (Claude consumes retrieval results; the index stays).

## 8. Deterministic drift (Watch Out)

**Illustrative story.** Claims over £5,000 needed a senior adjuster, and the check was an SQL query against the claims table. The architect replaced it with a prompt ("extract the amount and route if over 5K") because it was "one step, simpler." In this illustrative case, three months later **41 of 14,000 claims had been misrouted**. All 41 had amounts embedded in prose ("damages estimated around five thousand pounds"), and the model treated those as loose estimates. It followed the letter of the rule, not the intent.

- **Symptom:** a small rate of silent misroutes on threshold rules, found by audit, not by monitoring.
- **Root cause:** a rule that must be **right every time** was handed to a system that is **right most of the time**. The enforcer changed, not the threshold.
- **Compounding causes:** there were no routing test cases, because routing was seen as "something the model would handle" rather than "a rule the business counts on". Logs that would catch a broken SQL check don't record decisions made inside a single model call, so the drift was invisible.
- **Fix:** the threshold rule runs in code. Where a structured field exists, keep the check there (here, the SQL query against the claims table). Where the value must be extracted from prose, Claude extracts it into a typed field, **and** vague or approximate values ("around five thousand") are validated and routed to an exception/human queue, with test cases for boundary and hedged amounts. Extract-then-code alone still misroutes hedged amounts. A rule the business counts on must be **tested, monitored and owned by a named human**.
- **Tells:** "Can Claude handle that instead?" asked about an existing SQL/rules check; "keeps it in one step"; demos showing only clean inputs; numeric thresholds applied to free text.

Cost, complexity, risk: you pay model prices for lookups that a query does for a fraction of the cost, multiplied by request volume. Table-driven logic moved into a model becomes untraceable, whereas deterministic rules fail predictably and debuggably. When the model becomes the source of truth, authoritative answers **drift quietly, with no error and no warning**.

## 9. Decision rules: code/infrastructure vs model

### Ownership
**Deterministic rule stays in code** — When a step applies a business rule or threshold (priority, £5,000 routing, refund qualification, tax), choose the existing rule engine/SQL/validated calculation tool over a prompt instruction, because the rule must be right every time and the model is right most of the time. Run the rule on a structured field where one exists. Where the input must come from prose, Claude extracts it into a typed field, and vague or hedged values are validated and routed to an exception/human queue rather than passed to the rule as if exact. Test boundary and hedged cases, monitor the rule, and give it a named human owner.
- Trap: "Put the threshold in the system prompt, it's one step." This produces silent misroutes on prose-embedded values.

**Live state via tool call** — When the answer depends on live or frequently changing state (stock, coverage, contract tier, warranty, order status), choose a tool/MCP call to the system of record over model knowledge or a retrieval index, because the model can't know its information is stale and won't flag it.
- Trap: "The policy is published, so Claude can reason over it." Published prose that encodes a live decision still belongs to the system.

**Computation goes to code** — When the task needs precise arithmetic or logic (billable hours, totals, tax), choose deterministic code or code execution over model reasoning, because steerability is weakest on computation.
- Trap: "It's simple arithmetic." Simplicity doesn't change the property.

**Language work goes to Claude** — When work is reading, summarizing, extracting, classifying or drafting, choose Claude, ideally with a constrained output schema, over building rules, because that is next-token prediction's capability zone.
- Trap: sending OCR, redaction or schema validation to Claude because "it's all document handling". Conventional components are more predictable there.

**Keep infrastructure in place** — When the need is large-scale search, sub-50 ms scoring or a system of record, keep the specialized system and have Claude consume its outputs, because an LLM on a hard real-time path or posing as an index fails on latency, determinism and cost.
- Trap: "Claude can replace the vector index / fraud model."

**Ground on the source, not recall** — When output must reflect current private material (code, policies), choose source-grounded retrieval or read tools over training-data recall, because recall cannot represent the current implementation.

### Controls that must not live in the model
**Authorization before inference** — When roles see different data, enforce RBAC in the retrieval/application layer *before* content reaches prompt construction. Don't rely on system-prompt instructions, model refusals or post-generation filtering: once the model has seen restricted data, it is already exposed in context, traces, caches and outputs.
- Trap: "Instruct the model to ignore documents the user can't see," or "filter the response."

**Credentials and authority stay outside the model** — Resolve credentials server-side (secret store, per-user OAuth). Derive authority from the authenticated identity, not from text in the prompt, because prompts persist in logs and caches and self-declared authority is untrusted data.

**Deterministic controls in the app layer, behavior in the Skill** — Put authN/authZ, audit logging, retention, data access and consequential actions in the application layer. House style, disclaimers and prohibited-language lists go in a Skill or prompt, because a Skill guides behavior and is not a security boundary.
- Trap: "The compliance-approved Skill already handles it."

**Compliance on the strongest guarantee** — When a path is high-consequence (compliance checks, approvals), run it in deterministic server-side code, hooks or sandboxing, not in subagents or prompts, because those carry the weakest deterministic guarantees.
- Trap: "A compliance subagent reviews every interaction."

**Least-privilege toolset** — When an agent drafts for review, give it only the read tools it needs for grounding plus a write tool scoped to the review queue. Enforce that as a per-role allow-list at the orchestration layer. Send/submit/admin tools turn a drafter into an actor and bypass the human gate.
- Trap: "Keep the tool, it might be useful later," or "the model will decline to use it."

### Human ownership
**Pre-action gate on irreversible actions** — When output can trigger an irreversible or high-impact action (money out, publishing, access rights, employment), put a human approval gate *before* the action, with explicit review criteria and enough context for the reviewer. Post-hoc audit or random sampling can't prevent harm.
- Trap: "We'll audit a sample weekly."

**AI advises, humans approve** — When AI enters an existing approval workflow (PR review, underwriting), make it advisory (comments, findings) and keep approval authority and separation of duties with people under existing controls.
- Trap: auto-merge after AI review.

**Risk-stratified delegation and review** — When volume makes universal review infeasible, automate routine, well-evidenced cases. Mandatorily review low-confidence, high-impact, anomalous, disputed or identity-sensitive cases, plus a random slice of the rest to catch drift. Make escalation triggers explicit and observable (confidence threshold, impact category, classifier flag, user request), not left to model discretion.
- Trap: a dollar-only cutoff, review only after complaints, or review everything (breaks throughput).

## 10. Sequencing

1. Decompose (Claude / systems / humans) **before** choosing a pattern, reference architecture, model or entry point. Each decision constrains the next.
2. Within decomposition, identify the oversight points by impact and reversibility **before** designing sampling, escalation criteria or reviewer onboarding.
3. In a pipeline, deterministic pre-processing (OCR, redaction) **before** the model stage, then validation **before** persistence, then persistence **after** human review.
4. Authenticate and authorize **before** retrieval and prompt construction, never after generation.
5. Map AI-vs-human boundaries **before** a Claude Code pilot.

## 11. Recurring distractor patterns
- "One step is simpler": a deterministic rule or threshold moved into the prompt.
- "It's published policy prose, so it's a reasoning task": qualification and coverage decisions sent to Claude.
- "It's simple arithmetic": computation sent to Claude.
- "It's automatic, so a system can do it": an irreversible money-out action sent to automation with no human.
- Enforcing access control, compliance or authority with a prompt, a Skill, a subagent or post-filtering.
- A dollar or line-count threshold as the only risk proxy.
- Claude replacing infrastructure (search index, real-time scorer, system of record).
- A demo treated as proof of determinism.
- Mapping confidence-vs-correctness to evals (it maps to HITL), or non-determinism to HITL (it maps to evals).

## 12. Where the rules pull against each other
- **Value thresholds.** One framing uses monetary thresholds as worked HITL triggers (approve refunds above £2,000; review emails above a value threshold). Another treats a *blanket dollar cutoff* as wrong and stratifies by risk type (fraud, reversibility, identity, aggregate exposure). Reconcile: a value threshold is one valid trigger among several, never the only one.
- **Who reads an image.** One framing assigns "extract part number from a label photo" to Claude (perception). Another puts OCR in deterministic pre-processing and extraction in the model stage of an invoice pipeline. Reconcile: where a conventional OCR component exists and is reliable, use it, and give Claude the field extraction and classification over the text. Where the input is ad hoc (a single photo), Claude's vision is acceptable.
- **Classification vs priority.** One rule routes "decide priority" to a rule engine; another endorses Claude for routing tickets into 30 categories. These don't conflict once you see the distinction: a *partner-defined deterministic rule* stays in code, and *semantic classification of free text* is language work for Claude.
