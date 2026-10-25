using Godot;
using System;

namespace GumballNet.Network;

/// <summary>Persistent title, connection, lobby, and in-game pause overlay.</summary>
public partial class OnlineMenu : CanvasLayer
{
    private Control _screen = null!;
    private LineEdit _address = null!;
    private OptionButton _localPlayers = null!;
    private Label _status = null!;
    private Label _role = null!;
    private Button _connect = null!;
    private Button _enterMatch = null!;
    private Button _disconnect = null!;
    private Button _pauseWorld = null!;
    private VBoxContainer _teamChoices = null!;
    private readonly OptionButton[] _teamSelectors = new OptionButton[NetworkSession.MaxLocalPlayers];
    private bool _inMatch;

    public override void _Ready()
    {
        Layer = 100;
        ProcessMode = ProcessModeEnum.Always;
        BuildInterface();

        Session.StatusChanged += OnStatusChanged;
        Session.PlayerAssignmentChanged += OnPlayerAssignmentChanged;
        Session.PlayerTeamChanged += OnPlayerTeamChanged;
        Session.GamePauseChanged += OnGamePauseChanged;
        _address.GrabFocus();
    }

    public override void _Input(InputEvent @event)
    {
        if (@event is not InputEventJoypadButton && @event is not InputEventJoypadMotion)
            return;

        // Godot's built-in Control navigation otherwise reacts to every gamepad
        // connected to the computer. A development client should only consume
        // the controller devices assigned to its local seats.
        if (Array.IndexOf(Session.LocalControllerDevices, @event.Device) < 0)
            GetViewport().SetInputAsHandled();
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (!_inMatch || !@event.IsActionPressed("ui_cancel"))
            return;

        _screen.Visible = !_screen.Visible;
        GetViewport().SetInputAsHandled();
        if (_screen.Visible)
            _disconnect.GrabFocus();
    }

    private NetworkSession Session => GetNode<NetworkSession>("/root/NetworkSession");

