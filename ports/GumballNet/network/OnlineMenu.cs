using Godot;
using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Threading.Tasks;

namespace GumballNet.Network;

/// <summary>Controller-first local setup, server browser, and in-match overlay.</summary>
public partial class OnlineMenu : CanvasLayer
{
    private Control _screen = null!;
    private VBoxContainer _setupPage = null!;
    private VBoxContainer _browserPage = null!;
    private VBoxContainer _matchPage = null!;
    private VBoxContainer _serverList = null!;
    private Label _setupStatus = null!;
    private Label _browserStatus = null!;
    private Label _matchStatus = null!;
    private Label _role = null!;
    private Button _continueToServers = null!;
    private Button _resumeGame = null!;
    private Button _pauseWorld = null!;
    private readonly Button[] _playerCountButtons = new Button[NetworkSession.MaxLocalPlayers];
    private readonly Label[] _controllerLabels = new Label[NetworkSession.MaxLocalPlayers];
    private readonly HBoxContainer[] _teamRows = new HBoxContainer[NetworkSession.MaxLocalPlayers];
    private readonly Label[] _teamPlayerLabels = new Label[NetworkSession.MaxLocalPlayers];
    private readonly Label[] _teamStatusLabels = new Label[NetworkSession.MaxLocalPlayers];
    private readonly Button[] _redTeamButtons = new Button[NetworkSession.MaxLocalPlayers];
    private readonly Button[] _blueTeamButtons = new Button[NetworkSession.MaxLocalPlayers];
    private bool _inMatch;
    private double _controllerRefreshRemaining;

    private NetworkSession Session => GetNode<NetworkSession>("/root/NetworkSession");

    public override void _Ready()
    {
        Layer = 100;
        ProcessMode = ProcessModeEnum.Always;
        BuildInterface();
        Session.StatusChanged += OnStatusChanged;
        Session.PlayerAssignmentChanged += OnPlayerAssignmentChanged;
        Session.PlayerTeamChanged += OnPlayerTeamChanged;
        Session.GamePauseChanged += OnGamePauseChanged;
        SelectPlayerCount(Session.RequestedLocalPlayers);
        ShowPage(_setupPage);
    }

    public override void _Process(double delta)
    {
        if (_inMatch)
            return;
        _controllerRefreshRemaining -= delta;
        if (_controllerRefreshRemaining <= 0)
        {
            _controllerRefreshRemaining = 0.35;
            UpdateControllerReadiness();
        }
    }

    public override void _Input(InputEvent @event)
    {
        if (@event is not InputEventJoypadButton && @event is not InputEventJoypadMotion)
            return;
        if (Array.IndexOf(Session.LocalControllerDevices, @event.Device) < 0)
        {
            GetViewport().SetInputAsHandled();
            return;
        }
        if (_inMatch && @event is InputEventJoypadButton { Pressed: true, ButtonIndex: JoyButton.Start })
        {
            ToggleInGameMenu();
            GetViewport().SetInputAsHandled();
        }
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (!_inMatch || @event is InputEventJoypadButton || !@event.IsActionPressed("ui_cancel"))
            return;
        ToggleInGameMenu();
        GetViewport().SetInputAsHandled();
    }

    private void BuildInterface()
    {
        _screen = new ColorRect { Color = new Color("101827ed"), MouseFilter = Control.MouseFilterEnum.Stop };
        _screen.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        AddChild(_screen);
        var center = new CenterContainer();
        center.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        _screen.AddChild(center);
        var card = new PanelContainer { CustomMinimumSize = new Vector2(940, 0) };
        card.AddThemeStyleboxOverride("panel", Panel(new Color("18243a"), new Color("75d6ff"), 2, 18));
        center.AddChild(card);
        var margin = new MarginContainer();
        foreach (var side in new[] { "margin_left", "margin_right", "margin_top", "margin_bottom" })
            margin.AddThemeConstantOverride(side, 30);
        card.AddChild(margin);
        var root = Page();
        margin.AddChild(root);
        var title = Heading("GUMBALL NET");
        title.AddThemeFontSizeOverride("font_size", 40);
        root.AddChild(title);
        root.AddChild(Copy("ONE MATCH  •  UP TO 16 PLAYERS  •  UP TO 4 PER MACHINE"));
        root.AddChild(new HSeparator());
        _setupPage = BuildSetupPage();
        _browserPage = BuildBrowserPage();
        _matchPage = BuildMatchPage();
        root.AddChild(_setupPage);
        root.AddChild(_browserPage);
        root.AddChild(_matchPage);
    }

