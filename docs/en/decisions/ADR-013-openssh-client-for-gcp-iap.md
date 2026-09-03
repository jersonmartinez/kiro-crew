# ADR-013: Include the OpenSSH Client for GCP IAP

## Status
Accepted

## Context

The KiroCrew containers include the Google Cloud CLI and can authenticate to GCP, but `gcloud compute ssh` also needs a local SSH client. Without OpenSSH, the command reports that the platform does not support SSH even when the GCP account and IAP permissions are valid.

The required workflow is to connect from ACP shells to development VMs through Identity-Aware Proxy (IAP), optionally running a remote command. KiroCrew does not need to accept inbound SSH connections.

## Decision

Install the Debian `openssh-client` package in the shared runtime image built by `Dockerfile.kirocrew`. Verify `/usr/bin/ssh`, `ssh -V`, and `gcloud compute ssh --help` in both instances and in CI.

Do not install an SSH server, publish an SSH port, add private keys to the image, or change the container entrypoint. Remote authentication remains controlled by the authenticated GCP identity, Compute Engine/IAP IAM permissions, and the VM's SSH configuration.

## Alternatives Considered

### Install an SSH server

Rejected: KiroCrew only initiates outbound SSH connections. An SSH server would add an unnecessary inbound attack surface and require port, account, and lifecycle management.

### Use a host-side SSH client

Rejected: ACP commands execute inside the container and need a consistent runtime. Requiring the host client would make the workflow environment-dependent.

### Store a private key in the image or repository

Rejected: private keys must remain outside Git and container images. `gcloud compute ssh` can manage the connection using the authenticated GCP workflow instead.

## Consequences

- `gcloud compute ssh` works from both Kiro A and Kiro B when GCP/IAP permissions are configured.
- No new listening port or inbound service is introduced.
- The runtime image gains the OpenSSH client and its package dependencies.
- Remote VM access remains privileged infrastructure access and must use least-privilege IAM.
- Passwords, private keys, access tokens, and command output containing secrets must not be stored in Git or documentation.
