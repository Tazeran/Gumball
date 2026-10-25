using Godot;
using System;
using System.Collections.Generic;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace GumballNet.Network;

/// <summary>
/// Owns the single online match. The dedicated server owns the roster and
/// validates the owner of relayed player state. The first connected player is
/// the lobby owner, not the network host.
/// </summary>
public partial class NetworkSession : Node
{
    public const int ServerPort = 42837;
    public const int StatusPort = 42838;
    public const int MaxPlayers = 16;
    public const int MaxLocalPlayers = 4;
    public const string ArenaScene = "res://scenes/arena1.tscn";

    [Signal] public delegate void StatusChangedEventHandler(string message);
    [Signal] public delegate void PlayerAssignmentChangedEventHandler(int slot, bool lobbyOwner);
    [Signal] public delegate void RosterChangedEventHandler(int[] activeSlots);
    [Signal] public delegate void PlayerStateReceivedEventHandler(int slot, Vector3 position, float rotationY, Vector3 velocity);
    [Signal] public delegate void PlayerTeamChangedEventHandler(int slot, string team);
    [Signal] public delegate void GamePauseChangedEventHandler(bool paused);

    public bool IsDedicatedServer { get; private set; }
    public int LocalPlayerSlot { get; private set; }
    public int[] LocalPlayerSlots { get; private set; } = Array.Empty<int>();
    public int[] ActivePlayerSlots { get; private set; } = Array.Empty<int>();
    public bool IsLobbyOwner { get; private set; }
    public int LocalControllerDevice { get; private set; }
    public int[] LocalControllerDevices { get; private set; } = [0];
    public int RequestedLocalPlayers { get; private set; } = 1;
    public bool AutoEnterMatch { get; private set; }
    public bool IsGamePaused { get; private set; }
    public string ServerName { get; private set; } = "Gumball Server";

    private readonly Dictionary<long, List<int>> _peerSlots = new();
    private readonly Dictionary<int, string> _playerTeams = new();
    private readonly Queue<int> _freeSlots = new();
    private long _lobbyOwnerPeerId;
    private OnlineMenu? _onlineMenu;
    private UdpClient? _statusListener;
    private CancellationTokenSource? _statusCancellation;
    private volatile int _occupiedSeatCount;

    public override void _Ready()
    {
        ProcessMode = ProcessModeEnum.Always;
        for (var slot = 1; slot <= MaxPlayers; slot++)
            _freeSlots.Enqueue(slot);

        Multiplayer.PeerConnected += OnPeerConnected;
        Multiplayer.PeerDisconnected += OnPeerDisconnected;
        Multiplayer.ConnectedToServer += OnConnectedToServer;
        Multiplayer.ConnectionFailed += OnConnectionFailed;
        Multiplayer.ServerDisconnected += OnServerDisconnected;

        var commandLineArgs = new List<string>(OS.GetCmdlineArgs());
        commandLineArgs.AddRange(OS.GetCmdlineUserArgs());
        LoadServerName();

        foreach (var arg in commandLineArgs)
        {
            if (arg == "--auto-enter")
                AutoEnterMatch = true;
            else if (arg.StartsWith("--local-players=", StringComparison.Ordinal)
                && int.TryParse(arg["--local-players=".Length..], out var count))
                RequestedLocalPlayers = Math.Clamp(count, 1, MaxLocalPlayers);
            else if (arg.StartsWith("--controllers=", StringComparison.Ordinal))
                LocalControllerDevices = ParseControllers(arg["--controllers=".Length..]);
            else if (arg.StartsWith("--controller=", StringComparison.Ordinal)
                && int.TryParse(arg["--controller=".Length..], out var device))
                LocalControllerDevices = [Math.Clamp(device, 0, MaxLocalPlayers - 1)];
            else if (arg.StartsWith("--server-name=", StringComparison.Ordinal))
                ServerName = arg["--server-name=".Length..].Trim();
        }
        NormalizeControllerList();

        IsDedicatedServer = commandLineArgs.Contains("--server")
            || OS.HasFeature("dedicated_server");
        if (IsDedicatedServer)
            StartDedicatedServer();
        else
        {
            GD.Print($"GumballNet client requesting {RequestedLocalPlayers} local player(s), controllers {string.Join(',', LocalControllerDevices)}.");
            CallDeferred(nameof(CreateOnlineMenu));
            foreach (var arg in commandLineArgs)
            {
                if (arg.StartsWith("--connect=", StringComparison.Ordinal))
                    CallDeferred(nameof(ConnectDefault), arg["--connect=".Length..]);
            }
        }
    }

