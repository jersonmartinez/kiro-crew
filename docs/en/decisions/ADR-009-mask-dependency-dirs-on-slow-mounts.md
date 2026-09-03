# ADR-009: Mask dependency directories on slow mounts

## Status
Accepted (2026-08-18). Closes the root cause that ADR-006 and ADR-008 only mitigated with timeouts.

## Context

After ADR-008 made the ACP budget effective, `Request initialize timed out after 240s` persisted only for certain projects. With `PROJECTS_BASE` mounted from `C:/Users/.../Repositories` through Docker Desktop/virtiofs, `engineering-governance` traversal took 64.1 s for 58 213 files; without `node_modules` / `.git` / `build`, it took 0.5 s for 196 files. `node_modules` contributed 53 039 files and 57.1 s (89% of cost). Windows mounts cost approximately 1 ms per directory entry.

Direct `kiro-cli acp --agent kirocrew` initialize with that repository as `cwd` responded in ~1.9 s (8/8 attempts), proving the handshake itself does not traverse the tree. The single asyncio gateway can block its ACP reader loop during traversal, so an already-emitted response is not read within the budget. The component initiating traversal was not identified with certainty; removing I/O cost works independently of the caller. Path length and repository count are not causes.

## Decision

Mask each dependency/cache directory with an empty `tmpfs`, so the container cannot see it and traversal cannot descend into it. `scripts/generate-mask-override.sh` uses `find -maxdepth 4 ... -prune` and emits `docker-compose.override.yml` with one `tmpfs` per match. Masks are container paths, making the generated file portable. `make masks` regenerates it; `up`, `restart`, and `update` require it. Defaults (`KIROCREW_MASK_DIRS`) are `node_modules`, `.venv`, `venv`, `vendor`, `target`, `__pycache__`, `.next`, `.nuxt`, `.docusaurus`, `.cache`, `.pytest_cache`, `.mypy_cache`, `.gradle`.

`.git`, `build`, and `dist` remain visible deliberately because their measured cost is marginal and the agent needs them.

## Alternatives Considered

Continuing to raise `KIROCREW_ACP_INIT_TIMEOUT_SECS` was rejected: a 64 s traversal scales with repository size. Mounting only selected repositories improves exposure hygiene but does not solve a selected repository's `node_modules`. Native WSL2 storage is technically correct but costly for 18.17 GB and more than 100 Windows-edited repositories. Anonymous volumes leave orphans; `tmpfs` leaves no disk residue. `.gitignore` or agent ignore files do not stop traversal and are therefore ineffective.

## Consequences

- `engineering-governance` falls from **64.1 s / 58 213 files** to **6.3 s / 2 471 files** (10x); source, `docs/`, and `git` remain accessible.
- Masked directories appear **empty**. Agent `npm install` writes to `tmpfs`, limited by `KIROCREW_MASK_TMPFS_SIZE` (1 GB by default); it is not shared with Windows and does not survive restart. Remove a name from `KIROCREW_MASK_DIRS` and regenerate when real dependencies are needed.
- The generated `docker-compose.override.yml` is host-specific, ignored by Git, and must not be edited manually.
- Run `make masks` after cloning or installing dependencies; diagnosis is reproducible with `make mask-report PROJECT=<path>`.
