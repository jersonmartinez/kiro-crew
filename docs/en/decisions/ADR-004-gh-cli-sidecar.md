# ADR-004: GitHub CLI via init sidecar

## Status
Accepted

## Context
KiroCrew needs to inspect GitHub repositories and issues from inside its container. The base image does not include the `gh` CLI, and installing host tooling would make the bootstrap less reproducible.

## Decision
Use a `gh-cli` init service based on `debian:trixie-slim`. It installs the Debian `gh` package, copies `/usr/bin/gh` into the named volume `gh-bin`, and the `kirocrew` service mounts that volume read-only at `/opt/gh-cli`.

Authentication is supplied only through the local, ignored `GH_TOKEN` environment variable. The token is not written to the image, the Compose file, or `.env.example`.

## Consequences
- `gh` is available inside KiroCrew without installing it on the host.
- Updating the Debian package requires rerunning the init service.
- The GitHub token grants whatever scopes/permissions the user configured; it must be treated as a secret and rotated if exposed.
- The Dockerized Make service can verify `gh` with `make gh-test`.
