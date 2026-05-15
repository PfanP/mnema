# Quickstart

## Prerequisites

- Docker Desktop (Windows or macOS) or Docker Engine with Compose v2 (Linux)
- An API key for at least one supported provider (Anthropic, OpenAI, or a compatible gateway)

## 1. Install Mnema

**Linux and macOS:**

```bash
curl -fsSL https://raw.githubusercontent.com/pfanp/mnema/main/scripts/install.sh | sh
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/pfanp/mnema/main/scripts/install.ps1 | iex
```

If blocked by corporate policy:

```powershell
irm https://raw.githubusercontent.com/pfanp/mnema/main/scripts/install.ps1 -OutFile install.ps1
powershell -ExecutionPolicy Bypass -File install.ps1
```

The installer starts Mnema automatically. Your bearer token is printed at the
end of installation and saved to `~/.mnema/token` (Linux/macOS) or
`%USERPROFILE%\.mnema\token` (Windows).

### If you lose your token run:

**Linux and macOS:**

```bash
docker compose -f ~/.mnema/docker-compose.yml exec mnema node dist/index.js token
```

**Windows (PowerShell):**

```powershell
docker compose -f "$env:USERPROFILE\.mnema\docker-compose.yml" exec mnema node dist/index.js token
```

And for the stopped container case:

**Linux and macOS:**

```bash
docker compose -f ~/.mnema/docker-compose.yml run --rm mnema node dist/index.js token
```

**Windows (PowerShell):**

```powershell
docker compose -f "$env:USERPROFILE\.mnema\docker-compose.yml" run --rm mnema node dist/index.js token
```

## 2. Connect a provider

Open `http://localhost:5757/onboarding` in your browser. You will be prompted to:

1. Enter your provider credentials
2. Pick a default model
3. Answer a short questionnaire to seed your world model

Onboarding is optional. If you skip it, Mnema builds your world model from chat
extraction over time.

## 3. Point your client

Set your client's API base URL to `http://localhost:5757/v1` and use your bearer
token for authentication. The model list is populated from your configured
providers.

For client-specific instructions, see [clients.md](clients.md).

## 4. Start chatting

Open `http://localhost:5757/beliefs` to watch your world model grow as you work.

---

## Configuration

### Environment variables

| Variable      | Description                                                   | Default |
| ------------- | ------------------------------------------------------------- | ------- |
| `MNEMA_PORT` | Port the server listens on                                    | `5757`  |
| `PORT`        | Fallback if `MNEMA_PORT` is not set (for PaaS compatibility) | `5757`  |

To install on a different port:

**Linux and macOS:**

```bash
MNEMA_PORT=5858 sh install.sh
```

**Windows (PowerShell):**

```powershell
$env:MNEMA_PORT=5858; powershell -ExecutionPolicy Bypass -File install.ps1
```

---

## Managing Mnema

All commands reference the compose file written by the installer. Replace
`~/.mnema` with `%USERPROFILE%\.mnema` on Windows.

**Check logs:**

```bash
docker compose -f ~/.mnema/docker-compose.yml logs proxy
```

**Stop:**

```bash
docker compose -f ~/.mnema/docker-compose.yml down
```

**Start:**

```bash
docker compose -f ~/.mnema/docker-compose.yml up -d
```

**Update to the latest image:**

```bash
docker compose -f ~/.mnema/docker-compose.yml pull
docker compose -f ~/.mnema/docker-compose.yml up -d
```