    public Error StartDedicatedServer()
    {
        if (Multiplayer.HasMultiplayerPeer())
            Multiplayer.MultiplayerPeer.Close();

        var peer = new ENetMultiplayerPeer();
        var result = peer.CreateServer(ServerPort, MaxPlayers);
        if (result != Error.Ok)
        {
            GD.PushError($"Unable to listen on UDP {ServerPort}: {result}");
            return result;
        }

        Multiplayer.MultiplayerPeer = peer;
        StartStatusListener();
        GD.Print($"GumballNet dedicated server listening on UDP {ServerPort}.");
        EmitSignal(SignalName.StatusChanged, $"Server listening on UDP {ServerPort}");

        return Error.Ok;
    }

    public Error Connect(string address, int port = ServerPort)
    {
        Disconnect();
        address = string.IsNullOrWhiteSpace(address) ? "127.0.0.1" : address.Trim();

        var peer = new ENetMultiplayerPeer();
        var result = peer.CreateClient(address, port);
        if (result != Error.Ok)
        {
            EmitSignal(SignalName.StatusChanged, $"Connection could not start: {result}");
            return result;
        }

        Multiplayer.MultiplayerPeer = peer;
        GD.Print($"Connecting to {address}:{port}...");
        EmitSignal(SignalName.StatusChanged, $"Connecting to {address}:{port}…");
        return Error.Ok;
    }

    private void ConnectDefault(string address) => Connect(address, ServerPort);

    public void Disconnect()
    {
        if (Multiplayer.HasMultiplayerPeer())
            Multiplayer.MultiplayerPeer.Close();

        Multiplayer.MultiplayerPeer = new OfflineMultiplayerPeer();
        LocalPlayerSlot = 0;
        LocalPlayerSlots = Array.Empty<int>();
        ActivePlayerSlots = Array.Empty<int>();
        _playerTeams.Clear();
        IsLobbyOwner = false;
        ApplyGamePause(false);
        EmitSignal(SignalName.RosterChanged, ActivePlayerSlots);
    }

    public Error EnterMatch()
    {
        if (LocalPlayerSlot == 0)
        {
            EmitSignal(SignalName.StatusChanged, "Connect to the server before entering the match.");
            return Error.Unconfigured;
        }

        if (GetTree().CurrentScene?.SceneFilePath == ArenaScene)
            return Error.Ok;

        // The arena uses this only for the number of local viewports. Its online
        // path independently retains all 16 global player slots.
        GetNode("/root/Master").Set("player_count", RequestedLocalPlayers);

        var result = GetTree().ChangeSceneToFile(ArenaScene);
        if (result != Error.Ok)
            EmitSignal(SignalName.StatusChanged, $"Unable to load the match: {result}");
        return result;
    }

    private void OnPeerConnected(long peerId)
    {
        if (!Multiplayer.IsServer())
            return;
        GD.Print($"Peer {peerId} connected and is requesting local player seats.");
    }

    private void OnPeerDisconnected(long peerId)
    {
        if (!Multiplayer.IsServer() || !_peerSlots.Remove(peerId, out var slots))
            return;

        foreach (var slot in slots)
        {
            _freeSlots.Enqueue(slot);
            _playerTeams.Remove(slot);
        }
        _occupiedSeatCount = Math.Max(0, _occupiedSeatCount - slots.Count);
        if (_lobbyOwnerPeerId == peerId)
        {
            _lobbyOwnerPeerId = 0;
            foreach (var remainingPeer in _peerSlots.Keys)
            {
                _lobbyOwnerPeerId = remainingPeer;
                RpcId(remainingPeer, nameof(SetLobbyOwner), true);
                break;
            }
        }

        GD.Print($"Peer {peerId} left; slots {string.Join(',', slots)} are available.");
        BroadcastRoster();
        if (_peerSlots.Count == 0 && IsGamePaused)
            ApplyGamePause(false);
    }

