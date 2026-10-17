using Godot;

namespace GumballNet.Network;

/// <summary>A temporary code-built connection UI, independent of the legacy split-screen menu.</summary>
public partial class OnlineMenu : CanvasLayer
{
    private LineEdit _address = null!;
    private Label _status = null!;
    private Button _connect = null!;

    public override void _Ready()
    {
        Layer = 100;

        var panel = new PanelContainer
        {
            OffsetLeft = 24,
            OffsetTop = 24,
            OffsetRight = 444,
            OffsetBottom = 220
        };
        AddChild(panel);

        var content = new VBoxContainer();
        panel.AddChild(content);

        content.AddChild(new Label { Text = "GumballNet — Dedicated Online Match" });
        content.AddChild(new Label { Text = $"Server address (UDP port {NetworkSession.ServerPort})" });

        _address = new LineEdit
        {
            Text = "127.0.0.1",
            PlaceholderText = "play.example.com"
        };
        content.AddChild(_address);

        _connect = new Button { Text = "Join Online Match" };
        _connect.Pressed += ConnectPressed;
        content.AddChild(_connect);

        var disconnect = new Button { Text = "Disconnect" };
        disconnect.Pressed += DisconnectPressed;
        content.AddChild(disconnect);

        _status = new Label { Text = "Not connected." };
        content.AddChild(_status);

        var session = GetNode<NetworkSession>("/root/NetworkSession");
        session.StatusChanged += OnStatusChanged;
        session.PlayerAssignmentChanged += OnPlayerAssignmentChanged;
    }

    private void ConnectPressed()
    {
        _connect.Disabled = true;
        GetNode<NetworkSession>("/root/NetworkSession").Connect(_address.Text);
    }

    private void DisconnectPressed()
    {
        GetNode<NetworkSession>("/root/NetworkSession").Disconnect();
        _connect.Disabled = false;
        _status.Text = "Disconnected.";
    }

    private void OnStatusChanged(string message)
    {
        _status.Text = message;
        if (message.StartsWith("Could not") || message.Contains("disconnected"))
            _connect.Disabled = false;
    }

    private void OnPlayerAssignmentChanged(int slot, bool owner)
    {
        _connect.Disabled = true;
        _status.Text = owner
            ? $"Player {slot}; you own the lobby. The droplet owns simulation."
            : $"Player {slot}; joined the existing match.";
    }
}
