# Runbook — rotating factory secrets

The factory's `factory.config.yaml` **names** every secret and variable it depends on but never
holds their values. This runbook is the rotation procedure ADR-0013 §(i) flagged as missing: how to
rotate each referenced secret with **zero belt downtime**, and how to confirm the rotation with
`factory doctor` / `factory sync --check`.

> **The factory never handles secret material.** Every tool checks **presence at a named scope**,
> never the value. Rotation is therefore a GitHub-side operation (`gh secret set …`) plus a factory
> **verification** — the factory neither reads nor prints a secret at any point.

## What the config references

Each identity in `spec.identities.<name>` names its refs as `{ name, scope }` pairs. The framework's
default `floor` identity (the builder App that drives the belt):

| Ref | Kind | Default name | Scope | What it is |
|---|---|---|---|---|
| `appIdVariable` | **variable** (not secret) | `FLOOR_APP_ID` | `org` | the GitHub App's numeric ID — not sensitive, safe to read |
| `privateKeySecret` | **secret** | `FLOOR_APP_PRIVATE_KEY` | `org` | the App private key (PEM). The one true rotation subject |

`scope` (`org` or `repo`) tells `doctor`/`sync` **where** to check presence; a scope-less reference is
invalid. Your own config may add identities or set `scope: repo` — the procedure is identical, only
the `--org` vs `--repo` target of the `gh secret` command changes (see *Scope* below).

Separately, the optional **deepseek audit gate** uses a per-repo secret `deepseek audit key` (not a
schema identity — it is activated per repo by `scripts/enable-audit.sh`). Its rotation is covered at
the end.

## Rotating the App private key (`privateKeySecret`) — zero downtime

A GitHub App accepts **multiple** private keys simultaneously, so rotation overlaps cleanly: add the
new key, cut the factory over, then remove the old key.

1. **Generate a new key.** GitHub → the builder App's settings → *Private keys* → *Generate a private
   key*. A `*.pem` downloads. The old key still works — both are now valid.

2. **Pre-flight the new key locally, before publishing it** (optional but recommended). `factory
   doctor` can mint and issue a probe with the new key without touching the org secret yet:
   ```bash
   FACTORY_DOCTOR_APP_KEY=/path/to/new-app-key.pem FLOOR_APP_ID=<app-id> \
     factory doctor --repo your-org/some-repo
   ```
   A green `token mint` + `repository_dispatch` line confirms the new key is valid and the App
   installation still covers the repo. The key is streamed to `openssl` on stdin and never logged.

3. **Publish the new key** to the scope the config names (`org` for the default `floor`):
   ```bash
   gh secret set FLOOR_APP_PRIVATE_KEY --org your-org --visibility all < /path/to/new-app-key.pem
   ```
   `gh` reads the PEM from stdin — the value never appears on a command line or in shell history.
   Setting the secret overwrites the old value; workflows pick up the new key on their next run.

4. **Verify presence + capability** from the factory:
   ```bash
   factory doctor --repo your-org/some-repo    # presence + mint + probe dispatch, all green
   factory sync --check                         # config / factory.env / org state agree
   ```
   `doctor` confirms the secret is present at its scope and that a token still mints and a dispatch
   still fires. `sync --check` is the read-only drift gate (CI-safe).

5. **Retire the old key.** Once a real belt run has succeeded under the new key (open a trivial PR, or
   watch the floor motor), delete the old key in the App's *Private keys* list. Deleting it before a
   run has exercised the new one is the only way to cause an outage — don't.

6. **Delete the local PEM(s).** `shred -u` / `rm -P` the downloaded `*.pem` files. They are the
   material; the factory never needed them beyond the one-time `gh secret set`.

## Rotating the App ID (`appIdVariable`)

The App ID is a **variable**, not a secret, and only changes if the App is **recreated** (a rotation
of the App itself, not its key). If that happens:

```bash
gh variable set FLOOR_APP_ID --org your-org --body "<new-app-id>"
factory doctor --repo your-org/some-repo        # App ID + mint must go green
```
Because the App ID feeds the compiled runtime, also re-run `factory sync --apply` (operator-only) so
`vars.FLOOR_APP_ID` / `.factory/factory.env` match, then `factory sync --check` to confirm no drift.

## Rotating the deepseek audit key (`deepseek audit key`)

Per-repo, activated by `scripts/enable-audit.sh`. Rotate in place:
```bash
gh secret set deepseek audit key --repo your-org/some-repo
```
The audit gate no-ops when the secret is absent (a green step, never a dead-block), so a brief gap
between delete and set does not block PRs — it just skips the audit until the new key lands.

## Scope — org vs repo

- **`scope: org`** (the default) — one secret covers every repo, including ones provisioned later.
  Target with `gh secret set <NAME> --org your-org --visibility all`.
- **`scope: repo`** — the secret lives on a single repo (`gh secret set <NAME> --repo your-org/<repo>`).
  Use it only when an identity is deliberately scoped to one repo; `doctor`/`sync` then check presence
  on that repo, not the org.

A secret placed at the **wrong** scope reads as *absent* to the factory — `doctor` will report the
`privateKeySecret` missing even though a value exists at the other scope. Match the `scope` in
`factory.config.yaml` to where you set the secret.

## Verifying a rotation — the one command

```bash
factory doctor --repo your-org/some-repo
```
Green `private key: secret … present`, `token mint`, and `repository_dispatch` lines mean the
rotation is complete and the belt can run. A non-zero exit means **do not consider the rotation
done** — resolve the failing check first. See [`docs/factory-cli.md`](../factory-cli.md#factory-doctor--cutover-pre-flight-ticket-107).
