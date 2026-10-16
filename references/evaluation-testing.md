# Evaluation, Testing and Optimization

Use this file when a scenario involves building or sequencing evals, choosing a test type, gating a model or prompt change, diagnosing a regression, monitoring production, or cutting cost/latency without losing quality.

## Contents
1. Why evals exist
2. Eval anatomy and sequencing
3. Choosing the test type
4. Representativeness, stratification, subgroups
5. Gating changes: model migration, prompts, A/B experiments
6. Production: continuity, monitoring, drift
7. Diagnosing regressions
8. Optimization sequencing (cost and latency)
9. Recurring distractor patterns
10. Where the rules pull against each other

---

## 1. Why evals exist

Non-determinism is a property of the model, not a defect you fix: "you cannot certify behavior you only observed once." A demo that ran cleanly five times is not evidence of determinism; in an illustrative case, a reconciliation pipeline re-categorized the same statement differently in week two, and the change was found only by chance.

| Role of the eval | What it buys you |
|---|---|
| Release gate | A model or prompt swap is a code deployment; no eval set means no rollback signal |
| Design argument | "The eval set is not just a release gate, it's the only thing that makes the tier decision defensible during the design conversation" |
| Hidden-quality meter | Retrieval quality is not visible in output; it must be measured against a labeled set |
| Component contract | Each reference architecture carries its own eval contract; a healthy top level can mask a failing component |
| Rule watchdog | A rule the business counts on (e.g. a £5,000 routing threshold) needs test cases; in an illustrative case, treating it as "something the model would just handle" let 41 of 14,000 claims misroute silently |

Definition: an eval is a structured test set (inputs + expected outputs/criteria) producing comparable scores across models/prompts/configs; it decides improvement vs regression before production.

## 2. Eval anatomy and sequencing

**Minimum three components** for gating any model change:
1. **Curated test set** with known-good outputs covering the real distribution of work.
2. **Grading function** — model-graded against a rubric, or programmatic where the criterion is expressible in code.
3. **Delta threshold set in advance** below which you do not ship. Set it before running, or "you are writing the acceptance criteria after the build."

**Eval pipeline order**:

| Step | Before / after running inference |
|---|---|
| 1. Trace each stated requirement to a metric | Before |
| 2. Define metrics and slices (representative, edge, adversarial) | Before |
| 3. Curate and label data to match those slices | Before |
| 4. Fix thresholds / rollback criteria | Before |
| 5. Run the system against the dataset | — |
| 6. Score and aggregate, per slice | After |
| 7. Dashboards, release gates | After |
| 8. SME review of failures, rubric refinement | After (iterative) |

**Criteria before data** — When asked what precedes running an eval, choose "define metrics and slices" and "curate/label to match" over scoring, dashboards or SME rubric review because those need outputs to exist, and fixing criteria after seeing results introduces confirmation bias.
- Trap: "refine the rubric with SMEs" sounds rigorous but is a post-failure iterative step.

**Requirement-to-metric traceability** — When a scenario lists specific requirements (cost ceiling, "never expose data to unauthorized roles"), choose one metric that traces directly to each requirement over generic quality or ops metrics because criteria must be specific, measurable, achievable and relevant.
- For "never expose to unauthorized roles": access-control enforcement rate on a red-team dataset, target effectively 100%; ordinary functional tests miss bypass paths.
- For a cost ceiling: full per-query token cost (uncached input, cache reads/writes, output, thinking tokens) across normal, boundary and worst-case inputs.
- Trap: BLEU, throughput, p95 latency are real metrics that map to neither requirement.

**Outcome metrics over one proxy** — When one proxy metric looks strong (e.g. 89% first-response acceptance) but downstream overrides show criteria the system ignores, raise the input-scope gap and the outcome-validity gap over shipping, because acceptance does not show recommendations stay correct after expert review. Track override reasons, final agreement, financial impact.
- Trap: speculative statistical objections (survey representativeness, pilot length) with no evidence in the scenario.

## 3. Choosing the test type

Match the test to the objective it directly measures.

