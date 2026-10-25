using Godot;
using System;
using System.Collections.Generic;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace GumballNet.Network;

public sealed class ServerEndpoint
{
    public string Address { get; set; } = "127.0.0.1";
    public int StatusPort { get; set; } = NetworkSession.StatusPort;
}

public sealed class ServerDirectory
{
    public List<ServerEndpoint> Servers { get; set; } = [];
}

public sealed class ServerStatus
{
    public string Address { get; set; } = "";
    public string Name { get; set; } = "Gumball Server";
    public int GamePort { get; set; } = NetworkSession.ServerPort;
    public int Players { get; set; }
    public int Capacity { get; set; } = NetworkSession.MaxPlayers;
    public int Free { get; set; }
    public bool Paused { get; set; }
}

public static class ServerDiscovery
{
    public static List<ServerEndpoint> LoadDirectory()
    {
        try
        {
            var path = ProjectSettings.GlobalizePath("res://network/servers.json");
            return JsonSerializer.Deserialize<ServerDirectory>(System.IO.File.ReadAllText(path),
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true })?.Servers ?? [];
        }
        catch (Exception exception)
        {
            GD.PushWarning($"Could not read network/servers.json: {exception.Message}");
            return [];
        }
    }

    public static async Task<ServerStatus?> ProbeAsync(ServerEndpoint endpoint, int timeoutMilliseconds = 900)
    {
        try
        {
            using var client = new UdpClient();
            using var cancellation = new CancellationTokenSource(timeoutMilliseconds);
            await client.SendAsync(Encoding.UTF8.GetBytes("GUMBALL_STATUS_V1"), endpoint.Address, endpoint.StatusPort, cancellation.Token);
            var response = await client.ReceiveAsync(cancellation.Token);
            var status = JsonSerializer.Deserialize<ServerStatus>(response.Buffer,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
            if (status == null)
                return null;
            status.Address = endpoint.Address;
            return status;
        }
        catch
        {
            return null;
        }
    }
}
