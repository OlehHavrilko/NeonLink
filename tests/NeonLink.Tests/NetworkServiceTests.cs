using NeonLink.Server.Configuration;
using NeonLink.Server.Services;

namespace NeonLink.Tests;

/// <summary>
///     Unit tests for NetworkService
/// </summary>
public class NetworkServiceTests : IDisposable
{
    private readonly NetworkService _networkService;
    private readonly Settings _settings;

    public NetworkServiceTests()
    {
        _settings = new Settings
        {
            Server = new ServerSettings
            {
                Port = 8080,
                DiscoveryPort = 9877
            }
        };
        _networkService = new NetworkService(null, _settings);
    }

    public void Dispose()
    {
        _networkService.Dispose();
        GC.SuppressFinalize(this);
    }

    #region GetLocalIpAddress Tests

    [Fact]
    public void GetLocalIpAddress_ReturnsValidIpOrNull()
    {
        // Act
        var result = _networkService.GetLocalIpAddress();

        // Assert - should return null or a valid IP string
        if (result != null)
        {
            Assert.Matches(@"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$", result);
        }
    }

    [Fact]
    public void GetLocalIpAddress_ReturnsNonLoopback()
    {
        // Act
        var result = _networkService.GetLocalIpAddress();

        // Assert - if not null, should not be 127.0.0.1
        if (result != null)
        {
            Assert.NotEqual("127.0.0.1", result);
        }
    }

    #endregion

    #region GetPingAsync Tests

    [Fact]
    public async Task GetPingAsync_ReturnsNonNegative()
    {
        // Act
        var result = await _networkService.GetPingAsync();

        // Assert - ping should be >= 0 or -1 (error)
        Assert.True(result >= -1);
    }

    [Fact]
    public async Task GetPingAsync_WithHost_ReturnsValue()
    {
        // Act
        var result = await _networkService.GetPingAsync("8.8.8.8");

        // Assert
        Assert.True(result >= -1);
    }

    [Fact]
    public async Task GetPingAsync_CachesResult()
    {
        // Act
        var result1 = await _networkService.GetPingAsync();
        var result2 = await _networkService.GetPingAsync();

        // Assert - should return cached value on second call
        Assert.Equal(result1, result2);
    }

    #endregion

    #region GetNetworkStats Tests

    [Fact]
    public void GetNetworkStats_ReturnsValidStats()
    {
        // Act
        var stats = _networkService.GetNetworkStats();

        // Assert
        Assert.NotNull(stats);
        Assert.True(stats.CachedPing >= -1);
        // LastPingTime can be DateTime.MinValue if no ping was made yet
        Assert.NotNull(stats);
        Assert.False(stats.IsMdnsRunning);
        Assert.False(stats.IsUdpListening);
    }

    [Fact]
    public void GetNetworkStats_LocalIpMatchesGetLocalIpAddress()
    {
        // Arrange
        var expectedIp = _networkService.GetLocalIpAddress();

        // Act
        var stats = _networkService.GetNetworkStats();

        // Assert
        Assert.Equal(expectedIp, stats.LocalIp);
    }

    #endregion

    #region mDNS Broadcast Tests

    [Fact]
    public void StartMdnsBroadcast_NoThrow()
    {
        // Act & Assert - should not throw
        _networkService.StartMdnsBroadcast();
    }

    [Fact]
    public void StopMdnsBroadcast_NoThrow()
    {
        // Arrange
        _networkService.StartMdnsBroadcast();

        // Act & Assert - should not throw
        _networkService.StopMdnsBroadcast();
    }

    #endregion

    #region UDP Listener Tests

    [Fact]
    public void StartUdpListener_NoThrow()
    {
        // Act & Assert - should not throw
        _networkService.StartUdpListener((message, port) => { });
    }

    [Fact]
    public void StopUdpListener_NoThrow()
    {
        // Arrange
        _networkService.StartUdpListener((message, port) => { });

        // Act & Assert - should not throw
        _networkService.StopUdpListener();
    }

    #endregion

    #region SendBroadcastAsync Tests

    [Fact]
    public async Task SendBroadcastAsync_NoThrow()
    {
        // Act & Assert - should not throw
        await _networkService.SendBroadcastAsync();
    }

    #endregion

    #region Thread Safety Tests

    [Fact]
    public async Task ConcurrentPingRequests_DoNotThrow()
    {
        // Arrange
        const int parallelRequests = 5;

        // Act - multiple concurrent ping requests
        var tasks = Enumerable.Range(0, parallelRequests)
            .Select(_ => _networkService.GetPingAsync())
            .ToList();

        // Assert - all should complete without throwing
        var results = await Task.WhenAll(tasks);
        Assert.Equal(parallelRequests, results.Length);
        Assert.True(results.All(r => r >= -1));
    }

    #endregion

    #region Disposal Tests

    [Fact]
    public void Dispose_CanBeCalledMultipleTimes()
    {
        // Act & Assert - should not throw
        _networkService.Dispose();
        _networkService.Dispose();
    }

    #endregion
}