    private VBoxContainer BuildSetupPage()
    {
        var page = Page();
        page.AddChild(Heading("1 · LOCAL PLAYERS"));
        page.AddChild(Copy("Choose how many people will play on this machine."));
        var counts = new HBoxContainer();
        counts.AddThemeConstantOverride("separation", 10);
        for (var index = 0; index < _playerCountButtons.Length; index++)
        {
            var count = index + 1;
            var button = MakeButton(count.ToString(), new Color("304f75"));
            button.SizeFlagsHorizontal = Control.SizeFlags.ExpandFill;
            button.Pressed += () => SelectPlayerCount(count);
            _playerCountButtons[index] = button;
            counts.AddChild(button);
        }
        page.AddChild(counts);
        page.AddChild(Heading("CONTROLLERS"));
        for (var index = 0; index < _controllerLabels.Length; index++)
        {
            var label = Copy("");
            label.Visible = false;
            _controllerLabels[index] = label;
            page.AddChild(label);
        }
        _setupStatus = Copy("");
        page.AddChild(_setupStatus);
        _continueToServers = MakeButton("CONTINUE TO SERVERS", new Color("2d91bf"));
        _continueToServers.Pressed += OpenServerBrowser;
        page.AddChild(_continueToServers);
        page.AddChild(QuitButton());
        return page;
    }

    private VBoxContainer BuildBrowserPage()
    {
        var page = Page();
        page.AddChild(Heading("2 · AVAILABLE SERVERS"));
        page.AddChild(Copy("Reachable servers with enough free seats appear below."));
        _browserStatus = Copy("Checking configured servers…");
        page.AddChild(_browserStatus);
        var scroll = new ScrollContainer { CustomMinimumSize = new Vector2(0, 300) };
        _serverList = Page();
        _serverList.SizeFlagsHorizontal = Control.SizeFlags.ExpandFill;
        scroll.AddChild(_serverList);
        page.AddChild(scroll);
        var actions = new HBoxContainer();
        actions.AddThemeConstantOverride("separation", 10);
        var back = MakeButton("BACK", new Color("43516a"));
        var refresh = MakeButton("REFRESH SERVERS", new Color("2d91bf"));
        back.SizeFlagsHorizontal = Control.SizeFlags.ExpandFill;
        refresh.SizeFlagsHorizontal = Control.SizeFlags.ExpandFill;
        back.Pressed += () => ShowPage(_setupPage);
        refresh.Pressed += RefreshServers;
        actions.AddChild(back);
        actions.AddChild(refresh);
        page.AddChild(actions);
        page.AddChild(QuitButton());
        return page;
    }

    private VBoxContainer BuildMatchPage()
    {
        var page = Page();
        page.AddChild(Heading("MATCH MENU"));
        _role = Copy("Connected");
        _role.AddThemeFontSizeOverride("font_size", 17);
        page.AddChild(_role);
        _matchStatus = Copy("Choose a team or return to the game.");
        page.AddChild(_matchStatus);
        page.AddChild(Heading("TEAMS · CHANGE ANYTIME"));
        for (var index = 0; index < NetworkSession.MaxLocalPlayers; index++)
        {
            var localIndex = index;
            var row = new HBoxContainer { Visible = false };
            row.AddThemeConstantOverride("separation", 8);
            var playerLabel = new Label { CustomMinimumSize = new Vector2(90, 0) };
            var red = MakeButton("RED · RIGHT", new Color("a43d45"));
            var blue = MakeButton("BLUE/PURPLE · LEFT", new Color("5148a8"));
            var status = new Label { CustomMinimumSize = new Vector2(130, 0) };
            red.SizeFlagsHorizontal = Control.SizeFlags.ExpandFill;
            blue.SizeFlagsHorizontal = Control.SizeFlags.ExpandFill;
            red.Pressed += () => TeamSelected(localIndex, "A");
            blue.Pressed += () => TeamSelected(localIndex, "B");
            row.AddChild(playerLabel);
            row.AddChild(red);
            row.AddChild(blue);
            row.AddChild(status);
            _teamRows[index] = row;
            _teamPlayerLabels[index] = playerLabel;
            _teamStatusLabels[index] = status;
            _redTeamButtons[index] = red;
            _blueTeamButtons[index] = blue;
            page.AddChild(row);
        }
        _resumeGame = MakeButton("RETURN TO GAME", new Color("2d91bf"));
        _resumeGame.Pressed += () => _screen.Visible = false;
        page.AddChild(_resumeGame);
        _pauseWorld = MakeButton("PAUSE GAME WORLD", new Color("8a6428"));
        _pauseWorld.Pressed += () => Session.ToggleGamePause();
        page.AddChild(_pauseWorld);
        page.AddChild(QuitButton());
        return page;
    }

