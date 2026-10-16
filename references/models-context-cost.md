# Models, context, and cost

How to pick a model tier, size and shape the context, decide on extended thinking and caching, and work out cost and latency so a configuration holds up under review. These three decisions (model, context window use, context strategy) set cost at scale because they compound across every request.

## Contents
1. Four terms not to conflate
2. Model selection
3. A model swap is a release
4. Context sizing and the working-memory cliff
5. The four context strategies
6. Extended thinking, adaptive thinking, effort
7. Prompt caching economics
8. Cost and latency calculator, plus estimation recipe
9. Cost and latency optimisation rules
10. Sequencing
11. Recurring distractors
12. Where the rules pull against each other

---

## 1. Four terms not to conflate

| Term | What it is | Design consequence |
|---|---|---|
| **Context window** | The model's active attention space. Anything outside it doesn't exist to the model, and it resets between calls unless the app manages continuity | It is a ceiling with a hard edge, not storage |
| **Retrieval** | External knowledge fetched at query time. It **augments** the window and doesn't replace it | The model only sees what the retriever surfaces, so recall is a system you have to evaluate |
| **Persistent application state** | Owned by your system (order status, user records, balances) | **Requires a tool call**. Never retrieve it from an index, because the index is a snapshot |
| **Summaries / memory layers** | Continuity that the application manages | The model has no native memory between calls. Memory is an architectural choice, not a model capability |

Context strategy and context sizing are **separate decisions**. They interact but neither determines the other, and treating them as one is where most context-management designs go wrong.

---

## 2. Model selection

| Tier | Role | Illustrative calculator price in/out per MTok | Base latency |
|---|---|---|---|
| **Opus** | Most capable. Demanding reasoning, advanced coding, research synthesis where Sonnet misses the bar | $15 / $75 (illustrative; verify current pricing) | 1,900 ms |
| **Sonnet** | Balances intelligence, speed, and cost. **The default start** | $3 / $15 | 1,100 ms |
| **Haiku** | Fast and cheap. High-volume, bounded tasks such as classification and routing | $1 / $5 | 600 ms |

These figures are illustrative teaching values, not a price list (Opus list pricing in particular has changed across generations). In this set the ratios are: Opus 5× Sonnet, Sonnet 3× Haiku, and output 5× input on every tier. Verify current model names, prices, and latency against current Anthropic docs before quoting a partner.

**Start with Sonnet, move deliberately** — When there is no evidence yet, choose Sonnet over Opus or Haiku, because it balances capability and cost. Move up to Opus only when an eval set shows Sonnet misses the quality bar. Move down to Haiku only when an eval set confirms the quality trade-off is acceptable. Keep the moves "measured, not reflexive."
- Trap: "Use the best available model." It sounds safe in a demo and leaves nothing to defend later. "Not choosing a model is equivalent to choosing the most expensive one."

**Profile-led start for high-volume closed-set work** — When the workload is high-volume, latency-sensitive classification over a closed label set, start with Haiku over Sonnet, Opus, or extended thinking, because the task needs little reasoning depth and cost and latency dominate. Escalate to Sonnet only for the hard cases where evals show Haiku materially fails (subtle policy distinctions, multilingual ambiguity, adversarial edge cases), and route only those cases upward.
- Trap: Sonnet "because bigger", or Sonnet with thinking on every message. Both add latency and tokens with no metric gain.

**Per-step tiering** — When a pipeline has distinct steps, choose a tier per step, backed by per-step evals, over one global model ID, because steps differ in difficulty: classifier → Haiku, mid-pipeline summarisation → Sonnet, hardest final composition → Opus only if its eval demands it. Tiered routing (light model for routine requests, heavy model for hard ones) is the same idea applied to requests.
- Trap: Escalating to the "newest" or "most capable" model. Recency is not a selection criterion, and a new model must pass the existing gates before it replaces a validated one.

