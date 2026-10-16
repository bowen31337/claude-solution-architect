# Patterns and reference architectures

Patterns give the **shape** of Claude's involvement. Reference architectures give the **wiring**. Choosing a pattern means choosing how much autonomy to grant: the range runs from "Claude assists one step" to "Claude plans the whole sequence". The objective is not to pick the fanciest shape. It is to **name what each choice costs**.

## Contents
1. The three patterns: augmented LLM, workflow, agent
2. The four workflow sub-patterns
3. Five factors, in sequence (with rating-semantics caveat)
4. Agent bounding requirements; flexibility vs non-determinism
5. Improvement progression: prompt → tools → evaluator-optimizer → fine-tune
6. Packaging spectrum
7. Multi-agent orchestration
8. The five reference architectures
9. One pattern or two?
10. RAG vs live tool call
11. RAG chunking and indexing
12. Decision rules
13. Sequencing
14. Tempting wrong choices
15. Where the rules pull against each other

---

## 1. The three patterns

The patterns sit on two axes: **predictability of the path** and **model autonomy**.

| Pattern | What it is | Where control flow lives | Use when |
|---|---|---|---|
| **Augmented LLM** | A single model invocation, optionally with tool use, retrieval or extended thinking. One bounded job in one pass. "The simplest agentic pattern." | Your code. Control flow **never branches on what the model decides** | The task is well defined, the output is verifiable, and there's no reason to split it |
| **Workflow** | Named steps orchestrated **in your own code**. Each step may or may not call Claude | Your code: loggable, testable, guardable | Error cost is real, observability matters, and the steps can be determined in advance |
| **Agent** | A goal plus tools. The model decides its own sequence | **Inside the model.** The path isn't written anywhere you can inspect, and there's no code boundary where a guard can sit | **Only** when the path cannot be enumerated in advance **and** unexpected or inconsistent output is acceptable and recoverable (open-ended investigation, long-horizon work where the next move depends on the last result; e.g. Claude Code exploring an unfamiliar codebase) |

Both workflows and agents can call tools. "Agents can call tools, workflows can't" is false reasoning. Choosing a workflow for that reason is the right choice for the wrong reason.

**They fail differently.** A workflow fails when a step in your code fails, and standard debugging finds it. An agent fails when the model makes a bad decision somewhere in a sequence of turns, which standard debugging won't catch. In production, non-deterministic failures concentrate in agents.

## 2. The four workflow sub-patterns

| Sub-pattern | Shape | When | Example |
|---|---|---|---|
| **Chaining** | Step N consumes step N−1's output, in sequence | Natural stages with clear handoffs | Contract review: extract obligations → classify by risk → draft memo |
| **Routing** | A classifier (often Claude) picks the downstream path | Inputs vary in kind, and each kind needs different handling | Ticket: billing → account-data lookup; technical → product-docs retrieval; escalation → human queue |
| **Parallelization** | Concurrent model calls, then aggregate or vote | Independent sub-tasks | Due diligence on 12 supplier contracts → one risk report |
| **Evaluator-optimizer** | Generator attempts, evaluator critiques, loop until the criterion is met or the retry limit is hit | Quality is verifiable but a single attempt isn't reliable enough | Complaint reply graded on a rubric (names the issue, takes ownership, concrete next steps, brand tone) plus a structure check |

The sub-patterns aren't mutually exclusive, and most production workflows combine them. The **right choice is the simplest one that meets the error tolerance and observability requirements.** Revisit it with production data, and escalate only when measurement shows the simpler pattern falling short.

## 3. Five factors, in sequence

Walk the five factors **in this order: predictability → error cost → observability → latency → cost**. For each, ask whether it rules out a pattern. **The first factor that rules out a pattern is the deciding one.** Summaries often say "the binding constraint decides"; that is the same procedure, because the first factor that eliminates options *is* the binding constraint. So when error cost is binding, error cost picks the pattern.