    private void SelectPlayerCount(int count)
    {
        Session.ConfigureLocalPlayers(count);
        for (var index = 0; index < _playerCountButtons.Length; index++)
            _playerCountButtons[index].Text = index + 1 == count ? $"✓ {count}" : (index + 1).ToString();
        UpdateControllerReadiness();
        _playerCountButtons[count - 1].GrabFocus();
    }

    private void UpdateControllerReadiness()
    {
        var connected = Input.GetConnectedJoypads();
        var allReady = true;
        for (var index = 0; index < _controllerLabels.Length; index++)
        {
            var visible = index < Session.RequestedLocalPlayers;
            _controllerLabels[index].Visible = visible;
            if (!visible)
                continue;
            var device = Session.LocalControllerDevices[index];
            var ready = connected.Contains(device);
            allReady &= ready;
            _controllerLabels[index].Text = ready
                ? $"✓ PLAYER {index + 1} · CONTROLLER {device + 1} CONNECTED"
                : $"○ PLAYER {index + 1} · CONNECT CONTROLLER {device + 1}";
            _controllerLabels[index].AddThemeColorOverride("font_color", ready ? new Color("73e6a1") : new Color("ffb36b"));
        }
        _continueToServers.Disabled = !allReady;
        _setupStatus.Text = allReady ? "All local controllers are ready." : "Connect every required controller to continue.";
    }

    private void OpenServerBrowser()
    {
        if (_continueToServers.Disabled)
            return;
        ShowPage(_browserPage);
        RefreshServers();
    }

    private async void RefreshServers()
    {
        ClearChildren(_serverList);
        _browserStatus.Text = "Checking configured servers…";
        var tasks = new List<Task<ServerStatus?>>();
        foreach (var endpoint in ServerDiscovery.LoadDirectory())
            tasks.Add(ServerDiscovery.ProbeAsync(endpoint));
        var results = await Task.WhenAll(tasks);
        CallDeferred(nameof(ApplyServerResults), JsonSerializer.Serialize(results));
    }

