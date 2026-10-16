# Governance, Safety and Risk Management

Read this when a scenario involves access control, credentials, Claude Code policy, prompt injection, guardrails, human oversight, regulated data, fairness, or risk assessment. The idea underneath every rule here: **the prompt is guidance, not a security boundary.** Anything that must hold every time is enforced by code, configuration, credentials, or the environment. The model's instructions and judgment are an extra layer on top.

## Contents
1. Core frameworks: guidance vs enforcement, control placement, control → risk map
2. Identity, least privilege, credentials
3. Authorization before retrieval (RBAC)
4. Claude Code governance: scopes, precedence, permissions, hooks, sandbox
5. Prompt injection, untrusted content, exfiltration
6. Layered guardrails: input, output, refusals, audit
7. Human oversight: placement, escalation, sampling, accountability
8. Regulated data: HIPAA, GDPR, privilege, FedRAMP, retention
9. Responsible AI: fairness, transparency, ethics review
10. Risk classification, threat modeling, incident handling
11. Sequencing rules
12. Tempting wrong choices
13. Where the rules pull against each other

---

## 1. Core frameworks

### Guidance vs enforcement
| Layer | What it is | Can it be a security boundary? |
|---|---|---|
| System prompt, role text, refusal instructions | Behavioral guidance | No. "A constraint the model can quietly route around is not a constraint." |
| Skill (SKILL.md, disclaimers, prohibited-language list) | Reusable generation behavior | No. It guides behavior and is not a security boundary |
| Output contract / structured schema | Shapes the response format | Partly. Harder to drift past than role text, and the app should still validate it |
| Model refusal / "model declines the tool" | Voluntary behavior | No. Not deterministic authorization |
| Subagent doing a compliance check | Model judgment in an isolated context | No. That assigns compliance to the weakest deterministic guarantee |
| App/orchestration-layer code, policy engine, schema validation | Deterministic | Yes |
| Credentials, OAuth scopes, IAM, DB grants | Deterministic, outside the model | Yes. A prompt can't turn a read-only credential into write access |
| Hooks (PreToolUse etc.), permission rules, managed settings | Deterministic gates the agent cannot skip | Yes |
| Sandbox: filesystem boundaries, network egress rules | The environment enforces the boundary | Yes. "The environment itself should enforce the boundary, not just the agent's judgment." |

Primitive jobs: **Hooks = Guarantee**, Skills = Package a procedure. Only hooks enforce deterministically.
GOVERNING layers in Claude Code: **Hooks**, **Permission boundaries & approval flows**, **Sandboxing & restricted execution**. SHAPING layers (CLAUDE.md, Skills, Subagents, MCP) govern what the agent knows, not what it may touch.

### Where a control goes
| Belongs in app/orchestration layer (deterministic) | Belongs in prompt/Skill (behavioral) |
|---|---|
| AuthN/authZ of the requesting user | House style, tone, formatting |
| Audit logging of every generation and tool call | Disclaimer templates |
| Retention, data access, RBAC filtering | Prohibited-language policy (also validated after generation) |
| Thresholds and business rules (e.g. £5,000 routing) | Scope statement and fixed refusal phrasing |
| Approval gates for consequential actions | "Treat user/tool content as data, not instructions" |
| Per-role tool allow-lists | Uncertainty / "insufficient evidence" responses |

