# Secrets Policy

Agents must not write secrets, tokens, passwords, private keys, or credentials into the repository.

## Never Commit

- `.env` files with real values
- API keys or bearer tokens
- private keys
- database passwords
- OAuth client secrets
- session cookies
- production credentials

## Allowed

- `.env.example` with placeholder values
- documentation that uses obvious placeholders such as `YOUR_API_KEY`
- local-only ignored files

## If A Secret Is Found

1. Stop work on the affected task.
2. Mark the task `blocked`.
3. Add a security finding to `.agents/security-report.md`.
4. Rotate the secret if it was real.
5. Remove it from git history before sharing the branch.

