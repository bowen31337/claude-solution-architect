# Glossary

One line per term, alphabetical, covering the vocabulary used across these references. Prices, model names, feature availability and FedRAMP scopes change; verify against current Anthropic docs.

## A
- **Accountability (delegation test)** — Who must answer for a wrong call; with reversibility and stakes, one of the three justifications for whether Claude should own a part of the work.
- **acceptEdits** — Permission mode that auto-approves file edits and common fs commands (mkdir, touch, rm, mv, cp, sed); other Bash still prompts.
- **Adaptive thinking** — Extended thinking where the model decides whether and how much to think per request, steered by an `effort` level rather than a token budget; recommended on current models, the only mode on the newest.
- **ADR (Architecture Decision Record)** — Version-controlled record of context, decision, alternatives considered, trade-offs/consequences, date, authors, owner and reconsideration triggers.
- **Agent (pattern)** — Model given a goal and tools that chooses its own sequence of calls; control flow lives inside the model. Use only when the path cannot be enumerated and wrong outputs are recoverable; bound with narrow tools, per-turn budgets, explicit permissions, stopping criteria.
- **Agent (reference architecture)** — Goal-driven tool use with limited tool power and a turn budget; goes wrong as unbounded autonomy with state-changing tools and no review, turn limit or goal measure.
- **Agent SDK (Claude Agent SDK)** — Managed agent runtime (`@anthropic-ai/claude-agent-sdk`, `claude-agent-sdk`) exposing the loop that powers Claude Code, for embedding multi-turn agents in your product; not the same as the Anthropic SDK.
- **Agent Teams** — Primitive whose job is *coordinate peers*: multiple agents as coordinated peers, each owning part of a larger goal.
- **Agent-to-agent handoff** — Integration choice for stateful, long-running delegation between independently responsible agents.
- **AI Fluency 4D** — The four competencies: Delegation, Description, Discernment, Diligence.
- **AI-appropriate / human-retained / collaborative work** — The three delegation-map categories; collaborative = Claude drafts, a person decides.
- **API (Direct API)** — Direct HTTP requests to Claude; full control, and you own retries, streaming, tool plumbing, UI, logging. Maximum control vs maximum responsibility.
- **Approval gate / HITL checkpoint** — A gate that pauses execution for review, placed by the risk and reversibility of the next action; gate irreversible actions, sample low-stakes ones.
- **Augmented LLM (augmented call)** — The simplest agentic pattern: a single Claude call enhanced with tools or retrieval, no multi-step orchestration; control flow never branches on the model's decision.
- **Authoritative** — The source agreed to be treated as correct (system of record, live policy table, current price list), not model recollection.
- **auto (permission mode)** — Classifier approves safe actions and blocks risky ones; research preview, admin-enabled on Team/Enterprise; defaults to the Anthropic API as provider, with an environment variable enabling cloud-provider routes (verify current docs).
- **AWS Bedrock** — AWS managed service for accessing Claude inside a customer's AWS environment; AWS billing, IAM auth, inference profiles for cross-region routing.

## B
- **BAA (Business Associate Agreement)** — HIPAA contract governing how a vendor handles PHI for a covered entity; coverage is per configuration, and beta features are generally excluded unless listed.
- **Bedrock GovCloud** — Government route on AWS: FedRAMP High plus DoD IL4/5.
- **BM25** — Standard sparse/keyword ranking function; matches exact terms, identifiers, codes, citations.
- **Build-time interfaces** — How code reaches Claude: Direct API, SDKs, MCP, Agent SDK. They layer on one another rather than being alternatives.
- **Business-value pillars** — Efficiency (same unit of work done faster or more per person within the existing process), productivity (realized organizational output beyond per-task speed), transformation (structural redesign of roles or process), solution cost (spend vs the approved cost model), performance SLA (measured metric vs committed threshold).
- **bypassPermissions** — Permission mode that skips all checks; only for isolated containers/CI.