| Factor | Question | Augmented LLM | Workflow | Agent |
|---|---|---|---|---|
| **Predictability** | Can you enumerate the steps in advance? | Low (single bounded task) | Low (you wrote the path) | High (unpredictable by design) |
| **Error cost** | Is a failure a retry, an audit finding, or a lawsuit? | Medium (the model's output distribution without step-level guards) | Low (deterministic guards between steps) | High (full distribution across many turns) |
| **Observability** | Can ops see what happened and reconstruct why? | Medium (easy to log, opaque inside) | Low (logs as code, standard tooling) | High (the trajectory reads like a transcript; most tooling can't alert on it) |
| **Latency budget** | Is there a user-visible deadline? | Low (fastest; thinking or retrieval adds time) | Medium (predictable but additive) | High (open-ended; **budget for the worst case, not the median**) |
| **Cost** | Per-request tokens at expected volume? | Low | Medium (scales with step count) | High (iterative reasoning, multi-turn tools, retries, growing context) |

**Rating-semantics caveat.** Every cell rates *how much the pattern costs or exposes you* on that factor, so **Low = good, High = bad**. That makes the Predictability row read backwards from intuition: Agent "High" means "high *un*predictability exposure", not "highly predictable". When you quote this table, say "exposure" or "cost" explicitly so a reader doesn't invert it.

Cost caveat: agents don't *automatically* cost more. Cost comes from **accumulated context and the number of model calls**, and a poorly designed workflow can cost more than a well-designed agent. Design matters more than the pattern label.

Hard requirements first: when an option violates a **stated hard requirement** (SLA, residency, governance), eliminate it first as a gate. Only then do multi-pillar trade-off analysis on what's left.

## 4. Agent bounding and the flexibility trap

**Production agents require these bounds. They are not optional:**
- **Constrained tool entry points.** Keep the tool surface as narrow as the task allows, because autonomy is your liability surface and an agent can do anything its tools allow, including untested combinations.
- **Per-turn budgets** (turn limit, token/cost budget).
- **Explicit permissions**, with human review of state-changing tools.
- **Stopping criteria**, plus a way to **measure whether the goal was met**.

Curate tools by necessity. Keep the ones that trace to defined tasks or regular hand-offs; drop the unrelated and the speculative. Every tool adds attack surface, context, authorization complexity and eval burden. The target is the smallest catalog that reliably completes the approved tasks.

**Watch Out: flexibility vs non-determinism.** Agents get chosen because a task *feels* open-ended, not because it requires one. "If you could have written the steps in code, you could have used a workflow." In an illustrative case, a 90-day retrospective found three compounding failures:
1. **Optimized for unknown future flexibility instead of the known present shape.** Mined traces showed only **four paths**, which needed a **router + four chains**. The team spent six months rebuilding that structure inside the loop, minus the logging.
2. **Non-determinism became a compliance problem.** An auditor asked "which step approved the disbursement?" and the only answer was a model turn. *This failure is about the agent pattern.*
3. **Unpinned model version.** It rolled forward with no re-validation. *This is a model-governance gap that hits any pattern*; a workflow would inherit it too.

Tells: guardrail tools accumulating in the loop, "didn't want to constrain it too early", audit requirements on approval steps, traces that cluster into a few shapes. Fix: routing plus chaining for enumerable paths, and pin model versions behind an eval gate whatever the pattern.

## 5. Improvement progression: prompting before fine-tuning

Go in order, and stop at the first step that meets the bar:
1. **Optimize the prompt.** Most reliability problems are prompt problems.
2. **Add tool use or retrieval.**
3. **Move to a stronger pattern**, such as evaluator-optimizer.
4. **Only then consider fine-tuning.**

Fine-tuning fits only when (a) volume is very high and inference cost is the real constraint, (b) latency is critical and a smaller specialized model beats a prompted general one, or (c) prompting hasn't produced a consistent format. Otherwise it **locks you to a fixed model version**. Fine-tuning Claude is not broadly available and varies by model and route, so confirm with the Anthropic account team and verify against current Anthropic docs before recommending it.

## 6. Packaging spectrum

**Prompt-only** (instructions alone) → **direct tool use** (the model calls functions in your code) → **Skills-based architecture** (a versioned Skill packaging procedure, instructions and scripts as one governed unit).

- Reach for a **Skill** when the same procedure **runs repeatedly, must be distributed across teams/products, or must be versioned and governed**. One owner-maintained Skill referenced by every workflow beats copies embedded in each system prompt, which drift.
- **Skill vs MCP:** procedural knowledge (instructions, templates, examples) with no live system calls → Skill. Calling live databases/APIs or authenticating to an IdP → MCP/integration.
- **Skill vs retrieval corpus:** a procedure Claude must *follow* → Skill. Reference material to *search* → retrieval.
- **MCP vs direct tool:** MCP only when one tool must be reachable from multiple Claude clients. A single stateless call to a stable existing API → a direct custom tool with server-side credentials and timeouts.
- Skills require the Code Execution Tool. Prompt-library vs Skill detail lives in `prompting-and-skills.md`.

## 7. Multi-agent orchestration

**When:** use it only when work genuinely exceeds one context or is too varied for one agent, never as a default. Multi-agent multiplies token spend (every subagent has its own context, and the orchestrator pays to synthesize). Use **the fewest agents that meet the requirement, with clear ownership of the goal.**

**Roles.** The **orchestrator** owns the goal: it decomposes, delegates and synthesizes, and **never does the sub-task work itself**. **Subagents** own scoped sub-tasks, each in its own context, and return a result.

**Three things to design, not assume:** (1) how the work is decomposed; (2) how each result is structured so it can be combined; (3) how the orchestrator resolves conflicts or gaps.

**Fan-out** (a 400-file audit, a 200-doc corpus, a filing checked against 50 rules): split into independent units, one subagent per unit, and run them in parallel wherever units don't depend on each other. There are two wins: a clean, unit-sized context per subagent, and concurrency.

**Failure-recovery asymmetry.** Subagent failure is usually recoverable; orchestrator failure usually isn't. So make subagent work **idempotent and retryable**, and **protect orchestrator state**.

| Failure | Where it lands | Design response |
|---|---|---|
| Subagent returns malformed/empty result | Subagent boundary (recoverable) | Validate each result; retry or re-route; **record the gap rather than failing the run** |
| Two subagents conflict | Synthesis (recoverable) | An **explicit conflict-resolution rule**, or escalate to a human |
| Orchestrator loses goal/synthesis state | Orchestrator (often unrecoverable) | Protect state; **checkpoint so a failed run resumes rather than restarts** |
| Traces fragment across agents | Observability (cross-cutting) | Propagate a **shared trace ID** end to end |

Also record **model ID and version on every turn**, and propagate correlation IDs/W3C trace context across agent, MCP and tool boundaries. Without them you can't attribute drift to a migration or stitch spans into one transaction.

**Coverage reconciliation (Watch Out).** In an illustrative case, a 50-section contract was fanned out one subagent per section. The summary said "48 sections reviewed, 3 flagged". One subagent had timed out and another returned empty on a scanned page, and the orchestrator counted only what it received. Fix: a **coverage check at synthesis**, where results returned must equal units dispatched or the run flags the difference before anyone reads the summary. Add retry/gap-flagging at the subagent boundary. "A multi-agent system fails most dangerously when the summary looks complete and is not." **Validate coverage, don't assume it.**

**HITL gates.** A gate pauses execution for review, positioned by the **risk and reversibility** of the next action. **Gate before any irreversible or high-stakes action; sample lower-stakes actions** instead of gating each one. The gate is part of the orchestration design, not bolted on.

**Critique checklist.** In a fan-out design, the defects to look for are: synthesis that sums returned verdicts without reconciling against dispatched units (most-missed); an irreversible action (auto-archive) with no human gate; no retry or gap-flag on failed subagents. A shared trace ID is the *correct* practice, and so are per-document decomposition and parallel subagents returning structured verdicts, so don't flag them as defects.

**Subagent justification.** Create a dedicated subagent for a *recurring* specialization that needs its own prompt, tool allow-list, model or permissions, or for isolating exploration from the main context. Don't create one for one-off or generic work.

## 8. The five reference architectures

They are "**references, not blueprints**": adapt the shape that fits, and recognize when a workload draws on more than one.

| Architecture | What good looks like | Where it goes wrong |
|---|---|---|
| **Agent** | Works toward a goal choosing tools and order. Autonomy checked by **limiting what tools can do** and a **turn budget**. For codebase investigation, multi-source research, complex case triage | **Unbounded autonomy**: state-changing tools with no human review, no turn limit, no measure of goal completion |
| **RAG** | A **stable corpus** (manuals, internal docs, regulatory text) chunked and indexed; most relevant chunks passed as context | **RAG for live state** (order status, inventory, ticket queues). "The index is a snapshot." |
| **Document processing pipeline → Evaluator-optimizer** | **OCR → extract fields against a schema → validate → route exceptions.** Evaluator-optimizer because first-pass extraction on edge cases isn't trustworthy unchecked | **No exception path**: low-confidence extractions go through the same pipeline as clean ones, with no human gate |
| **Customer-service / triage → Routing** | Classify intent, then route: **knowledge retrieval** for documentation questions, **transactional API** for live state, **human approval layer** for high-consequence actions | Retrieval for live order status; **no escalation path to a human**; **deploying an agent variant before the simpler routed workflow was measured** |
| **Coding agent** | Two phases: (1) **agentic investigation** of the codebase; (2) **deterministic edit steps: parse, plan, propose, test, review**. Subagents get enough context for isolated tasks, but not too much | Edits and commits **without a human review gate**; **no regression tracking against an eval set per language/framework**; treated as a conversation rather than a **structured pipeline with defined handoffs** |

Diagram critique. In a routing design the classic three defects are: retrieval over an "Order Status Index" (should be a tool call), an agent loop holding refund/cancel/update-address tools with no approval layer, and a **missing** escalation path. The missing path is the most-missed because it "isn't drawn", so critique a diagram for what's absent. Retrieval over a product-manual corpus is correct; don't flag it.

Simplest pattern that fits: cited compliance Q&A. When answers must be grounded and cited from a fixed authoritative corpus, with latency, cost and audit predictability as priorities, use an **augmented LLM with RAG** and citations in a single call. Multi-agent planner/researcher/writer stacks, open-web agents and whole-corpus stuffing are all wrong. Retain doc IDs, effective dates and retrieval scores for audit.

## 9. One pattern or two?

**Draw on a second pattern when the two parts of your problem break in different ways worth managing separately.** For example, routing hands some intents to an agentic loop, or a doc pipeline uses RAG over policy text on exceptions. If you're reaching for a second pattern because you haven't decided what problem you're solving, **adapt one**: "That's a design decision you're deferring, not a pattern you're applying."

The costs: composition roughly **doubles the surface area**, so when in doubt, pick one. Each architecture carries its **own eval contract**, so keep separate eval sets per architecture, because a healthy top-level score can mask a failing component.

## 10. RAG vs live tool call

"**Retrieval is for stable knowledge**: things true yesterday and true tomorrow. **Tool use is for live state**: things whose current value is owned by a system and changes independently of your index." Two types of data need two access patterns and two mechanisms. The skill involved is **context engineering**: deciding which mechanism puts each kind of data in front of the model.

**Watch Out trace.** In an illustrative trace, a customer asks "Where's my order?" Chunk #1 (similarity 0.78) said it shipped on the 12th, and chunk #2 (0.74) said it was "being processed". In reality the parcel had been returned to the depot with a damaged label, a state in *neither* chunk, and a live order-status API existed but was never called. **Similarity is not truth.** When index snapshots disagree, the model picks the most similar one and answers confidently. This is a *data-architecture* failure, not a retrieval failure. Fix it with a tool call to the order-status service. A better chunker, a shorter refresh interval or a higher similarity threshold won't fix it, and neither will a better embedding model.

Tells: multiple conflicting chunks about one entity at different times; time-sensitive questions ("where's my…", status, inventory, balance) answered from an index; an existing API the design doesn't call; answers that shift with each index refresh; RAG chosen because it worked on a previous use case. The risk is **stale but confident** answers with normal latency and no errors.

Other mechanism boundaries:
- **Persistent application state** (orders, records, balances) needs a tool call. **Memory/summaries** are application-managed, not a model capability.
- **Filter/join/count/aggregate over a schema** calls for a constrained **structured query**, not semantic similarity.
- **A large stable document reused across many queries** (e.g. an 80K-token filing queried 14 times) calls for **prompt caching** of the full document as a prefix, not RAG chunking or summarization, because caching keeps full context and quality at a fraction of the input cost. See `models-context-cost.md`.
- **Retrieved content is untrusted.** Screen it for indirect prompt injection, separate it structurally, and never let it elevate tool permissions. See `governance-safety.md`.

## 11. RAG chunking and indexing

**Chunking follows what the corpus *is* (structure), "not a default size."**

| Approach | How | When it earns its place |
|---|---|---|
| **Fixed-size** (with overlap) | Uniform spans regardless of structure | Homogeneous, unstructured text with weak boundaries; simplest to operate |
| **Semantic** | Split on meaning boundaries, topic shifts, sentence groups | Prose where a chunk must be self-contained; avoids mid-idea cuts |
| **Hierarchical** | Preserve sections/subsections; retrieve at the fitting level | Structured docs (contracts, manuals, policies) where section context carries meaning |

Fixed-size chunking is the usual wrong answer for structured docs (contracts, handbooks): it cuts across section boundaries and loses structural context. Finer cases: **code/specs** → function/class/tree-aware boundaries; **heterogeneous short records** → one record per chunk (fixed-size plus overlap only if records are similar length and flat). A single universal chunker degrades retrieval.

**Indexing follows how queries are *phrased*.**

| Strategy | Matches | When |
|---|---|---|
| **Dense** (embeddings) | Meaning, paraphrase, intent | Queries worded differently from the source |
| **Sparse** (keyword, e.g. BM25) | Exact terms, identifiers, codes, names | Part numbers, statute citations, error codes |
| **Hybrid** | Both | Mixed query patterns: **"the common production case"** |

**Reciprocal rank fusion (RRF)** is the standard, **low-tuning** way to merge hybrid's two ranked lists. Each result is scored by its rank in each list, so items that rank well in both win. It is "a design decision with a known, defensible default." Reranking is an accepted alternative.

**The three-way trade-off:** retrieval quality vs latency vs maintenance. Smaller chunks plus hybrid raise quality *and* latency. Larger chunks plus dense-only lower latency and maintenance but miss exact-match queries. No universal point is right, so state the choice as a trade-off you can defend. Size the pipeline to the query patterns you actually have, not the most thorough one imaginable. Retrieval quality isn't visible in the output, so **measure it against a labeled set**, and choose top-k by evaluation (quality, recall, latency), with deeper retrieval reserved for complex queries.

**Silent degradation.** A pipeline that was correct at launch can degrade silently as documents are added. Re-run the labeled retrieval eval whenever the corpus grows materially or is re-indexed.

**Method (worked example).** In an illustrative exercise, the corpus is about 4,000 docs: section-numbered contracts, long-form project write-ups and a structured methodology handbook. The queries are concept lookup, exact-clause lookup and broad synthesis.
1. Pick **one chunking choice per document type, by structure**: contracts and handbook → hierarchical (keeps clauses and procedures intact); write-ups → semantic (prose has no section anchors, and fixed-size cuts mid-idea).
2. Pick **one indexing choice for the corpus, by query mix**: hybrid dense plus sparse. Sparse handles exact targets; dense handles concept and synthesis queries.
3. **Name the load-bearing constraint** and justify its cost: here it is query variety, which earns hybrid's extra compute and fusion step.
The most common miss is the index: choosing dense-only or sparse-only when the query set contains both exact-clause and open-ended questions.

## 12. Decision rules

**Simplest pattern that fits** — When the task is well defined, verifiable and single-pass, choose an augmented LLM over a workflow or agent, because it's fastest, cheapest and has the fewest parts. Escalate only on measured shortfall.
- Trap: multi-agent "planner/researcher/writer" for routine cited lookup.

**Known stages → workflow** — When the steps and transitions are known in advance (extract → classify → summarize → persist), choose a workflow over an agent, because control flow in code gives predictable cost, logging, testing and audit.
- Trap: "agents are more accurate / more consistent", or "workflows can't call tools".

**Agent only when the path is genuinely unknowable** — When the path can't be enumerated *and* errors are recoverable, choose a bounded agent (narrow tools, turn budget, permissions, stopping criteria, goal measurement).
- Trap: an agent as the "safe default" for perceived open-endedness, when the paths could have been enumerated and routed.

**Measure the routed workflow before an agent variant** — In triage, ship and measure routing first, because the agent variant adds autonomy whose value is unproven.

**Split sprawling agents by domain; don't front them with a router** — When an agent's tools have sprawled across several distinct workflow domains and accuracy has dropped, decompose into domain-focused agents. Adding a tool-router agent costs an extra model call on every request and doesn't fix the sprawl. Two findings justify decomposition: (a) the tools span several distinct workflow domains, and (b) the router alternative would add a model call to every request. Overlapping tool descriptions and unused tools are local fixes (rewrite the descriptions, prune the tools), not evidence for decomposition; fix them first.
- Trap: "router pattern is well documented publicly", or "overlapping descriptions prove we need separate agents".

**Multi-agent only past one context** — When work genuinely exceeds one context or is too varied, choose orchestrator plus subagents with coverage reconciliation, retries, gates and trace IDs. Otherwise stay single-agent.
- Trap: multi-agent as a default; synthesis that "sums what it received".

**Explicit conflict rule** — When subagent results can conflict, give the orchestrator an explicit resolution rule or a human escalation, not synthesizer discretion.

**Retrieval for stable knowledge, tools for live state** — When data is a stable corpus, choose RAG. When a system owns its current value, choose a tool/API call.
- Trap: tuning the retriever (embedding model, refresh interval, threshold) to fix a live-state category error.

**Exception path in document pipelines** — When extracting from semi-structured docs, choose validation plus an exception route plus evaluator-optimizer over single-pass extraction, with low-confidence items gated to a human.

**Coding agent = exploration + deterministic pipeline** — Choose agentic investigation followed by parse/plan/propose/test/review, with a human gate before commit and per-language/framework regression evals.

**Prompt first, fine-tune last** — When reliability falls short, go prompt → tools/retrieval → evaluator-optimizer before fine-tuning, because fine-tuning locks a model version and has limited availability.

**Groundedness failures need generation-side controls** — When RAG answers contain unsupported claims, constrain answers to source content, require citations, and add claim verification. Evals detect the problem but don't prevent it.

**Chunk by structure, index by query mix** — Hierarchical for section-numbered docs, semantic for prose, fixed-size for homogeneous text, structure-aware for code. Dense for paraphrase, sparse for identifiers, hybrid + RRF for mixed queries.
- Trap: one chunker for everything; dense-only when exact identifiers matter; "hybrid = dense".

**Interaction shape picks the integration** — Stateless, latency-sensitive single call → direct API/custom tool. Reuse across AI clients → MCP. Stateful, long-running delegation between independently responsible agents → agent-to-agent handoff. Team familiarity and vendor docs don't decide it.

## 13. Sequencing
1. Decompose ownership (`decomposition.md`) **before** choosing a pattern.
2. Apply hard gates (SLA, residency, governance) **before** the five-factor or multi-pillar trade-off.
3. Walk the factors in order: **predictability → error cost → observability → latency → cost**. The first factor that rules out a pattern decides.
4. Name the reference architecture **before** building, because committing upfront avoids expensive pivots.
5. Ship and measure the simpler pattern **before** escalating to a stronger one.
6. Prompt → tools/retrieval → evaluator-optimizer **before** fine-tuning.
7. In multi-agent work, validate each result at the subagent boundary, then reconcile coverage at synthesis, then gate before irreversible actions.
8. For RAG, chunking per doc type, then index per query mix, then a labeled retrieval eval **before** tuning top-k; re-run that eval as the corpus grows.

## 14. Tempting wrong choices
- An agent chosen for "flexibility" when the paths are enumerable.
- A router layered on a sprawling agent instead of decomposing by domain.
- Multi-agent stacks for routine single-call lookups.
- RAG over live/transactional state, "fixed" by better embeddings or faster refresh.
- "Retrieval is bad", which flags a correct product-manual RAG as a defect.
- A fan-out summary that counts results received, not units dispatched.
- Flagging a shared trace ID as noise (it's the fix).
- A missing escalation path or human gate, overlooked because it isn't drawn.
- Composing two reference architectures to defer a decision.
- Fine-tuning reached for before prompt, tools and evaluator-optimizer.
- Dense-only indexing on a corpus with exact-ID queries.

## 15. Where the rules pull against each other
- **Routers.** One rule endorses routing (often a Claude classifier); for example, a router plus four chains is the fix for agent over-reach on enumerable paths. Another rejects a *tool-router agent* in front of a sprawling agent because it adds a model call per request. Reconcile: routing is right when inputs differ in kind and need different downstream handling. It is wrong as a patch over capability sprawl, where the fix is domain decomposition. Either way, count the router's extra call in the cost and latency budget.
- **More agents vs fewer.** One default is "the fewest agents that meet the requirement". The tool-sprawl fix *adds* agents (domain-focused ones). Reconcile: split when tools span distinct domains and accuracy degrades; otherwise stay minimal.
- **Chunking taxonomy.** A simple framing says semantic for prose and hierarchical for structured docs. A finer one maps semantic chunking on clause/paragraph boundaries *and* hierarchical chunking to long structured documents, and adds code-aware and per-record chunking. Reconcile: the principle (preserve the unit that carries meaning) is shared; the finer taxonomy just refines it.
- **Retrieval modes.** The core set is dense, sparse and hybrid (with RRF). **Structured queries** for filter/aggregate work and **reranking** as an alternative to rank fusion are also valid. Reconcile: treat these as extensions, not contradictions.
- **Integration options.** The core choice is direct tool vs MCP; **agent-to-agent handoff** and **Claude Managed Agents** widen the set. Reconcile: the same principle governs every option, so resolve governance or residency gates first. Verify Managed Agents availability and data-handling against current Anthropic docs.