**The Opus-everywhere lesson (illustrative case)**
- In an illustrative case, the symptoms 90 days after launch were: monthly cost **7× the design-time cost projection**, median latency **2.3 s vs an 800 ms target**, CSAT **unchanged**. The overrun is the point: cost was never modelled during design.
- Causes: (1) the architecture doc had no model-tier decision at any step, so the implicit default shipped; (2) cost was reviewed monthly instead of being determined during development; (3) **extended thinking was on for a routing classifier** that didn't need it.
- Fix: build an eval set per step retroactively. Move the classifier to Haiku and summarisation to Sonnet (no regression on either), and keep Opus only on final composition. Result in this example: **cost −71%, median latency 940 ms, CSAT unchanged.**
- Lessons: "The absence of a deliberate choice is not neutral." "The eval set is not just a release gate, it's the only thing that makes the tier decision defensible during the design conversation." Cost that is visible only after launch turns design work into change management.

**Requirements before candidates** — When selecting a model for a new workload, define the quality bar, latency tolerance, expected volume, and cost ceiling, then shortlist candidates from that profile, and only then test. Testing without a decision frame produces numbers but not a defensible choice.

**Hard-gate elimination** — When an option violates a stated hard requirement (an SLA, a latency ceiling), eliminate it first, then compare the survivors on quality and cost. "Optimise after deployment" is not evidence of compliance. When ranked priorities are stated (accuracy first, latency second), follow them over general heuristics, and don't dismiss a measured regression as "within variance" without repeated runs.

**Fine-tuning is last** — Work through prompt → tools or retrieval → a stronger pattern (evaluator-optimizer) → fine-tuning, in that order. Fine-tuning locks you to a fixed model version and has limited availability (verify with the Anthropic account team). It fits only very high volume where inference cost binds, a critical latency budget where a specialised small model wins, or a format that prompting can't hold.

---

## 3. A model swap is a release

"A swap between two models is a code deployment." It looks like a one-line config change but rewrites product behaviour, and **the prompt–model pairing is what you ship**. Gate every swap on a minimum of three things:
1. A **curated test set** with known-good outputs that covers the real distribution of work.
2. A **grading function**: model-graded against a rubric, or programmatic where the check can be written in code.
3. A **delta or rollback threshold set before running the eval**. Otherwise "you are writing the acceptance criteria after the build."

No eval set means no rollback signal: by the time you see the regression, the user already has.

**Worked case: Sonnet → Haiku, done well (illustrative)**
- Context: in an illustrative case, a document-intelligence pipeline had run on Sonnet for 6 months, with the budget exhausted.
- Eval: **250 representative documents** with hand-validated targets, **stratified by document type**, scored with the same rubric for both models.
- Result: Sonnet averaged **0.94** and Haiku **0.86**. The variance was concentrated in two document types at **0.71 and 0.74**, and the rest were within tolerance.
- Pre-set rollback criterion: **any single doc type below 0.85 → reject.** The swap was rejected as proposed.
- Salvage: **partial migration.** The existing classifier routes those two types to Sonnet and everything else to Haiku. Cost drops materially with no regression.
- Why it worked: the criterion was fixed before the data arrived, so nobody could negotiate with it afterwards, and stratifying by type surfaced a split that a single average would have hidden.

**Stratify and pre-set** — When migrating models, stratify the eval by category, set per-category thresholds in advance, and prefer partial routing over an all-or-nothing switch.
- Trap: Accepting a good overall average. One healthy number can hide a failing category.

**Re-baseline the prompt on migration** — When the model version changes, re-evaluate prompts against a new baseline instead of assuming a prompt validated on the old version transfers. Instruction following, formatting, tool choice, latency, and cost can all shift.
- Trap: "Validated once, done."

**Pin versions and keep a stable regression set** — Pin model versions. Before promoting any upgrade, re-run a **fixed** regression set, including adversarial cases, with version-attributed scoring. A stable set makes changes attributable and lets a regression block the deployment.
- Trap: Rotating eval items at random, which destroys comparability. Relying on user complaints, which is incident handling, not evaluation.

**Record the model ID on every turn** — Log the model ID and version with each turn so that behaviour changes can be attributed to migrations and model drift can be told apart from prompt or retrieval defects. When a regression appears and one component is known to be unchanged, replay identical requests across versions, and only change the component that actually changed.

---

## 4. Context sizing and the working-memory cliff

