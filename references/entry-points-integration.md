# Entry points, build-time interfaces, delivery routes, and integration

Use this file when the question is "where and how does Claude get reached?": which surface the user touches, how engineers' code reaches Claude, whose cloud the request runs in, and how tools, data and procedures get wired in (MCP, Skills, direct tool calls, agent handoff). Deeper governance controls (RBAC, injection defense, permission modes, managed settings, HITL placement) live in `governance-safety.md`; this file only covers the elimination step those constraints perform on entry points and routes.

## Contents
1. The three layers and the three sequential decisions
2. End-user entry points
3. Build-time interfaces (and keeping terms separate)
4. Delivery routes
5. Regulated-constraint elimination
6. Naming the deciding tradeoff, with generalized worked patterns
7. Integration decision rules (MCP, Skill, direct API, agent handoff, auth, Tool Search)
8. Sequencing rules
9. Tempting wrong choices
10. Where the rules pull against each other

---

## 1. Three layers, three sequential decisions

Every deployment involves all three layers. They are not alternatives, and a choice in one rarely dictates another. Collapsing them ("it's all Claude") is the most common source of muddled architecture conversations.

| Layer | Question it answers | Examples | Chosen by / for |
|---|---|---|---|
| **Entry point** | *Who* reaches Claude, what Claude can touch, how much engineering the partner must do | Claude.ai (web, mobile, desktop), Claude Code, Cowork, Chrome, Excel, a custom app on the API | The user and the work |
| **Build-time interface** | *How code* reaches Claude | Direct API, SDKs, MCP, Agent SDK | The engineering team and the integration |
| **Delivery route** | *Where the request runs* (whose infrastructure, billing, identity, region) | Anthropic first-party, AWS Bedrock, GCP Vertex AI, Microsoft Foundry | Cloud commitments and compliance posture |

Classification traps: Claude Code is an entry point even though engineers use it; Direct API is a build-time interface (the route is "Anthropic first-party"); MCP and the Agent SDK are build-time interfaces, not entry points.

**Make the decisions in this order**, because the order prevents the most common mistakes:
1. **Entry point** — name the user and the work first.
2. **Build-time interface** — what suits the team and the integration shape.
3. **Delivery route** — what the partner has already committed to.

Before any of the three is decided on cost, ergonomics or build effort, apply non-discretionary constraints (privilege, HIPAA, GDPR/residency, FedRAMP, internal policy) to eliminate options. "Let the constraint eliminate options before preferences do."

## 2. End-user entry points

The entry point is "the same intelligence packaged for different jobs." A wrong entry point doesn't break the work; it adds daily friction, and outgrowing it later is expensive (a rebuild: code rewrite, conventions, user habits). Starting on the right one is cheaper than migrating off the wrong one. Verify current capabilities and plan availability of Cowork, Chrome and Excel against current Anthropic docs.

| Entry point | Audience | What it gives | Core tradeoff |
|---|---|---|---|
| **Claude.ai** (web, mobile, desktop) | Knowledge workers doing research, drafting, analysis, review; no code. "Entry point for applied AI users, not builders." | Conversations, file uploads, **Projects** for shared context, built-in connectors (Slack, Outlook, Google Drive) | **Zero build cost vs zero integration**: cannot embed in another product or customize what's exposed |
| **Claude Code** (terminal, IDE plugin for VS Code/JetBrains, desktop, web at claude.ai/code) | Engineers | Agentic coding: reads files, edits code, runs commands, multi-step engineering under configurable permission boundaries; customized via CLAUDE.md, Skills, subagents, hooks, MCP, permissions | **Purpose-built for engineering**: wrong shape for customer service or non-engineering workflows |
| **Claude Cowork** | Ops, admin, non-engineering roles | Desktop agent automating file/task work with local files and apps under configurable permissions. All paid plans (Pro, Max, Team, Enterprise) via Claude Desktop on macOS/Windows; Linux beta | **Real system actions vs supervision overhead**: permission scoping and human review matter more than in chat |
| **Claude in Chrome** | Knowledge workers whose tasks live in web apps | Browsing agent inside Chrome | Judgment call: a niche surface; choose it only when the work actually lives in the browser. It acts, so it carries the same supervision concerns as any acting agent |
| **Claude for Excel** | Analysts, finance | Spreadsheet agent over cells, formulas, structured data | Judgment call: a niche surface; choose it only when the work actually lives in the spreadsheet |
| **Custom app on the API/SDK** | Any audience the partner designs for (branch staff, clinicians, customers) | Whatever the partner builds: their UI, SSO, gateway, audit | Maximum fit and control; the partner pays the full build and operating cost |