## C
- **Cache breakpoint** — Boundary between the stable cacheable prefix and per-request content; static before dynamic, always.
- **Capability bloat** — Tools accumulated beyond defined tasks; adds attack surface, context cost, authorization complexity and eval burden.
- **Chain-of-thought (CoT)** — Asking the model to reason step by step; for multi-step logic where the path matters, not a default.
- **Chaining** — Workflow sub-pattern: sequential steps, each consuming the previous output.
- **Chunking** — Splitting documents into retrievable units before indexing, chosen by corpus structure: fixed-size, semantic, hierarchical.
- **Citations / search-result blocks** — API features that ground answers in supplied sources and render attributions; the simple pattern for cited RAG over an authoritative corpus.
- **Claude Code** — Agentic coding tool (CLI, IDE plugins, desktop, claude.ai/code) under permission boundaries; customized via CLAUDE.md, Skills, subagents, hooks, MCP, permissions. An entry point, for engineers.
- **Claude Cowork** — Desktop agent for non-developers working with local files and apps under configurable permissions.
- **Claude for Excel / Claude in Chrome** — Spreadsheet agent for analysts; browsing agent for work anchored in web apps.
- **Claude for Government (C4G)** — FedRAMP High civilian offering; government environments run on a model lag.
- **Claude for Work** — Team tier (admin controls, SSO/SAML, domain capture, contractual no-training) and Enterprise tier (adds SCIM, configurable retention, audit logs, Compliance API, HIPAA-ready option with BAA).
- **Claude Managed Agents** — Anthropic-hosted agent harness; validate data handling (inference location, persistence, residency) against policy before adopting.
- **Claude.ai** — Anthropic-hosted end-user chat (web, mobile, desktop) with Projects, uploads, connectors; for users, not builders; zero build cost vs zero integration.
- **CLAUDE.md** — Markdown loaded at Claude Code session start with standing conventions and context; commit at project scope; a shaping layer.
- **Code Execution Tool** — Sandboxed execution environment; required for Skills via the API.
- **Coding agent (reference architecture)** — Agentic investigation plus deterministic parse, plan, propose, test, review steps; human gate before commit; per-language/framework regression evals.
- **Compaction** — Context strategy that periodically summarizes/compresses history; risks dropping identifiers, numbers, prior decisions, one-off edge cases; largely one-way.
- **Compliance API** — Enterprise-tier programmatic access to compliance data; part of the vendor affordance inventory.
- **Confidence is not correctness** — Property consequence that makes HITL placement and verification architectural choices.
- **container.skills** — API parameter attaching Skills to a request.
- **Context engineering** — Deciding which mechanism is responsible for getting each kind of data in front of the model.
- **Context strategy** — How context is assembled across calls: monolithic, progressive, retrieval, compaction; usually combined; separate from context sizing.
- **Context window** — The model's active attention space; outside it nothing exists to the model; a ceiling, not a target.
- **Corpus** — Documents a retrieval system searches, indexed ahead of time; for stable reference, not live state.
- **Correlation ID / shared trace identifier** — ID propagated across orchestrator, subagents, MCP and tool calls so a run is reconstructable end to end.
- **Cost · Complexity · Risk** — The standard trade-off triad, applied to every decision.
- **Coverage reconciliation** — Check at synthesis that results returned equal units dispatched, flagging the gap before anyone reads the summary.
- **CSP delivery route** — Path API traffic takes (Anthropic, Bedrock, Vertex AI, Foundry); decides billing, identity, region, contract, not model behaviour; CSPs lag first-party features by weeks.

## D
- **Data residency** — Where data is physically stored or processed; drives region pinning.
- **default (permission mode)** — Asks before each action.
- **Defense in depth** — Layered controls (input screening, least-privilege tools, output validation, human confirmation, audit) so no single failure exposes the system.
- **Delegation** — First 4D competency: deciding not just whether Claude *can* do a part but whether it *should* own it.
- **Delegation map** — Output of decomposition: each part assigned to Claude, existing systems or humans, justified by reversibility, stakes, accountability.
- **Delivery routes** — Where the request runs: Anthropic first-party, AWS Bedrock, GCP Vertex AI, Microsoft Foundry.
- **Dense retrieval** — Embedding-based semantic matching; handles paraphrase and intent.
- **Description** — 4D competency: telling the model precisely what you want, naming scope, format and constraints.
- **Deterministic drift** — Anti-pattern: a rule that must be right every time moved into a model that is right most of the time, producing silent misroutes.
- **Deterministic rule** — Same input, same output every time; keep in the existing system.
- **Diligence** — 4D competency: taking responsibility for verifying and standing behind AI output.
- **Discernment** — 4D competency: critically evaluating AI output and evidence, e.g. proxy metrics or fairness claims.
- **Document processing pipeline** — Reference architecture: OCR, schema extraction, validation, exception routing, often evaluator-optimizer; fails with no exception path.
- **dontAsk** — Permission mode that auto-denies anything that would prompt and runs only allow-rule-covered actions; the mode for locked-down CI.
- **DPA (Data Processing Addendum)** — Contract terms for processing personal data, required alongside technical and operational controls under GDPR.
- **Dynamic Workflows** — Primitive whose job is *compose at runtime*: assemble a workflow's steps at runtime instead of fixing them in advance.

