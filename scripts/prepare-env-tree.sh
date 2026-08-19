#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'encrypted-env prepare: %s\n' "$*" >&2
  exit 1
}

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) \
  || fail "not inside a Git repository"

assert_directory_path() {
  local path="$1" label="$2"
  if [ -L "$path" ]; then
    fail "$label must not be a symlink: $path"
  fi
  if [ -e "$path" ] && [ ! -d "$path" ]; then
    fail "$label must be a directory: $path"
  fi
}

assert_regular_or_absent() {
  local path="$1" label="$2"
  if [ -L "$path" ]; then
    fail "$label must not be a symlink: $path"
  fi
  if [ -e "$path" ] && [ ! -f "$path" ]; then
    fail "$label must be a regular file: $path"
  fi
}

assert_tree() {
  local rel
  for rel in env env/enc env/dec; do
    assert_directory_path "$repo_root/$rel" "managed directory"
  done

  for rel in \
    env/enc/dev.env.enc \
    env/enc/prod.env.enc \
    env/dec/dev.env \
    env/dec/prod.env \
    env/dec/.dev.env.sha256 \
    env/dec/.prod.env.sha256; do
    assert_regular_or_absent "$repo_root/$rel" "managed file"
  done

  for rel in \
    .dockerignore \
    .env.example \
    .gitattributes \
    .gitignore \
    .sops.yaml \
    justfile; do
    assert_regular_or_absent "$repo_root/$rel" "policy file"
  done

  if [ -e "$repo_root/.env" ] || [ -L "$repo_root/.env" ]; then
    [ -L "$repo_root/.env" ] \
      || fail "root .env must be absent or a managed relative symlink"
    case "$(readlink "$repo_root/.env")" in
      env/dec/dev.env|env/dec/prod.env) ;;
      *) fail "root .env points outside managed env/dec targets" ;;
    esac
  fi
}

# Check both before and after creation to refuse repository-controlled symlink
# redirection. This is a local safety boundary, not a defense against an
# adversary concurrently mutating the same worktree as the current user.
assert_tree
umask 077
mkdir -p -- "$repo_root/env/enc" "$repo_root/env/dec"
assert_tree
chmod 700 -- "$repo_root/env/dec"

mode=$(stat -c '%a' "$repo_root/env/dec" 2>/dev/null || stat -f '%Lp' "$repo_root/env/dec")
[ "$mode" = 700 ] || fail "env/dec must be mode 0700 (found $mode)"

git -C "$repo_root" check-ignore --no-index -q env/dec/dev.env \
  || fail "env/dec plaintext is not ignored by Git"