Working memory has the hardest edge of the four properties: "things work until they don't, and then the transition is abrupt."
- **Everything counts**: system prompt, conversation history, retrieved documents, tool definitions, tool outputs, and model responses, including thinking.
- **Measure, don't estimate.** Characters-per-token varies by model generation, tokenizer, and language. Read the **`usage` field** on every response, because that is what limits and billing use. Call the **token-counting API** before sending large requests (verify current endpoint behaviour against current Anthropic docs).
- **The window is a ceiling, not a target.** Budget = largest realistic conversation + retrieved context + system prompt + working scratch + **margin for growth**.

Error names and stop reasons below are API details that can change; verify against current Anthropic docs.

| Failure | When it happens | Signal |
|---|---|---|
| Prompt over the token limit | Rejected before generation | `400 invalid_request_error` ("prompt is too long") |
| Raw body over the byte limit | Rejected before generation | `413 request_too_large` |
| Prompt fits but generation hits the window | Mid-generation | stop reason `model_context_window_exceeded`, truncated output |
| Output hits the requested cap | Mid-generation | stop reason `max_tokens`, truncated output |

**Diagnose truncation from stop_reason** — When output is cut off or JSON comes back malformed, read `stop_reason` and the raw model output before changing anything. Raise `max_tokens` only when `stop_reason` shows `max_tokens`. If the raw output is valid but the pipeline rejects it, the fault is downstream: stream assembly, transport, or the parser. After a change event, diff the prompt and output-schema config against the last known-good version and replay.
- Trap: Raising `max_tokens`, clearing the cache, or switching tier on speculation. Each one adds a variable and blurs the causal attribution.

**Pre-message bloat means tool schemas** — When context is heavily used before the user types anything (say 50k tokens), suspect upfront tool definitions from many MCP servers. Enable **Tool Search** (deferred schema loading) over disabling servers, adding a summarisation step, or using a bigger window, because only the tools actually selected then enter context and no capability is lost. Also sharpen tool descriptions so discovery finds the right tools, and keep only eval-justified core tools non-deferred.
- Trap: Blaming client-side factors, or claiming the model "reserves" context.

---

## 5. The four context strategies

| Strategy | Earns its place | Breaks |
|---|---|---|
| **Monolithic**: everything in the prompt at once | Bounded tasks with predictable input size; **stable prefixes that benefit from caching**; single-shot Q&A where retrieval latency isn't worth paying; reasoning that needs all the material at once | Context accumulates turn over turn; **cost and latency scale linearly with input**; attention degrades well before the hard limit; the window fills silently |
| **Progressive**: carry forward only what the next step needs, retrieve just in time, summarise across turns | Multi-turn dialogue, iterative refinement, agent loops that depend on recent state, staged workflows with narrow handoffs. **"The right default for most production workloads."** | Long-range coherence; decisions that depend on detail dropped earlier; **caching gets harder when carried-forward context mutates**; the exact input at step N can't be reconstructed for debugging |
| **Retrieval (RAG)** | Knowledge bases too large for context; sources that change faster than prompts are redeployed; queries that need only a slice; **citations required** | Synthesis across many documents the retriever scores independently; chunking that splits semantic units (tables, code, arguments); **recall failures** where the right document never makes the top-k; retrieval quality becomes another system to evaluate |
| **Compaction**: periodically summarise or compress | Long-running agents and conversations; phase transitions that checkpoint to a clean summary; sessions that would otherwise hit the limit mid-task | Drops load-bearing detail (**exact identifiers, numeric values, prior decisions, edge cases mentioned once**); the summariser is itself a model call; **largely one-way**; summary fidelity is "an unsolved evaluation problem" |

**Combining strategies: a long-running coding agent.** Session start (task plus referenced files) uses a **monolithic prefix**, small, stable, and cacheable. Active work uses a **progressive** recent window. Needing a file that isn't loaded triggers **just-in-time retrieval**. A filling context triggers **compaction** ("what we tried and what we learned"). No single strategy carries the whole session.

**Four design questions.** Each is a separate question; answer all four:
1. What does the model need at the start? → monolithic baseline
2. What does it need from the most recent steps? → progressive window
3. What might it fetch on demand? → retrieval layer
4. What earlier material can be compressed without losing decision-relevant detail? → compaction policy

