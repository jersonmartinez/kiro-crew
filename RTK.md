# RTK - Rust Token Killer (Agent CLI)

**Usage**: Token-optimized CLI proxy for shell commands.

## Rule

Prefer RTK for supported high-output shell commands so agents receive compact output. Use the normal command when exact/raw output is required, when RTK does not support the operation, or when filtered output would hide a failure needed for diagnosis.

In the Windows/MSYS environment, use the project wrapper at `~/.local/bin/rtk` when `rtk` is not already on PATH.

Examples:

```bash
rtk git status
rtk cargo test
rtk npm run build
rtk pytest -q
```

## Meta Commands

```bash
rtk gain            # Token savings analytics
rtk gain --history  # Recent command savings history
rtk proxy <cmd>     # Run raw command without filtering
```

## Verification

```bash
rtk --version
rtk gain
which rtk
```
