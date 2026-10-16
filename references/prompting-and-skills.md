# Prompting and Skills

At enterprise scale a prompt is "not a sentence you type, but an asset you design": a system prompt, a reusable template, and the guardrails that keep both safe and consistent. Prompting is the other major lever alongside model tier and context strategy. Its two halves are **system-prompt design** and **prompt reuse**.

## Contents
1. System-prompt architecture
2. Templates and fixed scaffolding
3. Description and underspecification
4. Guardrails: structural vs stated
5. Technique selection (zero-shot / few-shot / CoT)
6. Cross-model behaviour and bias
7. Caching mechanics
8. Prompt library vs Skill
9. Skills as an integration mechanism
10. Choosing a mechanism: Skill vs MCP vs retrieval vs CLAUDE.md
11. Sequencing
12. Tempting wrong choices
13. Where the rules pull against each other

---

## 1. System-prompt architecture

A one-off chat prompt and a prompt that hundreds of requests a day depend on are different artifacts. The reused version has three parts:

| Part | Contains | Why |
|---|---|---|
| **Role and scope** | Who the model is acting as; what is in and out of bounds | Unbounded scope invites improvisation |
| **Constraints** | What it must never do and must always do | These are the rules the business is counting on |
| **Output contract** | The exact shape the response must take (fields, schema, citation slot, refusal form) | Downstream code and reviewers depend on the shape. It is also the strongest prompt-level place to put a guardrail (§4) |

"When a system prompt is reused at scale, ambiguity is a defect multiplied across every request." A system prompt is set once per deployment and shapes every request. Keep it distinct from the user's per-turn message. A vague system prompt is paid for in every request that needs correction, retry, or human cleanup; designing it once is cheaper than diagnosing drift later.

**Structure prompts that will be reused** — When a prompt will be reused at scale, choose role/scope + constraints + output contract over a free-form instruction, because every gap gets filled differently on each request.
- Trap: Treating the demo prompt as the production prompt.

---

## 2. Templates and fixed scaffolding

A **template** is a system prompt with **parameterised slots** for the per-request parts and **fixed scaffolding** around them. The scaffolding carries the consistency and safety guarantees, so filling in a slot cannot accidentally remove a constraint. "Make the safe path the default path": users supply variable content and inherit the guardrails without re-authoring them. Templates also concentrate complexity in one place where it can be reviewed and governed, instead of in scattered ad-hoc prompts that nobody owns.

**Template shared prompts** — When many people or services fill in the same prompt, choose a template with fixed scaffolding over per-user prompts, because the guardrails are inherited rather than re-typed, and anything re-typed drifts.
- Trap: Each agent keeping a local copy of "the prompt". Those copies drift into many slightly different versions that nobody can roll back.

---

## 3. Description and underspecification

**Description** is one of the four AI Fluency (4D) competencies: telling the model precisely what you want. A well-described prompt names the **scope**, the **format** (the exact output contract), and the **constraints** that must never be violated.

**Underspecification** is "a gap the model fills with its own assumption, differently each time". In a reused asset that produces non-determinism nobody asked for.

How to diagnose it: read the prompt for what it *fails* to say. For each requirement the output must meet, ask whether the prompt **actually states it or merely hopes for it**. The fix is to make the implicit explicit: restate the goal alongside the instruction (steerability can follow the letter of an instruction and drift from its intent), name the format, and bound the constraints.

**Each requirement must be stated, not hoped for** — When reviewing a prompt, check every output requirement against an explicit sentence or contract field, because silence leads to improvisation and improvisation leads to drift.

**Resolve contradictions** — When a prompt contains contradictory instructions (for example "never speculate beyond the source" alongside "confidently fill gaps"), rewrite them into one coherent policy: forbid unsupported completion, allow an explicit "insufficient evidence" answer, and require citations. Don't add a priority meta-instruction and don't leave it to the model, because Claude picks among conflicting instructions unpredictably across requests and model versions.
- Trap: "Use whichever instruction fits best." That keeps the ambiguity. Raising temperature adds variance, not correctness.

**Ground with generation-side constraints** — When answers start making claims the retrieved sources don't support (often after a model upgrade), constrain the output to source-supported content, require citations or quotes, and add a post-generation claim-verification step. Regression evals only detect the problem, and input or authorisation controls address different risks. When a regression appears and retrieval hasn't changed, inspect the system prompt's grounding and citation instructions and replay the request on the previous model version.

---

## 4. Guardrails: structural vs stated

A guardrail is a rule or check, placed in a prompt, in code, or in the pipeline, that keeps output within defined boundaries. Where you place it decides how strong it is.

