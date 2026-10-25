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

## Quick local multiplayer test

On Windows, double-click `start-local-match.bat`. It starts:

1. One headless authoritative server on UDP `42837` with up to 16 match seats
2. Client 1 connected to `127.0.0.1`, using controller device `0`
3. Client 2 connected to `127.0.0.1`, using controller device `1`

The two graphical clients open at a 4K-friendly 16:9 size of `1840x1035`,
side-by-side at `(20,40)` and `(1940,40)` on screen 0. The
`CLIENT_SIZE`, `CLIENT_1_POSITION`, `CLIENT_2_POSITION`, and `CLIENT_SCREEN`
variables near the top of `start-local-match.bat` can be adjusted for a
different monitor arrangement.

Each machine may request one to four local players. The setup menu selects the
count, while `--local-players=1..4` and `--controllers=0,1,2,3` provide explicit
launch-time configuration. The total across all connected machines may not
exceed 16 players.

After connecting, every local seat has its own unrestricted team selector.
Red spawns at the right-hand base and blue/purple spawns at the left-hand base.
Press Escape during a match to reopen the overlay and change teams at any time;
switching teams respawns that player at the selected base for every client.

For automated development checks, `--auto-enter` enters the arena as soon as
the server assigns seats. The normal launchers leave the lobby screen visible.

The client helper accepts a comma-separated controller list followed by the
local player count. For example, `run-local-client.bat 0,1 2` starts one client
with two local players using controller devices 0 and 1. `run-local-client.bat 1`
starts a one-player client on controller device 1. Godot numbers the first
connected controller as device `0`, even though it is described to the player
as controller 1.

Before launching, the script closes existing Godot processes running this
specific GumballNet project. It does not intentionally close Godot editors or
other projects. If an unrelated program still owns UDP `42837`, the launcher
stops and reports the conflict rather than terminating that program.

The server is deliberately a separate process rather than one client acting as
host. This matches the production Podman deployment and exposes authority bugs
during local testing.

The helper processes start from the Godot installation directory. Godot 4.7.2
can otherwise incorrectly report that `GodotSharp/Api/Debug` is missing even
when that directory is beside the executable.

Only the dedicated server normally keeps a console window open. The other two
windows are graphical clients. `run-local-client.bat` remains available when a
diagnostic client console is useful.

For deployment instructions, see `deploy/README.md`.