**Progressive for long-lived work** — When the workload is multi-turn, an agent loop, or staged, choose progressive over monolithic. "Monolithic context is the silent budget killer": for example, a conversation that starts at **4,000 tokens can carry 80,000 by turn 30**, and nothing signals it until the bill arrives.

**Compaction keeps identifiers** — When compacting, explicitly preserve identifiers, numbers, prior decisions, and one-off edge cases, or move them into structured state that the summariser can't drop.

**Smallest useful context** — When deciding what evidence or history enters a request (summarising old turns, trimming retrieved passages to the relevant spans), curate the smallest useful context, because extra tokens cost money and also reduce recall and accuracy.

**Retrieval is for stable knowledge only** — When a question depends on a current value owned by a system (status, stock, balance), use a tool call, not retrieval. "Similarity is not truth." Also covered in the architecture references.

---

## 6. Extended thinking, adaptive thinking, effort

- Extended thinking is a per-request capability: the model reasons in a separate block of **thinking tokens** before answering. Those tokens are **billed as output** at the standard output rate and add latency. If thinking isn't engaged, no thinking tokens are generated or billed. The API may return a *summarised* thinking block, but you're billed for the tokens actually consumed.
- Controls: on **Opus 4.6+, Sonnet 4.6+, and Sonnet 5**, use **adaptive thinking with the `effort` parameter** (set an effort level, not a token budget). Adaptive is the **only** mode on **Claude Fable 5**. Manual **`budget_tokens`** is deprecated on the 4.6 generation and **removed on Sonnet 5, where it returns a 400**. These controls are time-sensitive, so verify against current Anthropic docs.
- The model reasons internally either way. The decision is whether to pay for an expanded reasoning pass.

**Thinking needs a measured gap** — When accuracy falls short, fix the prompt first, then run evals without thinking. Enable thinking only for the gap that remains, and only on the steps that show it (for example per clause in a contract review, where an eval justifies it). Thinking stays off unless an eval shows a measured accuracy gap that remains after prompt work; classifiers and routers rarely qualify, and they pay the latency on every call.
- Trap: "It can't hurt." In the illustrative calculator (§8), thinking adds **+1,500 ms and +2,000 output tokens per call** on every tier.

---

## 7. Prompt caching economics

The cache matches on a **stable prefix**. Mechanics such as breakpoints, ordering, and TTL are in `prompting-and-skills.md`. The architecture questions are whether caching pays and what it does to tenancy.

- Typical multipliers (**verify against current Anthropic docs**): a cache write costs about **1.25× base input** (5-minute TTL) or **2×** (1-hour TTL), and a cache read costs about **0.1× base input**. There is a minimum cacheable prefix length that varies by model.
- Caching pays when the prefix is large and called often enough within the TTL that reads amortise the writes. With infrequent calls or a small fixed portion, "caching can cost more than it saves".
- The cache is isolated per organisation (and per workspace where supported) and held in memory, not persistent storage. That matters when tenancy or residency is raised.

**Cache the reused document; don't shrink it** — When a large, stable document is queried many times (say an 80k-token filing queried 14 times), choose prompt caching of that document as the prefix over summarising it, chunking it into RAG, or moving to a smaller model, because caching cuts cost while keeping the full context and therefore the quality. The alternatives all change the input or the model and need re-evaluation.

**Information-preserving optimisations come first** — When cost must fall with no change in accuracy, apply the optimisations that keep identical information and capability first: prefix caching and retrieval caching keyed on source version. Only after that consider fewer chunks, trimmed instructions, or a smaller tier, and each of those needs a regression eval to prove equivalence.
- Trap: "Switch to a cheaper model" as the first step.

---

## 8. Cost and latency calculator, plus estimation recipe

**Calculator formula.** All values in this calculator (token counts, prices, base latencies, the thinking and monolithic increments) are illustrative teaching values chosen to show the ratios and trade-offs; they are not measurements or current list prices. Verify prices against current Anthropic docs before quoting a figure.
- Input tokens: **monolithic 8,000; progressive 2,500.** Output tokens: **600, plus 2,000 if thinking is on.**
- `costPerCall = inTok/1e6 × price_in + outTok/1e6 × price_out`
- `monthly = costPerCall × callsPerDay × 30`
- `latency = base[model] + (monolithic ? 300 : 0) + (thinking ? 1500 : 0)` ms

