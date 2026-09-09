# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

**This repo is single-context.**

## Before exploring, read these

- **`CONTEXT.md`** at the repo root
- **`docs/adr/`** — read ADRs that touch the area you're about to work in.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront. The `/domain-modeling` skill (reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates them lazily when terms or decisions actually get resolved.

Neither exists yet in this repo — that is expected, not a gap to fill.

## File structure

Single-context repo (this repo, and most repos):

```
/
├── CONTEXT.md
├── docs/adr/
│   ├── 0001-tcp-connection-lifecycle.md
│   └── 0002-protocol-based-dependency-injection.md
└── Sources/
```

If this ever becomes a multi-package repo, the multi-context layout is a root `CONTEXT-MAP.md` pointing at one `CONTEXT.md` per context, with context-scoped `docs/adr/` alongside each.

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal — either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (event-sourced orders) — but worth reopening because…_

## Related but separate

The `context/` symlink at the repo root points at a separate context-engineering repo (plans, status, decisions, learnings). It is not part of this domain-doc layout — `CONTEXT.md` and `docs/adr/` live in this repo and are committed with it.
