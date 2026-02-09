using NeonLink.Server.Configuration;
using NeonLink.Server.Models;
using NeonLink.Server.Services;

namespace NeonLink.Server.Tests;

/// <summary>
///     Тесты для CacheService
/// </summary>
public class CacheServiceTests
{
    private readonly Settings _settings;
    private readonly Mock<ILogger<CacheService>> _loggerMock;

    public CacheServiceTests()
    {
        _settings = new Settings();
        _loggerMock = new Mock<ILogger<CacheService>>();
    }

    [Fact]
    public void GetCpuName_ReturnsCachedValue()
    {
        // Arrange
        var service = new CacheService(_loggerMock.Object, _settings);
        var actualName = "Intel Core i7-12700K";
        
        // Act
        var cachedName = service.GetCpuName(actualName);
        
        // Assert
        Assert.Equal(actualName, cachedName);
    }

    [Fact]
    public void GetGpuName_ReturnsCachedValue()
    {
        // Arrange
        var service = new CacheService(_loggerMock.Object, _settings);
        var actualName = "NVIDIA GeForce RTX 3080";
        
        // Act
        var cachedName = service.GetGpuName(actualName);
        
        // Assert
        Assert.Equal(actualName, cachedName);
    }

    [Fact]
    public void GetRamTotal_ReturnsCachedValue()
    {
        // Arrange
        var service = new CacheService(_loggerMock.Object, _settings);
        var actualValue = 32.0;
        
        // Act
        var cachedValue = service.GetRamTotal(actualValue);
        
        // Assert
        Assert.Equal(actualValue, cachedValue);
    }

    [Fact]
    public void GetCachedHardwareInfo_ReturnsAllCachedInfo()
    {
        // Arrange
        var service = new CacheService(_loggerMock.Object, _settings);
        service.GetCpuName("Intel Core i7");
        service.GetGpuName("NVIDIA RTX 3080");
        service.GetRamTotal(32.0);
        
        // Act
        var info = service.GetCachedHardwareInfo();
        
        // Assert
        Assert.Equal("Intel Core i7", info.CpuName);
        Assert.Equal("NVIDIA RTX 3080", info.GpuName);
        Assert.Equal(32.0, info.RamTotal);
    }

    [Fact]
    public void ShouldRefreshCache_InitiallyTrue()
    {
        // Arrange
        var service = new CacheService(_loggerMock.Object, _settings);
        
        // Act
        var result = service.ShouldRefreshCache();
        
        // Assert
        Assert.True(result); // Кеш пуст, нужно обновить
    }

    [Fact]
    public void InvalidateCache_ClearsAllData()
    {
        // Arrange
        var service = new CacheService(_loggerMock.Object, _settings);
        service.GetCpuName("Intel Core i7");
        service.GetGpuName("NVIDIA RTX 3080");
        
        // Act
        service.InvalidateCache();
        var info = service.GetCachedHardwareInfo();
        
        // Assert
        Assert.Null(info.CpuName);
        Assert.Null(info.GpuName);
    }

    [Fact]
    public void CacheSize_IncreasesWithCachedItems()
    {
        // Arrange
        var service = new CacheService(_loggerMock.Object, _settings);
        
        // Act
        service.GetCpuName("Intel");
        service.GetGpuName("NVIDIA");
        service.GetRamTotal(32.0);
        
        // Assert
        Assert.Equal(3, service.CacheSize);
    }

    [Fact]
    public void GetStats_ReturnsCorrectStats()
    {
        // Arrange
        var service = new CacheService(_loggerMock.Object, _settings);
        service.GetCpuName("Intel");
        
        // Act
        var stats = service.GetStats();
        
        // Assert
        Assert.Equal(1, stats.ItemsCount);
        Assert.True(stats.CacheExpirationMinutes > 0);
    }

    [Fact]
    public void UpdateHardwareInfo_UpdatesExistingEntry()
    {
        // Arrange
        var service = new CacheService(_loggerMock.Object, _settings);
        service.GetCpuName("Intel Core i7");
        
        // Act
        service.UpdateHardwareInfo("CpuName", "Intel Core i9");
        var info = service.GetCachedHardwareInfo();
        
        // Assert
        Assert.Equal("Intel Core i9", info.CpuName);
    }

    [Fact]
    public void Dispose_CanBeCalledMultipleTimes()
    {
        // Arrange
        var service = new CacheService(_loggerMock.Object, _settings);
        
        // Act & Assert - не должно вызвать исключение
        service.Dispose();
        service.Dispose();
    }
}