    private void OnConnectedToServer()
    {
        GD.Print("Connected to the dedicated server; waiting for a player slot.");
        EmitSignal(SignalName.StatusChanged, "Connected; waiting for a player slot…");
        RpcId(1, nameof(RequestPlayerSlots), RequestedLocalPlayers);
    }

    private void OnConnectionFailed()
    {
        EmitSignal(SignalName.StatusChanged, "Could not connect to the server.");
        Disconnect();
    }

    private void OnServerDisconnected()
    {
        EmitSignal(SignalName.StatusChanged, "The server disconnected.");
        Disconnect();
    }

    [Rpc(MultiplayerApi.RpcMode.Authority, TransferMode = MultiplayerPeer.TransferModeEnum.Reliable)]
    private void ReceiveAssignment(int[] slots, bool lobbyOwner)
    {
        LocalPlayerSlots = slots;
        LocalPlayerSlot = slots.Length > 0 ? slots[0] : 0;
        IsLobbyOwner = lobbyOwner;
        EmitSignal(SignalName.PlayerAssignmentChanged, LocalPlayerSlot, lobbyOwner);
        EmitSignal(SignalName.StatusChanged,
            lobbyOwner
                ? $"Seats {string.Join(',', slots)} assigned (lobby owner)."
                : $"Seats {string.Join(',', slots)} assigned.");
    }

    [Rpc(MultiplayerApi.RpcMode.AnyPeer, TransferMode = MultiplayerPeer.TransferModeEnum.Reliable)]
    private void RequestPlayerSlots(int requestedCount)
    {
        if (!Multiplayer.IsServer())
            return;

        var peerId = Multiplayer.GetRemoteSenderId();
        if (_peerSlots.ContainsKey(peerId))
            return;
        requestedCount = Math.Clamp(requestedCount, 1, MaxLocalPlayers);
        if (_freeSlots.Count < requestedCount)
        {
            GD.Print($"Peer {peerId} requested {requestedCount} seats but only {_freeSlots.Count} remain.");
            Multiplayer.MultiplayerPeer.DisconnectPeer((int)peerId);
            return;
        }

        var slots = new List<int>(requestedCount);
        for (var index = 0; index < requestedCount; index++)
        {
            var slot = _freeSlots.Dequeue();
            slots.Add(slot);
            _playerTeams[slot] = slot % 2 == 1 ? "A" : "B";
        }
        _peerSlots[peerId] = slots;
        _occupiedSeatCount += slots.Count;
        if (_lobbyOwnerPeerId == 0)
            _lobbyOwnerPeerId = peerId;
        RpcId(peerId, nameof(ReceiveAssignment), slots.ToArray(), peerId == _lobbyOwnerPeerId);
        BroadcastRoster();
        BroadcastTeams();
        RpcId(peerId, nameof(ReceiveGamePause), IsGamePaused);
        GD.Print($"Peer {peerId} joined with slots {string.Join(',', slots)}.");
    }

    [Rpc(MultiplayerApi.RpcMode.Authority, TransferMode = MultiplayerPeer.TransferModeEnum.Reliable)]
    private void ReceiveRoster(int[] activeSlots)
    {
        ActivePlayerSlots = activeSlots;
        EmitSignal(SignalName.RosterChanged, activeSlots);
    }

    private void BroadcastRoster()
    {
        var activeSlots = new List<int>();
        foreach (var slots in _peerSlots.Values)
            activeSlots.AddRange(slots);
        activeSlots.Sort();
        ActivePlayerSlots = activeSlots.ToArray();
        EmitSignal(SignalName.RosterChanged, ActivePlayerSlots);
        Rpc(nameof(ReceiveRoster), ActivePlayerSlots);
    }