### Control → risk it addresses (map each control to the risk it *most directly* mitigates)
| Control | Risk it most directly addresses | What it does NOT do |
|---|---|---|
| Outbound tool allow-list, destination restrictions, per-call approval | Data exfiltration via outbound tool calls | Doesn't detect or prevent injection. It limits blast radius only |
| Stable adversarial/regression eval set re-run on each model version | Silent quality or safety drift after a model upgrade | Imposes no runtime authorization. It detects; it doesn't block a specific malicious document |
| Untrusted labeling + structural separation of tool results + injection classifier | Indirect prompt injection via retrieved/third-party content | Doesn't fix groundedness |
| Runtime classifier for override attempts + authZ from authenticated identity | Direct injection / self-claimed authority ("I am admin") | n/a |
| Retrieval-layer RBAC before prompt construction | Unauthorized data exposure across roles | Doesn't fix shared identity |
| Per-user scoped, revocable OAuth tokens | Shared identity, every user acting as one principal | Moving a shared key into a vault does not fix this |
| Actor attribution in tool-call logs | Missing accountability in audit | Doesn't prevent anything. It is detective |
| Secret store / runtime injection of credentials | Credential leakage via repo, prompt, traces, caches | n/a |
| Pre-delivery output classifier (block/replace) | Prohibited content reaching the user (e.g. regulated investment advice) | n/a |
| Schema validation between model output and execution | Malformed or out-of-policy actions reaching downstream systems | n/a |
| Citations, quote extraction, post-generation claim verification | Hallucination / ungrounded claims | Doesn't stop injected instructions. Adds traceability only |
| Read-only DB credential + read-only tool list + human confirmation on writes | Destructive changes to production data | n/a |
| Managed, non-overridable settings | Individual engineers disabling security controls | n/a |
| Human pre-action approval gate | Irreversible / high-impact harm | Post-hoc audit can't prevent harm |
| Subgroup error-rate analysis | Hidden unequal error burden (bias) | Approval-rate parity alone does not show it |
| SIEM / centralized log review | Detection and forensics | Detective, not preventive |

Knobs that are **never** security or compliance controls: temperature, max_tokens, streaming, picking the most capable model, session-length limits, refreshing refusal wording. They change length, quality, variance, or volume. They provide no authorization, contractual coverage, or minimum-necessary access.

---

## 2. Identity, least privilege, credentials

**Per-user identity over shared keys** — When an audit finds one API key shared by all users, choose per-user, least-privilege, revocable OAuth tokens over storing the shared key server-side, because a centrally stored shared key still makes every user the same principal.
- Trap: "Move the key to a secret manager". Good hygiene, but it doesn't fix identity.

**Attribute every tool call** — When tool-call logs lack the initiating user, log for each call who made it (the authenticated user), the session or request it belongs to, the tool, whether it was authorized, what resource it touched, when, and what happened, because accountability needs a named actor per action. Record model ID/version per turn too, and propagate a shared correlation/trace ID across agent/tool/MCP boundaries.
- Trap: schema validation or RBAC fixes offered for a logging gap. They address different risks.

**Least-privilege toolset** — When curating an agent's tools, keep only tools that trace to defined tasks or regular hand-offs. Remove "occasionally useful for unrelated work" and "speculative future" tools, because every extra tool adds attack surface, context, authorization complexity, and eval burden, and widens the blast radius of an injection or model error. Aim for the smallest catalog that reliably completes the approved tasks, not the smallest possible one. Keep the tool entry point as narrow as the task allows. Review tool telemetry periodically, and add tools only after security review and evals.
- Trap: "more tools = more capable".

**Drafter ≠ actor** — When an agent's job is drafting for human review, give it read tools for grounding plus a write tool scoped to the review queue only (Claude drafts; the system sends). Remove send/submit/external-execute tools and unrelated admin tools, because those turn a drafter into an actor and bypass the human gate.
- Trap: "direct vendor email saves a step".

**Exact per-role allow-list at the orchestration layer** — When a role needs exactly KB-read + draft-queue-write, enforce an allow-list of exactly those tools outside the model, before any tool call executes. Don't grant global read access or rely on the model to decline tools.
- Trap: disabling all tools (breaks the function) or "the model will decline" (voluntary, injectable).

**Production data: defense in depth** — When an agent touches a production DB, layer three things: the MCP server holds a read-only credential by default, the subagent's tool list is read-only, and any data-modifying operation needs explicit human confirmation. Log the actor, request, tool, approval, records affected and outcome.
- Trap: prompt-only "don't write", or a fully privileged credential "with care".