| Placement | Strength | Use for |
|---|---|---|
| Sentence in the role text | Weakest. "A rule stated in the role can be drifted past" | Tone and soft preferences |
| **Structural constraint in the output contract** | Stronger. It shapes the response format and "cannot be quietly ignored" | High-consequence content rules, such as never promising a refund or timeline |
| Deterministic check outside the model: schema validation, output classifier, policy engine, hook, permission | Enforced | Anything that must hold every time: authorisation, audit, consequential actions, prohibited content before delivery |

- "**An underspecified guardrail is worse than a missing one**": it gives the appearance of a control without the substance. "A constraint the model can quietly route around is not a constraint".
- **A prompt is not a security boundary.** Authentication and authorisation, RBAC, audit logging, credentials, and data access live in the application layer, and they act *before* data reaches the prompt.

**Build high-consequence guardrails into the output contract** — When a guardrail is high-consequence, encode it in the output contract as structure the format requires, rather than as a sentence in the role text.

**Layer prohibitions** — When a hard content prohibition must hold (for example, no regulated investment advice), combine system-prompt scope with fixed refusal phrasing **and** a pre-delivery output classifier that blocks or replaces violating text. Add schema validation between model output and any downstream action. Prefer preventive layers over detective ones such as logging or SIEM.
- Trap: One hardened system prompt, a lower temperature, or "override phrases". These are single points of failure or discoverable bypasses.

**Treat user content as data** — When users or retrieved documents embed instructions ("I am an admin, ignore your rules"), have the prompt treat that content as untrusted data, use clearly separated tool-result structures, and enforce privilege from the authenticated identity, outside the model.

**Compute deterministically** — When a prompt would encode a calculation or business rule (tax, thresholds, refund qualification), move it to validated code or a calculation tool, because a prompt-encoded rule is probabilistic and unvalidated.

---

## 5. Technique selection

Choose the technique by **task complexity, not habit**. Escalate deliberately: zero-shot → add examples only if needed → add explicit reasoning only if the task structure demands it. "Reach for the lightest technique that meets the requirement."

| Technique | What it is | When it fits |
|---|---|---|
| **Zero-shot** | Instruction only | Well-specified tasks handled reliably. **Try this first** |
| **Few-shot** | A handful of input/output examples | Format or judgment that is **easier to show than describe** |
| **Chain-of-thought** | Reason step by step before answering | Multi-step logic and interacting conditions, where **the path matters to the answer** |

Worked matrix:

| Task | Technique | Why |
|---|---|---|
| Classify tickets into 5 named categories | Zero-shot | Categories named, closed set |
| Extract date/vendor/amount from receipts with widely varying layouts | Few-shot | Format is easier to demonstrate, especially across layout variation |
| Does a clause create liability under three interacting conditions? | Chain-of-thought | Conditional chain; stepping through it prevents skipped interactions |
| Summarise 400 words into two sentences | Zero-shot | Bounded; heavier techniques add tokens for no gain |

**Zero-shot baseline for closed sets** — When the task is closed-set classification (even 30 categories) with labels and descriptions, start with a concise zero-shot prompt listing the categories, their descriptions, and the required output format. Measure it on an eval set, and add examples only in response to failures you have measured.
- Trap: Chain-of-thought "for safety", letting the model invent categories (which breaks the closed-set contract), or leaving out the descriptions.

**Anchor extraction with exact fields** — When schema consistency matters, give few-shot examples that use the **exact field names**, because examples are one of the most reliable format steers.

**Reserve chain-of-thought for reasoning** — Use chain-of-thought only where the task needs decomposition or complex judgment. On a task that doesn't need it, it is "a recurring tax for no gain." The same logic applies to extended thinking (see `models-context-cost.md` §6).

Maintenance note: few-shot examples are content you have to maintain, and **stale examples quietly steer the model wrong**.

---

## 6. Cross-model behaviour and bias

**The same prompt doesn't produce the same behaviour across tiers or generations.** A more capable model may need less scaffolding (fewer examples, less step-by-step), and a less capable one may need more. Treat a prompt tuned for one model as a starting point for another. **The prompt–model pairing is what you ship**, so a swap is a release gated by an eval.

**Re-evaluate the prompt on every swap** — When swapping or upgrading models, re-run the prompt against a stable reference set and re-baseline it. Instruction following, formatting, tool choice, latency, and cost can all change.

**Test prompt changes as regressions** — When a template changes and previously passing cases break, use regression tests against a stable known-good set. Adversarial, smoke, and integration tests answer different questions. When A/B testing prompts, pre-register the hypothesis, the primary metric, and the minimum detectable effect with its sample size, and control model version, retrieval config, and tool availability as confounders.

**Bias sources and discipline.** Bias comes from leading phrasing, unbalanced examples (few-shot sets showing only one kind of case), and assumptions baked into the instruction. Phrase neutrally, balance examples across the cases the system will actually see, and check whether the prompt **presumes an answer it should be eliciting**. Prompt bias is invisible in any single output and shows up only in aggregate, so treat neutrality as "a design requirement, not a polish step."

