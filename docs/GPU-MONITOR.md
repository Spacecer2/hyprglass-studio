# GPU Usage Monitor

`HyprglassGPUMonitor.sh` watches GPU utilization and automatically switches HyprGlass profiles based on real-time load. When a game or heavy GPU workload pushes utilization above the high threshold, the monitor switches to the `gaming` profile to reduce compositor overhead. After the GPU load stays below the low threshold for a sustained period, the previous profile is restored.

---

## How It Works

- Polls GPU usage every few seconds using one of:
  - `nvidia-smi` (NVIDIA)
  - `intel_gpu_top` (Intel)
  - `radeontop` (AMD)
- If GPU usage **> 80%**, the monitor applies the `gaming` profile and remembers the previously active profile.
- If GPU usage **< 40%** for **60 seconds**, the monitor restores the remembered profile.
- All decisions are written to `~/.config/hypr/logs/hyprglass-gpu.log`.

---

## Requirements

At least one of the following GPU monitoring tools must be installed and available in your `PATH`:

| Vendor | Tool |
|--------|------|
| NVIDIA | `nvidia-smi` |
| Intel  | `intel_gpu_top` (usually in `intel-gpu-tools`) |
| AMD    | `radeontop` |

The monitor also depends on `HyprglassProfile.sh` from the same `scripts/` directory to apply profiles.

---

## Installation

The script is included in `scripts/HyprglassGPUMonitor.sh`. Make it executable:

```bash
chmod +x /path/to/hyprglass-studio/scripts/HyprglassGPUMonitor.sh
```

Then start it as a background process, for example from your Hyprland startup config:

```ini
exec-once = /path/to/hyprglass-studio/scripts/HyprglassGPUMonitor.sh --daemon
```

---

## Usage

```bash
HyprglassGPUMonitor.sh [--daemon|--one-shot|--status|--help]
```

| Mode | Description |
|------|-------------|
| `--daemon` | Run continuously in the background (default) |
| `--one-shot` | Check GPU usage once, switch if needed, then exit |
| `--status` | Print current GPU tool, usage, active profile, and saved profile |
| `--help` | Show usage information |

---

## Configuration

Behavior can be adjusted through environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `HG_GPU_POLL_INTERVAL` | `5` | Seconds between GPU checks |
| `HG_GPU_HIGH` | `80` | High-load threshold in percent |
| `HG_GPU_LOW` | `40` | Low-load threshold in percent |
| `HG_GPU_LOW_DURATION` | `60` | Seconds below the low threshold before restoring the previous profile |
| `HG_GPU_GAMING_PROFILE` | `gaming` | Name of the profile to apply on high GPU load |

Example autostart with custom thresholds:

```ini
exec-once = env HG_GPU_HIGH=75 HG_GPU_LOW=30 /path/to/hyprglass-studio/scripts/HyprglassGPUMonitor.sh --daemon
```

---

## Logs

The monitor writes a timestamped log to:

```text
~/.config/hypr/logs/hyprglass-gpu.log
```

Example log entries:

```text
[2026-07-12 10:00:05] GPU monitor started (tool: nvidia, high: 80%, low: 40%, duration: 60s).
[2026-07-12 10:05:23] High GPU load detected (87% > 80%). Switched to 'gaming' (previous: default).
[2026-07-12 10:08:41] GPU load stayed below 40% for 60s (current: 12%). Restored previous profile 'default'.
```

---

## Troubleshooting

### "No supported GPU monitoring tool found"

Install the appropriate tool for your GPU:

- NVIDIA: included with the proprietary driver.
- Intel: `intel-gpu-tools` on most distributions.
- AMD: `radeontop` on most distributions.

### Profile is not applied

Make sure `HyprglassProfile.sh` exists in the same directory and is executable, and that a profile named `gaming` (or the value of `HG_GPU_GAMING_PROFILE`) exists in your profiles directory.

### Restore does not happen

A restore only occurs when:

1. The monitor previously auto-switched to the gaming profile (so it has a saved previous profile).
2. The active profile is still the gaming profile.
3. GPU usage stays below `HG_GPU_LOW` for at least `HG_GPU_LOW_DURATION` seconds.

If you manually changed profiles after the auto-switch, the monitor will not restore until the next high-load auto-switch creates a new saved state.

### Permissions for `intel_gpu_top`

`intel_gpu_top` may require root access or membership in the `video`/`render` group, depending on your distribution and kernel permissions. If the tool fails, the monitor logs a warning and skips that cycle.