    private void ApplyServerResults(string json)
    {
        ClearChildren(_serverList);
        var results = JsonSerializer.Deserialize<ServerStatus?[]>(json,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? [];
        var available = 0;
        foreach (var status in results)
        {
            if (status == null || status.Free < Session.RequestedLocalPlayers)
                continue;
            available++;
            var captured = status;
            var paused = status.Paused ? " · PAUSED" : "";
            var button = MakeButton($"{status.Name}\n{status.Players}/{status.Capacity} PLAYERS · {status.Free} FREE{paused}", new Color("2f6d58"));
            button.CustomMinimumSize = new Vector2(0, 68);
            button.Pressed += () => JoinServer(captured);
            _serverList.AddChild(button);
        }
        _browserStatus.Text = available > 0
            ? $"{available} server{(available == 1 ? "" : "s")} can fit {Session.RequestedLocalPlayers} local player{(Session.RequestedLocalPlayers == 1 ? "" : "s")}."
            : "No configured server is reachable with enough free seats.";
        if (_serverList.GetChildCount() > 0 && _serverList.GetChild(0) is Button first)
            first.GrabFocus();
    }

    private void JoinServer(ServerStatus status)
    {
        foreach (var child in _serverList.GetChildren())
            if (child is Button button)
                button.Disabled = true;
        _browserStatus.Text = $"Joining {status.Name}…";
        Session.Connect(status.Address, status.GamePort);
    }

    private void OnPlayerAssignmentChanged(int slot, bool owner)
    {
        var seats = string.Join(", ", Session.LocalPlayerSlots);
        _role.Text = owner ? $"PLAYERS {seats} · LOBBY OWNER" : $"PLAYERS {seats} · MATCH MEMBERS";
        _role.AddThemeColorOverride("font_color", owner ? new Color("ffd166") : new Color("75d6ff"));
        for (var index = 0; index < _teamRows.Length; index++)
        {
            var visible = index < Session.LocalPlayerSlots.Length;
            _teamRows[index].Visible = visible;
            if (!visible)
                continue;
            var playerSlot = Session.LocalPlayerSlots[index];
            _teamPlayerLabels[index].Text = $"PLAYER {playerSlot}";
            RefreshTeamRow(index, Session.GetPlayerTeam(playerSlot));
        }
        CallDeferred(nameof(EnterMatch));
    }

    private void EnterMatch()
    {
        if (Session.EnterMatch() != Error.Ok)
            return;
        _inMatch = true;
        ShowPage(_matchPage);
        _screen.Visible = false;
    }

    private void TeamSelected(int localIndex, string team)
    {
        if (localIndex < Session.LocalPlayerSlots.Length)
            Session.ChooseTeam(Session.LocalPlayerSlots[localIndex], team);
    }

    private void OnPlayerTeamChanged(int slot, string team)
    {
        var localIndex = Array.IndexOf(Session.LocalPlayerSlots, slot);
        if (localIndex >= 0)
            RefreshTeamRow(localIndex, team);
    }

    private void RefreshTeamRow(int localIndex, string team)
    {
        var red = team == "A";
        _teamStatusLabels[localIndex].Text = red ? "CURRENT: RED" : "CURRENT: BLUE";
        _teamStatusLabels[localIndex].AddThemeColorOverride("font_color", red ? new Color("ff8c92") : new Color("a99cff"));
        _redTeamButtons[localIndex].Text = red ? "✓ RED · RIGHT" : "RED · RIGHT";
        _blueTeamButtons[localIndex].Text = red ? "BLUE/PURPLE · LEFT" : "✓ BLUE/PURPLE · LEFT";
    }

    private void OnGamePauseChanged(bool paused)
    {
        _pauseWorld.Text = paused ? "RESUME GAME WORLD" : "PAUSE GAME WORLD";
        _matchStatus.Text = paused ? "The shared game world is paused. Menus and networking remain active." : "The game world is running.";
    }

    private void OnStatusChanged(string message)
    {
        if (message.StartsWith("Could not") || message.Contains("disconnected"))
        {
            _inMatch = false;
            ShowPage(_browserPage);
            RefreshServers();
            return;
        }
        if (_inMatch)
            _matchStatus.Text = message;
        else if (_browserPage.Visible)
            _browserStatus.Text = message;
    }

    private void ToggleInGameMenu()
    {
        _screen.Visible = !_screen.Visible;
        if (_screen.Visible)
        {
            ShowPage(_matchPage);
            _resumeGame.GrabFocus();
        }
    }

    private void ShowPage(Control page)
    {
        _setupPage.Visible = page == _setupPage;
        _browserPage.Visible = page == _browserPage;
        _matchPage.Visible = page == _matchPage;
        _screen.Visible = true;
    }

    private static VBoxContainer Page()
    {
        var page = new VBoxContainer();
        page.AddThemeConstantOverride("separation", 12);
        return page;
    }

    private static Label Heading(string text)
    {
        var label = Copy(text);
        label.AddThemeFontSizeOverride("font_size", 21);
        label.AddThemeColorOverride("font_color", new Color("75d6ff"));
        return label;
    }

    private static Label Copy(string text) => new()
    {
        Text = text,
        HorizontalAlignment = HorizontalAlignment.Center,
        AutowrapMode = TextServer.AutowrapMode.WordSmart,
        CustomMinimumSize = new Vector2(0, 30)
    };

    private static Button MakeButton(string text, Color color)
    {
        var button = new Button { Text = text, CustomMinimumSize = new Vector2(0, 48) };
        button.AddThemeFontSizeOverride("font_size", 17);
        button.AddThemeStyleboxOverride("normal", Panel(color, color.Lightened(0.18f), 1, 10));
        button.AddThemeStyleboxOverride("hover", Panel(color.Lightened(0.12f), color.Lightened(0.35f), 2, 10));
        button.AddThemeStyleboxOverride("pressed", Panel(color.Darkened(0.12f), color, 1, 10));
        button.AddThemeStyleboxOverride("focus", Panel(color.Lightened(0.08f), new Color("ffffff"), 3, 10));
        return button;
    }

    private Button QuitButton()
    {
        var quit = MakeButton("QUIT", new Color("303d52"));
        quit.Pressed += () => GetTree().Quit();
        return quit;
    }

    private static StyleBoxFlat Panel(Color background, Color border, int width, int radius) => new()
    {
        BgColor = background, BorderColor = border,
        BorderWidthLeft = width, BorderWidthTop = width, BorderWidthRight = width, BorderWidthBottom = width,
        CornerRadiusTopLeft = radius, CornerRadiusTopRight = radius,
        CornerRadiusBottomLeft = radius, CornerRadiusBottomRight = radius
    };

    private static void ClearChildren(Node parent)
    {
        foreach (var child in parent.GetChildren())
            child.Free();
    }
}
