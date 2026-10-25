# GumballNet

This is the in-progress Godot 4.7.2 .NET/C# port of Gumball. It is separate from
the original project at the repository root so the existing split-screen game
continues to work while the online version is built.

## Current online foundation

- One dedicated, authoritative match per server process
- Up to four remote players
- ENet over UDP port `42837`
- The first player is lobby owner; the droplet remains simulation authority
- A temporary in-game address/join panel
- The same build runs as a graphical client normally or as a headless server via `--server`
- Linux server export and Podman deployment files in `deploy/`

The connection/session layer is working code, but gameplay replication is the
next migration stage. The legacy GDScript gameplay still exists in this copy and
is not yet authoritative network code.

## Development

Install Godot 4.7.2 .NET and the .NET 8 SDK, then import this directory as its
own Godot project. Open `project.godot`, let Godot import the assets, and build
the C# solution.

Run a server from a terminal:

```powershell
Godot_v4.7.2-stable_mono_win64_console.exe --headless --path . --server
```

On Linux, the exported binary uses the same flags:

```sh
./GumballNetServer.x86_64 --headless --server
```

Run another copy normally, enter the server IP or DNS name in the online panel,
and select **Join Online Match**. Local testing uses `127.0.0.1`.

For deployment instructions, see `deploy/README.md`.
