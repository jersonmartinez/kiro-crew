# Engineering Budgets

These budgets make quality and operational expectations explicit for this local-development infrastructure project. They are initial targets based on the current Docker image and workflow; measure them over time before tightening them.

## Budget policy

- **Target**: preferred operating objective.
- **Warning**: investigate when exceeded repeatedly.
- **Hard limit**: automation must stop or fail instead of running without bounds.
- **Status**: whether the repository currently enforces the budget.

## CI budgets

| Budget | Target | Warning | Hard limit | Status |
| --- | ---: | ---: | ---: | --- |
| Pull request validation feedback | 15 min | 15 min | 20 min job timeout | Enforced by workflow timeout; queue time is external |
| Static validation | 30 sec | 2 min | 5 min | Measured by the job, not independently enforced |
| Make helper image build | 2 min | 5 min | Included in 20 min job limit | Enforced by CI job timeout |
| Runtime image build | 5 min cached / 10 min cold | 10 min | Included in 20 min job limit | Enforced by CI job timeout |
| Concurrent stale PR runs | 0 | 1 pending | Cancel superseded run | Enforced with workflow concurrency |
| CI artifact retention | 7 days | 14 days | 30 days | Apply when artifacts are added |
| Runtime image size (Docker metadata) | ≤3.5 GB | >3.5 GB | 4 GB | Enforced by CI image-size gate |

The runtime image is intentionally large because it includes Google Cloud tooling, LibreOffice, FFmpeg, browser dependencies, and OpenSSH. The local `nightly` image measured approximately 1.49 GB on 2026-09-05, while the stable `.env.example` image measured 3.58 GB in GitHub Actions on 2026-09-06. These are Docker image-size metadata values, not registry transfer sizes. The CI hard limit is 4 GB.

## Runtime budgets

| Budget | Target | Warning | Hard limit | Status |
| --- | ---: | ---: | ---: | --- |
| Both dashboards healthy after a warm start | 2 min | 3 min | 5 min | Verify with healthchecks |
| ACP initialize timeout | 120 sec default | 180 sec | Configured value | Enforced by runtime configuration |
| Dashboard exposure | localhost only | Any non-loopback bind | Public exposure | Enforced in Compose |
| Persistent backup cadence | Before risky changes / weekly during active use | More than 7 days old | No unbounded retention | Manual via `make backup` |
| Backup recovery objective | Restore within 30 min | 60 min | Document failure | Manual; not automated |

## Release budgets

| Budget | Target | Warning | Hard limit | Status |
| --- | --- | --- | --- | --- |
| Release frequency | As needed, preferably monthly or after a coherent feature | More than 90 days without review | None | Process target |
| Release contents | One logical change set with changelog and verification evidence | Mixed unrelated changes | No release without passing CI | CI gate and review process |
| Release rollback | Previous image digest and Git commit identified | Missing rollback reference | No production release without rollback plan | Documented; no production deploy pipeline yet |
| Vulnerability response | Acknowledge within 5 business days | 10 business days | Escalate to maintainers | Documented in `SECURITY.md` |
| Breaking operational change | ADR, migration note, and explicit version/release note | Missing one artifact | Block release | Process target |

## How to measure

Use these commands locally:

```bash
/usr/bin/time -p ./tests/validate.sh
time docker compose --env-file .env.example --profile tools build make
time docker compose --env-file .env.example build kiro-a kiro-b
docker image inspect kirocrew-local:latest --format='{{.Size}}'
docker compose --env-file .env ps
```

CI budgets should be reviewed after three representative runs. Do not reduce a budget solely because one cached run was fast; cold image builds and GitHub runner variability must be included.

## Current gaps

- There is no automated release or image publication workflow yet.
- Runtime smoke tests are not currently part of the GitHub Actions job because they require the full local credential and volume model.
- Backup age and restore time are not monitored automatically.
- Image-size reporting is documented but not yet a failing CI gate.
