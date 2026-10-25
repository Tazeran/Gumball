using Godot;
using System;

namespace GumballNet.Network;

/// <summary>Routes the shared build into its client or dedicated-server startup scene.</summary>
public partial class Bootstrap : Node
{
    public override void _Ready()
    {
        CallDeferred(nameof(RouteStartup));
    }

    private void RouteStartup()
    {
        var session = GetNode<NetworkSession>("/root/NetworkSession");
        if (session.IsDedicatedServer)
        {
            if (Array.Exists(OS.GetCmdlineUserArgs(), arg => arg == "--network-smoke-test"))
                return;

            GD.Print("Starting the authoritative match scene without client UI.");
            GetNode("/root/Master").Set("player_count", NetworkSession.MaxPlayers);
            GetTree().ChangeSceneToFile(NetworkSession.ArenaScene);
            return;
        }

        // NetworkSession owns the client startup UI. Keep this intentionally
        // empty so the legacy split-screen landing scene cannot steal focus or
        // launch its old local-only match behind OnlineMenu.
        GD.Print("Waiting at the online startup menu.");
    }
}
