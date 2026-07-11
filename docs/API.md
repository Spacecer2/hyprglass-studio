# Hyprglass Studio REST API

This document describes the REST API exposed by the Hyprglass Studio local server.

## 1. Base URL

All API endpoints are relative to:

```
http://localhost:8765
```

The server runs locally on port `8765` by default. Replace `localhost:8765` with the actual host and port if the server was started with custom network settings.

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
  "status": "ok",
  "service": "hyprglass-studio"
}
```

**curl example:**

```sh
curl -s http://localhost:8765/api/health | jq
```

---

### 3.2 `GET /api/config`

Returns the current active configuration used by the server.

**Response:**

| Status | Description                    |
|--------|--------------------------------|
| 200    | Current configuration object.  |

**Response body example:**

```json
{
  "theme": "default",
  "opacity": 0.95,
  "blur": true,
  "blur_size": 12,
  "accent_color": "#ff7b72",
  "border_radius": 8
}
```

**curl example:**

```sh
curl -s http://localhost:8765/api/config | jq
```

---

### 3.3 `POST /api/preview`

Generates a preview of a configuration without applying it to the live Hyprland session.

**Request headers:**

| Header           | Value              | Required |
|------------------|--------------------|----------|
| `Content-Type`   | `application/json` | Yes      |

**Request body example:**

```json
{
  "theme": "tokyonight",
  "opacity": 0.92,
  "blur": true,
  "blur_size": 16,
  "accent_color": "#7aa2f7",
  "border_radius": 10
}
```

**Response:**

| Status | Description                                        |
|--------|----------------------------------------------------|
| 200    | Preview generated successfully.                    |
| 400    | Invalid request body or unsupported option value.  |

**Response body example:**

```json
{
  "ok": true,
  "preview_id": "preview_9f3e2a1c",
  "message": "Preview rendered"
}
```

**curl example:**

```sh
curl -s -X POST http://localhost:8765/api/preview \
  -H "Content-Type: application/json" \
  -d '{
    "theme": "tokyonight",
    "opacity": 0.92,
    "blur": true,
    "blur_size": 16,
    "accent_color": "#7aa2f7",
    "border_radius": 10
  }' | jq
```

---

### 3.4 `POST /api/apply`

Applies a configuration to the live Hyprland session.

**Request headers:**

| Header           | Value              | Required |
|------------------|--------------------|----------|
| `Content-Type`   | `application/json` | Yes      |

**Request body example:**

```json
{
  "theme": "catppuccin",
  "opacity": 0.90,
  "blur": true,
  "blur_size": 20,
  "accent_color": "#f5c2e7",
  "border_radius": 12,
  "reload": true
}
```

**Response:**

| Status | Description                                  |
|--------|----------------------------------------------|
| 200    | Configuration applied successfully.          |
| 400    | Invalid request body or unsupported option.  |
| 500    | Failed to apply configuration.               |

**Response body example:**

```json
{
  "ok": true,
  "applied": {
    "theme": "catppuccin",
    "opacity": 0.90,
    "blur": true,
    "blur_size": 20,
    "accent_color": "#f5c2e7",
    "border_radius": 12
  },
  "reload": true
}
```

**curl example:**

```sh
curl -s -X POST http://localhost:8765/api/apply \
  -H "Content-Type: application/json" \
  -d '{
    "theme": "catppuccin",
    "opacity": 0.90,
    "blur": true,
    "blur_size": 20,
    "accent_color": "#f5c2e7",
    "border_radius": 12,
    "reload": true
  }' | jq
```

---

### 3.5 `GET /api/profiles`

Lists all saved configuration profiles.

**Response:**

| Status | Description              |
|--------|--------------------------|
| 200    | Array of profile names.  |

**Response body example:**

```json
{
  "profiles": [
    "default",
    "tokyonight",
    "catppuccin",
    "gruvbox",
    "nord"
  ]
}
```

**curl example:**

```sh
curl -s http://localhost:8765/api/profiles | jq
```

---

### 3.6 `POST /api/profile/<name>`

Loads and applies a saved profile by name.

**URL parameters:**

| Parameter | Description                         |
|-----------|-------------------------------------|
| `name`    | Name of the saved profile to load.  |

**Response:**

| Status | Description                                  |
|--------|----------------------------------------------|
| 200    | Profile loaded and applied successfully.     |
| 404    | Profile not found.                           |
| 500    | Failed to apply the loaded profile.          |

**Response body example:**

```json
{
  "ok": true,
  "profile": "tokyonight",
  "applied": {
    "theme": "tokyonight",
    "opacity": 0.92,
    "blur": true,
    "blur_size": 16,
    "accent_color": "#7aa2f7",
    "border_radius": 10
  }
}
```

**curl example:**

```sh
curl -s -X POST http://localhost:8765/api/profile/tokyonight | jq
```

## 4. Error Responses

All error responses follow a consistent JSON format:

```json
{
  "ok": false,
  "error": "short_error_code",
  "message": "Human-readable description of the error."
}
```

## 5. Error Codes

| HTTP Status | Error Code             | Description                                              |
|-------------|------------------------|----------------------------------------------------------|
| 400         | `invalid_request`      | The request body is malformed or contains invalid data.  |
| 404         | `not_found`            | The requested resource or profile does not exist.        |
| 405         | `method_not_allowed`   | The HTTP method is not supported for this endpoint.      |
| 415         | `unsupported_media`    | The `Content-Type` header is missing or not `application/json`. |
| 500         | `internal_error`       | An unexpected server error occurred.                     |
| 500         | `apply_failed`         | The server failed to apply the configuration.            |

## 6. curl Examples Summary

```sh
# Health check
curl -s http://localhost:8765/api/health | jq

# Get current config
curl -s http://localhost:8765/api/config | jq

# Generate a preview
curl -s -X POST http://localhost:8765/api/preview \
  -H "Content-Type: application/json" \
  -d '{"theme":"tokyonight","opacity":0.92,"blur":true}' | jq

# Apply a configuration
curl -s -X POST http://localhost:8765/api/apply \
  -H "Content-Type: application/json" \
  -d '{"theme":"catppuccin","opacity":0.90,"blur":true}' | jq

# List profiles
curl -s http://localhost:8765/api/profiles | jq

# Load a saved profile
curl -s -X POST http://localhost:8765/api/profile/tokyonight | jq
```
