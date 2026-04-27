# Memory Policy

Agent memory is durable project context. Treat it as a controlled input, not casual notes.

## Rules

- Memory entries should be append-only unless the human asks for cleanup.
- Each new entry should include date, source, confidence, scope, and content.
- Do not add speculative claims as memory without marking confidence.
- If memory becomes wrong, add a superseding entry instead of silently deleting it.
- Role memory should stay role-specific. Shared conventions belong in `AGENTS.md` or `.agents/sop.md`.

## Entry Template

```md
### YYYY-MM-DD - Short Title
Source:
Confidence: low | medium | high
Scope:
Supersedes:

Content:
```