    public string GetPlayerTeam(int slot) =>
        _playerTeams.TryGetValue(slot, out var team) ? team : (slot % 2 == 1 ? "A" : "B");

    public void ChooseTeam(int slot, string team)
    {
        if (Array.IndexOf(LocalPlayerSlots, slot) < 0 || (team != "A" && team != "B"))
            return;
        RpcId(1, nameof(RequestTeam), slot, team);
    }

    [Rpc(MultiplayerApi.RpcMode.AnyPeer, TransferMode = MultiplayerPeer.TransferModeEnum.Reliable)]
    private void RequestTeam(int slot, string team)
    {
        if (!Multiplayer.IsServer() || (team != "A" && team != "B"))
            return;
        var peerId = Multiplayer.GetRemoteSenderId();
        if (!_peerSlots.TryGetValue(peerId, out var ownedSlots) || !ownedSlots.Contains(slot))
            return;
        _playerTeams[slot] = team;
        EmitSignal(SignalName.PlayerTeamChanged, slot, team);
        Rpc(nameof(ReceivePlayerTeam), slot, team);
    }

    [Rpc(MultiplayerApi.RpcMode.Authority, TransferMode = MultiplayerPeer.TransferModeEnum.Reliable)]
    private void ReceivePlayerTeam(int slot, string team)
    {
        _playerTeams[slot] = team;
        EmitSignal(SignalName.PlayerTeamChanged, slot, team);
    }

    private void BroadcastTeams()
    {
        foreach (var pair in _playerTeams)
            Rpc(nameof(ReceivePlayerTeam), pair.Key, pair.Value);
    }

    public void ToggleGamePause()
    {
        if (LocalPlayerSlot != 0)
            RpcId(1, nameof(RequestGamePause), !IsGamePaused);
    }

    [Rpc(MultiplayerApi.RpcMode.AnyPeer, TransferMode = MultiplayerPeer.TransferModeEnum.Reliable)]
    private void RequestGamePause(bool paused)
    {
        if (!Multiplayer.IsServer() || !_peerSlots.ContainsKey(Multiplayer.GetRemoteSenderId()))
            return;
        ApplyGamePause(paused);
        Rpc(nameof(ReceiveGamePause), paused);
    }

    [Rpc(MultiplayerApi.RpcMode.Authority, TransferMode = MultiplayerPeer.TransferModeEnum.Reliable)]
    private void ReceiveGamePause(bool paused) => ApplyGamePause(paused);

    private void ApplyGamePause(bool paused)
    {
        IsGamePaused = paused;
        GetTree().Paused = paused;
        EmitSignal(SignalName.GamePauseChanged, paused);
    }

    public void PublishPlayerState(int slot, Vector3 position, float rotationY, Vector3 velocity)
    {
        if (IsDedicatedServer || Array.IndexOf(LocalPlayerSlots, slot) < 0 || !Multiplayer.HasMultiplayerPeer())
            return;
        RpcId(1, nameof(SubmitPlayerState), slot, position, rotationY, velocity);
    }

    [Rpc(MultiplayerApi.RpcMode.AnyPeer, TransferMode = MultiplayerPeer.TransferModeEnum.Unreliable)]
    private void SubmitPlayerState(int slot, Vector3 position, float rotationY, Vector3 velocity)
    {
        if (!Multiplayer.IsServer())
            return;
        var peerId = Multiplayer.GetRemoteSenderId();
        if (!_peerSlots.TryGetValue(peerId, out var ownedSlots) || !ownedSlots.Contains(slot))
        {
            GD.PushWarning($"Peer {peerId} attempted to update unowned player slot {slot}.");
            return;
        }

        EmitSignal(SignalName.PlayerStateReceived, slot, position, rotationY, velocity);
        Rpc(nameof(ReceivePlayerState), slot, position, rotationY, velocity);
    }

