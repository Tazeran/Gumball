using Godot;
using System;

namespace GumballNet.Network;

/// <summary>Routes the shared build into its client or dedicated-server startup scene.</summary>
public partial class Bootstrap : Node
{
    private const string LandingScene = "res://scenes/Menu/Landing.tscn";

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
            GetTree().ChangeSceneToFile(NetworkSession.ArenaScene);
            return;
        }

        GetTree().ChangeSceneToFile(LandingScene);
    }
}
