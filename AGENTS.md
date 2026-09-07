# Agent instructions

## Repository and tracking

- Canonical product repository: `github.com/fanwaave/push-notification-server.rs`.
- This repository, `github.com/ORESoftware/push-notification-server.rs`, is an independent historical/source copy. It is not an automatic redirect or mirror.
- New product work, releases, packages, container images, deployments, and provider integrations belong in the canonical Fanwaave repository.
- Linear project: `github.com/ORESoftware/push-notification-server.rs` remains the legacy tracker name for historical work; new Fanwaave product work should use the current Fanwaave project and issues.
- Historical parent implementation issue: `DEN-257`.
- Historical bootstrap: `DEN-259`.
- Historical provider extraction: `DEN-261`.
- Historical cluster submodule/deployment: `DEN-263`.
- Historical Supabase integration: `DEN-264`.
- Historical reliability/security/observability: `DEN-265`.

Do not mechanically replay or merge historical dependency updates into Fanwaave. Re-evaluate each change against the canonical repository's current source, lockfile, instructions, and exact-head checks.

## Git workflow

- Work from focused feature branches cut from current `main` and use pull requests.
- Avoid git rebase in favor of git merge.
- Sync with remote before and after material work.
- Resolve git conflicts semantically: do not merely pick one side. Preserve compatible behavior, contracts, tests, documentation, and security boundaries from both sides.
- After resolving conflicts, grep the entire worktree for conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`), review affected files from the top, and rerun every affected contract.
- Never force-push shared branches, rewrite reviewed history, or bypass exact-head checks.
- Never commit secrets, production device tokens, Web Push capability URLs, provider private keys, recipient addresses, or phone numbers.

## Nested instructions

Before editing, walk upward from `$PWD` to the filesystem root and apply every relevant `AGENTS.md`, from broadest to most specific.