Selected configurations at 10,000 calls per day (the default readout is Sonnet / progressive / thinking off; Opus rows use the illustrative $15/$75, verify current pricing):

| Config | $/month | Latency |
|---|---|---|
| Opus, monolithic, thinking on | 94,500 | 3.7 s |
| Opus, monolithic, off | 49,500 | 2.2 s |
| Sonnet, monolithic, off | 9,900 | 1.4 s |
| **Sonnet, progressive, off (default)** | **4,950** | **1.1 s** |
| Sonnet, progressive, on | 13,950 | 2.6 s |
| Haiku, progressive, off | 1,650 | 0.6 s |
| Haiku, monolithic, on | 6,300 | 2.4 s |

Reading the table: thinking adds about 1.5 s on every tier, which makes it the single biggest latency control, larger than any tier change (the whole Opus→Haiku spread is about 1.3 s). Monolithic adds 300 ms and roughly triples input cost. Opus monolithic costs 10× Sonnet progressive. The cost ceiling and the latency budget must both pass at the same time; one can't be traded against the other.

**Name the load-bearing control** — When presenting a configuration that passes, identify the **binding budget** (the one with the least margin) and name the single control that moves it. If latency binds, thinking and model tier are load-bearing. If cost binds, tier and context strategy are load-bearing. "Naming it explicitly is what makes the configuration defensible rather than lucky." Several configurations can usually pass a given cost and latency budget; the job is to find one that meets the binding budget and name its load-bearing control, not to find "the" configuration.
- Trap: Pointing at call volume because "it's the only input you can't change". Volume is real, but it isn't the control you design with. Also wrong: "once both are green, any setting can change freely". A binding constraint still exists; it is just invisible until a setting moves.

**Recipe: estimate cost for a design**
1. **List every model call per request** (classifier, retrieval-augmented answer, evaluator pass, retries, subagents). Cost follows accumulated context and number of calls, not the pattern label.
2. **Assign a tier per call** (§2).
3. **Size the tokens per call.** Input = system prompt + tool definitions + history + retrieved context + tool results. Output = answer + thinking. Split input into a *stable prefix* and a *per-request* part. Confirm with the token-counting API or `usage`. Inputs other than text are large. A scanned page or photo typically costs on the order of 1–1.6k tokens per image, and a PDF page costs its text plus its image, so a multi-page claim pack with photos can reach tens of thousands of tokens. History grows every turn. Verify current image-token rules.
4. **Price it.** `prefix × read rate (or the base rate if uncached) + dynamic × base input + output × output rate`. Add amortised cache writes (writes per TTL window × prefix × write rate). Caching only applies above a minimum cacheable prefix length, which varies by model. A short prefix may not cache at all, especially on smaller tiers, so check the current minimum before counting the savings.
5. **Scale it**: × calls/day × 30. Price the worst case as well as the median (long conversations, maximum retrieval, retries), because agents should be budgeted for the worst case.
6. **Latency**: sum the sequential calls on the critical path, using parallel branches at their slowest member, and add retrieval time and thinking. Report p95, not just the mean. Say which latency you mean: time to first token (what a streaming user feels) or time to the complete answer (what a downstream system waits for). Output length drives the second.
7. **Check both budgets, name the binding one and its load-bearing control.** Write the figures into the design doc, since cost found after launch becomes change management.

**Worked example** (Sonnet $3/$15; cache multipliers as in §7, verify):
- Setup: 10,000 calls/day, a 6,000-token stable prefix, 2,000 dynamic input tokens, 500 output tokens.
- Uncached: (8,000 × $3 + 500 × $15)/1e6 = $0.0315 per call, about **$9,450/month**.
- Cached: prefix 6,000 × $0.30/1e6 = $0.0018, plus dynamic $0.006, plus output $0.0075, giving $0.0153 per call, about **$4,590/month**. Traffic of roughly 7 calls/minute keeps a 5-minute cache warm, so writes are negligible.
- The 80k-filing case: 14 uncached queries cost about $3.36. One write ($0.30) plus 13 reads ($0.31) costs about $0.61, roughly 80% less with identical context.

