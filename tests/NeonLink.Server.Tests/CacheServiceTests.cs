using Microsoft.Extensions.Logging;

namespace NeonLink.Server.Tests;

/// <summary>
///     Unit tests for CacheService
/// </summary>
public class CacheServiceTests : IDisposable
{
    private readonly CacheService _cacheService;
    private readonly Mock<ILogger<CacheService>> _loggerMock;
    private readonly Settings _settings;

    public CacheServiceTests()
    {
        _loggerMock = new Mock<ILogger<CacheService>>();
        _settings = new Settings();
        _cacheService = new CacheService(_loggerMock.Object, _settings);
    }

    [Fact]
    public void Constructor_ShouldInitializeCorrectly()
    {
        // Arrange & Act - done in constructor

        // Assert
        _cacheService.CacheSize.Should().Be(0);
    }

    [Fact]
    public void GetCpuName_WhenNotCached_ShouldReturnActualValue()
    {
        // Arrange
        var cpuName = "Intel Core i9-13900K";

        // Act
        var result = _cacheService.GetCpuName(cpuName);

        // Assert
        result.Should().Be(cpuName);
        _cacheService.CacheSize.Should().Be(1);
    }

    [Fact]
    public void GetCpuName_WhenCached_ShouldReturnCachedValue()
    {
        // Arrange
        var cpuName = "Intel Core i9-13900K";
        _cacheService.GetCpuName(cpuName);

        // Act - call with different value
        var result = _cacheService.GetCpuName("AMD Ryzen 9 7950X");

        // Assert - should return cached value
        result.Should().Be(cpuName);
    }

    [Fact]
    public void GetGpuName_WhenNotCached_ShouldReturnActualValue()
    {
        // Arrange
        var gpuName = "NVIDIA RTX 4090";

        // Act
        var result = _cacheService.GetGpuName(gpuName);

        // Assert
        result.Should().Be(gpuName);
    }

    [Fact]
    public void GetRamTotal_WhenNotCached_ShouldReturnActualValue()
    {
        // Arrange
        var ramTotal = 64.0;

        // Act
        var result = _cacheService.GetRamTotal(ramTotal);

        // Assert
        result.Should().Be(ramTotal);
    }

    [Fact]
    public void ShouldRefreshCache_WhenJustInitialized_ShouldReturnTrue()
    {
        // Arrange & Act
        var result = _cacheService.ShouldRefreshCache();

        // Assert
        result.Should().BeTrue();
    }

    [Fact]
    public void InvalidateCache_ShouldClearAllCachedItems()
    {
        // Arrange
        _cacheService.GetCpuName("Test CPU");
        _cacheService.GetGpuName("Test GPU");
        _cacheService.CacheSize.Should().Be(2);

        // Act
        _cacheService.InvalidateCache();

        // Assert
        _cacheService.CacheSize.Should().Be(0);
    }

    [Fact]
    public void UpdateHardwareInfo_ShouldAddOrUpdateCache()
    {
        // Arrange
        var key = "TestKey";
        var value = "TestValue";

        // Act
        _cacheService.UpdateHardwareInfo(key, value);

        // Assert
        _cacheService.CacheSize.Should().Be(1);
    }

    [Fact]
    public void GetStats_ShouldReturnCorrectStatistics()
    {
        // Arrange
        _cacheService.GetCpuName("Test CPU");
        _cacheService.GetGpuName("Test GPU");

        // Act
        var stats = _cacheService.GetStats();

        // Assert
        stats.ItemsCount.Should().Be(2);
        stats.CacheExpirationMinutes.Should().Be(60);
    }

    [Fact]
    public void GetCachedHardwareInfo_ShouldReturnCachedInfo()
    {
        // Arrange
        _cacheService.GetCpuName("Intel Core i9");
        _cacheService.GetGpuName("RTX 4090");
        _cacheService.GetRamTotal(64.0);

        // Act
        var info = _cacheService.GetCachedHardwareInfo();

        // Assert
        info.CpuName.Should().Be("Intel Core i9");
        info.GpuName.Should().Be("RTX 4090");
        info.RamTotal.Should().Be(64.0);
    }

    public void Dispose()
    {
        _cacheService.Dispose();
    }
}