## E
- **Effort parameter** — Control for adaptive thinking; set effort, not `budget_tokens` (deprecated on the 4.6 generation, removed on Sonnet 5).
- **Entry points** — The interface people or systems use to reach Claude (Claude.ai, Claude Code, custom app); decides who can talk to Claude, what it can touch, how much engineering is needed.
- **Error cost** — Second of the five factors: is a mistake a retry, an audit, or a lawsuit?.
- **Eval** — Structured test set (inputs plus expected outputs or criteria) yielding comparable scores across models, prompts and configs; needs a curated set, a grading function, and a delta threshold set in advance.
- **Evaluator-optimizer** — Workflow sub-pattern: generator attempts, evaluator critiques, loop until criteria pass or retry limit.
- **Existing systems** — Owner bucket for anything the partner already paid to make reliable: rules engine, database of record, policy service.
- **Extended thinking** — Separate block of thinking tokens before the answer; billed as output, adds latency; enable only for a measured accuracy gap.

## F
- **Fan-out** — Splitting one task across parallel agent calls; a common source of silently dropped units if not tracked.
- **Few-shot** — Prompting with input/output examples; for formats or judgments easier to show than describe.
- **Fine-tuning** — Last step after prompt, tools/retrieval, evaluator-optimizer; locks a model version, limited availability.
- **Five factors** — Pattern-selection sequence: predictability, error cost, observability, latency budget, cost; the first factor that rules out a pattern decides.
- **Four key decisions** — What Claude owns; what shape the work is; which reference architecture; where the work meets Claude (entry point, model, context).
- **Four properties** — Next-token prediction, knowledge, working memory, steerability; forces you design around.
- **Functional vs non-functional requirement** — What the system does vs how well (latency, cost, availability, privacy, compliance); a strong NFR has metric, threshold, method and conditions.

## G
- **Generator-verifier loop** — Mitigation for next-token-prediction errors: one step produces, another checks.
- **Governance/control** — Who owns audit trails, access policy and compliance posture, not just whether controls exist.
- **Governing layers** — Claude Code layers that govern what the agent may touch: hooks, permission modes and approval flows, sandboxing.
- **Guardrail** — A rule or check (prompt, code or pipeline) constraining output to defined boundaries; an underspecified guardrail is worse than a missing one.

## H
- **Hierarchical chunking** — Chunking that preserves section structure; for contracts, manuals, policies.
- **HITL (human-in-the-loop)** — Human review placed by impact and reversibility, before consequential execution.
- **Hooks** — Primitive whose job is *guarantee*: deterministic code on lifecycle events (e.g. PreToolUse) enforcing a rule the model cannot skip.
- **Hybrid retrieval** — Dense plus sparse, fused (usually by RRF); the common production case for mixed query patterns.

## I
- **IDE** — Integrated Development Environment (VS Code, JetBrains, Xcode).
- **Indirect prompt injection** — Instructions hidden in retrieved or tool content; mitigate at the input boundary plus output validation.
- **Inference profiles** — Bedrock feature for cross-region routing.
- **Input preparation / prompt construction / output handling** — Request lifecycle stages: select and trim content; order and cache-boundary it; validate then persist the response.

## K
- **Knowledge (property)** — Reliable on common, recent, consistent topics; unreliable on rare, private or fast-changing ones, in the same confident tone.
- **Known-limitations register** — Handoff artifact listing unsupported behaviour so it is not mistaken for defects.