---

## 9. Cost and latency optimisation rules

**Cut cost and latency together** — When both must fall, choose prefix caching plus eval-validated model routing (simple query types go to the smaller tier) over raising `max_tokens`, adding context, or adding few-shot examples to every request, because those enlarge input or output and make both worse.

**Latency-bound with quality already fine** — Reduce retrieval to an **eval-validated top-k** and cache the stable system prompt, keeping deeper retrieval as an escalation for complex queries. Don't reach for a bigger model or deeper retrieval.

**Repeated prompt plus oversized retrieval** — When cost comes from a long repeated system prompt and large retrieved context, combine prefix caching with query-specific pruning (relevance scoring, dedup, metadata filters, reranking, token budgets), then confirm accuracy holds.

**Measure full per-query cost** — When there's a cost ceiling, measure uncached input, cache reads and writes, output, and thinking tokens across normal, boundary, and worst-case inputs. A mean over typical inputs isn't enough.

**Order request-lifecycle tactics by stage** — Input preparation (summarise history, trim retrieval) → prompt construction (cacheable prefix first, dynamic content after) → output handling (validate against the schema, then persist).

**Keep LLMs off hard real-time paths** — When a decision must happen in under 50 ms or must be deterministic, use specialised systems and keep LLM inference off the critical path.

---

## 10. Sequencing

1. Define success criteria: quality bar, latency, volume, cost ceiling. **Then** shortlist, **then** run the representative eval, **then** pick the cheapest model that reliably passes every gate, **then** retest periodically.
2. Set the rollback or delta threshold **before** running the swap eval.
3. Optimise the prompt **before** enabling thinking, and run the eval without thinking **before** turning it on.
4. Apply information-preserving optimisations (caching) **before** input-changing ones (trimming, fewer chunks, smaller tier), and run a regression eval **before** shipping any input-changing one.
5. Model cost **during design, before launch**, not in a monthly review afterwards.
6. Diagnose (`stop_reason`, raw output, config diff, replay) **before** fixing.
7. Eliminate options that fail a hard gate **before** any multi-factor trade-off.

---

## 11. Recurring distractors

- "Use the most capable (or newest) model" with no eval. That is an implicit choice of the most expensive option.
- Extended thinking or chain-of-thought on classification or routing with no measured gap, which costs latency and tokens on every request.
- Treating a model swap as a config change with no stratified eval, no pre-set threshold, and no rollback.
- Trusting one overall eval average when per-category stratification would reveal a partial migration.
- Raising `max_tokens`, using a bigger window, or adding retrieval depth to fix cost, latency, or truncation without reading `stop_reason`.
- Summarising, chunking, or downgrading the model to save cost when caching would keep identical quality.
- Monolithic context on long-lived multi-turn work, which grows silently (in the illustrative case above, 4k → 80k by turn 30).
- Retrieval standing in for live state, or compaction dropping identifiers and numbers.
- Disabling MCP servers, or using a bigger context, instead of Tool Search for a large tool catalog.
- Naming call volume, or "nothing", as the load-bearing control.

---

## 12. Where the rules pull against each other

- **Starting tier.** One default says start on Sonnet and move down to Haiku only after an eval confirms it. For high-volume, closed-label classification, start on Haiku and escalate hard cases to Sonnet. Reconcile: Sonnet is the default when there's no evidence. When the workload profile (volume, latency, closed labels) is known up front, a profile-led shortlist can start lower. Either way, evals decide.
- **Monolithic vs progressive.** One rule calls progressive "the right default". Another prefers caching a whole 80k document over RAG or summarisation when quality must not change. Reconcile: these are compatible. Monolithic earns its place for a stable, cacheable prefix, and progressive is for context that accumulates.
- **Prices.** The calculator uses Opus at $15/$75 as an illustrative teaching value (illustrative; verify current pricing), while real list prices change across model generations. Reconcile: use the calculator for ratios and trade-off reasoning, and verify current list prices and cache multipliers against current Anthropic docs before quoting any figure.
