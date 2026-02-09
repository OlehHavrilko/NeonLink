using NeonLink.Server.Configuration;
using NeonLink.Server.Models;
using NeonLink.Server.Services;

namespace NeonLink.Tests;

/// <summary>
///     Unit tests for CacheService
/// </summary>
public class CacheServiceTests : IDisposable
{
    private readonly CacheService _cacheService;
    private readonly Settings _settings;

    public CacheServiceTests()
    {
        _settings = new Settings();
        _cacheService = new CacheService(null, _settings);
    }

    public void Dispose()
    {
        _cacheService.Dispose();
        GC.SuppressFinalize(this);
    }

    #region GetCpuName Tests

    [Fact]
    public void GetCpuName_ReturnsCachedValue()
    {
        // Arrange
        var cpuName = "Intel Core i7-12700K";

        // Act
        var result = _cacheService.GetCpuName(cpuName);

        // Assert
        Assert.Equal(cpuName, result);
    }

    [Fact]
    public void GetCpuName_CachesValue()
    {
        // Arrange
        var cpuName = "AMD Ryzen 9 5900X";

        // Act
        _cacheService.GetCpuName(cpuName);
        var cacheSize = _cacheService.CacheSize;

        // Assert
        Assert.Equal(1, cacheSize);
    }

    #endregion

    #region GetGpuName Tests

    [Fact]
    public void GetGpuName_ReturnsCachedValue()
    {
        // Arrange
        var gpuName = "NVIDIA GeForce RTX 3080";

        // Act
        var result = _cacheService.GetGpuName(gpuName);

        // Assert
        Assert.Equal(gpuName, result);
    }

    #endregion

    #region GetRamTotal Tests

    [Fact]
    public void GetRamTotal_ReturnsCachedValue()
    {
        // Arrange
        var ramTotal = 32.0;

        // Act
        var result = _cacheService.GetRamTotal(ramTotal);

        // Assert
        Assert.Equal(ramTotal, result);
    }

    #endregion

    #region GetStorageInfo Tests

    [Fact]
    public void GetStorageInfo_WithFetcher_ReturnsCachedValue()
    {
        // Arrange
        var storageName = "Samsung SSD 970 EVO";
        var storageInfo = new StorageInfo { Name = storageName, Temp = 35.0 };

        // Act
        var result = _cacheService.GetStorageInfo(storageName, () => storageInfo);

        // Assert
        Assert.NotNull(result);
        Assert.Equal(storageName, result?.Name);
    }

    [Fact]
    public void GetStorageInfo_CachesResult()
    {
        // Arrange
        var storageName = "WD Blue SSD";
        var storageInfo = new StorageInfo { Name = storageName, Temp = 40.0 };

        // Act
        _cacheService.GetStorageInfo(storageName, () => storageInfo);
        var cacheSize = _cacheService.CacheSize;

        // Assert
        Assert.Equal(1, cacheSize);
    }

    #endregion

    #region GetCachedHardwareInfo Tests

    [Fact]
    public void GetCachedHardwareInfo_ReturnsEmptyInfo_WhenCacheEmpty()
    {
        // Act
        var result = _cacheService.GetCachedHardwareInfo();

        // Assert
        Assert.NotNull(result);
        Assert.Null(result.CpuName);
        Assert.Null(result.GpuName);
    }

    [Fact]
    public void GetCachedHardwareInfo_ContainsCachedData()
    {
        // Arrange
        _cacheService.GetCpuName("Intel Core i9");
        _cacheService.GetGpuName("RTX 4090");
        _cacheService.GetRamTotal(64.0);

        // Act
        var result = _cacheService.GetCachedHardwareInfo();

        // Assert
        Assert.Equal("Intel Core i9", result.CpuName);
        Assert.Equal("RTX 4090", result.GpuName);
        Assert.Equal(64.0, result.RamTotal);
    }

    #endregion

    #region ShouldRefreshCache Tests

    [Fact]
    public void ShouldRefreshCache_ReturnsTrue_WhenCacheEmpty()
    {
        // Act
        var result = _cacheService.ShouldRefreshCache();

        // Assert
        Assert.True(result);
    }

    #endregion

    #region InvalidateCache Tests

    [Fact]
    public void InvalidateCache_ClearsHardwareCache()
    {
        // Arrange
        _cacheService.GetCpuName("Test CPU");
        _cacheService.GetGpuName("Test GPU");
        Assert.Equal(2, _cacheService.CacheSize);

        // Act
        _cacheService.InvalidateCache();

        // Assert
        Assert.Equal(0, _cacheService.CacheSize);
    }

    #endregion

    #region UpdateHardwareInfo Tests

    [Fact]
    public void UpdateHardwareInfo_AddsToCache()
    {
        // Arrange
        var key = "CustomKey";
        var value = "CustomValue";

        // Act
        _cacheService.UpdateHardwareInfo(key, value);
        var cacheSize = _cacheService.CacheSize;

        // Assert
        Assert.Equal(1, cacheSize);
    }

    #endregion

    #region CacheSize Tests

    [Fact]
    public void CacheSize_ReflectsCachedItems()
    {
        // Arrange & Act
        _cacheService.GetCpuName("CPU1");
        _cacheService.GetGpuName("GPU1");
        _cacheService.GetRamTotal(16.0);

        // Assert
        Assert.Equal(3, _cacheService.CacheSize);
    }

    [Fact]
    public void CacheSize_ReturnsZero_WhenEmpty()
    {
        // Act
        var result = _cacheService.CacheSize;

        // Assert
        Assert.Equal(0, result);
    }

    #endregion

    #region GetStats Tests

    [Fact]
    public void GetStats_ReturnsValidStats()
    {
        // Act
        var stats = _cacheService.GetStats();

        // Assert
        Assert.NotNull(stats);
        Assert.Equal(0, stats.ItemsCount);
        Assert.Equal(60.0, stats.CacheExpirationMinutes); // Default is 60 minutes
    }

    #endregion

    #region Thread Safety Tests

    [Fact]
    public async Task ConcurrentAccess_AllDataReceived()
    {
        // Arrange
        const int threads = 10;
        var tasks = new List<Task>();

        // Act
        for (int i = 0; i < threads; i++)
        {
            var index = i;
            tasks.Add(Task.Run(() =>
            {
                _cacheService.GetCpuName($"CPU {index}");
                _cacheService.GetGpuName($"GPU {index}");
            }));
        }

        // Assert - all should complete without throwing
        await Task.WhenAll(tasks);
        Assert.True(_cacheService.CacheSize > 0);
    }

    #endregion
}
