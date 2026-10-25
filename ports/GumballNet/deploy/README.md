# GumballNet dedicated server

The server runs one match for up to 16 players. Gameplay uses UDP `42837` and
the lightweight server-browser status responder uses UDP `42838`.

## Droplet requirements

- Podman with Compose support
- UDP `42837` and `42838` allowed by the DigitalOcean cloud firewall and the droplet firewall
- A Linux Godot .NET dedicated-server export placed in `build/server/`

Caddy is not in the game-data path. ENet uses UDP directly; Caddy can later front an HTTPS status or account API.

## Deploy

```sh
podman compose -f deploy/compose.yaml up -d --build
podman logs -f gumball-server
```

Add the droplet IP or DNS name to `network/servers.json`. Set the server's
display name in `network/server.json` before exporting. Clients probe UDP
`42838`, then connect to the advertised gameplay port. The first connected
client becomes lobby owner, while the dedicated server owns the match roster.
