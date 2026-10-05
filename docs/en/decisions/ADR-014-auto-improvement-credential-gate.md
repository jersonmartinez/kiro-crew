# ADR-014: Auto-Improvement Credential Gate Provisioning

## Status

Accepted

## Context

The Auto-Improvement app bundled with Kiro Crew measures a target repository
before it changes it: it calibrates a metric, proves the ruler, and runs
keep-or-revert cycles that file survivors as draft pull requests. The work is
done by an unattended, provider-backed member-agent team, so upstream refuses
to build the runner while the gateway's effective sandbox is below `strict`:

```text
AgentRunnerOffline: the run did no work because the provider-backed agent
runner was refused because the gateway sandbox is 'auto' — the
auto-improvement provider path requires a sandbox.min_level governance floor
of 'strict' (credential-hiding profile) or the explicit
acceptUnsandboxedAgentRisk opt-in
```

Repository-controlled instructions could otherwise reach on-disk credential
stores. Only `strict` hides all of them: `cc` leaves SSH and GitHub CLI
credentials visible, and `auto`/`standard` additionally expose AWS
credentials. `agent.sandbox` only accepts `auto` or `off`, so `strict` cannot
be set as a user preference; it is reachable through the governance floor
(`sandbox.min_level`) or waived per-app through `acceptUnsandboxedAgentRisk`.

Both unblock paths exist upstream, but nothing provisioned them: operators had
to hand-edit files inside the persistent volume, which `configure-instance.sh`
already exists to manage.

## Decision

`configure-instance.sh` reconciles two environment variables on every
`make up`/`make configure` (they are passed to the `kiro-a-config` and
`kiro-b-config` services):

- `KIROCREW_SANDBOX_MIN_LEVEL` (`off|standard|cc|strict`): seeds
  `~/.kiro/crew/security_policy.json` — the local, operator-authored
  governance ceiling — with `identity.issuer: kiro-crew-compose` and
  `sandbox.min_level` set to the value. The floor clamps every agent spawn up
  to the strict, credential-hiding profile when `strict` is chosen. The file
  is reconciled as desired state: a file the stack did not generate (a
  different `identity.issuer`, or unparseable content) is never modified; a
  managed file loses `min_level` when the variable is unset and is removed
  when nothing else remains. Changes apply from the next gateway start.
- `KIROCREW_AUTO_IMPROVEMENT_ACCEPT_UNSANDBOXED_RISK` (`0|1`): `1` merges
  `"acceptUnsandboxedAgentRisk": true` into
  `~/.kiro/crew/apps/auto-improvement/data/config.json`, preserving any keys
  the app already wrote. `0` removes the key. An empty value leaves the file
  untouched so a consent granted through the dashboard is never silently
  revoked. It takes effect on the next run; the runner re-reads the file per
  run, so no restart is needed.

Both values are validated by `scripts/validation/validate-env.py` and pinned
by `tests/validate.sh`.

## Alternatives Considered

### Set `agent.sandbox` to `strict` directly

Rejected: `agent.sandbox` is an enum of `auto`/`off`; storing `strict` loads
as `auto` with an enum-violation warning. Only the governance floor clamps the
effective mode up to `strict`.

### Bake the opt-in into the image

Rejected: `acceptUnsandboxedAgentRisk` and the governance ceiling are operator
consents. Writing them unconditionally in `Dockerfile.kirocrew` would grant an
unattended repository-facing agent access to credential stores without the
operator ever making that decision.

### Always default `KIROCREW_SANDBOX_MIN_LEVEL` to `strict`

Rejected: the strict profile hides `~/.kube`, `~/.aws`, `~/.azure`, `~/.docker`
and `~/.config/gh` from every agent subprocess gateway-wide. This stack ships
kubectl and the GKE auth plugin (ADR-012/ADR-013), so defaulting to `strict`
would silently break `kubectl` from agent shells for existing deployments. The
gate stays closed by default; the operator picks a path.

## Consequences

- Auto-improvement works after setting one variable in `.env` and running
  `make configure` (risk consent) or `make restart` (governance floor).
- The strict floor trades agent access to `kubectl`/`aws`/`az` on-disk config
  for real credential isolation; `gh` and git keep working through `GH_TOKEN`,
  `gcloud` through the ADR-012 sandbox exception, and `~/.ssh` stays visible.
- The risk-consent path changes nothing outside the app, but member agents run
  under `auto`, so repository-influenced instructions could read credential
  files present in the instance home (`~/.kube`, `~/.ssh`).
- A fleet that later adopts centrally distributed policy is unaffected: the
  home-tier file stacks beneath the central document and a non-stack-managed
  file is left alone.
- Revoking works by unsetting the variables (`0` for the app consent); the
  stack removes what it wrote and leaves foreign files alone.
