# Encrypted dotenv lifecycle.
#
#   nix develop
#   just bootstrap
#   just seed dev
#   $EDITOR env/dec/dev.env
#   just encrypt dev
#   just run dev
#   just lock
#
# Only env/enc/dev.env.enc and env/enc/prod.env.enc may be committed.

set shell := ["bash", "-euo", "pipefail", "-c"]
set dotenv-load := false

age_key := env_var_or_default("SOPS_AGE_KEY_FILE", env_var("HOME") / ".config/sops/age/keys.txt")

_default:
    @just --list --unsorted

# Create managed directories, install guarded hooks, and verify repository policy.
bootstrap:
    @mkdir -p env/enc env/dec
    @chmod 700 env/dec
    @ores-sops install-hooks
    @ores-sops verify
    @bash scripts/check-env-policy.sh

# Create a local age identity. Refuses to overwrite an existing key.
age-keygen:
    #!/usr/bin/env bash
    set -euo pipefail
    key='{{ age_key }}'
    if [ -e "$key" ]; then
      echo "refusing to overwrite existing age identity: $key" >&2
      exit 1
    fi
    mkdir -p "$(dirname "$key")"
    umask 077
    age-keygen -o "$key"
    age-keygen -y "$key"

# Print only this host's public age recipient.
age-key:
    @age-keygen -y "{{ age_key }}"

# Seed ignored plaintext from the public schema. Never overwrites local plaintext.
seed name:
    #!/usr/bin/env bash
    set -euo pipefail
    case '{{ name }}' in dev|prod) ;; *) echo "name must be dev or prod" >&2; exit 2 ;; esac
    mkdir -p env/dec
    chmod 700 env/dec
    target="env/dec/{{ name }}.env"
    if [ -e "$target" ]; then
      echo "refusing to overwrite $target" >&2
      exit 1
    fi
    umask 077
    cp .env.example "$target"
    chmod 600 "$target"
    echo "seeded $target; fill values, then run: just encrypt {{ name }}"

# Run the service with ciphertext decrypted directly into the child process.
run name="dev":
    @sops exec-env --same-process --input-type dotenv env/enc/{{ name }}.env.enc 'cargo run --locked'

# Run the locked Rust test suite under an explicit encrypted profile.
test-env name="dev":
    @sops exec-env --input-type dotenv env/enc/{{ name }}.env.enc 'cargo test --locked --all-targets --all-features'

# Execute an explicit trusted command under an encrypted profile.
exec-env name command:
    @sops exec-env --input-type dotenv env/enc/{{ name }}.env.enc '{{ command }}'

# Atomically decrypt <name> and point ./.env at env/dec/<name>.env.
use name:
    @mkdir -p env/dec
    @chmod 700 env/dec
    @ores-sops use {{ name }}

# Show per-environment state without printing secret values.
status:
    @ores-sops status

# Edit ciphertext through SOPS without a durable plaintext edit file.
edit name:
    @ores-sops edit {{ name }}

# Encrypt local env/dec/<name>.env into the approved tracked ciphertext path.
encrypt name:
    @mkdir -p env/dec
    @chmod 700 env/dec
    @ores-sops encrypt {{ name }}

# Report only added, removed, or changed variable names.
diff name:
    @ores-sops diff {{ name }}

# Re-decrypt the selected environment when ciphertext changes.
refresh:
    @mkdir -p env/dec
    @chmod 700 env/dec
    @ores-sops refresh

# Remove managed plaintext, temporary state, and the root .env symlink.
lock:
    @ores-sops lock

# Keyless policy verification; protected hosts may set ORES_SOPS_VERIFY_DECRYPT=1.
verify:
    @bash scripts/check-env-policy.sh
    @ores-sops verify

# Structural production-recipient gate. Decryptability still needs a protected witness.
verify-release-policy name="prod":
    @python3 scripts/verify-sops-release-policy.py .sops.yaml {{ name }}

audit: verify

hooks:
    @ores-sops install-hooks
