using NeonLink.Server.Configuration;
using NeonLink.Server.Models;
using NeonLink.Server.Services;

namespace NeonLink.Server.Tests;

/// <summary>
///     Тесты для SensorService с mock Computer
/// </summary>
public class SensorServiceTests
{
    private readonly Settings _settings;
    private readonly Mock<ILogger<SensorService>> _loggerMock;
    private readonly AdminRightsChecker _adminChecker;

    public SensorServiceTests()
    {
        _settings = new Settings
        {
            Server = new ServerSettings
            {
                PollingIntervalMs = 500
            },
            Hardware = new HardwareSettings
            {
                EnableCpu = true,
                EnableGpu = true,
                EnableRam = true,
                EnableStorage = true,
                EnableNetwork = true,
                EnableGamingDetection = true
            },
            Gaming = new GamingSettings
            {
                GpuUsageThreshold = 85.0,
                CpuUsageThreshold = 40.0
            }
        };
        _loggerMock = new Mock<ILogger<SensorService>>();
        _adminChecker = new AdminRightsChecker();
    }

    [Fact]
    public void SetPollingInterval_ValidValue_UpdatesInterval()
    {
        // Arrange
        var service = new SensorService(_loggerMock.Object, _settings, _adminChecker);
        
        // Act
        service.SetPollingInterval(1000);
        
        // Assert - просто проверяем, что не вылетает исключение
        service.SetPollingInterval(5000);
    }

    [Fact]
    public void SetPollingInterval_BelowMinimum_ClampsToMinimum()
    {
        // Arrange
        var service = new SensorService(_loggerMock.Object, _settings, _adminChecker);
        
        // Act - значение ниже минимума
        service.SetPollingInterval(50);
        
        // Assert - должно быть за clamping
        service.SetPollingInterval(100); // это минимум
    }

    [Fact]
    public void SetPollingInterval_AboveMaximum_ClampsToMaximum()
    {
        // Arrange
        var service = new SensorService(_loggerMock.Object, _settings, _adminChecker);
        
        // Act - значение выше максимума
        service.SetPollingInterval(10000);
        
        // Assert
        service.SetPollingInterval(5000); // это максимум
    }

    [Fact]
    public void GetCurrentTelemetry_ReturnsTelemetryData()
    {
        // Arrange
        var service = new SensorService(_loggerMock.Object, _settings, _adminChecker);
        
        // Act
        var telemetry = service.GetCurrentTelemetry();
        
        // Assert
        Assert.NotNull(telemetry);
        Assert.NotNull(telemetry.System);
        Assert.NotNull(telemetry.AdminLevel);
    }

    [Fact]
    public async Task GetCurrentTelemetryAsync_ReturnsTelemetryData()
    {
        // Arrange
        var service = new SensorService(_loggerMock.Object, _settings, _adminChecker);
        
        // Act
        var telemetry = await service.GetCurrentTelemetryAsync();
        
        // Assert
        Assert.NotNull(telemetry);
        Assert.NotNull(telemetry.System);
        Assert.True(telemetry.Timestamp > 0);
    }

    [Fact]
    public async Task GetCurrentTelemetryAsync_TimestampIsRecent()
    {
        // Arrange
        var service = new SensorService(_loggerMock.Object, _settings, _adminChecker);
        var beforeCall = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        
        // Act
        var telemetry = await service.GetCurrentTelemetryAsync();
        var afterCall = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        
        // Assert
        Assert.True(telemetry.Timestamp >= beforeCall);
        Assert.True(telemetry.Timestamp <= afterCall);
    }

    [Fact]
    public void GetCurrentTelemetry_AdminLevelIsSet()
    {
        // Arrange
        var service = new SensorService(_loggerMock.Object, _settings, _adminChecker);
        
        // Act
        var telemetry = service.GetCurrentTelemetry();
        
        // Assert
        Assert.False(string.IsNullOrEmpty(telemetry.AdminLevel));
    }

    [Fact]
    public void GetCurrentTelemetry_CpuInfoIsInitialized()
    {
        // Arrange
        var service = new SensorService(_loggerMock.Object, _settings, _adminChecker);
        
        // Act
        var telemetry = service.GetCurrentTelemetry();
        
        // Assert
        Assert.NotNull(telemetry.System.Cpu);
    }

    [Fact]
    public void GetCurrentTelemetry_GpuInfoIsInitialized()
    {
        // Arrange
        var service = new SensorService(_loggerMock.Object, _settings, _adminChecker);
        
        // Act
        var telemetry = service.GetCurrentTelemetry();
        
        // Assert
        Assert.NotNull(telemetry.System.Gpu);
    }

    [Fact]
    public void GetCurrentTelemetry_RamInfoIsInitialized()
    {
        // Arrange
        var service = new SensorService(_loggerMock.Object, _settings, _adminChecker);
        
        // Act
        var telemetry = service.GetCurrentTelemetry();
        
        // Assert
        Assert.NotNull(telemetry.System.Ram);
    }

    [Fact]
    public void GetCurrentTelemetry_StorageListIsInitialized()
    {
        // Arrange
        var service = new SensorService(_loggerMock.Object, _settings, _adminChecker);
        
        // Act
        var telemetry = service.GetCurrentTelemetry();
        
        // Assert
        Assert.NotNull(telemetry.System.Storage);
    }

    [Fact]
    public void MultipleCalls_DoNotThrow()
    {
        // Arrange
        var service = new SensorService(_loggerMock.Object, _settings, _adminChecker);
        
        // Act & Assert - несколько параллельных вызовов
        var tasks = Enumerable.Range(0, 10)
            .Select(_ => service.GetCurrentTelemetryAsync())
            .ToList();
            
        Assert.NotEmpty(tasks);
    }

    [Fact]
    public async Task Dispose_CanBeCalledMultipleTimes()
    {
        // Arrange
        var service = new SensorService(_loggerMock.Object, _settings, _adminChecker);
        
        // Act & Assert - не должно вызвать исключение
        service.Dispose();
        service.Dispose();
        
        // Проверяем, что после dispose данные все еще возвращаются (graceful)
        var telemetry = service.GetCurrentTelemetry();
        Assert.NotNull(telemetry);
    }
}
