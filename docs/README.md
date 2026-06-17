# Road Safety Game documentation

## Tracked in git (spec kit)

| Path | Purpose |
|------|---------|
| [`core-game-rules.md`](./core-game-rules.md) | **Canonical gameplay rules** — zones, levels, scoring |
| [`specs/README.md`](./specs/README.md) | How to write and use per-feature specs |
| [`specs/_template.md`](./specs/_template.md) | Copy for each new feature spec |
| [`specs/YYYY-MM-DD-*.md`](./specs/) | One spec per shippable change |

Agents: [`.cursor/rules/spec-driven.mdc`](../.cursor/rules/spec-driven.mdc) · workspace [`AGENTS.md`](../../AGENTS.md)

## Workflow (quick)

1. Copy `specs/_template.md` → `specs/YYYY-MM-DD-feature-name.md`
2. Cite affected sections of `core-game-rules.md` in Background
3. Prompt: *Implement per `docs/specs/….md`. Do not edit the spec file.*
4. **Same task as code:** update core rules, spec checkboxes, `AGENTS.md` only for stable preferences