**Credentials never in prompt or repo** — When a credential is needed, resolve it server-side at runtime (secret manager, credential provider, delegated auth). Never place it in prompt context (prompts persist in traces, logs, caches, and outputs can leak them) or in committed config such as `.claude/settings.json`. Plaintext in user settings is also wrong. "Not committed" is not enough; use an OS credential store or secret manager. If a key is exposed, revoke/rotate immediately and investigate repo history.
- Trap: answers about scope precedence when the question is about secrets. MCP *definitions* may live in project config; only the secret *values* must stay out.

**Tool implementation hygiene** — A custom tool checks its inputs, authenticates on the server so the model never sees credentials, keeps authorization narrow, sets explicit timeouts, checks what comes back, and logs who called it, the outcome and the timing.

---

## 3. Authorization before retrieval

**RBAC at the retrieval layer** — When different roles (e.g. finance analysts vs external auditors) may see different documents, enforce RBAC deterministically at retrieval, before content reaches prompt construction, because the model should only ever receive what the principal is entitled to see. This keeps unauthorized content out of prompts, traces, caches, tool results, and outputs.
- Trap: system-prompt "ignore docs you're not allowed", model refusal, or post-generation filtering. By then exposure has already happened.

**Authenticate, then authorize, then retrieve** — At scale, authenticate and authorize before retrieval so retrieval can filter by identity. Measure the RBAC enforcement rate on a red-team dataset with a target of effectively 100%, because functional tests miss bypass paths.

**Read ≠ disclose** — Authorization to read a document does not imply authorization to transmit it externally. Separate data access from external communication.

**Minimize what enters context and logs** — Redact/tokenize sensitive identifiers in logs unless their use is specifically required and authorized. Put PII redaction in pre-processing, before model invocation, and schema validation before persistence to the system of record.

---

## 4. Claude Code governance

