# Hyprglass Studio REST API

This document describes the REST API exposed by the Hyprglass Studio local server (`src/server.py`).

## 1. Base URL

All API endpoints are relative to:

```
http://localhost:8765
```

The default port is `8765`. Use `--port` or the `STUDIO_PORT` environment variable when starting the server to change it.

## 2. Authentication

No authentication is required for local use. The server is intended to run on `localhost` and trusts the local user. Do not expose the server to untrusted networks without adding your own authentication layer.

## 3. Endpoints

### 3.1 `GET /api/health`

Returns the health status of the server.

**Response:**

| Status | Description                     |
|--------|---------------------------------|
| 200    | Server is running and healthy.  |

**Response body example:**

```json
{
  "ok": true,
  "version": "1.1.0"
}
```

**curl example:**

```sh
curl -s http://localhost:8765/api/health | jq
```

---

### 3.2 `GET /api/config`

Returns the raw text of the currently active `Hyprglass.conf`.

**Response:**

| Status | Description                    |
|--------|--------------------------------|
| 200    | Current configuration as text. |

**Response body example:**

```json
{
  "ok": true,
  "config": "plugin:hyprglass {\n    enabled = 1\n    ...\n}"
}
```

If no config has been written yet, `config` is an empty string.

**curl example:**

```sh
curl -s http://localhost:8765/api/config | jq -r '.config'
```

---

### 3.3 `POST /api/preview`

Writes the supplied configuration temporarily, reloads Hyprland, and opens a kitty preview window. When the preview window closes, the previous config is restored.

**Request headers:**

| Header           | Value              | Required |
|------------------|--------------------|----------|
| `Content-Type`   | `application/json` | Yes      |

**Request body:**

| Field    | Type   | Description                              |
|----------|--------|------------------------------------------|
| `config` | string | Full `Hyprglass.conf` content to preview.|

**Request body example:**

```sh
curl -s -X POST http://localhost:8765/api/preview \
  -H "Content-Type: application/json" \
  -d '{"config":"plugin:hyprglass {\n    enabled = 1\n    ...\n}"}'
```

**Response:**

| Status | Description                                        |
|--------|----------------------------------------------------|
| 200    | Preview opened successfully.                       |
| 400    | Invalid request body or missing `config`.          |

**Response body examples:**

Success:

```json
{
  "ok": true,
  "message": "preview opened",
  "pid": 12345
}
```

Error (preview already active):

```json
{
  "ok": false,
  "error": "preview already active"
}
```

---

### 3.4 `POST /api/apply`

Validates, writes, and reloads a full `Hyprglass.conf`. This is the same action triggered by the **Apply** button in the Studio UI.

**Request headers:**

| Header           | Value              | Required |
|------------------|--------------------|----------|
| `Content-Type`   | `application/json` | Yes      |

**Request body:**

| Field    | Type   | Description                              |
|----------|--------|------------------------------------------|
| `config` | string | Full `Hyprglass.conf` content to apply.  |

**Response:**

| Status | Description                                  |
|--------|----------------------------------------------|
| 200    | Configuration applied successfully.          |
| 400    | Invalid request body, missing `config`, or validation failure. |

**Response body examples:**

Success:

```json
{
  "ok": true,
  "message": "applied",
  "backup": "/home/user/.config/hypr/backups/hyprglass-studio/apply-20260712-143052.conf"
}
```

Validation failure:

```json
{
  "ok": false,
  "error": "invalid config: missing required field: default_preset"
}
```

**curl example:**

```sh
curl -s -X POST http://localhost:8765/api/apply \
  -H "Content-Type: application/json" \
  -d '{"config":"plugin:hyprglass {\n    enabled = 1\n    default_theme = dark\n    default_preset = default\n    blur_strength = 2.0\n    ...\n}"}' | jq
```

## 4. Error Responses

Error responses are returned with HTTP 400 (or 404 for unknown endpoints) and a JSON body:

```json
{
  "ok": false,
  "error": "Human-readable error message"
}
```

## 5. Validation Rules

`POST /api/apply` validates the supplied config before writing it. The config must contain:

- A `plugin:hyprglass { ... }` block.
- Required fields: `enabled`, `default_theme`, `default_preset`.
- Numeric fields within their documented ranges:
  - `blur_strength` (0–8)
  - `blur_iterations` (1–5)
  - `refraction_strength` (0–1)
  - `chromatic_aberration` (0–1)
  - `fresnel_strength` (0–1)
  - `specular_strength` (0–1)
  - `glass_opacity` (0–1)
  - `edge_thickness` (0–0.15)
  - `lens_distortion` (0–1)
- A `decoration { ... }` block with `active_opacity`, `inactive_opacity`, and `fullscreen_opacity` between 0 and 1.

## 6. curl Examples Summary

```sh
# Health check
curl -s http://localhost:8765/api/health | jq

# Get current config as text
curl -s http://localhost:8765/api/config | jq -r '.config'

# Open a preview (replace ... with full conf content)
curl -s -X POST http://localhost:8765/api/preview \
  -H "Content-Type: application/json" \
  -d '{"config":"plugin:hyprglass {\n  enabled = 1\n  ...\n}"}' | jq

# Apply a configuration
curl -s -X POST http://localhost:8765/api/apply \
  -H "Content-Type: application/json" \
  -d '{"config":"plugin:hyprglass {\n  enabled = 1\n  ...\n}"}' | jq
```

## 7. Note on Profiles

The Studio server does **not** expose profile list/load endpoints. Profiles are stored as `.conf` files in `~/.config/hypr/hyprglass-profiles/` and are applied with `HyprglassProfile.sh`. See [PROFILES.md](PROFILES.md) for details.
