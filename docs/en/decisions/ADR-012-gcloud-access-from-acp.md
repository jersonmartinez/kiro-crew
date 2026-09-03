# ADR-012: Allow GCloud Authentication From ACP Sessions

## Status
Accepted

## Context

KiroCrew authenticates Google Cloud independently inside each persistent agent home. The gateway process could use the configured `gcloud` account, but ACP sessions could not: the sandbox launcher bind-mounted an empty directory over `/home/kirocrew/.config/gcloud` before starting the agent subprocess.

This made `gcloud auth list` appear empty to prompts even when the instance itself was authenticated. It also prevented the agent from inspecting authorized GCP resources needed for the development workflow.

## Decision

Keep `/home/kirocrew/.config/gcloud` available inside ACP sessions for both KiroCrew instances. The image build patches the sandbox launcher source in `Dockerfile.kirocrew` by removing that directory from the launcher’s protected directory and file lists.

Authentication remains instance-local and persistent in `kiro-a-home` or `kiro-b-home`. The project does not bake credentials into the image or repository. The active GCP project is configured separately in each instance.

## Alternatives Considered

### Keep GCloud hidden and run commands outside ACP

This preserves the strongest credential isolation, but prevents prompts from directly inspecting GCP resources and requires an operator to relay every result.

### Expose a short-lived, least-privilege service-account credential

This would reduce the scope of the credential available to the agent, but requires an additional credential issuance and rotation workflow that is not currently part of this local development bootstrap.

### Expose the complete gcloud configuration

This is the selected approach for the current local development workflow because the OAuth login already lives in the instance volume and the agent needs native `gcloud` behavior. It is not appropriate for an internet-facing or shared production environment.

## Consequences

- ACP prompts can use the authenticated `gcloud` account and configured project.
- `kiro-a` and `kiro-b` remain isolated through separate named home volumes.
- The sandbox continues to hide `.ssh`, `.gnupg`, `.docker`, `.azure`, and other protected paths.
- Anyone able to run prompts in an instance can use that instance’s GCP credentials; IAM permissions must therefore be minimal and appropriate for the environment.
- Credential databases remain outside Git, Dockerfiles, generated diagrams, and `.env.example`.
