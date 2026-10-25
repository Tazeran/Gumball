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
    private VBoxContainer _playerCountPage = null!;
    private VBoxContainer _controllerPage = null!;
    private VBoxContainer _browserPage = null!;
    private VBoxContainer _matchPage = null!;
    private VBoxContainer _serverList = null!;
    private Label _controllerStatus = null!;
    private Label _browserStatus = null!;
    private Label _matchStatus = null!;
    private Label _role = null!;
    private Button _resumeGame = null!;
    private Button _pauseWorld = null!;
    private Control _seatOverlayRoot = null!;
    private readonly Control[] _seatMenuRegions = new Control[NetworkSession.MaxLocalPlayers];
    private readonly PanelContainer[] _seatMenuPanels = new PanelContainer[NetworkSession.MaxLocalPlayers];
    private readonly Label[] _seatMenuLabels = new Label[NetworkSession.MaxLocalPlayers];
    private readonly Button[] _seatSwapButtons = new Button[NetworkSession.MaxLocalPlayers];
    private readonly Button[] _seatLeaveButtons = new Button[NetworkSession.MaxLocalPlayers];
    private readonly int[] _seatMenuSelections = new int[NetworkSession.MaxLocalPlayers];
    private readonly int[] _seatMenuAxisDirections = new int[NetworkSession.MaxLocalPlayers];
    private readonly Button[] _playerCountButtons = new Button[NetworkSession.MaxLocalPlayers];
    private readonly Label[] _controllerLabels = new Label[NetworkSession.MaxLocalPlayers];
    private readonly bool[] _controllerConfirmed = new bool[NetworkSession.MaxLocalPlayers];
    private readonly HBoxContainer[] _teamRows = new HBoxContainer[NetworkSession.MaxLocalPlayers];
    private readonly Label[] _teamPlayerLabels = new Label[NetworkSession.MaxLocalPlayers];
    private readonly Label[] _teamStatusLabels = new Label[NetworkSession.MaxLocalPlayers];
    private readonly Button[] _redTeamButtons = new Button[NetworkSession.MaxLocalPlayers];
    private readonly Button[] _blueTeamButtons = new Button[NetworkSession.MaxLocalPlayers];
    private bool _inMatch;
    private bool _openingServerBrowser;
    private double _controllerRefreshRemaining;
    private readonly int[] _menuAxisDirections = new int[2];
    private readonly double[] _menuAxisRepeatRemaining = new double[2];

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
        ShowPage(_playerCountPage);
        CallDeferred(nameof(FocusInitialPlayerCount));
    }

    public override void _Process(double delta)
    {
        PollMenuStick(delta);
        if (_inMatch || !_controllerPage.Visible)
            return;
        _controllerRefreshRemaining -= delta;
        if (_controllerRefreshRemaining <= 0)
        {
            _controllerRefreshRemaining = 0.35;
            UpdateControllerReadiness();
        }
    }

    private void PollMenuStick(double delta)
    {
        if (!_screen.Visible || Session.LocalControllerDevices.Length == 0)
        {
            Array.Fill(_menuAxisDirections, 0);
            return;
        }

        var device = Session.LocalControllerDevices[0];
        PollMenuAxis(0, Input.GetJoyAxis(device, JoyAxis.LeftX), Side.Left, Side.Right, delta);
        PollMenuAxis(1, Input.GetJoyAxis(device, JoyAxis.LeftY), Side.Top, Side.Bottom, delta);
    }

    private void PollMenuAxis(int axisIndex, float value, Side negativeSide, Side positiveSide, double delta)
    {
        const float engageThreshold = 0.6f;
        const float releaseThreshold = 0.35f;
        var previousDirection = _menuAxisDirections[axisIndex];
        var direction = Math.Abs(value) <= releaseThreshold
            ? 0
            : Math.Abs(value) >= engageThreshold
                ? Math.Sign(value)
                : previousDirection;

        if (direction == 0)
        {
            _menuAxisDirections[axisIndex] = 0;
            _menuAxisRepeatRemaining[axisIndex] = 0;
            return;
        }

        if (direction != previousDirection)
        {
            _menuAxisDirections[axisIndex] = direction;
            _menuAxisRepeatRemaining[axisIndex] = 0.55;
            MoveMenuFocus(direction < 0 ? negativeSide : positiveSide);
            return;
        }

        _menuAxisRepeatRemaining[axisIndex] -= delta;
        if (_menuAxisRepeatRemaining[axisIndex] <= 0)
        {
            _menuAxisRepeatRemaining[axisIndex] = 0.18;
            MoveMenuFocus(direction < 0 ? negativeSide : positiveSide);
        }
    }

    private void MoveMenuFocus(Side side)
    {
        var current = GetViewport().GuiGetFocusOwner();
        var next = current?.FindValidFocusNeighbor(side);
        next?.GrabFocus();
    }

    public override void _Input(InputEvent @event)
    {
        if (@event is not InputEventJoypadButton && @event is not InputEventJoypadMotion)
            return;
        if (_inMatch && @event is InputEventJoypadButton { Pressed: true, ButtonIndex: JoyButton.Start })
        {
            var localIndex = Array.IndexOf(Session.LocalControllerDevices, @event.Device);
            if (localIndex >= 0)
                ToggleSeatMenu(localIndex);
            else if (Input.GetConnectedJoypads().Contains(@event.Device))
                Session.RequestLocalPlayer(@event.Device);
            GetViewport().SetInputAsHandled();
            return;
        }
        if (Array.IndexOf(Session.LocalControllerDevices, @event.Device) < 0)
        {
            GetViewport().SetInputAsHandled();
            return;
        }
        if (_inMatch)
        {
            var localIndex = Array.IndexOf(Session.LocalControllerDevices, @event.Device);
            if (localIndex >= 0 && _seatMenuPanels[localIndex].Visible)
            {
                HandleSeatMenuInput(localIndex, @event);
                GetViewport().SetInputAsHandled();
                return;
            }
        }
        if (_screen.Visible && @event is InputEventJoypadMotion)
        {
            // PollMenuStick owns analog navigation. Consuming the original
            // motion prevents Godot's built-in UI actions from moving focus a
            // second time for the same stick gesture.
            GetViewport().SetInputAsHandled();
            return;
        }
        if (!_inMatch && _controllerPage.Visible && @event is InputEventJoypadButton { Pressed: true } button)
        {
            if (button.ButtonIndex == JoyButton.A)
            {
                ConfirmController(@event.Device);
                GetViewport().SetInputAsHandled();
                return;
            }
            if (button.ButtonIndex == JoyButton.B)
            {
                ReturnToPlayerCount();
                GetViewport().SetInputAsHandled();
                return;
            }
        }
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event is InputEventJoypadButton || !@event.IsActionPressed("ui_cancel"))
            return;
        if (!_inMatch)
        {
            if (_browserPage.Visible)
                ReturnToControllerConfirmation();
            else if (_controllerPage.Visible)
                ReturnToPlayerCount();
            GetViewport().SetInputAsHandled();
            return;
        }
        if (Session.LocalPlayerSlots.Length > 0)
            ToggleSeatMenu(0);
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
        _playerCountPage = BuildPlayerCountPage();
        _controllerPage = BuildControllerPage();
        _browserPage = BuildBrowserPage();
        _matchPage = BuildMatchPage();
        root.AddChild(_playerCountPage);
        root.AddChild(_controllerPage);
        root.AddChild(_browserPage);
        root.AddChild(_matchPage);
        BuildSeatMenus();
    }

    private void BuildSeatMenus()
    {
        _seatOverlayRoot = new Control { MouseFilter = Control.MouseFilterEnum.Ignore, Visible = false };
        _seatOverlayRoot.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        AddChild(_seatOverlayRoot);
        for (var index = 0; index < NetworkSession.MaxLocalPlayers; index++)
        {
            var localIndex = index;
            var region = new Control { MouseFilter = Control.MouseFilterEnum.Ignore };
            var center = new CenterContainer { MouseFilter = Control.MouseFilterEnum.Ignore };
            center.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
            var panel = new PanelContainer { CustomMinimumSize = new Vector2(330, 0), Visible = false };
            panel.AddThemeStyleboxOverride("panel", Panel(new Color("18243aee"), new Color("75d6ff"), 2, 14));
            var margin = new MarginContainer();
            foreach (var side in new[] { "margin_left", "margin_right", "margin_top", "margin_bottom" })
                margin.AddThemeConstantOverride(side, 18);
            var page = Page();
            var label = Heading("");
            var swap = MakeButton("SWAP TEAM", new Color("5148a8"));
            var leave = MakeButton("LEAVE", new Color("8c3d48"));
            swap.Pressed += () => SwapSeatTeam(localIndex);
            leave.Pressed += () => LeaveSeat(localIndex);
            page.AddChild(label);
            page.AddChild(swap);
            page.AddChild(leave);
            page.AddChild(Copy("START/B · CLOSE"));
            margin.AddChild(page);
            panel.AddChild(margin);
            center.AddChild(panel);
            region.AddChild(center);
            _seatOverlayRoot.AddChild(region);
            _seatMenuRegions[index] = region;
            _seatMenuPanels[index] = panel;
            _seatMenuLabels[index] = label;
            _seatSwapButtons[index] = swap;
            _seatLeaveButtons[index] = leave;
        }
    }

    private VBoxContainer BuildPlayerCountPage()
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
        page.AddChild(Copy("Highlight 1–4, then press A to choose."));
        page.AddChild(QuitButton());
        return page;
    }

    private VBoxContainer BuildControllerPage()
    {
        var page = Page();
        page.AddChild(Heading("2 · CONFIRM CONTROLLERS"));
        page.AddChild(Copy("Each local player must press A on their assigned controller."));
        for (var index = 0; index < _controllerLabels.Length; index++)
        {
            var label = Copy("");
            label.Visible = false;
            _controllerLabels[index] = label;
            page.AddChild(label);
        }
        _controllerStatus = Copy("");
        page.AddChild(_controllerStatus);
        page.AddChild(Copy("Press B to change the number of local players."));
        return page;
    }

    private VBoxContainer BuildBrowserPage()
    {
        var page = Page();
        page.AddChild(Heading("3 · AVAILABLE SERVERS"));
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
        back.Pressed += ReturnToControllerConfirmation;
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
        Array.Fill(_controllerConfirmed, false);
        _openingServerBrowser = false;
        ShowPage(_controllerPage);
        UpdateControllerReadiness();
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
            var connectedNow = connected.Contains(device);
            if (!connectedNow)
                _controllerConfirmed[index] = false;
            var ready = connectedNow && _controllerConfirmed[index];
            allReady &= ready;
            _controllerLabels[index].Text = ready
                ? $"✓ PLAYER {index + 1} · CONTROLLER {device + 1} READY"
                : connectedNow
                    ? $"○ PLAYER {index + 1} · CONTROLLER {device + 1} · PRESS A"
                : $"○ PLAYER {index + 1} · CONNECT CONTROLLER {device + 1}";
            _controllerLabels[index].AddThemeColorOverride("font_color", ready ? new Color("73e6a1") : new Color("ffb36b"));
        }
        _controllerStatus.Text = allReady ? "All controllers confirmed. Opening server list…" : "Waiting for every local player.";
        if (allReady && !_openingServerBrowser)
        {
            _openingServerBrowser = true;
            CallDeferred(nameof(OpenServerBrowser));
        }
    }

    private void OpenServerBrowser()
    {
        ShowPage(_browserPage);
        RefreshServers();
    }

    private void ConfirmController(int device)
    {
        var localIndex = Array.IndexOf(Session.LocalControllerDevices, device);
        if (localIndex < 0 || localIndex >= Session.RequestedLocalPlayers)
            return;
        _controllerConfirmed[localIndex] = true;
        UpdateControllerReadiness();
    }

    private void ReturnToPlayerCount()
    {
        Array.Fill(_controllerConfirmed, false);
        _openingServerBrowser = false;
        ShowPage(_playerCountPage);
        _playerCountButtons[Math.Clamp(Session.RequestedLocalPlayers - 1, 0, _playerCountButtons.Length - 1)].GrabFocus();
    }

    private void ReturnToControllerConfirmation()
    {
        Array.Fill(_controllerConfirmed, false);
        _openingServerBrowser = false;
        ShowPage(_controllerPage);
        UpdateControllerReadiness();
    }

    private void FocusInitialPlayerCount()
    {
        _playerCountButtons[0].GrabFocus();
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
        if (_inMatch)
            CallDeferred(nameof(RefreshSeatMenus));
        else
            CallDeferred(nameof(EnterMatch));
    }

    private void EnterMatch()
    {
        if (Session.EnterMatch() != Error.Ok)
            return;
        _inMatch = true;
        ShowPage(_matchPage);
        _screen.Visible = false;
        _seatOverlayRoot.Visible = true;
        RefreshSeatMenus();
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
        {
            RefreshTeamRow(localIndex, team);
            RefreshSeatMenu(localIndex);
        }
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
            _seatOverlayRoot.Visible = false;
            ShowPage(_browserPage);
            RefreshServers();
            return;
        }
        if (_inMatch)
            _matchStatus.Text = message;
        else if (_browserPage.Visible)
            _browserStatus.Text = message;
    }

    private void ToggleSeatMenu(int localIndex)
    {
        if (localIndex < 0 || localIndex >= Session.LocalPlayerSlots.Length)
            return;
        var open = !_seatMenuPanels[localIndex].Visible;
        _seatMenuPanels[localIndex].Visible = open;
        _seatMenuSelections[localIndex] = 0;
        _seatMenuAxisDirections[localIndex] = 0;
        Session.SetControllerMenuOpen(Session.LocalControllerDevices[localIndex], open);
        RefreshSeatMenu(localIndex);
    }

    private void HandleSeatMenuInput(int localIndex, InputEvent @event)
    {
        if (@event is InputEventJoypadButton { Pressed: true } button)
        {
            if (button.ButtonIndex is JoyButton.DpadUp or JoyButton.DpadDown)
                SelectSeatMenuOption(localIndex, _seatMenuSelections[localIndex] == 0 ? 1 : 0);
            else if (button.ButtonIndex == JoyButton.A)
            {
                if (_seatMenuSelections[localIndex] == 0)
                    SwapSeatTeam(localIndex);
                else
                    LeaveSeat(localIndex);
            }
            else if (button.ButtonIndex == JoyButton.B)
                ToggleSeatMenu(localIndex);
            return;
        }
        if (@event is not InputEventJoypadMotion { Axis: JoyAxis.LeftY } motion)
            return;
        var direction = Math.Abs(motion.AxisValue) >= 0.65f ? Math.Sign(motion.AxisValue) : 0;
        if (direction != 0 && _seatMenuAxisDirections[localIndex] == 0)
            SelectSeatMenuOption(localIndex, _seatMenuSelections[localIndex] == 0 ? 1 : 0);
        if (Math.Abs(motion.AxisValue) <= 0.35f)
            direction = 0;
        _seatMenuAxisDirections[localIndex] = direction;
    }

    private void SelectSeatMenuOption(int localIndex, int selection)
    {
        _seatMenuSelections[localIndex] = selection;
        RefreshSeatMenu(localIndex);
    }

    private void SwapSeatTeam(int localIndex)
    {
        if (localIndex >= Session.LocalPlayerSlots.Length)
            return;
        var slot = Session.LocalPlayerSlots[localIndex];
        Session.ChooseTeam(slot, Session.GetPlayerTeam(slot) == "A" ? "B" : "A");
        _seatMenuPanels[localIndex].Visible = false;
        Session.SetControllerMenuOpen(Session.LocalControllerDevices[localIndex], false);
    }

    private void LeaveSeat(int localIndex)
    {
        if (localIndex >= Session.LocalPlayerSlots.Length)
            return;
        var slot = Session.LocalPlayerSlots[localIndex];
        var device = Session.LocalControllerDevices[localIndex];
        _seatMenuPanels[localIndex].Visible = false;
        Session.SetControllerMenuOpen(device, false);
        Session.ReleaseLocalPlayer(slot);
    }

    private void RefreshSeatMenus()
    {
        var count = Session.LocalPlayerSlots.Length;
        _seatOverlayRoot.Visible = _inMatch;
        for (var index = 0; index < _seatMenuRegions.Length; index++)
        {
            var active = index < count;
            _seatMenuRegions[index].Visible = active;
            if (!active)
            {
                _seatMenuPanels[index].Visible = false;
                continue;
            }
            LayoutSeatRegion(_seatMenuRegions[index], index, count);
            RefreshSeatMenu(index);
        }
    }

    private void RefreshSeatMenu(int localIndex)
    {
        if (localIndex >= Session.LocalPlayerSlots.Length)
            return;
        var slot = Session.LocalPlayerSlots[localIndex];
        var team = Session.GetPlayerTeam(slot) == "A" ? "RED" : "BLUE/PURPLE";
        _seatMenuLabels[localIndex].Text = $"PLAYER {slot} · {team}";
        _seatSwapButtons[localIndex].Text = (_seatMenuSelections[localIndex] == 0 ? "▶ " : "") + "SWAP TEAM";
        _seatLeaveButtons[localIndex].Text = (_seatMenuSelections[localIndex] == 1 ? "▶ " : "") + "LEAVE MATCH";
    }

    private static void LayoutSeatRegion(Control region, int index, int count)
    {
        var columns = count == 1 ? 1 : 2;
        var rows = count <= 2 ? 1 : 2;
        var column = index % columns;
        var row = index / columns;
        region.AnchorLeft = (float)column / columns;
        region.AnchorRight = (float)(column + 1) / columns;
        region.AnchorTop = (float)row / rows;
        region.AnchorBottom = (float)(row + 1) / rows;
        region.OffsetLeft = region.OffsetTop = region.OffsetRight = region.OffsetBottom = 0;
    }

    private void ShowPage(Control page)
    {
        _playerCountPage.Visible = page == _playerCountPage;
        _controllerPage.Visible = page == _controllerPage;
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
