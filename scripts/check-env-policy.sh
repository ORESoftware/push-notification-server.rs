#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

fail() {
  echo "encrypted-env policy: $*" >&2
  exit 1
}

for file in .dockerignore .gitignore .gitattributes .sops.yaml .env.example justfile env/README.md scripts/prepare-env-tree.sh scripts/verify-sops-release-policy.py; do
  test -f "$file" || fail "missing $file"
done

bash -n scripts/prepare-env-tree.sh
bash scripts/prepare-env-tree.sh

git check-ignore --no-index -q .env || fail "root .env must be ignored"
git check-ignore --no-index -q sample.env || fail "root plaintext dotenv must be ignored"
git check-ignore --no-index -q sample.env.local || fail "suffixed dotenv must be ignored"
git check-ignore --no-index -q nested/sample.env || fail "nested dotenv must be ignored"
git check-ignore --no-index -q nested/deeper/sample.env.local || fail "deep dotenv must be ignored"
git check-ignore --no-index -q env/dec/dev.env || fail "env/dec plaintext must be ignored"
if git check-ignore --no-index -q env/enc/dev.env.enc; then
  fail "approved dev ciphertext is ignored"
fi
if git check-ignore --no-index -q env/enc/prod.env.enc; then
  fail "approved prod ciphertext is ignored"
fi

for pattern in \
  '.env' \
  '.env.*' \
  '**/*.env' \
  '**/*.env.*' \
  'env/dec' \
  'env/dec/**' \
  'env/enc' \
  'env/enc/**' \
  '*.pem' \
  '*.key' \
  '*.p8' \
  '*service-account*.json'; do
  grep -Fxq "$pattern" .dockerignore \
    || fail ".dockerignore is missing required exclusion: $pattern"
done

grep -Fq '/env/enc/*.env.enc text eol=lf' .gitattributes \
  || fail "missing ciphertext LF normalization"
grep -Fq 'path_regex: ^env/enc/dev\.env\.enc$' .sops.yaml \
  || fail "missing exact dev SOPS creation rule"
grep -Fq 'path_regex: ^env/enc/prod\.env\.enc$' .sops.yaml \
  || fail "missing exact prod SOPS creation rule"

rule_count=$(grep -E '^[[:space:]-]*path_regex: .*env/enc' .sops.yaml | wc -l | tr -d ' ')
test "$rule_count" = 2 || fail "only exact dev/prod env/enc rules are allowed"
recipient_count=$(grep -Eo 'age1[a-z0-9]{58}' .sops.yaml | sort -u | wc -l | tr -d ' ')
test "$recipient_count" -ge 3 || fail "dev/prod policy requires at least three distinct public recipients"
python3 scripts/verify-sops-release-policy.py .sops.yaml prod

python3 - <<'PY'
from pathlib import Path
import re

text = Path("justfile").read_text(encoding="utf-8")
recipes = (
    "bootstrap:",
    "seed name:",
    'run name="dev":',
    'test-env name="dev":',
    "exec-env name command:",
    "use name:",
    "status:",
    "edit name:",
    "encrypt name:",
    "diff name:",
    "refresh:",
    "lock:",
    "verify:",
    'verify-release-policy name="prod":',
    "hooks:",
)
for recipe in recipes:
    start = text.index(recipe)
    next_recipe = text.find("\n\n", start)
    body = text[start:] if next_recipe == -1 else text[start:next_recipe]
    if "bash scripts/prepare-env-tree.sh" not in body:
        raise SystemExit(f"{recipe} must invoke the symlink-safe environment-tree guard")

for unsafe in (
    r"(?m)^\s*@?mkdir\s+-p\s+(?:--\s+)?(?:env/enc\s+)?env/dec(?:\s|$)",
    r"(?m)^\s*@?chmod\s+700\s+(?:--\s+)?env/dec(?:\s|$)",
):
    if re.search(unsafe, text):
        raise SystemExit("justfile must not manipulate env/dec before the symlink-safe guard")
PY

is_plaintext_env_path() {
  case "$1" in
    .env.example|*/.env.example) return 1 ;;
    .env|*.env|.env.*|*.env.*|env/dec/*) return 0 ;;
    *) return 1 ;;
  esac
}

while IFS= read -r -d '' path; do
  mode=$(git ls-files -s -- "$path" | awk 'NR==1 { print $1 }')
  case "$path" in
    env/enc/dev.env.enc|env/enc/prod.env.enc)
      test "$mode" != 120000 || fail "approved ciphertext path is a symlink: $path"
      ;;
    env/enc/*)
      fail "unexpected tracked path under env/enc: $path"
      ;;
    .dockerignore|.sops.yaml|.gitattributes|.gitignore|.env.example|justfile|scripts/prepare-env-tree.sh)
      test "$mode" != 120000 || fail "policy path is a symlink: $path"
      ;;
    *)
      if is_plaintext_env_path "$path"; then
        fail "tracked plaintext dotenv path: $path"
      fi
      ;;
  esac
done < <(git ls-files -z)

age_private='AGE-SE''CRET-KEY-1'
pem_private='-----BEGIN ''PRIVATE KEY-----'
openssh_private='-----BEGIN OPENSSH ''PRIVATE KEY-----'
if git grep -I -q -e "$age_private" -e "$pem_private" -e "$openssh_private" -- .; then
  fail "tracked private-key material detected"
fi

for file in env/enc/dev.env.enc env/enc/prod.env.enc; do
  test -f "$file" || continue
  grep -q '^sops_mac=ENC\[' "$file" || fail "$file does not look like SOPS dotenv ciphertext"
  while IFS= read -r line || test -n "$line"; do
    case "$line" in
      sops_*=*) ;;
      [A-Za-z_][A-Za-z0-9_]*=ENC\[*\]) ;;
      [A-Za-z_][A-Za-z0-9_]*=*) fail "$file contains an obvious plaintext assignment" ;;
    esac
  done < "$file"
done

if test -e .env || test -L .env; then
  test -L .env || fail ".env exists but is not a managed symlink"
  target=$(readlink .env)
  case "$target" in
    env/dec/dev.env|env/dec/prod.env) ;;
    *) fail ".env points outside managed env/dec targets" ;;
  esac
fi

if test -d env/dec; then
  mode=$(stat -c '%a' env/dec 2>/dev/null || stat -f '%Lp' env/dec)
  test "$mode" = 700 || fail "env/dec must be mode 0700"
fi

if command -v ores-sops >/dev/null 2>&1; then
  ores-sops verify
fi

echo "encrypted environment policy is valid"
