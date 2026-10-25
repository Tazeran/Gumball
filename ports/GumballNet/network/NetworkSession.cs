using Godot;
using System;
using System.Collections.Generic;

namespace GumballNet.Network;

/// <summary>
/// Owns the single online match. The dedicated server is always authoritative;
/// the first connected player is the lobby owner, not the simulation host.
/// </summary>
public partial class NetworkSession : Node
{
    public const int ServerPort = 42837;
    public const int MaxPlayers = 16;
    public const int MaxLocalPlayers = 4;
    public const string ArenaScene = "res://scenes/arena1.tscn";

    [Signal] public delegate void StatusChangedEventHandler(string message);
    [Signal] public delegate void PlayerAssignmentChangedEventHandler(int slot, bool lobbyOwner);
    [Signal] public delegate void RosterChangedEventHandler(int[] activeSlots);

    public bool IsDedicatedServer { get; private set; }
    public int LocalPlayerSlot { get; private set; }
    public int[] LocalPlayerSlots { get; private set; } = Array.Empty<int>();
    public int[] ActivePlayerSlots { get; private set; } = Array.Empty<int>();
    public bool IsLobbyOwner { get; private set; }
    public int LocalControllerDevice { get; private set; }
    public int[] LocalControllerDevices { get; private set; } = [0];
    public int RequestedLocalPlayers { get; private set; } = 1;
    public bool AutoEnterMatch { get; private set; }

    private readonly Dictionary<long, List<int>> _peerSlots = new();
    private readonly Queue<int> _freeSlots = new();
    private long _lobbyOwnerPeerId;
    private OnlineMenu? _onlineMenu;

    public override void _Ready()
    {
        for (var slot = 1; slot <= MaxPlayers; slot++)
            _freeSlots.Enqueue(slot);

        Multiplayer.PeerConnected += OnPeerConnected;
        Multiplayer.PeerDisconnected += OnPeerDisconnected;
        Multiplayer.ConnectedToServer += OnConnectedToServer;
        Multiplayer.ConnectionFailed += OnConnectionFailed;
        Multiplayer.ServerDisconnected += OnServerDisconnected;

        var commandLineArgs = new List<string>(OS.GetCmdlineArgs());
        commandLineArgs.AddRange(OS.GetCmdlineUserArgs());

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
                    CallDeferred(nameof(Connect), arg["--connect=".Length..]);
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
        GD.Print($"GumballNet dedicated server listening on UDP {ServerPort}.");
        EmitSignal(SignalName.StatusChanged, $"Server listening on UDP {ServerPort}");

        return Error.Ok;
    }

    public Error Connect(string address)
    {
        Disconnect();
        address = string.IsNullOrWhiteSpace(address) ? "127.0.0.1" : address.Trim();

        var peer = new ENetMultiplayerPeer();
        var result = peer.CreateClient(address, ServerPort);
        if (result != Error.Ok)
        {
            EmitSignal(SignalName.StatusChanged, $"Connection could not start: {result}");
            return result;
        }

        Multiplayer.MultiplayerPeer = peer;
        GD.Print($"Connecting to {address}:{ServerPort}...");
        EmitSignal(SignalName.StatusChanged, $"Connecting to {address}:{ServerPort}…");
        return Error.Ok;
    }

    public void Disconnect()
    {
        if (Multiplayer.HasMultiplayerPeer())
            Multiplayer.MultiplayerPeer.Close();

        Multiplayer.MultiplayerPeer = new OfflineMultiplayerPeer();
        LocalPlayerSlot = 0;
        LocalPlayerSlots = Array.Empty<int>();
        ActivePlayerSlots = Array.Empty<int>();
        IsLobbyOwner = false;
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
            _freeSlots.Enqueue(slot);
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
            slots.Add(_freeSlots.Dequeue());
        _peerSlots[peerId] = slots;
        if (_lobbyOwnerPeerId == 0)
            _lobbyOwnerPeerId = peerId;
        RpcId(peerId, nameof(ReceiveAssignment), slots.ToArray(), peerId == _lobbyOwnerPeerId);
        BroadcastRoster();
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
        for (var index = 0; index < devices.Length; index++)
            devices[index] = index < LocalControllerDevices.Length ? LocalControllerDevices[index] : index;
        LocalControllerDevices = devices;
        LocalControllerDevice = devices[0];
    }
}
