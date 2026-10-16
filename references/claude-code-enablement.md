# Claude Code enablement and developer productivity

Covers developer productivity and operational enablement with Claude Code: customization and governance layers, the coding-agent reference architecture, and common ways Claude Code is misused. Deeper security controls (managed-settings hardening, deny rules, secrets, least-privilege tool audits) live in `governance-safety.md`. This file keeps them brief and points there.

## Contents
1. Shaping vs governing layers
2. Permission modes (all six) and sandboxing
3. Where configuration lives: scopes and precedence
4. Decision rules: layer choice and context hygiene
5. Decision rules: configuration scope
6. Decision rules: team rollout and Skill governance
7. Decision rules: CI and headless use
8. Decision rules: MCP troubleshooting and Tool Search
9. Coding-agent architecture and PR workflow
10. Measuring developer productivity
11. Sequencing rules
12. Recurring distractor patterns
13. Where the rules pull against each other

---

## 1. Shaping vs governing layers

A layer is a discrete configuration entry point controlling one aspect of how the agent thinks or acts. Layers are independent, composable, and applied at different execution points. Keep the two groups apart: shaping layers make the agent useful, and governing layers make it safe. Most design errors come from putting a guarantee in a shaping layer.

| Group | Layer | What it is | Use it for |
|---|---|---|---|
| Shaping | **CLAUDE.md** | Markdown loaded at session start | Persistent context for every task: coding standards, repo layout, team conventions |
| Shaping | **Skills** | Markdown procedures (SKILL.md + optional scripts) invoked on demand, not loaded upfront | Repeatable workflows: commit-push-PR, release notes, schema migration. On-demand loading keeps context lean |
| Shaping | **Subagents** | Isolated context-window helpers with their own prompt, tool list, model | Bounded tasks that would clutter the main thread (code review, codebase exploration); read-only or restricted tool surfaces |
| Shaping | **MCP servers** | External tools/data over the protocol | Tools that must be reusable across clients (e.g. a team Linear server also used from Claude.ai) |
| Governing | **Hooks** | Scripts on lifecycle events (before/after tool, session start, stop) | Deterministic gates the agent cannot skip. The guarantee comes from code, not prompting |
| Governing | **Permission boundaries & approval flows** | Six permission modes + allow/ask/deny rules | Anywhere an unintended action has non-trivial cost |
| Governing | **Sandboxing & restricted execution** | Filesystem boundaries, network egress rules, constrained command surfaces | Where a wrong action has real consequences and approval prompts alone are not a sufficient backstop |

Lines worth reusing: "Permissions govern what the agent is allowed to touch. Hooks govern what must happen before or after an action." "The environment itself should enforce the boundary, not just the agent's judgment." Primitive jobs: Skills = *package a procedure*, Hooks = *guarantee*, Subagents = *isolate/parallelize*, MCP = *connect*. Only hooks enforce deterministically.

## 2. Permission modes and sandboxing

Verify current mode names and availability against current Anthropic docs. Auto mode was a research preview at the time of writing.

| Mode | Behaviour | When to use |
|---|---|---|
| **default** | Asks before each action | Interactive work in an unfamiliar or sensitive repo; the safe baseline |
| **acceptEdits** | Auto-approves file edits and common fs commands (mkdir, touch, rm, mv, cp, sed); other Bash still prompts | Trusted repo, iterative editing where edit prompts are pure friction but shell commands still deserve a look |
| **plan** | Read-only until the user approves a plan | Exploration and design before change; high-risk changes where you want a reviewed plan first |
| **auto** | Classifier approves safe actions, blocks risky ones. Research preview; all plans; admin-enabled on Team/Enterprise; defaults to the Anthropic API as provider; an environment variable enables cloud-provider routes (verify current docs) | Longer interactive sessions where prompt fatigue is the problem and an admin has enabled it |
| **dontAsk** | Auto-denies anything that would prompt; runs only what allow rules cover | **Locked-down CI**: headless, nobody to answer prompts, explicit allow-list defines the job |
| **bypassPermissions** | Skips all checks | Only inside an isolated container/CI sandbox where the environment is the boundary |

