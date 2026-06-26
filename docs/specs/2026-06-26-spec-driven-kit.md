# Spec-driven kit & core game rules

| Field | Value |
|-------|--------|
| **Status** | Done |
| **Author** | |
| **Created** | 2026-06-26 |
| **Related** | Cursor agent workflow |

---

## Goal

Give agents a **spec-driven development kit**: canonical gameplay rules, per-feature specs, always-on Cursor rules, and a requirement to **update docs in the same task as code** so behaviour and documentation stay aligned.

## Non-goals

- Full GitHub Spec Kit CLI integration
- Actor workflow docs / smoke registry (LMS-style `docs/workflows/` — not needed for this Flutter game yet)
- Replacing workspace [`AGENTS.md`](../../../AGENTS.md) (preferences + deep ops facts remain there)

---

## Background

- Prior work used ad-hoc chat without a formal completion gate or meta-spec recording the kit itself.
- Partial kit already existed: `docs/core-game-rules.md`, `docs/specs/`, `.cursor/rules/spec-driven.mdc`.
- Touches: agent workflow only (no product gameplay changes).

---

## Requirements

### Functional

1. `docs/core-game-rules.md` — canonical gameplay rules (TMX zones, levels, scoring, scenarios).
2. `docs/specs/` — README, `_template.md`, dated specs per feature; architecture reference [`2026-06-26-level-system-design.md`](./2026-06-26-level-system-design.md).
3. `.cursor/rules/spec-driven.mdc` — always apply: read specs, **agent completion gate** before finishing non-trivial tasks.
4. `.gitignore` — track spec kit + `.cursor/rules/`; keep `.cursor/mcp.json` and local secrets local if added later.
5. Workspace `AGENTS.md` — pointers to core rules, level-system spec, and doc-sync obligation.

### Access & eligibility

- N/A (documentation only)

---

## Technical design

### Delivered files

| Item | Path |
|------|------|
| Core rules | `docs/core-game-rules.md` |
| Spec index | `docs/README.md` |
| Spec workflow | `docs/specs/README.md`, `docs/specs/_template.md` |
| Meta spec | `docs/specs/2026-06-26-spec-driven-kit.md` (this file) |
| Level architecture | `docs/specs/2026-06-26-level-system-design.md` |
| Agent rule | `.cursor/rules/spec-driven.mdc` |
| Preferences | `AGENTS.md` (workspace root) |
| Git tracking | `.gitignore` exceptions for spec kit |

---

## Acceptance criteria

- [x] `docs/core-game-rules.md` covers TMX zones, road-crossing, junctions, scoring, level curriculum (§7), adverse weather (§8)
- [x] `.cursor/rules/spec-driven.mdc` includes **agent completion gate** (core rules, specs, AGENTS.md policy)
- [x] `_template.md` includes Spec kit updates checklist + completion gate reference
- [x] `docs/README.md` and `docs/specs/README.md` document workflow, specs vs plans, and sync table
- [x] `.gitignore` tracks `docs/` spec kit and `.cursor/rules/`; ignores local Cursor state
- [x] **Spec kit updated** — this file records the kit itself; all dated specs normalized to template

---

## Test plan

### Manual

1. `@docs/core-game-rules.md` in a Cursor prompt — agent cites §3 road-crossing zebra wait rule.
2. Start a feature with a dated spec — agent offers to update core rules when changing zone behaviour.
3. `git status` shows `docs/specs/`, `docs/core-game-rules.md`, `.cursor/rules/spec-driven.mdc` as addable.

---

## Spec kit updates (required when shipping)

- [x] [`../core-game-rules.md`](../core-game-rules.md) — §1–§8 (pre-existing)
- [x] This spec — **Status** → Done
- [x] `AGENTS.md` — spec kit + completion gate bullets
- [x] `.gitignore` — spec kit + `.cursor/rules/` tracking

---

## Implementation log

| Date | Note |
|------|------|
| 2026-06-26 | LMS-style spec kit: completion gate in spec-driven.mdc; meta spec; README/template upgrades; gitignore for `.cursor/rules/` |
| 2026-06-26 | Normalized all dated specs to completion-gate template + spec index in specs/README |
