using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Text;
using Makaretu.Dns;
using NeonLink.Server.Configuration;

namespace NeonLink.Server.Services;

/// <summary>
///     Сервис для работы с сетью - ping и mDNS broadcast
///     Согласно плану v2.0:
///     - Ping: отдельная реализация через System.Net.NetworkInformation
///     - mDNS: Makaretu.Dns.Multicast
/// </summary>
public class NetworkService : IDisposable
{
    private readonly ILogger<NetworkService>? _logger;
    private readonly Settings _settings;
    
    private ServiceDiscovery? _mdns;
    private TcpListener? _udpListener;
    private CancellationTokenSource? _cts;
    
    private readonly SemaphoreSlim _pingLock = new(1, 1);
    private int _cachedPing = -1;
    private DateTime _lastPingTime;
    private readonly TimeSpan _pingCacheDuration = TimeSpan.FromSeconds(5);

    private bool _disposed;

    public NetworkService(
        ILogger<NetworkService>? logger,
        Settings settings)
    {
        _logger = logger;
        _settings = settings;
        _lastPingTime = DateTime.MinValue;

        _logger?.LogInformation("NetworkService initialized");
    }

    /// <summary>
    ///     Получить ping (кешированный, не чаще 1 раза в 5 секунд)
    /// </summary>
    public async Task<int> GetPingAsync(string host = "8.8.8.8")
    {
        await _pingLock.WaitAsync();
        try
        {
            // Проверка кеша
            if ((DateTime.UtcNow - _lastPingTime).TotalSeconds < _pingCacheDuration.TotalSeconds)
            {
                return _cachedPing;
            }

            _lastPingTime = DateTime.UtcNow;

            try
            {
                using var ping = new Ping();
                var reply = await ping.SendPingAsync(host, timeout: 1000);
                _cachedPing = reply.Status == IPStatus.Success
                    ? (int)reply.RoundtripTime
                    : -1;
            }
            catch
            {
                _cachedPing = -1;
            }

            return _cachedPing;
        }
        finally
        {
            _pingLock.Release();
        }
    }

    /// <summary>
    ///     Получить текущий IP адрес машины
    /// </summary>
    public string? GetLocalIpAddress()
    {
        try
        {
            // Попытка найти IP в локальной сети
            var host = Dns.GetHostEntry(Dns.GetHostName());
            foreach (var ip in host.AddressList)
            {
                if (ip.AddressFamily == AddressFamily.InterNetwork)
                {
                    // Пропускать loopback
                    if (IPAddress.IsLoopback(ip))
                        continue;
                    
                    return ip.ToString();
                }
            }
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Error getting local IP address");
        }

        return null;
    }

    /// <summary>
    ///     Запустить mDNS broadcast
    /// </summary>
    public void StartMdnsBroadcast()
    {
        try
        {
            var port = _settings.Server.Port;
            var localIp = GetLocalIpAddress();

            if (string.IsNullOrEmpty(localIp))
            {
                _logger?.LogWarning("Cannot start mDNS - no local IP found");
                return;
            }

            _mdns = new ServiceDiscovery();
            _mdns.Advertise(new ServiceProfile(
                instanceName: Environment.MachineName,
                serviceName: "_neonlink._tcp",
                port: (ushort)port,
                addresses: new[] { IPAddress.Parse(localIp) }
            ));

            _logger?.LogInformation(
                "mDNS broadcast started: {Name}._neonlink._tcp.local:{Port}",
                Environment.MachineName, port);
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Error starting mDNS broadcast");
        }
    }

    /// <summary>
    ///     Остановить mDNS broadcast
    /// </summary>
    public void StopMdnsBroadcast()
    {
        _mdns?.Dispose();
        _mdns = null;
        _logger?.LogInformation("mDNS broadcast stopped");
    }

    /// <summary>
    ///     Запустить UDP broadcast listener (для Android discovery)
    /// </summary>
    public void StartUdpListener(Action<string, int>? onMessage)
    {
        _cts = new CancellationTokenSource();
        var port = _settings.Server.DiscoveryPort;

        try
        {
            _udpListener = new TcpListener(IPAddress.Any, port);
            _udpListener.Start();
            
            _logger?.LogInformation(
                "UDP listener started on port {Port} for Android discovery",
                port);

            // Асинхронное ожидание подключений
            _ = Task.Run(async () =>
            {
                while (!_cts.Token.IsCancellationRequested)
                {
                    try
                    {
                        var client = await _udpListener.AcceptTcpClientAsync(_cts.Token);
                        var stream = client.GetStream();
                        var buffer = new byte[1024];
                        
                        var bytesRead = await stream.ReadAsync(buffer, 0, buffer.Length, _cts.Token);
                        if (bytesRead > 0)
                        {
                            var message = Encoding.UTF8.GetString(buffer, 0, bytesRead);
                            _logger?.LogDebug("Received UDP message: {Message}", message);
                            
                            onMessage?.Invoke(message, port);
                            
                            // Ответ клиенту
                            var response = $"NEONLINK_ACK:{DateTimeOffset.UtcNow.ToUnixTimeSeconds()}";
                            var responseBytes = Encoding.UTF8.GetBytes(response);
                            await stream.WriteAsync(responseBytes, 0, responseBytes.Length, _cts.Token);
                        }
                        
                        client.Close();
                    }
                    catch (OperationCanceledException)
                    {
                        break;
                    }
                    catch (Exception ex)
                    {
                        _logger?.LogError(ex, "Error in UDP listener");
                    }
                }
            }, _cts.Token);
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Error starting UDP listener");
        }
    }

    /// <summary>
    ///     Остановить UDP listener
    /// </summary>
    public void StopUdpListener()
    {
        _cts?.Cancel();
        _udpListener?.Stop();
        _logger?.LogInformation("UDP listener stopped");
    }

    /// <summary>
    ///     Отправить UDP broadcast с информацией о сервере
    /// </summary>
    public async Task SendBroadcastAsync()
    {
        var port = _settings.Server.DiscoveryPort;
        var localIp = GetLocalIpAddress();

        if (string.IsNullOrEmpty(localIp))
            return;

        try
        {
            using var client = new UdpClient();
            var endpoint = new IPEndPoint(IPAddress.Broadcast, port);
            var message = $"NEONLINK:{localIp}:{_settings.Server.Port}";
            var data = Encoding.UTF8.GetBytes(message);

            await client.SendAsync(data, data.Length, endpoint);
            
            _logger?.LogDebug("UDP broadcast sent: {Message}", message);
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Error sending UDP broadcast");
        }
    }

    /// <summary>
    ///     Получить сетевую статистику
    /// </summary>
    public NetworkStats GetNetworkStats()
    {
        return new NetworkStats
        {
            LocalIp = GetLocalIpAddress(),
            CachedPing = _cachedPing,
            LastPingTime = _lastPingTime,
            IsMdnsRunning = _mdns != null,
            IsUdpListening = _udpListener != null
        };
    }

    public void Dispose()
    {
        if (_disposed)
            return;

        StopMdnsBroadcast();
        StopUdpListener();
        _pingLock.Dispose();
        
        _disposed = true;
        _logger?.LogInformation("NetworkService disposed");
    }
}

/// <summary>
///     Сетевая статистика
/// </summary>
public class NetworkStats
{
    public string? LocalIp { get; set; }
    public int CachedPing { get; set; }
    public DateTime LastPingTime { get; set; }
    public bool IsMdnsRunning { get; set; }
    public bool IsUdpListening { get; set; }
}