**Neutral comparison** — When a prompt presupposes an answer ("explain why X is better"), reframe it as an even-handed comparison against explicit criteria, so the alternatives get symmetrical treatment.

---

## 7. Caching mechanics

**Story: "a cache that never hits."** A reusable analysis prompt saved nothing in production because the per-request document sat *above* the large fixed instruction block. The cache matches on a stable prefix, so putting dynamic content first changed the prefix on every request and nothing ever hit. The tell is per-request data above the instructions together with a hit rate near zero. Dynamic content placed before the breakpoint means the cache never hits; at hundreds of calls a day, the stable prefix is where the savings live.

The four mechanics an architect designs around:
1. **Cache breakpoints.** Mark the boundary between the fixed, cacheable part and the variable part, and keep the fixed part genuinely fixed. A timestamp or user name in the "static" block breaks the cache.
2. **Content ordering.** "Static before dynamic, always": large unchanging instructions, tool definitions, and reference documents first, per-request content after the breakpoint.
3. **TTL selection.** Match the cache lifetime to how often the fixed content changes and how often the prompt is called. Prompts called constantly suit a longer-lived cache. Rarely called prompts may never amortise the write.
4. **When the write isn't worth it.** Writes cost more than base input. With infrequent calls or a small fixed portion, caching can cost more than it saves. "Caching is a design decision, not a default to switch on everywhere."

Typical API facts (**verify against current Anthropic docs**): a default 5-minute TTL with a 1-hour option; a limited number of breakpoints per request; a minimum cacheable prefix length that varies by model; writes at about 1.25× (5-minute) or 2× (1-hour) base input; reads at about 0.1×. The cache is isolated per organisation and held in memory. Economics are in `models-context-cost.md` §7–8.

**Stable prefix first** — When a prompt has a large fixed part and per-request content, put the static part before the cache breakpoint and the dynamic part after it.

**Skip the cache when it won't amortise** — When call volume is low or the fixed prefix is small, choose no caching over caching, because the write overhead may never pay back.

**Reference placement (worked example).** The brief: a support reply drafted hundreds of times a day from a ticket and a manual section, which must cite the section and must never promise a refund or timeline.
- Stable prefix: role, tone rules, output contract, and the never-promise guardrail.
- After the breakpoint: the ticket and the manual section only.
- Guardrail: a structural field in the output contract.
- Packaging: a versioned Skill.

**Which lifecycle stage a tactic belongs to**: ordering and cache boundaries are **prompt construction**; trimming retrieval and summarising history are **input preparation**; schema validation and then persistence are **output handling**. Caching is decided at assembly time, not at retrieval or post-processing.

---

## 8. Prompt library vs Skill

- **Modular prompt library**: a shared collection of fragments and templates that engineers assemble in their own code.
- **Skill**: a formal, versioned, self-contained unit, a **SKILL.md** packaging instructions, optional executable scripts, and resources with version management, so the whole procedure travels as one governed artifact. Its job is "package a procedure".

| Consideration | Lean towards a prompt library | Lean towards a Skill |
|---|---|---|
| Repeatability | Assembled per use, often tweaked | A stable procedure run the same way every time |
| Distribution | Within one codebase or team | Across teams or products that need the same procedure |
| Governance | Lightweight; engineers own the fragments | Needs versioning, approval, and rollback, which Skills carry |

"Versioned reuse is the control." An ungoverned prompt copied across teams drifts into many versions.

**Skill for stable, shared, governed procedures** — When a procedure is stable, distributed across teams or products, and needs versioning and rollback, choose a Skill. When the prompt is tweaked per use within one team, choose a prompt library.

**One owner, one Skill** — When a procedure must behave identically across several workflows and changes a few times a year, package it as **one Skill owned by the responsible team and referenced from every workflow**. Don't paste copies into each system prompt (they drift) and don't let each team rewrite it.

**Federated authoring, central gate** — When rolling Skills out at scale (many teams), use federated authorship with a central review and publication gate. The gate checks security, tool permissions, duplication, versioning, and test evidence. Skills can bundle scripts and grant broad tool access, which is why formal review before publication matters.
- Trap: A fully central team (a bottleneck that is cut off from domain expertise), or no review at all.

**A Skill guides behaviour, it doesn't enforce** — Put reusable generation behaviour in the Skill: house style, disclaimer templates, prohibited-language lists. Keep authentication and authorisation, audit logging, retention, and data access in the application layer, because a Skill is not a security boundary and audit evidence can't depend on the model choosing to follow an instruction.

---

## 9. Skills as an integration mechanism