Permission rules are allow / ask / deny patterns. Deny is evaluated before ask and allow, and a deny from any scope wins over allow. Rules may merge across scopes rather than replace. Sandboxing (OS-level filesystem and network containment), WebFetch domain restrictions and hooks back up command patterns that are fragile on their own, such as network utilities. Details: `governance-safety.md`.

## 3. Where configuration lives

| Scope | Location (typical) | Shared? | Put here |
|---|---|---|---|
| **Managed** | Admin-deployed policy file / MDM | Org-wide, non-overridable | Security and compliance controls no individual may disable |
| **Command-line arguments** | Per invocation | No | One-off overrides for a single run |
| **Local project** | `.claude/settings.local.json` (not committed) | One person, one project | Machine-specific tweaks to a project |
| **Shared project** | `.claude/settings.json`, `.mcp.json`, `CLAUDE.md`, committed | Everyone who clones the repo | Team-shared MCP server definitions, permission rules, hooks, subagents, project context |
| **User** | `~/.claude/settings.json` | One person, all projects | Personal preferences: theme, editor, preferred response language |

Precedence, highest to lowest: **managed > command-line arguments > local project (`.claude/settings.local.json`) > shared project (`.claude/settings.json`) > user (`~/.claude/settings.json`)**, and deny rules win over allow. Managed sits on top so no repo or person can defeat a central control. Some security keys have special behaviour, and permission rules can merge, so check the effective rule set rather than assuming the top file wins. Verify against current Claude Code settings docs.

Secrets go in none of these files. Committed config holds server definitions and env-var references; credentials resolve at runtime from a secret manager or OS credential store. "Not committed" (user/local scope) is still plaintext and still wrong. Project-scope MCP servers still require workspace trust/approval on each machine. See `governance-safety.md` for secret handling and managed-setting delivery checks.

---

## 4. Decision rules: layer choice and context hygiene

**CLAUDE.md for repeated context** — When engineers re-explain conventions or architecture at the start of every session, choose a project-scoped CLAUDE.md committed to the repo over manual re-entry or dropping the standards, because it loads automatically every session, applies the same for every engineer, and goes through code review.
- Trap: "retype faster", "ban the tool", or "delete the conventions". All keep the waste or lose consistency.
- Keep CLAUDE.md concise and specific (adherence improves) and review it periodically for stale, conflicting or verbose content.

**Subagent only for a recurring specialization** — When a task recurs and needs its own focused prompt, narrow tool permissions, or a different model (e.g. DB schema review), choose a dedicated subagent over the general agent, because it encodes the role once, isolates context and applies least privilege. For one-off or generic work, skip it.
- Trap: defining a subagent for an ad hoc question or with the same generic prompt as the main agent. That is maintenance overhead with no specialization.
- Give each subagent a triggering description, eval cases, an owner and lifecycle review.

**Subagents for exploration, grounded in source** — When output must reflect current private code (docs generation, impact analysis), choose subagents that read files with scoped read-only search tools over training-data recall, because recall cannot represent the current implementation, and the exploration stays out of the main context.
- Trap: "Claude already knows this framework". Parametric knowledge is not the repo.
- Route the generated artifact through normal change control (PR, checks, human approval), never direct publish.

**Skill vs CLAUDE.md** — When a procedure is run on demand (release notes, migration steps), choose a Skill over pasting it into CLAUDE.md, because Skills load only when invoked and CLAUDE.md is paid for in every session's context.
- Trap: stuffing every procedure into CLAUDE.md "so it is always available". That bloats context and dilutes adherence.

**Hook for a rule that must hold** — When a check must run every time (block writes to protected paths, run a formatter or secret scan before commit), choose a hook (e.g. PreToolUse) over a CLAUDE.md instruction or a subagent, because only code-level gates cannot be skipped by the model.
- Trap: "add it to CLAUDE.md in bold". Instructions shape behaviour and guarantee nothing.

**Deliver assistance where developers work** — When the goal is developer productivity, choose Claude Code in the IDE/terminal over a separate channel such as a shared Slack bot, because the integration point decides context availability and context-switching friction. The model being the same does not make them equivalent.
- Trap: "Slack gives an audit log". True but secondary; telemetry and repo history provide the trail.