| Objective in the scenario | Test type | Not this |
|---|---|---|
| A change may have broken behavior that previously passed | **Regression** against a stable known-good reference set, consistent scoring | Adversarial, smoke, integration |
| Safety under attack (injection, malformed input) | **Adversarial / red-team** | Regression (measures established behavior only) |
| Cross-component correctness (auth → retrieval → prompt → model → validation → logging → downstream) | **End-to-end integration** | Prompt-template unit tests (one component) |
| Is the service up | Smoke | — (shallow; never answers quality) |
| Silent safety drift after model upgrade | **Stable adversarial set, version-attributed scoring, gated before promotion** | Random rotation, skipping evals, complaints |
| Retrieval returns the right chunk | **Labeled retrieval set** (recall@k) | Inspecting fluent answers |
| Groundedness of answers | Claim-to-source checks on sampled outputs | Fluency/BLEU |

**Pin the regression set** — When guarding against regression across upgrades, choose a fixed set with per-version scoring gated before promotion over rotating the set because only a stable set makes a change attributable and lets a regression block deployment.
- Trap: "rotate the set randomly to avoid overfitting" destroys comparability.

**Map control to the risk it most directly addresses** — An adversarial eval re-run on version change mitigates silent drift; it does not stop a malicious document at runtime and imposes no outbound authorization. Evals detect; runtime controls prevent.
- Trap: proposing "add a regression eval" as the fix for an active hallucination or injection problem. Generation-side constraints (citations, quotes, claim verification) prevent unsupported claims; evals only detect them.

**Evaluate behavior, not infrastructure** — Over-refusal and ungrounded answers are model-behavior failures needing model-specific evals, grounding and calibrated fallbacks; TLS expiry, DB timeouts and misrouted load balancers need monitoring and retries. Prompt changes do not fix infrastructure and infra fixes do not fix behavior.

**Per-architecture eval contracts** — When a solution composes two reference architectures (e.g. routing + RAG, doc pipeline + RAG on exceptions), keep a separate eval set per architecture rather than one for the composed system because a healthy top-level score can mask a failing component. For a coding agent, track regression rates against an eval set per language/framework. For per-step model tiers, build per-step evals.

## 4. Representativeness, stratification, subgroups

**Representative data** — When the eval set does not represent the deployment population (one region, one tenure band), choose expanding coverage to every population served and rescoring per slice before broader release, because aggregate scores on a narrow slice hide subgroup gaps and discriminatory outcomes.
- Trap: "scores are high, keep it"; narrowing further; replacing it with qualitative pilot impressions from a convenience sample (supplement, never substitute).

**Stratify and report per subgroup** — When migrating or optimizing, stratify the test set by category (document type, intent, language, population) and set per-category thresholds in advance, because one overall score hides partial regressions.
- Illustrative worked case: 250 representative, hand-validated documents stratified by type. Sonnet 0.94 avg, Haiku 0.86 avg; two types at 0.71 and 0.74. A pre-set rule "any single doc type below 0.85 → reject" rejected the swap; the salvage routed those two types to Sonnet via the existing classifier, the rest to Haiku.

**Fairness needs error analysis, not parity** — Approval-rate parity does not assess error-rate parity; agreement with human decisions is fidelity, not fairness (the labels may carry the bias). Use confusion matrices, FPR/FNR, calibration, intersectional slices, confidence intervals, override patterns; test the whole system, since bias enters via pretraining, prompts, retrieval, proxies and workflow. See governance reference for the full rule set.

## 5. Gating changes: model migration, prompts, A/B experiments

**Treat every swap as a release** — When a model version, tier, prompt template or output-schema config changes, re-run the eval against a new baseline because instruction following, formatting, tool choice, latency and cost can all shift; "the prompt-model pairing is what you are actually shipping."
- Trap: "validated once, done"; assuming a prompt tuned on one version transfers.

**Pin model versions** — Unpinned versions that roll forward with no re-validation are a model-governance gap that hits any pattern. For example, compliance asks "which version of the model" approved a disbursement, and it turns out the version rolled forward two weeks earlier unvalidated.

**Model-selection order**: define quality bar, latency tolerance, volume, cost → shortlist candidates from requirements and known capabilities → representative eval → compare quality and ops metrics → pick the cheapest model that reliably passes every gate → retest periodically and on each new version. Default: start at Sonnet; move up to Opus only when evals show Sonnet misses the bar; down to Haiku only when evals confirm the trade-off is acceptable. Model names and tiers are time-sensitive — verify against current Anthropic docs.

**Extended thinking is an eval decision** — Run evals without it first; fix the prompt; enable it only for a measured remaining gap, because thinking tokens bill as output and add latency on every call. A common finding in reviews is thinking enabled on a routing classifier for no gain.

