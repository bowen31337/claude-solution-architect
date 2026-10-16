# Claude Solution Architect — an Agent Skill

An [Agent Skill](https://docs.anthropic.com/en/docs/agents-and-tools/agent-skills/overview) that makes Claude reason like a senior **Claude solution architect**: it designs, critiques and defends systems built on Claude — the Claude API and SDKs, the Agent SDK, Claude Code, Claude.ai, MCP, Skills, and Amazon Bedrock / Google Vertex AI / Microsoft Foundry — and names the deciding tradeoff behind every recommendation.

It is built for the decisions that sit *above* the code: what Claude should own versus existing systems and humans, which pattern the work needs, how it is governed, and how anyone will know it works.

## What it does

| Mode | Give it… | You get… |
|---|---|---|
| **Design** | A business brief ("we want Claude to…") | A sequenced design: framing, Claude/system/human decomposition, pattern, reference architecture, per-step model tier and cost/latency estimate, prompting layer, entry point → interface → delivery route, governance, eval plan, rollout, and a Mermaid diagram |
| **Critique** | An architecture doc, diagram or proposal | Severity-ranked findings (principle, evidence, failure scenario, fix) — including what's *missing* — plus the sound parts you shouldn't change |
| **Scenario reasoning** | A multiple-choice, yes/no or ordering question | Option-by-option analysis, the binding signal in the question, and the deciding principle — useful for Claude Certified Architect exam study |

### Principles it applies

- Rules that must be right every time (thresholds, policy, math, access control) live in deterministic code — a prompt is not a security boundary.
- Live state comes from a tool call to the system of record, not from a retrieval index.
- Simplest pattern that meets the requirement: workflow before agent, one agent before many.
- Sonnet by default, tiered per step; every model swap is a release gated by a pre-registered eval and rollback criterion.
- Human gates placed by risk type and reversibility, not transaction size.
- Regulatory constraints (HIPAA/BAA, GDPR residency, FedRAMP, privilege) eliminate entry points and routes before preferences do.
- Evidence before changes; foundations before dependents.

## Install

**Claude Code (personal):**
```bash
git clone https://github.com/bowen31337/claude-solution-architect ~/.claude/skills/claude-solution-architect
```

**Claude Code (one project, shared with the team):**
```bash
git clone https://github.com/bowen31337/claude-solution-architect .claude/skills/claude-solution-architect
```

**Claude.ai / Claude apps:** zip the folder and upload it under *Settings → Capabilities → Skills*.

**Claude API:** upload via the Skills API and attach it to a container — see Anthropic's Agent Skills docs.

The skill triggers automatically when you ask Claude to design or review a Claude-based system, choose a model/entry point/route, place guardrails or human review, plan evals, or work through architect-style scenario questions.

## Example prompts

- *"We're an HVAC company on Azure with 300 technicians. Design a Claude assistant that answers from 2,000 service manuals, checks parts stock, and approves warranty claims over $1,500."*
- *"Review this support-bot architecture before steering committee: Opus with extended thinking on every message, a nightly vector index of orders, full history every turn…"*
- *"Our hospital already has a BAA with AWS. A vendor says just use Claude.ai Enterprise. Which entry point and route, and what's the deciding tradeoff?"*

## Structure

```
claude-solution-architect/
├── SKILL.md                         # modes, the 9-step design sequence, core principles, output templates
├── references/                      # loaded on demand
│   ├── design-workflow.md           # intake questions, step-by-step procedure, sequencing rules, checklist
│   ├── decomposition.md             # four properties, primitives, Claude / systems / humans split
│   ├── patterns-and-architectures.md# augmented LLM vs workflow vs agent, multi-agent, 5 reference architectures, RAG
│   ├── models-context-cost.md       # model tiering, context strategies, thinking, caching, cost/latency estimation
│   ├── prompting-and-skills.md      # system prompts, guardrails, techniques, Skills vs prompt libraries
│   ├── entry-points-integration.md  # Claude.ai / Claude Code / API / SDK / Agent SDK / MCP; Bedrock / Vertex / Foundry
│   ├── governance-safety.md         # least privilege, settings scopes, prompt injection, HITL, HIPAA/GDPR, responsible AI
│   ├── claude-code-enablement.md    # team rollout, CLAUDE.md, hooks, permission modes, CI, MCP ops, productivity metrics
│   ├── evaluation-testing.md        # eval design, regression gates, experiments, diagnosis, optimization order
│   ├── lifecycle-stakeholders.md    # success criteria, SLAs, value pillars, stakeholder comms, ADRs, rollout
│   ├── anti-patterns.md             # named failure patterns, quick-scan checklist, common distractor shapes
│   └── glossary.md
└── evals/evals.json                 # test prompts and assertions used to evaluate the skill
```

## How it was tested

The skill was developed with Anthropic's `skill-creator` eval loop. Each test prompt runs with and without the skill, and the outputs are graded against assertions. The suite covers:
- full designs: field service, insurance claims, healthcare prior authorization
- critiques: an over-provisioned support bot, a fan-out contract audit, a telco RAG/agent design, and a mostly-sound invoice pipeline that tests whether the skill over-flags correct components
- scenario questions with distractors where the reasoning is right but the answer is wrong

Assertions check substance, for example:
- live state comes from tool calls
- thresholds are enforced in code
- human gates sit before irreversible actions
- eval thresholds are fixed before the data comes in

They also check answer quality: proportionate length, no invented statistics. See `evals/evals.json`.

## Caveats

- Model names, prices, feature availability, cloud-provider model coverage, FedRAMP scopes and BAA-eligible features change often. The references mark these values as snapshots to verify against [current Anthropic documentation](https://docs.anthropic.com).
- Numbers in the references, such as cost multiples and accuracy deltas, illustrate failure modes. They are not benchmarks.
- This is an independent community project. It is not affiliated with, endorsed by, or an official resource of Anthropic, and it contains no official certification exam content.

## License

MIT — see [LICENSE](LICENSE).
