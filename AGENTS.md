# Agent instructions

## RTK

- Prefer RTK for supported high-output commands to reduce context usage, especially `git`, `docker`, test, and log inspection commands.
- Use the normal command when RTK does not support the operation, when exact/raw output is required, or when RTK would hide an error needed for diagnosis.
- Verify availability with `~/.local/bin/rtk --version` at the start of a session when this workflow is relevant; `source ~/.bashrc` may be used when the shell should resolve `rtk` by name.
- In the Windows/MSYS environment, invoke `~/.local/bin/rtk`, the configured wrapper that delegates to the verified WSL2 installation.
- Do not install or update RTK from unpinned arbitrary sources; use the official RTK release/install instructions and verify checksums when installing release artifacts.

@RTK.md
