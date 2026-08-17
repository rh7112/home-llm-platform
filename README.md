# Home LLM Platform

A fully self-hosted LLM setup for family use and coding assistance — no data
sent to a third-party AI vendor. Runs on a home gaming PC (Ryzen 7 5700X,
32GB RAM, RTX 5070 12GB VRAM) plus a Synology NAS for remote access.

## Architecture

- **[Ollama](https://ollama.com)** — serves the models locally. Model
  weights are relocated off the OS drive via the `OLLAMA_MODELS` environment
  variable (large downloads, best kept off a small system SSD).
- **[Open WebUI](https://github.com/open-webui/open-webui)** — the chat
  interface, in Docker. See [`docker/docker-compose.yml`](docker/docker-compose.yml).
- **[SearXNG](https://github.com/searxng/searxng)** — self-hosted,
  privacy-respecting web search, also in Docker, wired into Open WebUI's
  Web Search settings. Its JSON API is disabled by default and must be
  enabled in `settings.yml` (`search.formats: [html, json]`) after first
  launch.
- **Synology VPN Server (OpenVPN)** — remote access to the home network,
  including Open WebUI, for family members.
- **[Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)**
  — a simpler public-access path for Open WebUI alongside the VPN. See
  [`cloudflared/config.example.yml`](cloudflared/config.example.yml) and
  [`windows/register-cloudflared-task.ps1`](windows/register-cloudflared-task.ps1).
- **[Continue.dev](https://continue.dev)** — VS Code coding assistant,
  pointed at the local Ollama models. See [`continue/config.yaml`](continue/config.yaml).

### Models in use

| Model | Purpose |
|---|---|
| `qwen2.5-coder:14b` | Primary coding assistant (chat/edit) |
| `qwen2.5-coder:1.5b` | Fast inline autocomplete |
| `qwen2.5:14b-instruct` | General-purpose chat |
| `qwen2.5vl:7b` | Vision — image transcription/understanding |

Note the vision model's actual Ollama tag has no hyphen: `qwen2.5vl`, not
`qwen2.5-vl` (the latter 404s).

## Setup

1. Install [Ollama](https://ollama.com/download), set `OLLAMA_MODELS` to a
   drive with room before pulling anything, then pull the models above.
2. `cd docker && docker compose up -d`, then edit the generated
   `searxng-config/settings.yml` to enable JSON output, and
   `docker compose restart searxng`.
3. Copy `continue/config.yaml` to `~/.continue/config.yaml` (or
   `%USERPROFILE%\.continue\config.yaml` on Windows).
4. For remote access, either set up Synology VPN Server directly, or copy
   `cloudflared/config.example.yml` to `cloudflared/config.yml` (gitignored),
   fill in your own tunnel ID/hostname from `cloudflared tunnel create`, and
   run `windows/register-cloudflared-task.ps1` — **on Windows, prefer the
   Scheduled Task approach over `cloudflared service install`** (see below).

## Lessons learned

Worth reading before you hit the same walls:

- **Docker silently breaks VPN LAN routing.** `dockerd` resets the iptables
  `FORWARD` chain's default policy to `DROP` on every startup, with no
  awareness of anything else on the box that also needs forwarding (like a
  VPN server's "allow clients to access the LAN" feature). Confirmed via
  `iptables -S` showing `-P FORWARD DROP` with zero packets ever hitting the
  VPN subnet's NAT rule, and via Windows' `pktmon` proving packets genuinely
  never arrived at the destination host at all. Fixed persistently by
  appending explicit `ACCEPT` rules to the Docker startup script, after
  `dockerd` starts — see [`nas/start-docker-iptables-fix.sh`](nas/start-docker-iptables-fix.sh).
- **`cloudflared service install` on Windows doesn't actually honor
  `--config`.** The registered service's binary path never includes it,
  regardless of what you pass at install time, and when running as
  `LocalSystem` it looks for config in `LocalSystem`'s own profile directory,
  not yours — causing a silent crash-loop. A Scheduled Task running as your
  own user is simpler and just works, since it matches exactly what running
  the command manually in a terminal does.
- **WSL2 "mirrored" networking mode can break Docker's published ports on
  non-loopback interfaces.** Tried it as a fix for a different symptom, made
  things worse (`localhost` worked, the LAN IP didn't, even locally) —
  reverted. Worth knowing before reaching for it as a fix for
  container-not-reachable-from-LAN issues.
- **Environment variable changes need the app fully restarted, not just a
  new terminal.** Setting `OLLAMA_MODELS` via `SetEnvironmentVariable` didn't
  take effect until Ollama's background process was fully killed and
  relaunched — a new PowerShell window alone wasn't enough, since Ollama was
  already running.