**Pre-register A/B experiments** — When comparing two prompts with random assignment, choose to fix the hypothesis, primary success metric, minimum detectable effect and power-based sample size before launch over post-hoc analysis because pre-registration prevents metric cherry-picking and ensures the test can detect a meaningful change. Also fix significance thresholds, stopping rules, guardrail metrics and exclusion criteria; hold model version, retrieval config and tool availability constant as confounders.
- Trap: "promote/reject", "analyze vs predefined metric", "document the recommendation" are all post-data steps.

**Honor ranked priorities** — When options trade off (e.g. config cuts p95 latency 38% but drops accuracy 2%), choose the option matching the deployment's explicitly ranked priorities because optimization follows documented acceptance criteria. A measured regression cannot be waved off as variance without repeated evaluation.
- Trap: "latency generally matters more"; "2% is within noise".

## 6. Production: continuity, monitoring, drift

**Evals continue after go-live** — When a system is in production, keep the eval framework and reference set carried forward, sample production outputs for eval, and turn every production failure into a new test case, because the eval's value compounds over the lifecycle and a changing framework makes framework changes look like performance changes.
- Iteration loop: telemetry + sampled evals + stakeholder feedback → pick highest-impact change → validate offline against the existing baseline → controlled rollout → monitor → update docs and known limitations.
- Feed human-reviewer decisions back into the eval dataset.
- Trap: "stop measuring after launch"; "rebuild the evals each cycle".

**Measure prevalence before reacting** — When a single failure is reported (one fabricated citation after six months), sample recent outputs to estimate prevalence and audit the pipeline for missing grounding controls before choosing a response, because scope determines proportionate action.
- Trap: immediate shutdown with no diagnosis (may become right if severe); dismissing it as an anecdote; telling users it never fabricates.

**Specify monitoring before instrumenting** — Define metrics and slices across normal and adversarial traffic, SLOs and error budgets before instrumenting traces, because alert thresholds need observed normal-state data and dashboards/runbooks depend on final metric definitions.

**Log the model ID on every turn** — Record model identity and version per turn and propagate correlation IDs / W3C trace context (a shared trace ID) across agent, MCP and tool calls, because without them you cannot attribute behavior to a migration, reproduce a failure, or separate model drift from prompt or retrieval defects.

**Watch what drifts silently** — Retrieval pipelines degrade as documents are added; in an illustrative case, monolithic context grew from 4,000 to 80,000 tokens by turn 30 with no signal until billing; model-made decisions inside one request are invisible to logs built for SQL checks. Each needs an explicit measurement, not trust.
- A retrieval pipeline correct at launch can degrade silently as the corpus grows — re-run the labeled retrieval eval on every re-index and on corpus growth.

## 7. Diagnosing regressions

Evidence first, then change exactly one thing. Order:
1. Identify the change event (model version, prompt, template, schema config, maintenance window).
2. Build a minimal reproduction isolating one variable.
3. Diff current config (system prompt, output schema, stop sequences, structured-output setting) against last-known-good.
4. Replay identical pre-change requests against current and previous config/model version.
5. Inspect raw model output before parsing. Raw valid but pipeline rejects → fault is downstream (streaming assembly, transport, parser). Raw malformed → prompt, schema enforcement, stop reason, request config.
6. Only then fix, and confirm with the regression set.

**Investigate what changed, not what didn't** — When one component is known unchanged (retrieval pipeline) and answers start contradicting sources, check whether the failure reproduces on the previous model version and inspect grounding/citation instructions, rather than modifying the unchanged component.

**Avoid knee-jerk knobs** — When a regression appears (e.g. malformed JSON after a maintenance window), choose last-known-good comparison and controlled replay over speculative fixes because each knob adds a variable and weakens causal attribution:
- Lower temperature reduces variance, doesn't explain systematic error; raising it hurts repeatability.
- Switching model tier adds a confound.
- Clearing the prompt cache assumes corruption without evidence.
- Raising max_tokens is right only once `stop_reason` shows `max_tokens` truncation.
- New embedding model / more chunks / bigger window changes a component with no evidence of failure and adds noise.
- Immediate rollback before capturing a baseline destroys evidence (use rollback later as a controlled comparison).

**Diagnose a retrieval category error correctly** — When answers are stale-but-confident, contradict the database, and shift with index refresh, the cause is retrieval over live state; the fix is a tool call to the system of record, not a better chunker, shorter refresh or higher similarity threshold. "Similarity is not truth."