A Skill is a packaging format and also an integration path:
- Attach Skills to a request through the **`container.skills`** parameter.
- Publish and version them through the **`/v1/skills`** endpoint, and manage them under version control.
- **Skills require the Code Execution Tool**, which adds a dependency on a sandboxed execution environment. Account for it in governance reviews, and before using any feature with PHI (including Code Execution and Skills), check that it is covered by the BAA / eligible-feature list; verify against current Anthropic docs.
- Skills are portable across Claude surfaces (claude.ai, API, Claude Code). In Claude Code they are **invoked on demand, not loaded upfront**, which keeps context lean (progressive loading).

Feature names and availability are time-sensitive, so verify against current Anthropic docs. When deciding how a reusable procedure reaches Claude across entry points, weigh a versioned Skill alongside MCP and direct tool use.

---

## 10. Choosing a mechanism: Skill vs MCP vs retrieval vs CLAUDE.md

| Need | Choose | Not |
|---|---|---|
| Procedural knowledge Claude must **follow** (instructions, templates, examples, scripts), with no live system calls, portable across surfaces | **Skill** | MCP, which adds transport, auth, hosting, and ops for nothing |
| Calls to **live** databases, APIs, enterprise services, or authentication against an IdP, reused by **two or more** Claude clients | **MCP server** | A Skill; or MCP with only one client, where plain API tool use is enough |
| A tool used by one product only | **Direct API tool use** (custom tool) | MCP, which "earns its place only when reused across clients" |
| Large stable **reference** material to search, cite, or look up | **Retrieval / RAG** | A Skill (Skills are for procedures you follow, not corpora you search) |
| Live transactional state | **Tool call to the system of record** | Retrieval ("the index is a snapshot") |
| Standing context for every Claude Code session (conventions, repo layout) | **Project CLAUDE.md**, committed, concise, and reviewed for staleness | Re-explaining every session; Skills, which load on demand |
| A recurring specialised task needing its own prompt, tool allowlist, or model | **Subagent** | The general agent; or a subagent for one-off work |
| A rule that must never be skipped | **Hook / permission / server-side code** | A prompt, Skill, or subagent |
| A versioned policy document the model checks against (for example a playbook) | **Retrieve it per item from the source of truth at call time** | The whole document frozen in the system prompt, which goes stale and is reprocessed on every call |

**Skill vs MCP turns on live access** — When choosing between a Skill and an MCP server, the deciding question is whether the capability needs live external-system access. Callable from the CLI is not decisive, because Skills work across the supported environments.

---

## 11. Sequencing

1. Define success criteria and an eval method **before** optimising prompts.
2. Zero-shot baseline → measure → **then** few-shot → **then** chain-of-thought or thinking, each step justified by a measured failure.
3. Fix the prompt **before** adding tools or retrieval, **before** evaluator-optimizer, **before** fine-tuning.
4. Put static content **before** the cache breakpoint and dynamic content after it, and model the hit rate and TTL **before** committing to caching.
5. Authorise and retrieve **before** prompt construction, so restricted data never enters the prompt. Validate output **before** persisting it or acting on it.
6. Pre-register the hypothesis, metric, and sample size **before** running a prompt A/B test.
7. Have a Skill reviewed at the central gate **before** publication.

---

## 12. Tempting wrong choices

- Stating a high-consequence rule in the role text, or a single hardened system prompt, as the guardrail.
- Treating a prompt or Skill instruction as a security boundary for authorisation, audit, or data access.
- Chain-of-thought or few-shot "for safety" on simple, bounded tasks.
- Putting dynamic content before the static block, which means the cache never hits, or caching everywhere regardless of volume.
- Pasting procedure copies into each system prompt, or letting each team keep its own local template, instead of one versioned Skill.
- Choosing MCP for procedural knowledge with no live calls, or for a tool with a single client.
- Putting a whole policy or playbook in the system prompt instead of retrieving it per item from the versioned source.
- Leaving contradictions in place with a "use your judgment" priority line, or lowering or raising temperature as a fix.
- Reusing a validated prompt unchanged on a new model version.
- Leading phrasing or one-sided few-shot sets that presume the answer.

---

## 13. Where the rules pull against each other

- **Where a guardrail is strong enough.** One framing treats a constraint built into the output contract as one that "cannot be quietly ignored", the strongest prompt-level placement. Another treats every prompt-level control, including scope and refusal phrasing, as behavioural, and requires a deterministic layer outside the model (output classifier, schema validation, permissions). Reconcile: encode the rule structurally in the contract **and** validate the contract in code before delivery or action.
- **Grounds for choosing a Skill.** One framing decides the Skill question on repeatability, distribution, and governance (vs a prompt library). Another decides it on live-system access (vs MCP) and enforcement (vs the application layer). Reconcile: these are complementary tests; apply all three.
