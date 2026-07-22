# Runbook: the factory builder GitHub App

Sets up the **builder identity** for the factory — a GitHub App that authors PRs and
pushes branches on behalf of Claude Code. Per [ADR-0001](../../docs/decisions/ADR-0001-gate-identity-model.md):
an App costs **no seat** (a machine *user* would), and because the bot is always the
PR author, either human is automatically an independent approver (GitHub blocks
self-approval). The App **builds; it never approves** — it can't be a CODEOWNER.

All steps are run by **you** (org admin), one-time. Commands assume:

```bash
export ORG=your-org
export APP_NAME=your-factory-app      # must be globally unique; adjust if taken
```

Prerequisites: org owner access, `gh` authenticated, `jq` + `openssl` installed.

---

## Step 1 — Create the App

Org **Settings → Developer settings → GitHub Apps → New GitHub App**.

- [ ] **Name:** `your-factory-app` · **Homepage:** the org/repo URL
- [ ] **Webhook:** uncheck **Active** (Claude Code drives it; no webhooks needed)
- [ ] **Where can this be installed:** *Only on this account*
- [ ] **Repository permissions** — least privilege for a day-to-day builder:

| Permission | Level | Why |
|---|---|---|
| Contents | Read and write | push branches + commits |
| Pull requests | Read and write | open/update PRs |
| Issues | Read and write | `sync-issues.sh` (issues + labels) |
| **Workflows** | Read and write | **required** if the bot ever commits files under `.github/workflows/` (bootstrap/upgrade sync CI). Omitting this is the #1 push rejection — see Troubleshooting. |
| Metadata | Read-only | mandatory (auto-selected) |

> **Do NOT** grant `Administration` to the always-on builder. Ruleset/environment
> creation (`setup-repo.sh`) and team creation (`setup-teams.sh --create`) are
> one-time admin ops — run those as **yourself**, or with a separate short-lived
> admin token, so the builder bot stays least-privilege.

- [ ] **Create the App**, then note the **App ID** (Settings → the App → *About*).

## Step 2 — Generate a private key

- [ ] On the App page: **Private keys → Generate a private key** → downloads a `.pem`.
- [ ] Store it in your secret manager (this key = the bot's credential). Never commit it.

```bash
export APP_ID=<app-id>
export APP_PEM=/secure/path/your-factory-app.private-key.pem
```

## Step 3 — Install the App on the org

- [ ] App page → **Install App** → install on `$ORG`.
- [ ] Choose **All repositories** (or select the delivery + code repos). Installation is
      what actually grants the permissions to those repos.

## Step 4 — Mint an installation token (git auth)

Installation tokens are **short-lived (1 hour)**. Mint one from the App ID + private key:

```bash
# JWT (RS256), then exchange it for an installation token scoped to $ORG.
b64() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
now=$(date +%s)
header='{"alg":"RS256","typ":"JWT"}'
payload=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$((now-60))" "$((now+540))" "$APP_ID")
unsigned="$(printf '%s' "$header" | b64).$(printf '%s' "$payload" | b64)"
jwt="$unsigned.$(printf '%s' "$unsigned" | openssl dgst -sha256 -sign "$APP_PEM" | b64)"

inst=$(curl -fsS -H "Authorization: Bearer $jwt" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/orgs/$ORG/installation" | jq -r .id)
TOKEN=$(curl -fsS -X POST -H "Authorization: Bearer $jwt" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/installations/$inst/access_tokens" | jq -r .token)
echo "minted token (expires in 1h)"
```

Save this as `factory-app-token.sh` (printing just `$TOKEN`) if you want it reusable.
In **GitHub Actions**, skip the script and use
[`actions/create-github-app-token`](https://github.com/actions/create-github-app-token)
with `app-id` + `private-key` secrets instead.

## Step 5 — Wire it into git / Claude Code

Point git at a credential helper that mints a **fresh** token (so hourly expiry is
invisible), and set the commit identity so commits attribute to the bot:

```bash
# Credential helper — returns a fresh installation token on demand.
git config --global credential."https://github.com".helper \
  '!f() { echo username=x-access-token; echo "password=$(factory-app-token.sh)"; }; f'

# Commit identity = the bot user (so `git log` / PR author show your-factory-app[bot]).
BOT_ID=$(gh api "users/${APP_NAME}[bot]" --jq .id)
git config --global user.name  "${APP_NAME}[bot]"
git config --global user.email "${BOT_ID}+${APP_NAME}[bot]@users.noreply.github.com"
```

For a single push without a helper, the token-in-URL form also works:
`git push "https://x-access-token:${TOKEN}@github.com/$ORG/<repo>.git" <branch>`.

## Step 6 — Verify

- [ ] Push a throwaway branch and open a PR through the App.
- [ ] PR **author** shows `your-factory-app[bot]`.
- [ ] A **human** (not the bot) can approve it — the bot never approves (ADR-0001).
- [ ] CI checks run on the App-authored PR.

```bash
git checkout -b chore/app-smoke && git commit --allow-empty -m "chore: app smoke test

Role: release-engineer"
git push -u origin chore/app-smoke
gh pr create --fill && gh pr view --json author --jq .author.login   # -> your-factory-app[bot]
```

---

## Rotation & security

- The `.pem` is the crown jewel — store in a secret manager, rotate periodically
  (**Generate a private key** makes a new one; delete the old), and never log it.
- Keep the installation scoped to the repos that need it.
- Keep the builder least-privilege (no `Administration`); run admin/rollout ops as a human.
- Revoke fast: suspend the installation or delete the key to cut off the bot immediately.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `refusing to allow ... to create or update workflow ... without workflow scope` | The App lacks **Workflows: write** (Step 1). Add it and reinstall. This is exactly the rejection we hit pushing `ci.yml`. |
| `401`/`403` when minting the token | JWT clock skew (`exp` must be ≤10 min out; check server time), wrong `APP_ID`, or key/App mismatch. |
| Auth works, then fails ~1h later | Installation tokens expire hourly — use the Step 5 credential helper so each git op mints fresh. |
| Bot can't approve its own PR | By design (ADR-0001). A human approves; the bot only builds. |
| CI didn't trigger on the bot's PR | App-authored pushes *do* trigger workflows (unlike the Actions `GITHUB_TOKEN`), so check the workflow's `on:` filters, not the identity. |

## See also

- [ADR-0001](../../docs/decisions/ADR-0001-gate-identity-model.md) — why an App, and the gate model.
- `scripts/setup-teams.sh` — verify CODEOWNERS teams before flipping rulesets to `active`.
- `ROLLOUT.md` — the full go-live sequence (the App is a prerequisite for autonomous PRs).