### Settings scopes (verify against current Anthropic docs)
| Scope | Location / delivery | Use for | Not for |
|---|---|---|---|
| **Managed** (enterprise policy) | Deployed centrally by admins | Org-wide, non-overridable security/compliance controls | Repo-specific setup |
| **CLI arguments** | Per invocation | Session overrides | Durable policy |
| **Local** | Machine-specific, one person in one project | Personal per-project overrides | Security enforcement (not shareable or tamper-proof) |
| **Project** | `.claude/settings.json`, `.mcp.json`, `CLAUDE.md` committed to the repo | Team-shared MCP servers, permission rules, hooks, subagents, conventions | Secrets. Also not tamper-proof: anyone with repo write access can edit or delete it, and local settings override its non-permission values (a local *allow* still can't beat a project *deny*) |
| **User** | `~/.claude/settings.json` | Portable personal preferences (theme, response language) | Team consistency, company-wide controls, API keys |

**Precedence, highest → lowest: managed > command-line arguments > local > project > user.** Permission rules may merge across scopes rather than replace, and some security keys behave specially. **Deny beats allow from any scope**; evaluation order is deny → ask → allow.

**Managed for tamper-resistance** — When a control must be impossible for any single engineer to turn off, use managed settings marked non-overridable, because they beat CLI arguments and every user-controlled scope. Also verify the policy is actually delivered, monitor config changes, and make startup fail safe if the managed setting is missing or invalid.
- Trap: user scope (user can edit), CI env var (covers pipelines only, not IDE/interactive use), project scope (anyone with repo write access can edit or remove the rule).

**Project and managed complement each other** — Put team-shared config in project scope and mandatory security controls in managed. Project-scope MCP servers still need workspace trust/approval.

**Narrow Bash + explicit deny** — When permission rules grant unrestricted Bash, replace them with narrowly scoped command patterns the workflows need plus explicit deny rules for sensitive operations, because Bash exposes filesystem, credential, network, and infra capabilities. Where command patterns are fragile (network utilities), add WebFetch domain restrictions, hooks, and sandboxing (OS-level filesystem/network containment). Combine a managed baseline with project-specific permissions, and keep high-impact commands on confirmation.
- Trap: "simplicity", "consistency across tools", or disabling permission rules.

**Diagnose a denial; don't widen it** — When a permission is unexpectedly denied, inspect the effective rules across all scopes, find the denying rule, and amend only that rule if justified.
- Trap: retrying (the decision is deterministic), disabling permissions, granting broad Bash.

### Permission modes (six; verify against current Anthropic docs)
| Mode | Behavior | Use |
|---|---|---|
| **default** | Asks before each action | Interactive work |
| **acceptEdits** | Auto-approves file edits + common fs commands (mkdir, touch, rm, mv, cp, sed); other Bash still prompts | Trusted editing sessions |
| **plan** | Read-only until user approves the plan | Investigation before change |
| **auto** | Classifier approves safe actions, blocks risky ones; research preview, admin-enabled on Team/Enterprise | Reduced prompting with a model-based check |
| **dontAsk** | Auto-denies anything that would prompt; runs only allow-rule-covered actions | **Locked-down CI** |
| **bypassPermissions** | Skips all checks | Containers/CI only |

**dontAsk over bypassPermissions for CI** — When locking down CI, choose dontAsk, because it runs only allow-listed actions. bypassPermissions belongs only in isolated containers.

**Hooks vs permissions** — "Permissions govern what the agent is allowed to touch. Hooks govern what must happen before or after an action." Use a PreToolUse hook when a check must run before every tool call regardless of the model.

**Govern shared Skills** — Skills bundle instructions, scripts, and resources and may grant broad tool access, so at scale let teams author Skills but route them through a central review and publication gate that checks security, tool permissions, duplication, versioning, test evidence and compliance.

---

## 5. Prompt injection, untrusted content, exfiltration

**Exfiltration triad ("lethal trifecta")** — When an agent combines **untrusted content + sensitive data + a network-egress tool**, treat indirect prompt injection as the exfiltration vector. The signature: a retrieved document instructs the model to send sensitive content via an HTTP tool to an attacker URL. Break the triad by treating tool results as untrusted, restricting outbound domains, separating data access from external communication, using least-privilege tools, and requiring approval for sensitive transmissions.
- Trap: flagging normal authorized behavior (allow-listed 200s on a user request, routine Q&A, authorized retrieval).

**Indirect injection: mitigate at the input boundary plus output validation** — When retrieved or third-party content could carry instructions, label all retrieved content untrusted, keep tool results in clearly separated structures, screen with injection classifiers, and validate outputs. For production, stack several defences: track where each piece of content came from, keep it structurally apart from instructions, screen it, give the agent only the tools it needs, validate outputs against a schema, and have a person confirm any consequential action.
- Trap: citations (traceability only), egress allow-list (blast radius only), offline adversarial evals (catch regressions, not a live malicious doc).

**Direct injection / claimed authority** — When users embed "I am an admin, bypass restrictions", combine prompt instructions to treat user content as untrusted data, runtime classifiers for override attempts, tool permissions that user content cannot elevate (authorization comes from authenticated identity/role), and audit logging. Add rate limiting, escalation, and human confirmation for consequential actions.
- Trap: trusting the model alone; honoring self-asserted privilege (a fundamental authZ error).

**Open-web access adds injection and provenance risk** — When answers must come from an authoritative corpus, don't give the assistant open-web browsing.

---

## 6. Layered guardrails

**Robust = deterministic prevention + adversarial regression** — The marks of robust guardrails are per-role tool allow-lists that the orchestrator checks before it runs any tool call, plus adversarial inputs in the eval set with regression tracking of guardrail performance.
- Trap: centralized log review (detective), user-feedback backlog (reactive), refreshing refusal wording (unverified, prompt-only).

**Validation boundary + defense in depth** — Put deterministic schema validation (Structured Outputs) between model output and any downstream action, and layer prompt guardrails with runtime content checks (classifiers, policy engines, permissions, confirmation gates).
- Trap: a single hardened system prompt (single point of failure), lowering temperature, secret "override phrases" (a discoverable bypass).

**Hard content prohibition = preventive layers** — When the assistant must never give, e.g., regulated investment recommendations, use a system prompt that defines explicit out-of-scope categories with **fixed refusal phrasing**, plus a **pre-delivery output classifier** that blocks or replaces violating text. Test with adversarial prompts, paraphrases, multi-turn escalation, and classifier false negatives.
- Trap: SIEM logging (detective), session-length limits (volume, not content), temperature.

**Encode high-consequence guardrails structurally** — When a rule like "never promise a refund or timeline" is high-consequence, build it into the output contract rather than the role text, because "a rule stated in the role can be drifted past". The output contract is the strongest prompt-level place for it; then validate in code, which is stronger still.

**Templates make the safe path the default** — Fixed scaffolding carries the guardrails, so filling a slot can't remove a constraint. "An underspecified guardrail is worse than a missing one."

**Deterministic rules stay deterministic** — A rule the business counts on (thresholds, priority, refund qualification, tax) runs in code (SQL, a rule engine) on a structured field where one exists, e.g. a query against the claims table. Moving it into the model gives silent misroutes; in an illustrative case, 41 of 14,000 claims around a £5,000 threshold were misrouted. Where the value must come from prose, Claude extracts it into a typed field, and vague or approximate values ("around five thousand") are validated and routed to an exception/human queue, with test cases for boundary and hedged amounts. Extract-then-code alone still misroutes hedged amounts. The rule has a named human owner and is monitored.

---

## 7. Human oversight

### Placement by risk type, not just value
Justify delegation with **reversibility, stakes, accountability**. Also weigh risk *types*: **fraud potential, reversibility, identity sensitivity, cumulative exposure**, plus discrimination and policy inconsistency.

**Risk-stratified delegation over a dollar cutoff** — When a team argues "small refunds = low risk, auto-approve", automate routine, well-evidenced cases and escalate anomalous, disputed, identity-sensitive, or policy-edge cases, because small transactions still carry fraud, discrimination, inconsistency, and aggregate loss.
- Trap: review everything (kills value), maximize throughput, or ban delegation wherever money is involved.

**Pre-action gate for irreversible actions** — When output can trigger an irreversible or high-impact action (money, publishing, access rights, employment), place the human between the model output and the action, with explicit approval criteria and enough context for the reviewer. An action like auto-archiving with no gate is a defect.
- Trap: post-hoc audit (can't prevent harm), random sampling without criteria, removing review.

**Explicit escalation triggers** — Escalate on confidence below a defined threshold, high-impact decision categories, classifier ambiguity flags, and explicit user request for review, because escalation must happen before consequential execution and be auditable.
- Trap: model discretion, on-call availability, escalate-after-complaint.

**Missing escalation path is a defect** — Critique designs for what's absent: a routing design with no route to a human is the most-missed defect.

**Risk-stratified review sampling** — When reviewing everything is infeasible, review all low-confidence and high-impact outputs plus a random sample of high-confidence routine ones (to catch drift and overconfident errors). Sampling lower-stakes actions rather than gating each one is fine, as long as the sample follows these criteria. Feed reviewer decisions back into the eval set.
- Trap: complaint-only, reviewing only high-confidence outputs, universal review.

**AI stays advisory in approval workflows** — When adding Claude to PR review, have it post structured findings as comments. Humans keep approval under existing branch protection. Don't exempt AI-generated code from review by line count. Set review depth by risk: which components change, what privileges and data they touch, how reversible the change is, how well it's tested, and how widely it deploys.
- Trap: auto-merge, disabling protection, "<50 lines skips review", raising the threshold to 200.

**Named accountable human** — High-impact decisions keep human accountability. They are never attributed to the model. A rule the business counts on must be "tested, watched, and owned by a human". Compliance asking "which step approved the disbursement?" needs a discrete auditable step, not a model turn.

---

## 8. Regulated data (verify current scopes, eligible features, and FedRAMP levels against current Anthropic docs / Trust Center)

### Constraints eliminate options before cost or ergonomics
| Constraint | Rules out | Usually survives |
|---|---|---|
| Attorney-client privilege | Consumer Claude.ai; any surface the firm can't audit end to end | API/SDK behind the firm's app + SSO + approved LLM gateway; the **firm owns the audit trail** (audit *ownership*, not mere existence) |
| HIPAA (PHI) | Any entry point without a BAA for the **specific configuration** | BAA-covered config via the existing route; **beta features generally excluded** unless listed |
| GDPR / residency | Routes where the execution region can't be pinned | CSP route region-pinned, DPA inherited; Foundry: verify hosting form per model |
| FedRAMP / government | Paths not on an authorized cloud at the required level | Claude for Government (FedRAMP High); Bedrock GovCloud (FedRAMP High + IL4/5); Vertex Assured Workloads (FedRAMP High + IL2). Model lag applies |
| Internal residency policy | Routes outside the approved vendor list | Whichever CSP the CIO already cleared: "procurement, not engineering" |

**HIPAA turns on BAA coverage, not geography** — When PHI is involved, choose the route whose specific configuration is BAA-covered. A BAA for one config doesn't extend to another. If an existing BAA already covers a route, that removes compliance risk before any other tradeoff.
- Trap: "right route, wrong reason" (US region / residency); switching entry points to sign a new BAA when one is already confirmed.

**HIPAA package** — For a HIPAA-eligible deployment on Anthropic offerings, combine a commercial/Enterprise plan under a signed BAA, the HIPAA-ready configuration, **Zero Data Retention** where required, and configured **audit logging**. Keep PHI only within BAA-eligible services. Switch off feedback, beta and third-party paths the agreement doesn't cover. Never send PHI into training/feedback loops unless covered. Enforce RBAC at retrieval with audit events (minimum necessary). Enterprise alone isn't automatically covered, and the BAA is authoritative on covered features. Shared responsibility: the customer still owns access control, minimum-necessary use, workforce policy, retention, incident response, and vendor risk.
- Trap: consumer/personal accounts, disabling audit logs "to avoid storing PHI", "a BAA is blanket authorization", max_tokens/model/streaming as compliance.

**GDPR = contractual + technical + operational** — A commercial tier under a signed DPA (with SCCs), retention configured, personal data the task doesn't need redacted or minimized, and documented procedures for data-subject requests. The customer stays the controller.
- Trap: relying on the enterprise tier alone; personal tier without a DPA; pasting full personal data "for context".

**Privilege → client-owned audit** — When the GC requires AI tooling behind the firm's own audit infrastructure, choose API/SDK behind the firm's gateway over Claude.ai Enterprise, because Enterprise audit logs live in Anthropic's infrastructure. Privilege is not a residency constraint.

**Gating constraints first** — When a non-negotiable boundary exists (e.g. financial data must stay inside an approved network), resolve it before weighing ops savings or cost. For managed agents, check where inference runs, how sessions persist, encryption, which subprocessors are involved, how credentials are handled, whether actions are auditable, and how deletion works.

**Cache tenancy** — Prompt caches are isolated per organization (and per workspace on supported platforms) and held in memory, not persistent storage. Verify the tenancy config when residency matters.

**Tier by governance need** — Team: SSO/SAML, domain capture, contractual no-training. Enterprise: SCIM, configurable retention, audit logs, Compliance API, HIPAA-ready option with BAA. (Verify current tier features.)

---

## 9. Responsible AI

**Fairness = subgroup error rates** — For example, a system showing approval-rate parity and 94% agreement with human underwriters is still not shown to be fair. Require subgroup error analysis (confusion matrices, FPR/FNR, calibration, intersectional slices, confidence intervals). Agreement with humans is fidelity, not fairness; audit the reference labels, because matching biased history reproduces the bias.
- Trap: "needs a bigger sample" or "review missed groups" when no evidence supports them.

**Bias testing is mandatory even without company training data** — Pretraining, prompts, retrieval, proxies, and the workflow can all introduce bias. Test outcome disparity of the whole system (selection rates, FP/FN, calibration, intersectional slices, override patterns) before deployment.
- Trap: disclosure, provider responsible-use policy, "no protected-class labels" as substitutes.

**Representative evals** — An eval set from one region/tenure band must be expanded to the deployment population and rescored by slice before release.

**Ethics review checklist** — Include human accountability for high-impact decisions and checks that outputs don't rely on unsupported generalizations about people. Cover *all* outputs (models can be confidently biased), protected and intersectional groups, override mechanisms, transparency, and appeal channels.
- Trap: vendor licensing (legal), latency/throughput parity (operational), reviewing only by confidence threshold.

**Transparency** — When AI materially shapes user-facing output, disclose AI involvement proportionately and give a documented path to a human. You need not reveal proprietary prompts or security controls.
- Trap: concealment, refusing all questions about AI use, disclosing to staff only.

**Prompt bias** — Phrase neutrally and balance few-shot examples across real cases. Bias "shows up only in aggregate".

---

## 10. Risk classification, threat modeling, incidents

**LLM-intrinsic vs infrastructure failures** — Over-refusal triggered by surface features and plausible-but-ungrounded answers are model-behavior failures. Treat them with grounding, citations, permission to express uncertainty, verification, and model-specific evals. TLS expiry, load-balancer misroutes, and DB timeouts are infrastructure failures, handled with monitoring, config management, and retries. Prompt changes don't fix infra, and infra fixes don't fix behavior.

**Groundedness failures need generation-side controls** — Use citations, quotes, and post-generation claim verification rather than regression evals (detect only), OAuth (identity), or injection classifiers (malice).

**Threat model: assets and actors first** — Inventory assets touched (prompts, retrieved docs, credentials, outputs, audit logs, tools, external systems, sensitive data) with sensitivity classification, and enumerate threat actors and attack vectors before assessing likelihood/impact. Mitigations, residual-risk acceptance, and documentation come after. Keep threat models current with attacker tactics.

**Regulatory assessment order** — Determine applicability (data types, jurisdiction, audience) and inventory existing vendor compliance affordances (Trust Center, Compliance API, audit/retention/residency controls) before mapping data flows to clauses.

**Proportionate incident response** — When one fabricated citation is reported, sample recent outputs to estimate prevalence and audit for missing grounding controls before choosing a response.
- Trap: immediate shutdown with no diagnosis (may become right if the risk proves severe), dismissing it as an anecdote, telling users "it doesn't fabricate".

**Exposed secret** — Revoke/rotate first, then investigate history.

**Runbooks cover the full chain** — Detection → triage → containment/rollback → escalation, with dashboards/log references. Include data-governance events, prompt regressions, and cost anomalies. Exercise the runbooks and update them after incidents.

**Security audience gets evidence** — For security/compliance reviewers: threat model, control mappings, residual-risk acceptance criteria, audit traceability.

**Model governance** — Pin model versions and gate roll-forward on a stable adversarial/regression set with version-attributed scoring before promotion. An unpinned model rolled forward with no re-validation is "a model-governance gap that would hit any pattern".

---

## 11. Sequencing rules
| Process | Order |
|---|---|
| Solution design | Name user/work → apply non-discretionary constraints (privilege, BAA config, residency, FedRAMP, approved CSP) → *then* cost/latency/ergonomics |
| Data access | Authenticate → authorize → retrieve (filtered) → construct prompt → generate → validate → deliver/persist |
| Pipeline | Deterministic pre-processing (OCR, PII redaction, validation) → model stage → schema validation → human review where needed → persist |
| Threat assessment | Assets + sensitivity, threat actors + vectors → likelihood/impact → mitigations → residual-risk acceptance → document with owners |
| Regulatory assessment | Applicability → inventory existing affordances → map data flows to clauses → gap comparison → document gaps/residual risk → prioritize/approve → schedule remediation |
| HITL design | Identify oversight points by impact/reversibility → define sampling + escalation criteria per point → pilot on representative traffic → reviewer onboarding/SLA docs → iterate |
| Claude Code rollout | Workflows, security boundaries, managed-vs-project split → project baseline (MCP, permissions, subagents, CLAUDE.md) → limited pilot → evidence review → refine → docs/training → controlled expansion with rollback |
| Gate placement | Human gate **before** the irreversible action, never after; escalation **before** consequential execution |
| Secret exposure | Revoke/rotate → investigate history → move to secret store |
| Single reported failure | Measure prevalence + audit controls → proportionate response |
| Model change | Stable eval with version-attributed scoring → promote only if gates pass |
| Managed control rollout | Deploy → verify delivery → monitor changes → fail safe on missing/invalid |

---

## 12. Tempting wrong choices
- **Prompt as boundary**: "add a system-prompt instruction / rely on refusal / put it in the Skill" for authZ, audit, or compliance.
- **Too late**: post-generation filtering or render-time RBAC; post-hoc audit in place of a pre-action gate; escalate-after-complaint.
- **Right control, wrong risk**: allow-list → "prevents injection"; evals → "prevents exfiltration"; citations → "stops injection"; vault → "fixes shared identity".
- **Detective sold as preventive**: SIEM/log review, feedback backlog, offline evals offered where blocking is needed.
- **Irrelevant knobs**: temperature, max_tokens, streaming, biggest model, session limits as safety/compliance controls.
- **Wrong scope**: user/project/CI-env/local for tamper-proof policy; managed for repo-specific setup; secrets in any settings file.
- **Value as proxy for risk**: dollar cutoffs, PR line counts, confidence-only review scoping.
- **Wrong regulatory reason**: residency/region for HIPAA or privilege; Enterprise tier "alone" for HIPAA/GDPR; disabling audit logs to "reduce exposure".
- **Aggregate fairness**: approval-rate parity or agreement with humans offered as proof of fairness.
- **Absolutes**: review everything / remove all review / disable all tools or permissions / immediate shutdown.
- **Out-of-order steps**: mitigations before assets/threats; clause mapping before applicability; iterate before the pilot runs.
- **Flagging normal behavior**: authorized retrieval or allow-listed calls picked as the "risk signal".

---

## 13. Where the rules pull against each other
- **Value threshold vs risk type.** One default gates human approval by value ("refund above £2,000", "emails above a value threshold"). Another rejects monetary value *alone* as the delegation criterion and requires risk-type stratification (fraud, reversibility, identity sensitivity, cumulative exposure). Reconcile: a value threshold is one escalation trigger among several, never the sole one.
- **Sampling.** One rule says "sample lower-stakes actions rather than gating each one". Another insists sampling be risk-stratified with criteria (all low-confidence/high-impact + random slice) and rejects random sampling without criteria as an oversight mechanism. Reconcile: sample instead of gating low-stakes actions, but choose the sample by those criteria.
- **Where a guardrail lives.** One framing says a constraint built into the output contract "cannot be quietly ignored". Another treats anything the model generates as guidance and puts enforcement (authZ, audit, validation, classifiers) in the app layer. Reconcile: output contract for shaping (the strongest prompt-level place), plus deterministic validation of it.
- **Subagents.** Subagent compliance checks are the weakest deterministic guarantee, yet a *read-only subagent tool list* is a valid layer in production-DB defense. Reconcile: subagent tool scoping is configuration (enforceable); subagent judgment is not.
- **HIPAA entry point.** One default penalizes switching to Claude.ai Enterprise + new BAA when Bedrock is already BAA-covered. Another says the HIPAA posture is Claude Enterprise + BAA + ZDR + audit logging. Not contradictory: prefer existing confirmed coverage; absent that, the Enterprise + BAA + ZDR + audit package.
- **Permission mode names.** Mode names change between releases, and some references mention a "Manual mode starts read-only" term that is not among the six modes listed above. Verify mode names against current Claude Code docs.