    [Rpc(MultiplayerApi.RpcMode.Authority, TransferMode = MultiplayerPeer.TransferModeEnum.Unreliable)]
    private void ReceivePlayerState(int slot, Vector3 position, float rotationY, Vector3 velocity)
    {
        if (Array.IndexOf(LocalPlayerSlots, slot) < 0)
            EmitSignal(SignalName.PlayerStateReceived, slot, position, rotationY, velocity);
    }

    [Rpc(MultiplayerApi.RpcMode.Authority, TransferMode = MultiplayerPeer.TransferModeEnum.Reliable)]
    private void SetLobbyOwner(bool isOwner)
    {
        IsLobbyOwner = isOwner;
        EmitSignal(SignalName.PlayerAssignmentChanged, LocalPlayerSlot, isOwner);
    }

    private void CreateOnlineMenu()
    {
        _onlineMenu = new OnlineMenu();
        AddChild(_onlineMenu);
    }

    public void ConfigureLocalPlayers(int count)
    {
        RequestedLocalPlayers = Math.Clamp(count, 1, MaxLocalPlayers);
        NormalizeControllerList();
    }

    private static int[] ParseControllers(string value)
    {
        var devices = new List<int>();
        foreach (var part in value.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            if (int.TryParse(part, out var device) && device is >= 0 and < MaxLocalPlayers)
                devices.Add(device);
        return devices.Count == 0 ? [0] : devices.ToArray();
    }

    private void NormalizeControllerList()
    {
        var devices = new int[RequestedLocalPlayers];
        var used = new HashSet<int>();
        var writeIndex = 0;
        foreach (var configured in LocalControllerDevices)
        {
            if (writeIndex >= devices.Length || !used.Add(configured))
                continue;
            devices[writeIndex++] = configured;
        }
        for (var candidate = 0; writeIndex < devices.Length && candidate < MaxLocalPlayers; candidate++)
        {
            if (!used.Add(candidate))
                continue;
            devices[writeIndex++] = candidate;
        }
        LocalControllerDevices = devices;
        LocalControllerDevice = devices[0];
    }

    private void LoadServerName()
    {
        try
        {
            var path = ProjectSettings.GlobalizePath("res://network/server.json");
            using var document = JsonDocument.Parse(System.IO.File.ReadAllText(path));
            if (document.RootElement.TryGetProperty("name", out var name) && !string.IsNullOrWhiteSpace(name.GetString()))
                ServerName = name.GetString()!;
        }
        catch (Exception exception)
        {
            GD.PushWarning($"Could not read network/server.json: {exception.Message}");
        }
    }

    private void StartStatusListener()
    {
        _statusCancellation?.Cancel();
        _statusListener?.Dispose();
        _statusCancellation = new CancellationTokenSource();
        try
        {
            _statusListener = new UdpClient(StatusPort);
            _ = RunStatusListener(_statusCancellation.Token);
            GD.Print($"Server status available on UDP {StatusPort} as '{ServerName}'.");
        }
        catch (Exception exception)
        {
            GD.PushError($"Unable to listen for status probes on UDP {StatusPort}: {exception.Message}");
        }
    }

    private async Task RunStatusListener(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested && _statusListener != null)
        {
            try
            {
                var request = await _statusListener.ReceiveAsync(cancellationToken);
                if (Encoding.UTF8.GetString(request.Buffer) != "GUMBALL_STATUS_V1")
                    continue;
                var response = JsonSerializer.SerializeToUtf8Bytes(new
                {
                    protocol = 1,
                    name = ServerName,
                    gamePort = ServerPort,
                    players = _occupiedSeatCount,
                    capacity = MaxPlayers,
                    free = MaxPlayers - _occupiedSeatCount,
                    paused = IsGamePaused
                });
                await _statusListener.SendAsync(response, request.RemoteEndPoint, cancellationToken);
            }
            catch (OperationCanceledException) { }
            catch (ObjectDisposedException) { }
            catch (Exception exception)
            {
                GD.PrintErr($"Status listener error: {exception.Message}");
            }
        }
    }

    public override void _ExitTree()
    {
        _statusCancellation?.Cancel();
        _statusListener?.Dispose();
    }
}
