# Security Policy

## Scope

KiroCrew is a local-development Docker Desktop/WSL2 bootstrap. It can mount writable project directories, access the host Docker Engine through `/var/run/docker.sock`, and pass configured GitHub or GCP credentials into agent workflows. Treat it as privileged local tooling, not as a public multi-user service.

## Supported versions

Only the latest commit on the default branch and the latest published release, when one exists, receive security fixes. Older commits and untagged local images are not supported security baselines.

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability. Use the repository's [private vulnerability reporting form](https://github.com/jersonmartinez/kiro-crew/security/advisories/new). If that form is unavailable, ask a repository administrator to enable GitHub private vulnerability reporting before sharing sensitive details.

Include:

- A concise description and impact.
- Reproduction steps or a minimal proof of concept.
- Affected commit, image digest, operating system, and Docker/WSL versions.
- Any suggested mitigation.

Remove tokens, private keys, personal data, and customer information before submitting a report. If a secret was exposed, revoke or rotate it immediately and mention only the secret type, never its value.

## Response targets

- Acknowledge a report within 5 business days.
- Triage severity and reproducibility within 10 business days.
- Coordinate a fix, mitigation, or public status update with the reporter.

These are response targets, not a guarantee of a particular resolution time.

## Security expectations for contributors

- Never commit secrets or include them in logs, screenshots, backups, images, or documentation.
- Keep dashboards bound to localhost unless an explicit isolation review approves otherwise.
- Minimize Docker socket, mount, capability, and token scope.
- Document security-boundary changes in an ADR and add a corresponding validation or runtime test.
- Review the [security guide](docs/en/security.md) before changing permissions or credential flows.
