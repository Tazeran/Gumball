# GumballNet dedicated server

The first online version runs one authoritative match for up to four players on UDP port `42837`.

## Droplet requirements

- Podman with Compose support
- UDP `42837` allowed by the DigitalOcean cloud firewall and the droplet firewall
- A Linux Godot .NET dedicated-server export placed in `build/server/`

Caddy is not in the game-data path. ENet uses UDP directly; Caddy can later front an HTTPS status or account API.

## Deploy

```sh
podman compose -f deploy/compose.yaml up -d --build
podman logs -f gumball-server
```

Clients connect to the droplet's IP address or DNS name on UDP port `42837`. The first connected client becomes lobby owner, while the server remains authoritative.
