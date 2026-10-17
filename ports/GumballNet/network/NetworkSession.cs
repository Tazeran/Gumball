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
    public const int MaxPlayers = 4;
    public const string ArenaScene = "res://scenes/arena1.tscn";

    [Signal] public delegate void StatusChangedEventHandler(string message);
    [Signal] public delegate void PlayerAssignmentChangedEventHandler(int slot, bool lobbyOwner);

    public bool IsDedicatedServer { get; private set; }
    public int LocalPlayerSlot { get; private set; }
    public bool IsLobbyOwner { get; private set; }

    private readonly Dictionary<long, int> _peerSlots = new();
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

        IsDedicatedServer = commandLineArgs.Contains("--server")
            || OS.HasFeature("dedicated_server");
        if (IsDedicatedServer)
            StartDedicatedServer();
        else
        {
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

        var networkSmokeTest = Array.Exists(OS.GetCmdlineUserArgs(), arg => arg == "--network-smoke-test");
        if (!networkSmokeTest && GetTree().CurrentScene?.SceneFilePath != ArenaScene)
            GetTree().ChangeSceneToFile(ArenaScene);

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
        IsLobbyOwner = false;
    }

    private void OnPeerConnected(long peerId)
    {
        if (!Multiplayer.IsServer())
            return;

        if (_freeSlots.Count == 0)
        {
            Multiplayer.MultiplayerPeer.DisconnectPeer((int)peerId);
            return;
        }

        var slot = _freeSlots.Dequeue();
        _peerSlots[peerId] = slot;
        if (_lobbyOwnerPeerId == 0)
            _lobbyOwnerPeerId = peerId;

        RpcId(peerId, nameof(ReceiveAssignment), slot, peerId == _lobbyOwnerPeerId);
        GD.Print($"Peer {peerId} joined the single match in slot {slot}.");
    }

    private void OnPeerDisconnected(long peerId)
    {
        if (!Multiplayer.IsServer() || !_peerSlots.Remove(peerId, out var slot))
            return;

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

        GD.Print($"Peer {peerId} left; slot {slot} is available.");
    }

    private void OnConnectedToServer()
    {
        GD.Print("Connected to the dedicated server; waiting for a player slot.");
        EmitSignal(SignalName.StatusChanged, "Connected; waiting for a player slot…");
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
    private void ReceiveAssignment(int slot, bool lobbyOwner)
    {
        LocalPlayerSlot = slot;
        IsLobbyOwner = lobbyOwner;
        EmitSignal(SignalName.PlayerAssignmentChanged, slot, lobbyOwner);
        EmitSignal(SignalName.StatusChanged,
            lobbyOwner ? $"Connected as player {slot} (lobby owner)." : $"Connected as player {slot}.");
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
}