## L
- **Least privilege** — Give an agent only the tools, credentials and scopes its defined tasks need, enforced outside the model.
- **Lethal trifecta** — Untrusted content plus sensitive data plus a network-egress tool: the exfiltration risk combination.
- **Live state** — Data that changes during a process (order status, inventory, balances); requires a tool call to the system of record, not retrieval.
- **Load-bearing constraint** — The binding (least-margin) constraint whose control decides the configuration; name it to make a design defensible rather than lucky.
- **Local scope** — Claude Code settings for one person in one project (`.claude/settings.local.json`), not committed.

## M
- **Managed settings** — Centrally deployed, non-overridable Claude Code policy; highest precedence.
- **MCP (Model Context Protocol)** — Open protocol where a server exposes tools, prompts and resources to any MCP client; primitive job *connect*; earns its place when reused across clients.
- **.mcp.json** — Project-scope MCP server definitions committed to the repo.
- **MDE (minimum detectable effect)** — Smallest effect an A/B test must detect; sets power-based sample size, defined before launch.
- **Microsoft Foundry** — Azure route; Entra ID auth, Azure billing; hosted-on-Azure vs hosted-on-Anthropic forms per model.
- **Model tiers** — Opus (most capable), Sonnet (default start), Haiku (fastest/cheapest); move up or down only on eval evidence.
- **model_context_window_exceeded** — Stop reason when a fitting prompt's generation hits the ceiling; distinct from 400 "prompt is too long" and 413 request_too_large.
- **Monolithic** — All context loaded up front; fine for bounded tasks and cacheable prefixes; cost grows linearly and fills silently.
- **Multi-agent system** — Multiple Claude instances each handling a subtask, coordinated by an orchestrator; use only when work exceeds one context.

## N
- **Next-token prediction** — Property: strong on common patterns; risk concentrates on names, dates, citations, statistics.
- **Non-determinism** — Identical inputs can yield different outputs; the reason evaluation frameworks exist.

## O
- **Observability** — Seeing what the system did, reconstructing why, detecting failure; third of the five factors.
- **Orchestrator** — Owns the goal: decomposes, delegates, synthesizes; never does sub-task work; its failure is usually unrecoverable.
- **Output contract** — The required shape of the response; the strongest prompt-level place to encode a high-consequence guardrail (deterministic code checks are stronger).

## P
- **Parallelization** — Workflow sub-pattern: concurrent independent calls, aggregated or voted.
- **Parametric knowledge** — What the model learned in training; answering from memory with no lookup.
- **Permission modes** — Six Claude Code modes: default, acceptEdits, plan, auto, dontAsk, bypassPermissions.
- **Permission rules** — allow / ask / deny patterns; deny is evaluated first and wins from any scope.
- **plan (permission mode)** — Read-only until the user approves a plan.
- **Precedence (Claude Code settings)** — managed > command-line arguments > local project (`.claude/settings.local.json`) > shared project (`.claude/settings.json`) > user (`~/.claude/settings.json`); deny rules win over allow.
- **Predictability** — First of the five factors: can you enumerate the steps in advance?.
- **Primitives (seven)** — Tools (act), MCP (connect), Subagents (isolate/parallelize), Hooks (guarantee), Skills (package a procedure), Agent Teams (coordinate peers), Dynamic Workflows (compose at runtime).
- **Progressive** — Context loaded in stages, carrying forward only what the next step needs; the right default for most production workloads.
- **Project scope** — Committed Claude Code config (`.claude/settings.json`, `.mcp.json`, `CLAUDE.md`) shared with everyone who clones the repo.
- **Prompt caching** — Reuses a previously processed stable prefix to cut cost and latency; a design decision, not a default.
- **Prompt injection (direct)** — User text claiming authority or overriding instructions; self-declared authority is untrusted data, not identity.