**Claude.ai tiers — pick by governance need** (verify current tier features):

| Tier | Adds | Fit |
|---|---|---|
| Free, Pro, Max (consumer) | Individual use | Low-sensitivity work only; no DPA/BAA framework |
| **Team** (Claude for Work) | Admin controls, SSO and SAML, domain capture, contractual no-training on customer content | Organizations needing admin, SSO, no-training |
| **Enterprise** (Claude for Work) | SCIM provisioning, configurable retention, audit logs, Compliance API, HIPAA-ready option with signed BAA | Regulated orgs that can accept audit logs living in Anthropic's infrastructure |

**Pick the entry point by the work** — When the user is non-technical and the work is chat over approved documents, choose Claude.ai with a Project over a custom build because a custom build adds cost with no change in capability; audience decides before integration depth.
- Trap: "custom API build gives more control" — control nobody needed, paid for every month.

**Claude Code is for engineers** — When the users are not engineers (branch staff, warehouse staff, ops), choose Claude.ai, Cowork, or a custom app over Claude Code because Claude Code is a terminal/IDE engineering tool; same model underneath, but the wrapper is wrong.
- Trap: "it's all Claude" reasoning, or picking Claude Code because the last project used it.

**Meet developers at the point of work** — When the goal is developer productivity, choose Claude Code in the IDE/terminal over a separate channel (e.g., a shared Slack bot) because the integration point determines context availability and context-switching friction; model capability alone doesn't decide it.
- Trap: "Slack gives an audit log" (true but secondary; telemetry and repo history provide one) or "equivalent because same model."

**One entry point unless the work spans several** — When tempted to offer multiple entry points, choose one unless the use case genuinely spans them, because each carries its own non-trivial integration cost (you pay twice).

## 3. Build-time interfaces

These **layer** on one another; they are not always alternatives.