    private void BuildInterface()
    {
        _screen = new ColorRect { Color = new Color("101827e8"), MouseFilter = Control.MouseFilterEnum.Stop };
        _screen.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        AddChild(_screen);

        var margin = new MarginContainer();
        margin.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        foreach (var side in new[] { "margin_left", "margin_right", "margin_top", "margin_bottom" })
            margin.AddThemeConstantOverride(side, 32);
        _screen.AddChild(margin);

        var center = new CenterContainer();
        center.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        margin.AddChild(center);

        var card = new PanelContainer { CustomMinimumSize = new Vector2(560, 0) };
        card.AddThemeStyleboxOverride("panel", Panel(new Color("18243a"), new Color("75d6ff"), 2, 18));
        center.AddChild(card);

        var cardMargin = new MarginContainer();
        cardMargin.AddThemeConstantOverride("margin_left", 36);
        cardMargin.AddThemeConstantOverride("margin_right", 36);
        cardMargin.AddThemeConstantOverride("margin_top", 30);
        cardMargin.AddThemeConstantOverride("margin_bottom", 30);
        card.AddChild(cardMargin);

        var stack = new VBoxContainer();
        stack.AddThemeConstantOverride("separation", 14);
        cardMargin.AddChild(stack);

        var title = new Label { Text = "GUMBALL NET", HorizontalAlignment = HorizontalAlignment.Center };
        title.AddThemeFontSizeOverride("font_size", 42);
        title.AddThemeColorOverride("font_color", new Color("75d6ff"));
        stack.AddChild(title);

        var subtitle = new Label
        {
            Text = "ONE SERVER  •  ONE MATCH  •  UP TO 16 PLAYERS",
            HorizontalAlignment = HorizontalAlignment.Center
        };
        subtitle.AddThemeFontSizeOverride("font_size", 14);
        subtitle.AddThemeColorOverride("font_color", new Color("a9b9cc"));
        stack.AddChild(subtitle);
        stack.AddChild(new HSeparator());

        var addressLabel = new Label { Text = $"DEDICATED SERVER  ·  UDP {NetworkSession.ServerPort}" };
        addressLabel.AddThemeFontSizeOverride("font_size", 13);
        addressLabel.AddThemeColorOverride("font_color", new Color("a9b9cc"));
        stack.AddChild(addressLabel);

        _localPlayers = new OptionButton { CustomMinimumSize = new Vector2(0, 42) };
        for (var count = 1; count <= NetworkSession.MaxLocalPlayers; count++)
            _localPlayers.AddItem(count == 1 ? "1 local player" : $"{count} local players");
        _localPlayers.Selected = Session.RequestedLocalPlayers - 1;
        stack.AddChild(_localPlayers);

        _address = new LineEdit
        {
            Text = "127.0.0.1",
            PlaceholderText = "Server IP or hostname",
            CustomMinimumSize = new Vector2(0, 46)
        };
        _address.AddThemeFontSizeOverride("font_size", 18);
        stack.AddChild(_address);

        _connect = MakeButton("JOIN ONLINE MATCH", new Color("2d91bf"));
        _connect.Pressed += ConnectPressed;
        stack.AddChild(_connect);

        _status = new Label
        {
            Text = "Enter the droplet address, or use 127.0.0.1 for a local server.",
            AutowrapMode = TextServer.AutowrapMode.WordSmart,
            HorizontalAlignment = HorizontalAlignment.Center,
            CustomMinimumSize = new Vector2(0, 44)
        };
        _status.AddThemeColorOverride("font_color", new Color("d9e7f2"));
        stack.AddChild(_status);

        _role = new Label { Text = "Not connected", HorizontalAlignment = HorizontalAlignment.Center };
        _role.AddThemeFontSizeOverride("font_size", 16);
        _role.AddThemeColorOverride("font_color", new Color("7f91a8"));
        stack.AddChild(_role);

        _teamChoices = new VBoxContainer { Visible = false };
        _teamChoices.AddThemeConstantOverride("separation", 8);
        var teamHeading = new Label { Text = "TEAM SELECTION (CHANGE ANYTIME)", HorizontalAlignment = HorizontalAlignment.Center };
        teamHeading.AddThemeColorOverride("font_color", new Color("a9b9cc"));
        _teamChoices.AddChild(teamHeading);
        for (var index = 0; index < _teamSelectors.Length; index++)
        {
            var localIndex = index;
            var selector = new OptionButton { CustomMinimumSize = new Vector2(0, 38), Visible = false };
            selector.AddItem("RED TEAM — RIGHT BASE");
            selector.AddItem("BLUE / PURPLE TEAM — LEFT BASE");
            selector.ItemSelected += selected => TeamSelected(localIndex, selected);
            _teamSelectors[index] = selector;
            _teamChoices.AddChild(selector);
        }
        stack.AddChild(_teamChoices);

        _pauseWorld = MakeButton("PAUSE GAME WORLD", new Color("8a6428"));
        _pauseWorld.Visible = false;
        _pauseWorld.Pressed += PauseWorldPressed;
        stack.AddChild(_pauseWorld);

        _enterMatch = MakeButton("ENTER MATCH", new Color("39a96b"));
        _enterMatch.Visible = false;
        _enterMatch.Pressed += EnterMatchPressed;
        stack.AddChild(_enterMatch);

        _disconnect = MakeButton("DISCONNECT", new Color("6a3445"));
        _disconnect.Visible = false;
        _disconnect.Pressed += DisconnectPressed;
        stack.AddChild(_disconnect);

        var footer = new HBoxContainer { Alignment = BoxContainer.AlignmentMode.Center };
        var quit = MakeButton("QUIT", new Color("303d52"));
        quit.CustomMinimumSize = new Vector2(150, 40);
        quit.Pressed += QuitPressed;
        footer.AddChild(quit);
        stack.AddChild(footer);
    }

    private static Button MakeButton(string text, Color color)
    {
        var button = new Button { Text = text, CustomMinimumSize = new Vector2(0, 48) };
        button.AddThemeFontSizeOverride("font_size", 17);
        button.AddThemeStyleboxOverride("normal", Panel(color, color.Lightened(0.18f), 1, 10));
        button.AddThemeStyleboxOverride("hover", Panel(color.Lightened(0.12f), color.Lightened(0.35f), 2, 10));
        button.AddThemeStyleboxOverride("pressed", Panel(color.Darkened(0.12f), color, 1, 10));
        button.AddThemeStyleboxOverride("focus", Panel(color.Lightened(0.08f), new Color("ffffff"), 2, 10));
        return button;
    }

    private static StyleBoxFlat Panel(Color background, Color border, int width, int radius) => new()
    {
        BgColor = background,
        BorderColor = border,
        BorderWidthLeft = width,
        BorderWidthTop = width,
        BorderWidthRight = width,
        BorderWidthBottom = width,
        CornerRadiusTopLeft = radius,
        CornerRadiusTopRight = radius,
        CornerRadiusBottomLeft = radius,
        CornerRadiusBottomRight = radius
    };

