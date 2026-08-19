# Encrypted environment profiles

This service uses the canonical `ORESoftware/ores-sops` dotenv lifecycle:

```text
env/enc/dev.env.enc     optional tracked local/dev ciphertext
env/enc/prod.env.enc    optional tracked protected-operator ciphertext
env/dec/dev.env         ignored local plaintext, mode 0600
env/dec/prod.env        ignored local plaintext, mode 0600
.env                    managed relative symlink to one env/dec profile
```

Empty `env/enc` and `env/dec` directories intentionally have no `.gitkeep`.
Policy permits exactly the two ciphertext filenames under `env/enc`, and
nothing under `env/dec` may be tracked.

## Provider-secret boundary

The repository owns the environment schema and may carry reviewed encrypted
local, development, test, or operator profiles. Production credentials for the
Kubernetes deployment remain owned by External Secrets and the protected
cluster secret store; checking in ciphertext here does not replace that
production boundary.

Use one SendGrid key per service, scoped only to Mail Send. Prefer a Twilio API
Key SID/secret pair for production rotation instead of the account Auth Token.
Never reuse an account-wide or full-access key across repositories. Credentials
that have appeared in chat, tickets, logs, shell history, or CI output must be
revoked before they are added to any profile.

No ciphertext is added by this rollout. An authorized operator first rotates
the provider credential, verifies the public recipients in `.sops.yaml`, and
then creates the initial file locally.

## First use

```sh
nix develop
just age-keygen                 # only when this host has no age identity
just age-key                    # share only the public age1... line
just bootstrap
just seed dev
$EDITOR env/dec/dev.env
just diff dev                   # reports variable names only
just encrypt dev
git add env/enc/dev.env.enc
just verify
just run dev
```

For the protected operator profile, verify recipient custody first:

```sh
just verify-release-policy prod
just seed prod
$EDITOR env/dec/prod.env
just encrypt prod
git add env/enc/prod.env.enc
just verify
```

Normal changes should use `just edit dev|prod`. Commands that do not require a
plaintext file should use `just run`, `just test-env`, or `just exec-env` so
plaintext is injected directly into the process environment.

`just lock` removes managed plaintext and the root `.env` symlink.

## CI and Kubernetes

Pull-request CI is keyless: it verifies path rules, ignore behavior, recipient
separation, ciphertext shape, private-key markers, and symlink boundaries. It
does not decrypt and must never receive an age private key on untrusted code.

The Kubernetes deployment continues to receive provider values from
`dd-push-notification-server-secrets`. Rotation should update that protected
source and restart the workload; do not copy a cluster credential into Git.
