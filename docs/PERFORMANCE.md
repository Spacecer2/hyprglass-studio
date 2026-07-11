# Performance Tuning Guide

This guide helps you tune Hyprglass Studio for the best balance between visual quality and performance on your hardware.

---

## Table of Contents

- [Impact of `blur_strength` on GPU Usage](#impact-of-blur_strength-on-gpu-usage)
- [Recommended Settings for Different GPUs](#recommended-settings-for-different-gpus)
- [Gaming Mode Explanation](#gaming-mode-explanation)
- [How to Disable for Fullscreen](#how-to-disable-for-fullscreen)
- [Battery Life Considerations](#battery-life-considerations)
- [Benchmarking Tips](#benchmarking-tips)
- [Troubleshooting Lag](#troubleshooting-lag)

---

## Impact of `blur_strength` on GPU Usage

The `blur_strength` setting controls how many times the blur shader samples the screen texture. Higher values produce a smoother, more diffuse background blur, but each increment increases GPU load.

### How GPU cost scales

| `blur_strength` | Approximate GPU overhead | Visual quality |
|-----------------|--------------------------|----------------|
| 0               | None (disabled)          | No blur        |
| 1-3             | Low                      | Subtle blur    |
| 4-7             | Moderate                 | Balanced       |
| 8-12            | High                     | Strong blur    |
| 13+             | Very high                | Heavy blur     |

GPU cost rises roughly linearly with `blur_strength` because each additional unit adds more texture samples per pixel. On integrated GPUs or older discrete cards, values above 7 may cause noticeable frame-time spikes, especially at high resolutions (1440p or 4K).

### Other quality knobs that affect GPU usage

- `blur_passes`: Multi-pass blur is more expensive but can look smoother. Reducing passes to `1` can halve GPU cost.
- `noise_intensity`: Adds a grain overlay. Mostly free on modern GPUs, but can add small overhead on integrated graphics.
- `resolution_scale`: Rendering the effect at a lower resolution and upscaling can dramatically reduce GPU load.

---

## Recommended Settings for Different GPUs

Use these starting points and adjust based on your own benchmarks.

### Integrated graphics (Intel UHD, older AMD APU)

```ini
blur_strength = 3
blur_passes = 1
noise_intensity = 0.0
resolution_scale = 0.75
fps_cap = 60
```

### Entry-level discrete GPU (GTX 1650, RX 6400)

```ini
blur_strength = 5
blur_passes = 1
noise_intensity = 0.05
resolution_scale = 1.0
fps_cap = 60
```

### Mid-range GPU (RTX 3060, RX 6700 XT)

```ini
blur_strength = 7
blur_passes = 2
noise_intensity = 0.08
resolution_scale = 1.0
fps_cap = 144
```

### High-end GPU (RTX 4070+, RX 7800 XT+)

```ini
blur_strength = 10
blur_passes = 2
noise_intensity = 0.1
resolution_scale = 1.0
fps_cap = 240
```

> **Tip:** If you use a high refresh-rate monitor, cap the effect's FPS slightly below your desktop refresh rate to avoid competing with foreground applications.

---

## Gaming Mode Explanation

Gaming mode is designed to reduce the compositor's workload while a game or fullscreen application is active.

When enabled, Hyprglass Studio can:

- Lower `blur_strength` automatically.
- Reduce `fps_cap` for the background effect.
- Pause non-essential visual effects.

### Enable gaming mode

```ini
gaming_mode = true
```

### Configure gaming-mode behavior

```ini
gaming_mode_blur_strength = 2
gaming_mode_fps_cap = 30
gaming_mode_disable_noise = true
```

This keeps a lightweight blur active on the desktop while keeping GPU headroom available for games.

---

## How to Disable for Fullscreen

Disabling the effect entirely when an application is fullscreen can eliminate any chance of stutter or input lag.

### Disable automatically on fullscreen

```ini
disable_on_fullscreen = true
```

When this option is enabled, Hyprglass Studio stops rendering the blur effect as soon as any window enters fullscreen. The effect resumes once the fullscreen window exits.

### Combine with gaming mode

For the best gaming experience, use both options together:

```ini
gaming_mode = true
disable_on_fullscreen = true
```

This ensures the GPU is fully dedicated to the fullscreen application.

---

## Battery Life Considerations

Running a live blur effect continuously consumes GPU power, which can reduce battery life on laptops.

### Quick battery-saving tips

1. Lower `blur_strength` to `3` or below.
2. Set `fps_cap` to `30` on battery.
3. Reduce `resolution_scale` to `0.75` or `0.5`.
4. Disable `noise_intensity` entirely.
5. Enable `disable_on_fullscreen` so videos and presentations do not waste power.

### Example battery profile

```ini
blur_strength = 2
blur_passes = 1
noise_intensity = 0.0
resolution_scale = 0.75
fps_cap = 30
disable_on_fullscreen = true
```

If your system supports power-profiles, consider toggling Hyprglass Studio to a low-power preset when unplugged.

---

## Benchmarking Tips

Before and after tuning, measure performance so changes are based on data rather than feel alone.

### Tools to use

- `nvidia-smi` or `radeontop` for GPU utilization.
- `intel_gpu_top` for Intel integrated graphics.
- `hyprctl` frame-time output if available from your compositor.
- MangoHud to overlay GPU and frame-time information.

### Benchmarking procedure

1. Set your desired configuration.
2. Restart Hyprglass Studio to ensure settings are applied.
3. Open a static desktop with a few windows and record idle GPU usage.
4. Move windows rapidly or switch workspaces to stress the blur effect.
5. Record GPU usage, clock speeds, and perceived smoothness.
6. Change one setting at a time and repeat.

### What to watch

- **GPU utilization %:** Lower is better.
- **Frame time (ms):** Should be consistent; spikes cause stutter.
- **Power draw (W):** Important on laptops.
- **Compositor latency:** Should remain under 5 ms if possible.

---

## Troubleshooting Lag

If Hyprglass Studio feels laggy or causes stutter, work through these steps.

### 1. Lower `blur_strength`

This is the single most effective change. Drop to `3` or `4` and test.

### 2. Reduce `blur_passes`

Set `blur_passes = 1`. Multiple passes are the most common cause of frame-time spikes.

### 3. Cap the frame rate

```ini
fps_cap = 60
```

An uncapped effect can consume unnecessary GPU cycles.

### 4. Lower the resolution scale

```ini
resolution_scale = 0.75
```

Rendering at 75% resolution and upscaling can recover a lot of performance with only minor visual loss.

### 5. Disable noise

```ini
noise_intensity = 0.0
```

### 6. Check for fullscreen or gaming mode misconfiguration

If the effect is still active during fullscreen, verify:

```ini
disable_on_fullscreen = true
```

### 7. Update GPU drivers

Ensure you are running the latest Mesa or proprietary drivers for your GPU. Older drivers may compile shaders inefficiently.

### 8. Verify compositor settings

Some compositors allow you to disable compositing effects globally. Make sure Hyprglass Studio is not fighting with another blur or transparency plugin.

### 9. Check thermal throttling

If GPU temperatures are high, clock speeds may drop and cause lag. Clean fans, improve airflow, or reduce effect quality.

### 10. Collect debug logs

Run Hyprglass Studio from a terminal with verbose logging enabled and look for repeated shader compilation errors or dropped frames.

---

## Summary of Key Settings

| Setting                 | Performance impact | Tuning recommendation                                      |
|-------------------------|--------------------|------------------------------------------------------------|
| `blur_strength`         | High               | Lower first if lag occurs                                  |
| `blur_passes`           | Very high          | Use `1` on weaker GPUs                                     |
| `resolution_scale`      | High               | Reduce to `0.75` or `0.5` for battery life or weak GPUs    |
| `fps_cap`               | Medium             | Cap to monitor refresh rate or `30` on battery             |
| `noise_intensity`       | Low-Medium         | Set to `0.0` if every frame counts                         |
| `gaming_mode`           | Low overhead       | Enable for automatic downscaling while gaming              |
| `disable_on_fullscreen` | None (saves power) | Enable for maximum performance during fullscreen apps      |

Start with the recommended profile for your GPU, then adjust one setting at a time until you reach the right balance of quality and performance.