    private void ConnectPressed()
    {
        GD.Print("Online menu join pressed.");
        _connect.Disabled = true;
        _address.Editable = false;
        _status.Text = "Opening a game session…";
        Session.ConfigureLocalPlayers(_localPlayers.Selected + 1);
        _localPlayers.Disabled = true;
        Session.Connect(_address.Text);
    }

    private void QuitPressed()
    {
        GD.Print("Online menu quit pressed.");
        GetTree().Quit();
    }

    private void DisconnectPressed()
    {
        Session.Disconnect();
        _connect.Visible = true;
        _connect.Disabled = false;
        _address.Editable = true;
        _localPlayers.Disabled = false;
        _enterMatch.Visible = false;
        _disconnect.Visible = false;
        _role.Text = "Not connected";
        _teamChoices.Visible = false;
        _pauseWorld.Visible = false;
        _status.Text = "Disconnected. Enter a server address to reconnect.";
    }

    private void EnterMatchPressed()
    {
        if (Session.EnterMatch() != Error.Ok)
            return;

        _inMatch = true;
        _screen.Visible = false;
    }

    private void OnStatusChanged(string message)
    {
        _status.Text = message;
        if (message.StartsWith("Could not") || message.Contains("disconnected"))
        {
            _connect.Disabled = false;
            _address.Editable = true;
            _localPlayers.Disabled = false;
        }
    }

    private void OnPlayerAssignmentChanged(int slot, bool owner)
    {
        _connect.Visible = false;
        _address.Editable = false;
        _disconnect.Visible = true;
        _enterMatch.Visible = true;
        _enterMatch.GrabFocus();
        var seats = string.Join(", ", Session.LocalPlayerSlots);
        var seatLabel = Session.LocalPlayerSlots.Length == 1 ? $"PLAYER {seats}" : $"PLAYERS {seats}";
        _role.Text = owner ? $"{seatLabel}  •  LOBBY OWNER" : $"{seatLabel}  •  MATCH MEMBER";
        _role.AddThemeColorOverride("font_color", owner ? new Color("ffd166") : new Color("75d6ff"));
        _status.Text = owner
            ? "You joined first. The dedicated server still owns the simulation."
            : "You joined the active dedicated match.";
        _teamChoices.Visible = true;
        _pauseWorld.Visible = true;
        for (var index = 0; index < _teamSelectors.Length; index++)
        {
            var visible = index < Session.LocalPlayerSlots.Length;
            _teamSelectors[index].Visible = visible;
            if (!visible)
                continue;
            var playerSlot = Session.LocalPlayerSlots[index];
            _teamSelectors[index].Clear();
            _teamSelectors[index].AddItem($"PLAYER {playerSlot}: RED TEAM — RIGHT BASE");
            _teamSelectors[index].AddItem($"PLAYER {playerSlot}: BLUE / PURPLE TEAM — LEFT BASE");
            _teamSelectors[index].Selected = Session.GetPlayerTeam(playerSlot) == "B" ? 1 : 0;
        }
        if (Session.AutoEnterMatch)
            CallDeferred(nameof(EnterMatchPressed));
    }

    private void TeamSelected(int localIndex, long selected)
    {
        if (localIndex >= Session.LocalPlayerSlots.Length)
            return;
        Session.ChooseTeam(Session.LocalPlayerSlots[localIndex], selected == 1 ? "B" : "A");
    }

    private void OnPlayerTeamChanged(int slot, string team)
    {
        var localIndex = Array.IndexOf(Session.LocalPlayerSlots, slot);
        if (localIndex >= 0)
            _teamSelectors[localIndex].Selected = team == "B" ? 1 : 0;
    }

    private void PauseWorldPressed() => Session.ToggleGamePause();

    private void OnGamePauseChanged(bool paused)
    {
        _pauseWorld.Text = paused ? "RESUME GAME WORLD" : "PAUSE GAME WORLD";
        _pauseWorld.AddThemeStyleboxOverride("normal",
            Panel(paused ? new Color("2f8b57") : new Color("8a6428"), new Color("ffffff"), 1, 10));
        _status.Text = paused
            ? "The game world is paused for everyone. Menus and networking remain active."
            : "The game world is running.";
    }
}
