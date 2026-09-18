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

<!-- BEGIN ores-agents-pointer: managed by ORESoftware/my-ai; edit there, not here -->

## Canonical agent instructions

Before doing anything else in this repository, also read:

    .ores/agents/AGENTS.md

That path is a symlink to `~/codes/oresoftware/my-ai/AGENTS.md`, whose canonical copy is
<https://github.com/ORESoftware/my-ai/blob/main/AGENTS.md>.

It exists at a fixed path *inside* the repository because some agents cannot walk up past
the repository root, so machine-wide instructions one or more directories above are
invisible to them. This pointer plus that path make the same file reachable from a working
directory anywhere in the tree.

The symlink is deliberately **not committed**: it names an absolute path that is only valid
on a machine with `~/codes/oresoftware/my-ai` checked out, so committing it would produce a
broken link for everyone else and for CI. `.ores/` is git-ignored for that reason. If
`.ores/agents/AGENTS.md` is missing on your machine, create it with:

    mkdir -p .ores/agents
    ln -sfn "$HOME/codes/oresoftware/my-ai/AGENTS.md" .ores/agents/AGENTS.md

or run `~/codes/oresoftware/my-ai/scripts/link-repo-agents.sh` once to do it for every git
repository under `~/codes`, and `--check` to verify them.

A missing `.ores/agents/AGENTS.md` is a setup gap on the reader's machine, never a reason to
skip the canonical instructions: fetch them from the URL above instead.

<!-- END ores-agents-pointer -->
