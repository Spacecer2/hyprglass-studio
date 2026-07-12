# Time-Based Profile Scheduler

The `HyprglassScheduler.sh` daemon switches HyprGlass session profiles automatically based on the time of day. This is useful for applying a focused `coding` profile during work hours, a balanced `default` profile in the evening, and a minimal `movies` profile at night.

## How It Works

1. The scheduler reads a simple text schedule from `~/.config/hypr/hyprglass-schedule.conf`.
2. Every minute it determines which profile is active for the current time.
3. If the active profile differs from the last applied profile, it calls `HyprglassProfile.sh apply <profile>`.

The scheduler wraps around midnight: if the current time is before the first entry of the day, the last entry of the schedule is used.

## Schedule File Format

Create `~/.config/hypr/hyprglass-schedule.conf`:

```conf
# HyprGlass time-based schedule
# Format: HH:MM profile_name

08:00 coding
18:00 default
22:00 movies
```

Rules:

- One entry per line.
- Time must be in 24-hour `HH:MM` format.
- `profile_name` must match a `.conf` file in `~/.config/hypr/hyprglass-profiles/`.
- Lines starting with `#` are treated as comments and ignored.
- Entries do not need to be sorted; the scheduler sorts them automatically.

## Running as a Daemon

Add the scheduler to your Hyprland configuration so it starts automatically:

```conf
exec-once = ~/.config/hypr/scripts/HyprglassScheduler.sh --daemon
```

On startup it will immediately apply the profile matching the current time, then check every minute and switch when the schedule changes.

Only one daemon instance is allowed at a time. If the scheduler is already running, a new `--daemon` invocation exits silently.

## Command-Line Usage

```bash
# Run the scheduler in the background (default)
~/.config/hypr/scripts/HyprglassScheduler.sh --daemon

# Apply the correct profile once and exit
~/.config/hypr/scripts/HyprglassScheduler.sh --one-shot

# Show current status and next scheduled switch
~/.config/hypr/scripts/HyprglassScheduler.sh --status

# Stop a running scheduler daemon
~/.config/hypr/scripts/HyprglassScheduler.sh --stop

# Show help
~/.config/hypr/scripts/HyprglassScheduler.sh --help
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HG_SCHEDULE_FILE` | `~/.config/hypr/hyprglass-schedule.conf` | Path to the schedule file |
| `HG_SCHEDULER_LOG` | `~/.config/hypr/logs/hyprglass-scheduler.log` | Path to the log file |
| `HG_SCHEDULER_PID` | `~/.cache/.hyprglass_scheduler.pid` | Path to the PID file |

Example with a custom schedule file:

```bash
HG_SCHEDULE_FILE=~/.config/hypr/my-schedule.conf \
    ~/.config/hypr/scripts/HyprglassScheduler.sh --daemon
```

## Example Schedule

A typical day-night cycle:

```conf
07:00 default
09:00 coding
13:00 default
17:00 gaming
20:00 movies
23:00 default
```

## Interaction With Other Auto-Switchers

The scheduler applies profiles on a fixed timer. If `HyprglassGPUMonitor.sh` or window rules switch to a different profile, the scheduler will switch back at the next minute boundary if the scheduled profile differs. To avoid conflicts:

- Disable the scheduler when you want manual or GPU-driven control.
- Use `--stop` to stop the daemon and `--one-shot` to apply the current scheduled profile only when desired.

## Logging and Troubleshooting

The scheduler logs every switch and error to `~/.config/hypr/logs/hyprglass-scheduler.log`.

Common issues:

| Symptom | Cause | Fix |
|---------|-------|-----|
| Profile does not switch | `HyprglassProfile.sh` not found or not executable | Ensure both scripts are in the same directory and executable |
| Schedule is ignored | Missing or malformed schedule file | Check `HG_SCHEDULE_FILE` and verify `HH:MM` formatting |
| Wrong profile after midnight | Schedule wraps to last entry | This is expected; add an entry at `00:00` if you want a specific overnight profile |

To verify the schedule without applying anything:

```bash
~/.config/hypr/scripts/HyprglassScheduler.sh --status
```
