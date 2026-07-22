# `factory.config.yaml` — schema `factory.sh/v1`

The single authored source of truth for one factory instance's **non-secret** configuration.
GitHub-side state (variables, rulesets, project) is a *derived output* reconciled from this file,
never a competing source (ADR-0015 Decision 1). This document defines the schema; the CLI that
loads, validates, and compiles it lands in TICKET-095/096/097.

> **Framework-neutral by construction.** The `apiVersion` group is `factory.sh/v1` — **not** an
> org-carrying group like `factory.<org>.example/…`. The schema that de-org-ifies the framework
> must not carry any org in its own envelope (ADR-0015 Decision 3). Every instance-specific value lives under
> `metadata`/`spec`, never in the group name, and never as a default baked into framework code.

## Envelope

| Field | Type | Required | Notes |
|---|---|---|---|
| `apiVersion` | string | yes | Exactly `factory.sh/v1`. Bumped only by a schema migration (`factory migrate`, TICKET-106). |
| `kind` | string | yes | Exactly `FactoryInstance`. |
| `metadata.name` | string | yes | Human label for this instance (e.g. `your-software-factory`). Not an identifier GitHub sees. |
| `spec` | object | yes | The instance configuration (below). |

## `spec`

```yaml
apiVersion: factory.sh/v1
kind: FactoryInstance
metadata:
  name: <instance-label>
spec:
  github:
    organization: <org-login>            # string, required — the GitHub org slug
    project:
      title: <project-title>             # string, required — org Project resolved by TITLE (natural key)
  repositories:
    naming:
      allowedPatterns:                   # list<regex>, required — repo-name policy for this org
        - '<ere>'
  runners:
    labels: [<label>, ...]               # list<string>, optional — runner labels; default [] (github-hosted)
  rulesets:
    routingFile: .factory/ruleset-map.tsv   # path, required — instance repo→ruleset routing table
  identities:                            # map<name, identity>, optional
    <identity-name>:
      <refKey>: { name: <VAR_OR_SECRET_NAME>, scope: org | repo }
```

### Field reference

| Path | Type | Required | Meaning |
|---|---|---|---|
| `spec.github.organization` | string | **yes** | Org login. Resolved by slug; no ID cached. |
| `spec.github.project.title` | string | **yes** | Org Project title. Resolved by **title** (natural key) each run — no number/node-ID is cached (ADR-0015 Decision 6). |
| `spec.repositories.naming.allowedPatterns` | list\<ERE\> | **yes** | Allowed repo-name patterns for the org. At least one pattern. |
| `spec.runners.labels` | list\<string\> | optional | Runner labels workflows target. Empty/absent ⇒ github-hosted. |
| `spec.rulesets.routingFile` | path | **yes** | Path (under `.factory/`) to the instance's `repo-basename → ruleset-file` TSV. The generic ruleset *definitions* are framework-shipped; the *routing* is instance data (TICKET-101 performs the split). |
| `spec.identities.<name>.<refKey>` | secret/variable reference | optional | A `{ name, scope }` pair — see below. |

### Secret / variable references — `{ name, scope }`

Every reference to a GitHub **secret** or **variable** is a two-field object, never a bare string:

```yaml
identities:
  floor:
    appIdVariable:    { name: FLOOR_APP_ID,          scope: org }
    privateKeySecret: { name: FLOOR_APP_PRIVATE_KEY, scope: org }
```

- `name` — the GitHub secret/variable **name** only. **Never a value.** The material lives in
  GitHub; the config declares *which* secret must exist. `factory validate` refuses any value that
  looks like secret material (token prefixes, PEM blocks, high-entropy); enforcement lands in
  TICKET-095.
- `scope` — `org` or `repo`, so `doctor`/`sync` know *where* to check presence. A **scope-less
  reference is invalid** (a correctly-placed secret at the other scope would otherwise be
  mis-reported as missing). Enforcement lands in TICKET-095 (ADR-0015 Decision 8).

### Not in this schema

- **No lock / state / ID-cache field** (ADR-0015 Decision 6). The runtime resolves every GitHub
  object by natural key (org by slug, project by title, ruleset by name) and caches nothing. The
  single value with no natural key — the App *installation ID* — is not authored config and never
  appears here.
- **No secret values**, ever. References only.

## Layout — `.factory/`

| Path | Origin | Committed? | Vendored to consumers? |
|---|---|---|---|
| `factory.config.yaml` | **authored** (this schema) | yes | **no** — instance config never ships in the bundle (ADR-0015 Decision 5; cross-tenant leak) |
| `.factory/ruleset-map.tsv` | authored (routing) | yes | no |
| `.factory/factory.env` | **generated** by `factory sync` (TICKET-097) | yes, drift-checked | no |
| `templates/factory/schema/factory.config.v1.md` | framework | yes | **yes** — consumers need the schema, not an instance config |

## Coverage — the 56 audit literals map to schema fields (AC3)

The no-new-hardcoded-identity baseline (`tests/factory/hardcoded-identity.baseline`, 56 rows)
enumerates every instance literal in framework code today. Each maps to a field below; **nothing
legitimate is left inexpressible, and nothing is obsolete-to-delete.** (Deletion of the literals
themselves is TICKET-099/100/101; this ticket only proves the schema can express them.)

| Literal (class) | Count | Schema field | Notes |
|---|---|---|---|
| `self-hosted`, `daedmonds` | 21 | `spec.runners.labels` | `daedmonds` is the host-specific label in `runs-on: [self-hosted, daedmonds7]`; both are runner labels. |
| `your-org` | 10 | `spec.github.organization` | the org slug the `${ORG:-…}` defaults point home to. |
| `Your Factory Board` | 6 | `spec.github.project.title` | the org Project, resolved by title. |
| `product` | 5 | `spec.repositories.naming.allowedPatterns` | the repo-name prefix policy. |
| `license-go`, `pg-cdc`, `aws-marketplace-keys` | 14 | `spec.rulesets.routingFile` | instance repo→ruleset routing (`ruleset-map.tsv`) + the per-repo ruleset *definitions* those rows point to; the split from generic rulesets is TICKET-101. |
| **total** | **56** | | every row mapped; none inexpressible; none obsolete. |

Proof of expressiveness is completed by the consumer-zero round-trip in TICKET-098 (the framework
authoring its *own* config against this schema and the baseline reaching 0). The schema fields
must exist — they do, above.

## Ownership rules (ADR-0015, Decisions 1–8)

This schema is the authoring surface for the authority contract recorded in
[ADR-0015](../../../docs/decisions/ADR-0015-factory-configuration-authority.md): authored config
is authoritative for all non-secret configuration (D1); secrets are references, never values (D2);
authoring format ≠ runtime format, group is framework-neutral (D3); three directions of truth (D4);
consumer-zero + separate config-root discovery (D5); **no persistent lock file** (D6);
declarative subject = org policy + routing-named repos, not the whole fleet (D7); config is
authoritative and secret scope is named (D8).