| Interface | What it is | Use when | Core tradeoff |
|---|---|---|---|
| **Direct API** (HTTP) | Raw requests; team owns retries, streaming, tool use, observability, UI | SDK lacks a freshly shipped feature, or the team prefers raw HTTP | **Maximum control vs maximum responsibility** |
| **SDKs** (Python, TypeScript, Java, Go, Ruby, C#, PHP) | Language-native wrapper: auth, formatting, retries, streaming, tool-use plumbing. Any agent loop is still the partner's code | **Default for embedding Claude in a product** | **Ergonomics vs control**: you move at Anthropic's release cadence |
| **MCP** (Model Context Protocol) | Open protocol: one server exposes tools, prompts, resources to any MCP-aware client (Claude.ai, Claude Code, API, third-party). "Build the server once, connect it everywhere." A sharing convention across products, not a calling convention inside one | The same tools/data must be reachable from more than one Claude client | **Reusability across clients vs added architectural complexity**; with one client it is overhead without payback |
| **Agent SDK** (`@anthropic-ai/claude-agent-sdk` npm, `claude-agent-sdk` PyPI) | Managed agent loop, the same loop powering Claude Code, embedded in partner code: iteration, tool execution, observation, termination | Claude must act across multiple turns inside the partner's own product, where the Claude Code CLI is the wrong shape (e.g., an internal agent in a web app) | **Managed loop vs custom orchestration**: you give up fine-grained loop control |

**Keeping terms separate:**
- **API vs SDK** — the same thing from Claude's view, different ergonomics. SDK is the default; drop to raw HTTP only when a new API feature isn't in the SDK yet.
- **MCP vs API tool use** — different layers, not alternatives. MCP is how a tool is *exposed and discovered* across clients; API tool use is how Claude *calls* a tool inside one request. An MCP server's tools are still invoked through tool use. Pick MCP when one tool must be reachable from multiple Claude clients; plain API tool use when the tools live in one product.
- **Anthropic SDK vs Agent SDK** — "SDK" is ambiguous. The Anthropic SDK is a convenience wrapper with no agent loop. The Agent SDK is a managed runtime that runs the loop (pick tool → run → observe → continue until done or a stop condition).

**One-line selection rule:** one request, one response → API/SDK; reusable tools across multiple clients → MCP; Claude acting across multiple turns inside the partner's product → Agent SDK. They work together.

**Skills as an integration mechanism:** beyond packaging, a Skill can be attached to a request via the `container.skills` parameter and published/versioned through the `/v1/skills` endpoint, kept under version control. Skills require the **Code Execution Tool**, so they bring a sandboxed-execution dependency. Weigh a versioned Skill alongside MCP and direct tool use when deciding how a reusable procedure reaches Claude across entry points. Verify parameter and endpoint names against current Anthropic docs.

## 4. Delivery routes

Same model on all four routes. The choice is **not technical capability**; it is about what the partner has already committed to: which cloud account spend lands in, which identity system authenticates, which region traffic terminates in, which procurement contract is already signed.

| Route | Billing / identity | Pick when |
|---|---|---|
| **Anthropic first-party** (api.anthropic.com, API key; SDKs wrap it) | Anthropic billing | No binding cloud commitment; wants newest features day-one; consolidating AI spend with Anthropic. **Default when no procurement constraint pulls the other way.** |
| **AWS Bedrock** (Messages API at `/anthropic/v1/messages`; legacy InvokeModel/Converse still documented) | AWS billing, IAM | Committed AWS EA, stack on AWS, spend draws down the commitment; identity, networking, audit inherit. Regional availability matters; **inference profiles** solve cross-region routing |
| **GCP Vertex AI** (Model Garden; Anthropic Vertex client or Google SDK) | GCP project billing, Google Cloud credentials; models enabled per project | On GCP, ML stack in Vertex, single billing/audit across foundation models |
| **Microsoft Foundry** (Azure; Foundry catalog) | Azure subscription, **Entra ID** | Microsoft EA, Entra identity, Azure footprint. Two hosting forms: **Hosted on Azure** (inference in partner's Azure env; at time of writing this covered Opus 4.8, Sonnet 5, Haiku 4.5) and **Hosted on Anthropic infrastructure** (other models). Verify the hosting form per model against current docs when residency matters |

**Unchanged across routes:** model, prompting, eval strategy, tool use, context-window behavior.
**Changes:** model identifiers/version strings, regional availability, CSP wrapping features (Bedrock inference profiles, Foundry model deployments, Vertex Model Garden access controls).
**Feature lag:** CSP routes trail first-party on new features by weeks, sometimes longer for major capabilities. Government environments run on a further model lag. Verify current availability per route against current Anthropic and CSP docs.

**Route follows the commitment** — When the partner has an AWS/GCP/Azure enterprise agreement, choose Bedrock/Vertex/Foundry over first-party because spend draws down the commitment and identity/audit inherit, while model behavior is identical.
- Trap: "direct API gives the most control / fastest features" when nobody asked for day-one features and procurement already points at a CSP.

**Day-one features need first-party** — When the design depends on a just-released capability, choose first-party over a CSP route because CSP routes lag by weeks.

## 5. Regulated-constraint elimination

Some decisions are not discretionary. These constraints rule entry points and routes in or out **before** cost, ergonomics or build effort. Claude.ai is eliminated most often because consumer-grade surfaces aren't built for every enterprise data-handling requirement. **API/SDK routed through a partner-approved gateway with logging, retention and identity controls in the partner's own infrastructure** survives most regulated reviews. Name the governing constraint when you recommend.

| Constraint | Rules out | Usually survives | Deciding concept |
|---|---|---|---|
| **Attorney-client privilege** | Consumer Claude.ai for privileged review; any surface the firm can't audit end to end. Claude for Work adds admin/audit, but the firm must confirm the config meets its privilege bar | API/SDK behind the firm's own app, SSO, and firm-approved LLM gateway logging every request | **Audit ownership**, not audit existence: Enterprise audit logs live in Anthropic's infrastructure; the firm must be able to produce the log itself |
| **HIPAA (PHI)** | Any entry point without a BAA for the **specific configuration**; a BAA for one config doesn't extend to another; consumer/personal accounts | API/SDK on a BAA-covered config via an existing route; or a commercial plan (e.g., Enterprise) with signed BAA, HIPAA-ready config, ZDR where required, audit logging | **BAA coverage of the configuration**, not geography. Beta features are generally excluded unless listed; switch off feedback, beta and third-party paths the agreement doesn't cover |
| **GDPR & data residency** | Routes where execution region can't be pinned or data leaves the boundary at any step; personal tiers without a DPA | CSP route (Bedrock or Vertex) with region pinned to the covered jurisdiction, DPA terms inherited from the cloud contract; Foundry — verify residency per hosting form. Also needs DPA/SCCs, retention config, minimization/redaction, DSR procedures | Region pinning plus controller obligations; the tier alone is not enough |
| **FedRAMP / government** | Any path not on an authorized cloud at the required impact level | **Claude for Government (C4G)** — FedRAMP High civilian; **Bedrock GovCloud** — FedRAMP High + DoD IL4/5; **Vertex Assured Workloads** — FedRAMP High + IL2 | Authorization level; confirm the needed model is offered (model lag). Verify current scopes with Anthropic |
| **Internal data-residency / approved-vendor policy** | Routes outside the approved cloud vendor list, regardless of capability | A route on the approved CSP | "Procurement, not engineering: whichever one their CIO has already cleared" |

**Constraint before benefit** — When a non-negotiable data-boundary or residency constraint exists (including for a move to managed/hosted agents), resolve it as a gate before weighing operational savings, pattern fit or cost, because those benefits are irrelevant if data leaves the boundary. For managed agents, check where inference runs, how sessions persist, encryption, which subprocessors are involved, how credentials are handled, whether actions are auditable, and how deletion works.
- Trap: arguing from ops savings, token cost, or topology support.

**Keep a confirmed compliance path** — When an existing BAA/contract already covers a configuration, choose the route it covers over a competing proposal that needs a new BAA or a new entry point, because switching adds procurement delay and dependency with no benefit.

## 6. Name the deciding tradeoff

A right entry point paired with the wrong reason is not correct. State the tradeoff out loud: it is also the signal that tells you later when to switch.

| Category | Means | Typically decides |
|---|---|---|
| **Audience** | Who the users are and what they can operate | Non-technical team → ready-made entry point (Claude.ai + Project), not a build-time interface |
| **Integration depth** | Whether Claude must reach systems programmatically | Needs core-system retrieval → API/SDK (rules out Claude.ai before governance is even considered) |
| **Governance / control** | Who *owns* audit trails, access policy, compliance posture (not merely whether controls exist) | Privilege → firm-owned gateway; existing BAA coverage → that route |
| **Regulatory residency** | Where data is stored/processed | GDPR region pinning — *not* HIPAA or privilege |
| **Latency** | Round-trip and time budget | Keep the request path inside the cloud the app already runs in |

In summary, the entry-point tradeoffs are: **speed of setup vs depth of control, prebuilt UI vs custom integration, breadth of tools vs focus.**

**Generalized worked patterns** (illustrative situation shapes):

| Situation shape | Right answer | Right reason | Right-answer/wrong-reason or near-miss traps |
|---|---|---|---|
| Non-engineering team, chat over approved internal docs | Claude.ai + Project | Audience | Custom API build (cost, no capability gain); Claude Code (wrong audience) |
| Frontline staff on shared devices, handoff notes/checklists | Claude.ai + Project | Audience | Same as above; audience decides before integration depth |
| Assistant must pull from a core system of record; partner has an AWS EA | Bedrock (API/SDK) | Integration depth (then procurement picks the route) | Claude.ai Enterprise (no programmatic retrieval); direct API (right class, ignores the EA) |
| Privileged documents; counsel requires firm-owned audit infrastructure | API/SDK behind firm app + gateway | Governance/control (audit ownership) | Claude.ai Enterprise (right category, audit lives in Anthropic infra); Bedrock "for residency" (privilege isn't residency) |
| PHI; existing BAA confirms a CSP route covers the config | That CSP route | Governance/control (existing BAA coverage) | Same route "for US-region residency" (HIPAA turns on BAA, not geography); direct API + new BAA (viable, needless delay); switch to Enterprise + BAA (new procurement dependency) |
| Tight latency budget (hundreds of ms); app runs on GCP | Vertex AI | Latency (stay in-cloud; verify inference placement per region) | Direct API "fastest features" (irrelevant to latency); Bedrock (cross-cloud, no justification) |
| Illustrative example: mid-market law firm contract review with privilege, an approved gateway, and a document system | API/SDK thin web app + SSO + gateway; parallelized section-by-section workflow with evaluator; playbook retrieved per clause from a versioned source; Sonnet + progressive context; associate signs off | Each decision constrains the next | Claude.ai + Project (privilege fails first); full playbook in system prompt (stale, reprocessed); open-ended agent + Opus everywhere (unused flexibility, bill) |

**Hard real-time is not an entry-point question** — When the path has a deterministic sub-50 ms budget (e.g., streaming fraud scoring), keep LLM inference off the critical path entirely; no route choice fixes it.

### Anti-pattern: Claude Code misused outside engineering
In an illustrative case, a regional bank's "operations assistant" for branch staff is proposed as: Claude Code on branch laptops with per-branch CLAUDE.md; MCP servers for customer DB, appointments, policy corpus; subagents doing compliance checks on every interaction.
- **Three failure mechanisms:** (1) entry point chosen **before the user was named**; (2) MCP **carried forward from a prior project** with no second client; (3) compliance, the highest-consequence path, given to the **weakest deterministic guarantee** (an LLM subagent).
- **Fix:** custom web app calling the API directly; compliance in deterministic server-side code; bank SSO; plain tool use; tool calls audited at the server boundary.
- **Tell-tale signals:** "Claude Code" + non-engineering users; MCP with no second client; a subagent or prompt enforcing a compliance rule.
- Moral: "The entry point should follow the work, not precede it." The two most common mistakes are reaching for Claude Code on non-engineering work and treating MCP as the default integration layer.

## 7. Integration decision rules

### Choosing the integration mechanism

**Decide by portability and statefulness** — When choosing between MCP, direct API integration and agent-to-agent handoff, decide on (a) whether more than one AI client needs to reuse the integration and (b) whether the interaction is stateless/latency-sensitive or stateful/long-running. MCP for a standard interface reused across clients; direct API for narrow, stateless, latency-sensitive calls where the app owns the logic; agent handoff for stateful, long-running delegation between independently responsible agents.
- Trap: vendor doc quality or team familiarity (affects effort, not fit); encryption in transit (mandatory for all, doesn't differentiate).

**Single stateless call → direct tool** — When Claude needs one low-latency, stateless call to a stable existing HTTP API, choose a custom tool calling that endpoint directly with scoped credentials over a stateful session, a message bus, an MCP wrapper, or another agent in front, because each layer adds hops, dependencies, failure modes and latency. The tool implementation checks its inputs, authenticates on the server (the model never sees credentials), keeps authorization narrow, sets explicit timeouts, checks the response, and logs who called it, what happened and how long it took.
- Trap: agent-to-agent handoff "for flexibility."

**MCP only with a second client** — When only one product uses a tool, choose API tool use over MCP because MCP's reusability has no payback; choose MCP when the same tool must be reachable from multiple Claude clients (e.g., a team's Linear server used from both Claude Code and Claude.ai).
- Trap: MCP carried over from the last project as a default layer.

**Skill for procedure, MCP for live systems** — When the capability is reusable procedural knowledge (instructions, templates, examples, resources) with no live external calls, choose a Skill over an MCP server because MCP adds transport, auth, hosting and ops complexity, and Skills are portable across Claude surfaces. When Claude must call live databases, APIs, enterprise services or authenticate against an IdP, choose MCP/integration.
- Trap: "it must be callable from the CLI" (not decisive; Skills work across supported environments).

**One owned Skill, referenced everywhere** — When one procedure must behave identically across several workflows and changes periodically, choose a single owner-maintained Skill referenced by all of them over copies in each system prompt, because one authoritative version propagates updates and avoids drift. Content Claude must *follow* is a Skill; reference material Claude *searches* is a retrieval corpus.
- Trap: shared retrieval corpus for a mandated procedure; letting each team rewrite it.

**Skill is not a security boundary** — When a control must be deterministic (authN/authZ, audit logging, retention, data access, consequential actions), keep it in the application layer, not inside a Skill; put reusable generation behavior (house style, disclaimers, prohibited-language list) in the Skill.

**Agent SDK for embedded multi-turn acting** — When Claude must act over multiple turns inside the partner's own product, choose the Agent SDK over the Claude Code CLI or a hand-rolled loop because it provides the managed loop.

**Live state through tools, not retrieval** — When the data is owned by a system and changes independently (order status, inventory, balances, coverage), integrate it as a tool/API call over a retrieval index, because the index is a snapshot. When the operation is filter/join/count/aggregate over a schema, invoke a constrained structured query rather than semantic similarity. (Full RAG rules live in the RAG/context reference.)

### Identity, credentials and tracing

**Per-user OAuth over a shared key** — When one API key is shared by all users, choose per-user, scope-restricted, revocable OAuth tokens over moving the shared key into a secret store, because a centrally stored shared key still makes every user the same principal. Every tool-call log should name the actor: which user, which session or request, which tool, the authorization decision, the resource touched, when, and the outcome.

**Credentials stay server-side** — Resolve credentials from a secret store or delegated auth at runtime; never place them in prompt context or committed config, because prompts persist in traces, logs and caches. Shareable config (e.g., MCP server definitions, env-var references) can be committed; secret values cannot.

**Authorize before retrieval** — When integrated data is access-controlled, authenticate and authorize before retrieval and prompt construction so unauthorized data never enters model context. Details in `governance-safety.md`.

**Trace across every boundary** — When requests cross agent, MCP and tool boundaries, propagate request-scoped correlation IDs (or W3C trace context) end to end and record model ID and version on every turn, because otherwise spans can't be stitched and behavior changes can't be attributed to migrations.
- Trap: flagging already-healthy items (span export, latency/token metrics, redacted payload logging) as gaps.

**Queue bursty traffic** — When traffic is bursty at scale, put an async queue between intake and model invocation for backpressure, controlled concurrency and retries.

### Tool catalogs and MCP operations

**Tool Search for large catalogs** — When many MCP servers/tools bloat context before the user types (tens of thousands of tokens, slow time-to-first-response), enable Tool Search (deferred schema loading, progressive discovery) over disabling servers, a fixed hard-coded subset, per-turn tool summaries, or a bigger context, because only the selected tools enter context and full capability is kept. Improve tool/server descriptions so discovery picks well, monitor selection accuracy, keep only eval-justified foundational tools non-deferred.
- Trap: blaming client-side factors (display, keyboard) or "hidden model reservations"; only content sent to the API consumes tokens.

**Decompose sprawl by domain** — When a toolset grows across several distinct workflow domains and accuracy drops, decompose into domain-focused agents over adding a router agent in front, because the router adds a model call to every request without fixing the sprawl. Overlapping descriptions get clarified; unused tools get removed. Keep only tools that trace to defined tasks or regular hand-offs.

**Diagnose MCP least-destructively** — When an MCP server is missing or flaky, check registration/status first (`claude mcp list`, `/mcp`, `claude mcp get <name>` for transport/command/creds/approval), then refresh the session; when a failure correlates with a one-time OS permission prompt and later runs succeed, document the first-run requirement. Avoid disabling all servers, reinstalling, suppressing permission dialogs or replacing a working server.

**Share MCP config through project scope** — When every engineer on a repo needs the same MCP servers, commit `.mcp.json` / `.claude/settings.json` at project scope (secrets excluded; project servers still need workspace trust/approval); put non-overridable org policy in managed settings.

## 8. Sequencing rules

1. **Name the user and the work** before choosing any entry point.
2. **Apply non-discretionary constraints** (privilege, BAA configuration, GDPR region, FedRAMP level, approved-vendor list) before cost, latency, ergonomics or build effort.
3. **Entry point → build-time interface → delivery route**, in that order.
4. For a regulatory assessment: establish applicability (data types, jurisdiction, audience) and inventory existing compliance affordances (Trust Center, Compliance API, audit/retention/residency controls) **before** mapping data flows to clauses; gap analysis and remediation come after.
5. **Authenticate/authorize before retrieval**, before prompt construction, before generation.
6. Choose the integration mechanism by **portability first, then statefulness/latency**; add MCP only once a second client exists.

## 9. Tempting wrong choices

- **"It's all Claude"** — collapsing layers; Claude Code put in front of non-engineers.
- **Familiarity-driven tooling** — MCP or Claude Code carried over from the last project with no second client or no engineering audience.
- **Right route, wrong reason** — residency cited for HIPAA (turns on BAA coverage) or for privilege (turns on audit ownership).
- **Right category, wrong entry point** — Claude.ai Enterprise offered where audit *ownership* is required.
- **"Most control" ignoring procurement** — direct API chosen when an existing CSP commitment should drive the route.
- **Custom build for a non-technical audience** — more cost, no capability gain.
- **Switching compliance paths** — proposing a new BAA or new entry point when an existing one already covers the configuration.
- **Extra layers on a simple call** — agent handoff, message bus or stateful session in front of one stateless API call.
- **MCP for procedural knowledge** — server, auth and hosting overhead for something a Skill packages.
- **Prompt/Skill/subagent as the enforcement point** — compliance or authorization delegated to the model.
- **Disabling or bloating instead of deferring** — turning off MCP servers or growing the context instead of Tool Search.
- **Shared key in a vault** — secret storage presented as a fix for shared identity.

## 10. Where the rules pull against each other

- **Agent-to-agent handoff vs Agent SDK.** One framing lists the build-time interfaces as Direct API / SDK / MCP / Agent SDK, with no handoff; another treats "MCP vs direct API vs agent handoff" as the core integration choice, with handoff for stateful, long-running delegation between independently responsible agents. Reconcile: use both lenses. The Agent SDK answers "how do I run a loop in my product"; handoff answers "how do separate agents pass long-running work."
- **MCP vs direct tool as alternatives.** One rule says MCP and API tool use are different layers, not alternatives (MCP tools are still called via tool use). Another frames "direct API/custom tool vs MCP" as a choice. Reconcile: the real decision is whether to add an MCP exposure layer on top of tool use, which pays off only with cross-client portability.
- **Skills portability vs dependency.** Skills are lighter than MCP and portable across claude.ai, API and Claude Code; but API Skills require the Code Execution Tool (a sandbox dependency). Reconcile: recommend Skills for procedure, and name the dependency when recommending them via the API.
- **HIPAA entry point.** One default says stay on the route an existing BAA already covers and treat switching to Claude.ai Enterprise + BAA as needless procurement. Another says Claude Enterprise + signed BAA + ZDR + audit logging is the correct HIPAA posture when choosing among Anthropic offerings. Reconcile: both turn on BAA coverage of the specific configuration; prefer the already-covered path, and absent one, use the Enterprise package.
- **GDPR emphasis.** One answer to residency is route selection (region-pinned Bedrock/Vertex, DPA inherited from the cloud contract). Another is an enterprise tier plus DPA, retention configuration, minimization/redaction and DSR procedures, with the warning that the tier alone isn't enough. Reconcile: pin the region and implement controller obligations.
- **Latency.** A few-hundred-millisecond budget is solved by keeping traffic inside the existing cloud (e.g., Vertex); a hard sub-50 ms deterministic path should not have LLM inference on the critical path at all. Reconcile: route choice helps only within an LLM-feasible budget.
- **Managed agents.** Claude Managed Agents (hosted harness) look like an operational win, but they are gated on data-boundary checks. Reconcile: treat them as another hosting option subject to the same constraint-first elimination; verify current capabilities against Anthropic docs.