## 8. Optimization sequencing (cost and latency)

**Accuracy-preserving first** — When cost or latency must drop with quality held constant, first apply optimizations that keep identical information and model capability (prompt caching of the static prefix; caching reused retrieved chunks with source-version invalidation keys) over ones that change inputs or model (fewer chunks, truncated instructions, smaller model), because the latter need regression evals to prove equivalence.

| Order | Lever | Needs regression eval? |
|---|---|---|
| 1 | Prompt caching on stable prefix (static before dynamic) | No (same input) — still verify hit rate |
| 2 | Retrieval/result caching with invalidation keys | No |
| 3 | Trim retrieved context to relevant spans; eval-validated top-k; dedup, rerank, metadata filters | Yes |
| 4 | Per-step / per-type model routing (Haiku/Sonnet/Opus) | Yes, stratified |
| 5 | Drop or limit extended thinking where not earning its place | Yes |
| Last | Fine-tuning (locks a model version; limited availability — verify with Anthropic account team) | Yes |

**Both cost and latency** — choose prompt caching plus eval-validated routing of simple query types to a smaller model; reject larger max_tokens, full-corpus context or more few-shot examples per request, which enlarge input/output and worsen both.

**Latency-bound, quality already fine** — cut input tokens (empirically validated top-k) and cache the stable prefix; keep escalation to deeper retrieval for complex queries; never reach for the heaviest model.

**Name the load-bearing control** — When presenting a passing configuration, identify the budget with least margin and the single control that moves it (latency binds → tier and extended thinking; cost binds → tier and context strategy). A passing config without a named load-bearing control is lucky, not defensible. Illustrative list prices (per M tokens, in/out): Opus $15/$75, Sonnet $3/$15, Haiku $1/$5 — verify against current Anthropic docs.

**Retroactive per-step evals** — In an illustrative Opus-everywhere case, the fix was per-step eval sets, classifier → Haiku, summarization → Sonnet, Opus only on final composition: cost −71%, median latency 940 ms, CSAT unchanged. "Not choosing a model is equivalent to choosing the most expensive one."

**Caching can cost more** — Low call volume or a small fixed prefix may never amortize cache writes; a cache with dynamic content before the breakpoint never hits. Measure hit rate.

## 9. Recurring distractor patterns

- Wrong test type for the objective: regression offered for attack resilience; adversarial offered for prompt-template regressions; smoke tests as quality evidence.
- Evals as prevention: "add a regression eval" proposed for a live hallucination/injection problem that needs runtime controls.
- Criteria after data: scoring, dashboards, SME rubric refinement, or thresholds chosen after results.
- One aggregate number: average score, approval-rate parity, or acceptance rate treated as readiness; no per-slice reporting.
- Non-representative set kept because scores are high, or swapped for qualitative impressions.
- Rotating or rebuilding the reference set, destroying comparability.
- Knee-jerk knobs during diagnosis: temperature, model swap, cache clear, max_tokens, new embedding model, immediate rollback.
- Optimizations that change inputs/model offered before accuracy-preserving caching; "bigger model / more context / more examples" for a latency problem.
- Stopping evaluation at go-live; dismissing a measured regression as variance.

## 10. Where the rules pull against each other

- **Partial routing as salvage vs "unanalysed hybrid" as distractor.** One rule says routing failing doc types to Sonnet and the rest to Haiku is a sound salvage; another says "hybrid routing" is wrong when proposed without analysis (e.g. as a way around an SLA gate). Reconcile: routing is right only when per-slice eval data shows which slices need the heavier path.
- **Default starting tier.** One default says start with Sonnet and move deliberately; for high-volume, latency-sensitive closed-set classification (e.g. a moderation classifier), start with Haiku and escalate hard cases on eval evidence. Reconcile: Sonnet is the no-evidence default; a clearly light, high-volume workload profile justifies shortlisting Haiku first, still eval-gated.
- **Order of cost levers.** One framing leads with per-step model downgrades (the Opus-everywhere fix); another says apply information-preserving levers (caching) before model or input changes. Reconcile: both require evals for any capability change; when "accuracy must not change," apply caching first.
- **Scope of eval coverage.** One framing treats evals mainly as a pre-release and model-swap gate; a broader one adds production continuity, A/B design, monitoring specification and adversarial/fairness slices. Not contradictory; use the broader scope for any system going to production.