## R
- **RAG (retrieval-augmented generation)** — Reference architecture retrieving chunks of a stable corpus at request time to ground answers; wrong for live state ("the index is a snapshot").
- **RBAC at retrieval** — Authorization enforced before content reaches prompt construction, so unauthorized data never enters context.
- **Reference architectures (five)** — Agent; RAG; Document processing pipeline (evaluator-optimizer); Customer-service/ticket triage (routing); Coding agent.
- **Regression test** — Scoring against a stable known-good reference set after a prompt, model or config change.
- **Retrieval** — Fetching outside information at request time to ground the answer; augments the context window, does not replace it.
- **Reversibility / stakes / accountability** — The three delegation tests.
- **Risk-stratified sampling** — Review all low-confidence and high-impact outputs plus a random slice of routine ones.
- **Routing** — Workflow sub-pattern: a classifier picks the downstream path by input kind.
- **RRF (reciprocal rank fusion)** — Low-tuning default for merging hybrid result lists by rank in each list.
- **Runbook** — Alerts with triage, escalation, rollback, and pointers to dashboards and logs.

## S
- **Sandboxing** — Environment-level containment (filesystem, network egress, command surface) so the environment, not the agent's judgment, enforces the boundary.
- **SDK** — Language library wrapping the API (Python, TypeScript, Java, Go, Ruby, C#, PHP); default for embedding Claude; "SDK" can mean the Anthropic SDK or the Agent SDK.
- **Semantic chunking** — Splitting on meaning boundaries; for long-form prose.
- **Shaping layers** — Claude Code layers shaping what the agent knows and does: CLAUDE.md, Skills, subagents, MCP servers.
- **Shippable** — Production-ready on accuracy, latency, cost and reliability, having passed evals and review gates.
- **Skill** — Versioned, reusable unit (SKILL.md plus optional scripts/resources) packaging a procedure; loaded on demand; via API through `container.skills` and `/v1/skills`; guides behaviour but is not a security boundary.
- **SLA** — Metric plus percentile threshold plus evaluation window plus breach consequence (e.g. p95 < 800 ms over 28 days).
- **SLO / error budget** — Service-level objective and its allowed shortfall; specified before instrumenting monitoring.
- **Sparse retrieval** — Keyword matching (e.g. BM25) for exact tokens, IDs, codes.
- **SSO / SAML / SCIM** — Single sign-on; the federation protocol; automated user provisioning.
- **Steerability** — Property: follows short, concrete instructions; weak on abstract instructions and precise computation; may follow the letter while drifting from intent.
- **Subagent** — Primitive whose job is *isolate/parallelize*: a scoped sub-task in a separate context, with its own prompt, tools and model.
- **System prompt** — Instructions set once per deployment to shape behaviour across every request: role/scope, constraints, output contract.

## T
- **Template** — System prompt with parameterized slots and fixed scaffolding, so filling a slot cannot remove a guardrail; make the safe path the default.
- **Terminal** — Text command interface (command line/shell).
- **Thinking tokens** — Tokens spent in extended thinking; billed at the output rate.
- **Three-way trade-off (RAG)** — Retrieval quality vs latency vs maintenance.
- **Tokens** — Unit of text processing (~word fragment); cost and context limits are measured in tokens; measure via the `usage` field.
- **Tool Search** — Deferred tool-schema loading with on-demand discovery for large tool/MCP catalogs; keeps capability while cutting context.
- **Tool use** — Claude calls external functions mid-response, choosing when and with what arguments; primitive job *act*; MCP tools are invoked through tool use.
- **TTL (cache)** — Cache lifetime, matched to how often fixed content changes and how often the prompt is called.

## U
- **Underspecification** — A gap the model fills with its own assumption, differently each time.
- **usage field** — Per-response token counts; the number that limits and billing use.
- **User scope** — Personal Claude Code settings (`~/.claude/settings.json`) across all projects.

## V
- **Vertex AI** — Google Cloud managed service for Claude via Model Garden; GCP billing and credentials; Assured Workloads covers FedRAMP High plus IL2.

## W
- **Working memory** — Property: everything inside the context window is available, nothing outside; the hardest edge, with abrupt failure.
- **Workflow** — Named steps orchestrated in your code; loggable, testable; choose when steps are knowable and error cost or observability matter.
- **Workspace trust** — Per-machine approval Claude Code requires before project-scope MCP servers run.
- **Wrapper** — Code encapsulating another library or API to ease use or translate interfaces; an entry point is a wrapper around the same model.

## Z
- **ZDR (Zero Data Retention)** — Arrangement where inputs/outputs are not retained after the response, used where required, e.g. alongside a BAA for PHI.
- **Zero-shot** — Instruction-only prompting; the default to try first for clear, bounded tasks.