**Claude Code is for engineers** — When the users are not engineers (branch staff, warehouse staff, ops), do not choose Claude Code, because it is an engineering entry point that assumes a terminal. Name the user first.
- Trap: "it's all Claude", or carrying the tool forward from the last project.

## 5. Decision rules: configuration scope

**Project scope for team-shared config** — When every engineer on a repo needs the same MCP servers, permission rules, hooks and context, choose committed project scope (`.claude/settings.json`, `.mcp.json`, `CLAUDE.md`) over user/local scope or scripts syncing personal files, because it distributes through clone/pull/review with version history and no drift.
- Trap: managed config for repo-specific setup. Managed is for org-wide policy, not per-repo tooling. Also traps: OS env vars per workstation, the lead's local file.

**Managed scope for non-overridable controls** — When a security setting must hold org-wide and no individual may turn it off, choose managed settings over project, user or CI env vars, because managed takes precedence over CLI args and every user-controlled scope. Project and managed complement each other.
- Trap: project scope (anyone with repo write access can edit or remove the rule; local settings override its other values, though a local allow can't beat a deny) or a CI env var (covers pipeline runs only, not local or IDE use).

**User scope for portable personal preferences** — When a setting is one engineer's preference across all projects (theme, response language), choose user scope, because it follows the person and affects no one else.
- Trap: putting personal preferences in project scope, or API keys in user settings (credential handling, not a preference).

**Diagnose an unexpected permission denial** — When Claude Code denies an action the engineer expected to be allowed, choose inspecting the effective rules across all scopes to find the specific denying rule, then decide whether to amend or keep it, over retrying, disabling permissions, or granting broad Bash, because the decision is deterministic and least privilege must hold.
- Trap: "allow Bash(*) to unblock". It fixes one prompt and removes the whole boundary.

## 6. Decision rules: team rollout and Skill governance

**Design before pilot** — When rolling Claude Code into a team, do role-boundary design (which steps benefit from AI, where human authority stays, what goes in managed vs project scope) and baseline environment setup (project MCP servers, permissions, subagents, CLAUDE.md) before the pilot, because a pilot must test a deliberately designed, consistently configured workflow.
- Trap: full runbooks, org-wide training, sign-off from every manager, or "iterate on findings" before the pilot. Those mature after evidence exists.

**Keep only needed tools in the baseline** — When building the baseline, include tools and MCP servers that trace to defined workflows and remove speculative ones, because every tool adds attack surface, context cost, authorization complexity and eval burden.
- Trap: "enable everything so the pilot isn't blocked".

**Federated authorship, central review gate** — When shared Skills (standards, review checklists, postmortem templates) roll out to many teams, choose federated authorship by domain teams plus a central review-and-publication gate over a single central team or fully decentralized authoring, because domain teams own content while the gate checks security, tool permissions, duplication, versioning, test evidence and compliance.
- Trap: central platform team writes everything (bottleneck, no domain expertise), or anyone publishes (inconsistent, possibly unsafe). Skills can bundle scripts and grant tool access, so review before publication is required.

**One owner-maintained Skill, referenced everywhere** — When a procedure must behave identically across workflows and changes periodically, choose one versioned Skill with a named owner over copies in each system prompt or CLAUDE.md, because one authoritative version propagates changes and does not drift.
- Trap: per-team copies "so teams can adapt it".

## 7. Decision rules: CI and headless use

**dontAsk for locked-down CI** — When Claude Code runs headless in a pipeline with no one to answer prompts, choose dontAsk with an explicit allow-list over bypassPermissions, because dontAsk runs only allow-listed actions and auto-denies the rest, so the allow-list is the job definition.
- Trap: bypassPermissions "because there's nobody to approve". It skips every check, so it belongs only in an isolated, disposable container where the sandbox is the boundary.

**Sandbox the runner** — When a CI agent can run shell commands, contain the runner (filesystem boundaries, egress rules, scoped short-lived credentials) in addition to permission rules, because approval rules alone are not a sufficient backstop when a wrong command has real consequences.
- Trap: relying on the prompt or on allow patterns for network tools.

**AI review is advisory** — When adding Claude Code to the PR workflow, have it post structured findings as PR comments and leave approval with humans under existing branch protection, because accountability and separation of duties stay with people.
- Trap: auto-merge after analysis, relaxing branch protection, silently closing low-quality PRs.

**No size-based review exemptions** — When review capacity is short, do not exempt small AI-generated PRs from review, because removing review removes the verification step AI output needs, and line count is a poor proxy for risk (a one-line auth change outweighs a large docs edit). Base review depth on component, privilege, data sensitivity, reversibility, tests and deployment impact.
- Trap: raising the threshold (same flawed proxy) or rejecting all AI PRs (discards value).

## 8. Decision rules: MCP troubleshooting and Tool Search

**Least-destructive diagnostic first** — When a newly added MCP server does not appear, check registration first (`claude mcp list` or `/mcp`), then restart/reconnect the session (config changes usually need it), then `claude mcp get <name>` for transport, command, credentials and approval state, because targeted checks keep evidence and working capability.
- Trap: disabling all servers, reinstalling, switching products. These destroy comparison points.

**Minimal repro, one variable at a time** — When diagnosing Claude Code operational problems, build a minimal reproduction and inspect MCP status before changing the environment, because that separates model behaviour from transport, auth, config and workspace-trust failures.
- Trap: raising temperature, filing a ticket before local evidence, rolling back before capturing a baseline.

**First-run OS permission prompts are transient** — When an MCP server fails on first launch while OS permission dialogs appear, and later runs succeed, confirm repeatability and document the first-run grant in onboarding, because it is expected initialization behaviour.
- Trap: suppressing permission dialogs (weakens endpoint security) or replacing a working server.

**Tool Search for large catalogs** — When many MCP servers bloat context before the user types (e.g. ~50k tokens, 60+ tools), enable Tool Search (deferred schemas, discovered on demand) over disabling servers, a fixed hard-coded subset, or a bigger context, because only selected tools enter context and all capability is kept.
- Trap: blaming client-side factors, adding a tool-summarizing call each turn, or adding more servers.
- Also tighten server and tool descriptions so discovery picks correctly, monitor tool-selection accuracy, and keep only eval-justified foundational tools non-deferred. Verify Tool Search availability and defaults against current docs.

## 9. Coding-agent architecture and PR workflow

Good shape, two phases:
1. **Agentic investigation** of the codebase. The path cannot be written in advance, so the agent pattern earns its place here.
2. **Deterministic edit steps: parse, plan, propose, test, review**, with defined handoffs. Subagents take isolated tasks with enough context, but not so much that steps become unmanageable.

Where it goes wrong: the agent edits and commits **without a human review gate**; no tracking of **regression rates against an eval set per language/framework**; treating it as a conversation rather than a **structured pipeline with defined handoffs**.

Context strategy for a long-running coding agent combines all four: monolithic prefix at session start (task + referenced files, cache-friendly), progressive recent state during active work, just-in-time retrieval for unloaded files, compaction of verbose early exploration. Compaction must keep identifiers, numbers, prior decisions and one-off edge cases.

**Human gate before commit/merge** — When a coding agent can change code, require human review before commit or merge and keep branch protection, because the agent fails by making a bad decision somewhere in its trajectory, with no code boundary where a guard sits.
- Trap: "tests pass, so auto-commit". Tests are one deterministic step, not the review.

**Per-language regression evals** — When a coding agent serves several languages or frameworks, track regression rates against a stable eval set per language/framework, and re-run on every model or prompt change, because a healthy aggregate can hide one stack regressing.
- Trap: one blended success rate.

## 10. Measuring developer productivity

Use the business-value pillars and keep them distinct:

| Pillar | Measures | Coding example |
|---|---|---|
| Efficiency | Same unit of work done faster, or more per person, within the existing process | Time to first PR draft |
| Productivity | Realized organizational output beyond per-task speed | Features shipped, lead time, change-failure rate |
| Transformation | Structural redesign of roles or process | Engineers redeployed from boilerplate to design work |
| Solution cost | Spend vs the approved cost model | Tokens and seats per merged PR vs the modelled cost |
| Performance SLA | Measured metric vs committed threshold | CI agent p95 latency vs its committed SLA |

**Net, outcome-based metrics, not acceptance rate** — When reporting developer productivity, choose net outcome metrics (cycle time after review and rework, defect and revert rates, review time added, cost per merged change) over suggestion acceptance rate or generation speed alone, because acceptance is a proxy that says nothing about whether accepted code survives review, and correction effort offsets gross speed gains.
- Trap: for example, a team reports "89% acceptance, ship it" while reviewers keep overriding. Overrides signal an input-scope gap and an outcome-validity gap.

**Efficiency is not productivity** — When engineers save time but output is unchanged, report "productivity not yet realized", not success, because freed time has not turned into organizational output.
- Trap: counting time saved as productivity.

**Operational runbook completeness** — When writing the runbook for a Claude-based developer service, include alerts with triage steps, escalation paths, rollback procedures and pointers to dashboards/logs, covering model errors, latency, rate limits, tool failures, prompt regressions, cost anomalies and dependency outages. Test them in exercises and update after incidents.
- Trap: any partial subset (dashboards only; alerts and triage only).

## 11. Sequencing rules

- Rollout: discovery → boundary definition (human authority, managed vs project) → baseline design (project MCP, permissions, subagents, CLAUDE.md) → limited pilot → evidence review → baseline refinement → docs/training → controlled expansion with support and rollback.
- Before any CLAUDE.md/Skill/hook decision: name the user. If they are not engineers, Claude Code is the wrong entry point.
- MCP troubleshooting: list/status → restart session → `claude mcp get` detail → minimal repro → only then environment changes or rollback, as a controlled comparison.
- Coding change: agentic investigation → plan → propose edit → test → AI review comment → human approval under branch protection → merge.
- Skill publication: domain team authors → central review (security, tool permissions, duplication, versioning, test evidence) → publish versioned → owner maintains.
- Model or prompt change for a coding agent: re-run per-language regression evals before rollout.

## 12. Recurring distractor patterns

- Putting a guarantee in a shaping layer (CLAUDE.md line, Skill, subagent) instead of a hook, permission rule or sandbox.
- bypassPermissions for CI "because no one can approve" when dontAsk + allow-list fits.
- Managed config for repo-specific setup, or project config for a control that must resist override.
- Secrets in any settings file, including uncommitted user/local files.
- Destructive troubleshooting (disable all servers, reinstall, switch tools) before `claude mcp list` and a restart.
- Fixing tool-catalog bloat by removing capability or enlarging context instead of Tool Search.
- Auto-merging or exempting "small" AI PRs from review.
- Measuring success by acceptance rate or raw speed.
- Running training, runbooks or org-wide rollout before the pilot.
- Claude Code for non-engineering users; MCP carried forward with no reuse need.

## 13. Where the rules pull against each other

- **MCP reuse test.** One rule says MCP earns its place only when a tool is reused across two or more clients; otherwise use plain API tool use. Another treats committed project-scope MCP servers as the normal way to give a Claude Code team shared tools. Reconcile: inside Claude Code, MCP is simply the mechanism for connecting external tools, so the reuse test applies to custom products built on the API, not to equipping Claude Code itself.
- **Subagents as a control.** One framing calls compliance-by-subagent the weakest deterministic guarantee. Another lists a read-only subagent tool list as one layer of defense in depth (e.g. production DB safety). Reconcile: a restricted subagent tool list is a valid layer when backed by a least-privilege credential and a human gate; a subagent that *judges* compliance is not a control.
- **Permission modes vs permission rules.** One emphasis is choosing the right mode (bypassPermissions for isolated containers/CI only, dontAsk for locked-down CI); another is getting the allow/ask/deny rules and their scopes right (managed > command-line arguments > local project > shared project > user; deny wins; secrets never in config). No conflict: both express the same least-privilege instinct, and a mode is only as safe as the rules behind it. Verify scope and precedence behaviour against current Claude Code settings docs.
