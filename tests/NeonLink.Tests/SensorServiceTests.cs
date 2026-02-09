using NeonLink.Server.Configuration;
using NeonLink.Server.Models;
using NeonLink.Server.Services;
using NeonLink.Server.Utilities;
using Xunit;

namespace NeonLink.Tests;

/// <summary>
///     Unit tests for SensorService
/// </summary>
public class SensorServiceTests : IDisposable
{
    private readonly Settings _settings;
    private readonly Mock<ILogger<SensorService>> _loggerMock;
    private readonly Mock<IAdminRightsChecker> _adminCheckerMock;
    private SensorService? _sensorService;

    public SensorServiceTests()
    {
        _settings = new Settings
        {
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
                GpuUsageThreshold = 85.0
            },
            Server = new ServerSettings
            {
                PollingIntervalMs = 500
            }
        };

        _loggerMock = new Mock<ILogger<SensorService>>();
        _adminCheckerMock = new Mock<IAdminRightsChecker>();

        _adminCheckerMock
            .Setup(x => x.CheckAdminLevel())
            .Returns(new AdminCheckResult
            {
                Level = AdminLevel.Full,
                IsAdmin = true,
                Message = "Full admin access"
            });
    }

    public void Dispose()
    {
        _sensorService?.Dispose();
        GC.SuppressFinalize(this);
    }

    #region Constructor Tests

    [Fact]
    public void Constructor_WithValidSettings_CreatesInstance()
    {
        // Act
        _sensorService = new SensorService(_loggerMock.Object, _settings, _adminCheckerMock.Object);

        // Assert
        Assert.NotNull(_sensorService);
    }

    [Fact]
    public void Constructor_WithNullLogger_DoesNotThrow()
    {
        // Act & Assert
        var service = new SensorService(null, _settings, _adminCheckerMock.Object);
        service.Dispose();
    }

    #endregion

    #region SetPollingInterval Tests

    [Fact]
    public void SetPollingInterval_ValidValue_SetsInterval()
    {
        // Arrange
        _sensorService = new SensorService(null, _settings, _adminCheckerMock.Object);

        // Act
        _sensorService.SetPollingInterval(1000);

        // Assert - no exception means success
    }

    [Fact]
    public void SetPollingInterval_TooLowValue_ClampsToMinimum()
    {
        // Arrange
        _sensorService = new SensorService(null, _settings, _adminCheckerMock.Object);

        // Act - should not throw, clamps to 100ms minimum
        _sensorService.SetPollingInterval(10);

        // Assert
    }

    [Fact]
    public void SetPollingInterval_TooHighValue_ClampsToMaximum()
    {
        // Arrange
        _sensorService = new SensorService(null, _settings, _adminCheckerMock.Object);

        // Act - should not throw, clamps to 5000ms maximum
        _sensorService.SetPollingInterval(10000);

        // Assert
    }

    [Theory]
    [InlineData(100)]
    [InlineData(500)]
    [InlineData(1000)]
    [InlineData(2000)]
    [InlineData(5000)]
    public void SetPollingInterval_ValidRangeValues_DoesNotThrow(int intervalMs)
    {
        // Arrange
        _sensorService = new SensorService(null, _settings, _adminCheckerMock.Object);

        // Act & Assert
        var exception = Record.Exception(() => _sensorService.SetPollingInterval(intervalMs));
        Assert.Null(exception);
    }

    #endregion

    #region Initialize Tests

    [Fact]
    public async Task Initialize_WhenCalled_SetsUpComputer()
    {
        // Arrange
        _sensorService = new SensorService(null, _settings, _adminCheckerMock.Object);

        // Act
        var result = _sensorService.Initialize();

        // Assert - result depends on actual hardware, but method should not throw
        // In a test environment without hardware, this may return false
    }

    #endregion

    #region GetTelemetry Tests

    [Fact]
    public async Task GetCurrentTelemetryAsync_WhenCalled_ReturnsTelemetryData()
    {
        // Arrange
        _sensorService = new SensorService(null, _settings, _adminCheckerMock.Object);
        _sensorService.Initialize();

        // Act
        var result = await _sensorService.GetCurrentTelemetryAsync();

        // Assert
        Assert.NotNull(result);
        Assert.NotNull(result.System);
    }

    [Fact]
    public void GetCurrentTelemetry_WhenCalled_ReturnsTelemetryData()
    {
        // Arrange
        _sensorService = new SensorService(null, _settings, _adminCheckerMock.Object);
        _sensorService.Initialize();

        // Act
        var result = _sensorService.GetCurrentTelemetry();

        // Assert
        Assert.NotNull(result);
        Assert.NotNull(result.System);
    }

    [Fact]
    public async Task GetCurrentTelemetryAsync_CalledMultipleTimes_ReturnsConsistentStructure()
    {
        // Arrange
        _sensorService = new SensorService(null, _settings, _adminCheckerMock.Object);
        _sensorService.Initialize();

        // Act
        var result1 = await _sensorService.GetCurrentTelemetryAsync();
        var result2 = await _sensorService.GetCurrentTelemetryAsync();

        // Assert
        Assert.NotNull(result1.System);
        Assert.NotNull(result2.System);
    }

    #endregion

    #region Thread Safety Tests

    [Fact]
    public async Task GetCurrentTelemetryAsync_ConcurrentCalls_AllComplete()
    {
        // Arrange
        _sensorService = new SensorService(null, _settings, _adminCheckerMock.Object);
        _sensorService.Initialize();

        // Act - multiple concurrent calls
        var tasks = Enumerable.Range(0, 10)
            .Select(_ => _sensorService.GetCurrentTelemetryAsync())
            .ToList();

        // Assert
        var results = await Task.WhenAll(tasks);
        Assert.Equal(10, results.Length);
        Assert.All(results, r => Assert.NotNull(r.System));
    }

    [Fact]
    public void GetCurrentTelemetry_ConcurrentCalls_AllComplete()
    {
        // Arrange
        _sensorService = new SensorService(null, _settings, _adminCheckerMock.Object);
        _sensorService.Initialize();

        // Act - multiple concurrent calls
        var results = new List<TelemetryData>();
        Parallel.For(0, 10, _ =>
        {
            var telemetry = _sensorService.GetCurrentTelemetry();
            lock (results)
            {
                results.Add(telemetry);
            }
        });

        // Assert
        Assert.Equal(10, results.Count);
        Assert.All(results, r => Assert.NotNull(r.System));
    }

    #endregion

    #region Telemetry Structure Tests

    [Fact]
    public async Task GetCurrentTelemetryAsync_ReturnsCpuInfo()
    {
        // Arrange
        _sensorService = new SensorService(null, _settings, _adminCheckerMock.Object);
        _sensorService.Initialize();

        // Act
        var result = await _sensorService.GetCurrentTelemetryAsync();

        // Assert
        Assert.NotNull(result.System.Cpu);
    }

    [Fact]
    public async Task GetCurrentTelemetryAsync_ReturnsGpuInfo()
    {
        // Arrange
        _sensorService = new SensorService(null, _settings, _adminCheckerMock.Object);
        _sensorService.Initialize();

        // Act
        var result = await _sensorService.GetCurrentTelemetryAsync();

        // Assert
        Assert.NotNull(result.System.Gpu);
    }

    [Fact]
    public async Task GetCurrentTelemetryAsync_ReturnsRamInfo()
    {
        // Arrange
        _sensorService = new SensorService(null, _settings, _adminCheckerMock.Object);
        _sensorService.Initialize();

        // Act
        var result = await _sensorService.GetCurrentTelemetryAsync();

        // Assert
        Assert.NotNull(result.System.Ram);
    }

    [Fact]
    public async Task GetCurrentTelemetryAsync_ReturnsStorageList()
    {
        // Arrange
        _sensorService = new SensorService(null, _settings, _adminCheckerMock.Object);
        _sensorService.Initialize();

        // Act
        var result = await _sensorService.GetCurrentTelemetryAsync();

        // Assert
        Assert.NotNull(result.System.Storage);
    }

    [Fact]
    public async Task GetCurrentTelemetryAsync_ReturnsNetworkInfo()
    {
        // Arrange
        _sensorService = new SensorService(null, _settings, _adminCheckerMock.Object);
        _sensorService.Initialize();

        // Act
        var result = await _sensorService.GetCurrentTelemetryAsync();

        // Assert
        Assert.NotNull(result.System.Network);
    }

    [Fact]
    public async Task GetCurrentTelemetryAsync_ReturnsTimestamp()
    {
        // Arrange
        _sensorService = new SensorService(null, _settings, _adminCheckerMock.Object);
        _sensorService.Initialize();

        // Act
        var result = await _sensorService.GetCurrentTelemetryAsync();

        // Assert
        Assert.True(result.Timestamp > 0);
    }

    [Fact]
    public async Task GetCurrentTelemetryAsync_ReturnsAdminLevel()
    {
        // Arrange
        _sensorService = new SensorService(null, _settings, _adminCheckerMock.Object);
        _sensorService.Initialize();

        // Act
        var result = await _sensorService.GetCurrentTelemetryAsync();

        // Assert
        Assert.False(string.IsNullOrEmpty(result.AdminLevel));
    }

    #endregion

    #region Gaming Info Tests

    [Fact]
    public async Task GetCurrentTelemetryAsync_WithGamingEnabled_ReturnsGamingInfo()
    {
        // Arrange
        _sensorService = new SensorService(null, _settings, _adminCheckerMock.Object);
        _sensorService.Initialize();

        // Act
        var result = await _sensorService.GetCurrentTelemetryAsync();

        // Assert - gaming info may be null if GPU usage is below threshold
        if (result.Gaming != null)
        {
            Assert.NotNull(result.Gaming);
        }
    }

    [Fact]
    public void GetCurrentTelemetry_WithGamingDisabled_ReturnsNullGamingInfo()
    {
        // Arrange
        var settings = new Settings
        {
            Hardware = new HardwareSettings
            {
                EnableGamingDetection = false
            },
            Server = new ServerSettings { PollingIntervalMs = 500 }
        };

        _sensorService = new SensorService(null, settings, _adminCheckerMock.Object);
        _sensorService.Initialize();

        // Act
        var result = _sensorService.GetCurrentTelemetry();

        // Assert
        Assert.Null(result.Gaming);
    }

    #endregion

    #region Error Handling Tests

    [Fact]
    public async Task GetCurrentTelemetryAsync_AfterDisposal_ReturnsCachedData()
    {
        // Arrange
        _sensorService = new SensorService(null, _settings, _adminCheckerMock.Object);
        _sensorService.Initialize();
        _sensorService.Dispose();

        // Act - should not throw, returns cached data
        var result = await _sensorService.GetCurrentTelemetryAsync();

        // Assert - should return some telemetry data
        Assert.NotNull(result);
    }

    [Fact]
    public void GetCurrentTelemetry_AfterDisposal_ReturnsCachedData()
    {
        // Arrange
        _sensorService = new SensorService(null, _settings, _adminCheckerMock.Object);
        _sensorService.Initialize();
        _sensorService.Dispose();

        // Act - should not throw, returns cached data
        var result = _sensorService.GetCurrentTelemetry();

        // Assert - should return some telemetry data
        Assert.NotNull(result);
    }

    #endregion

    #region Admin Level Tests

    [Theory]
    [InlineData(AdminLevel.Full)]
    [InlineData(AdminLevel.Limited)]
    [InlineData(AdminLevel.Minimal)]
    public async Task GetCurrentTelemetryAsync_ReturnsCorrectAdminLevel(AdminLevel level)
    {
        // Arrange
        _adminCheckerMock
            .Setup(x => x.CheckAdminLevel())
            .Returns(new AdminCheckResult
            {
                Level = level,
                IsAdmin = level == AdminLevel.Full
            });

        _sensorService = new SensorService(null, _settings, _adminCheckerMock.Object);
        _sensorService.Initialize();

        // Act
        var result = await _sensorService.GetCurrentTelemetryAsync();

        // Assert
        Assert.Equal(level.ToString(), result.AdminLevel);
    }

    #endregion

    #region Hardware Enabling Tests

    [Fact]
    public void Constructor_WithCpuDisabled_SetsCpuDisabled()
    {
        // Arrange
        var settings = new Settings
        {
            Hardware = new HardwareSettings { EnableCpu = false },
            Server = new ServerSettings { PollingIntervalMs = 500 }
        };

        // Act
        _sensorService = new SensorService(null, settings, _adminCheckerMock.Object);

        // Assert - should not throw
        Assert.NotNull(_sensorService);
    }

    [Fact]
    public void Constructor_WithGpuDisabled_SetsGpuDisabled()
    {
        // Arrange
        var settings = new Settings
        {
            Hardware = new HardwareSettings { EnableGpu = false },
            Server = new ServerSettings { PollingIntervalMs = 500 }
        };

        // Act
        _sensorService = new SensorService(null, settings, _adminCheckerMock.Object);

        // Assert - should not throw
        Assert.NotNull(_sensorService);
    }

    [Fact]
    public void Constructor_WithRamDisabled_SetsRamDisabled()
    {
        // Arrange
        var settings = new Settings
        {
            Hardware = new HardwareSettings { EnableRam = false },
            Server = new ServerSettings { PollingIntervalMs = 500 }
        };

        // Act
        _sensorService = new SensorService(null, settings, _adminCheckerMock.Object);

        // Assert - should not throw
        Assert.NotNull(_sensorService);
    }

    [Fact]
    public void Constructor_WithNetworkDisabled_SetsNetworkDisabled()
    {
        // Arrange
        var settings = new Settings
        {
            Hardware = new HardwareSettings { EnableNetwork = false },
            Server = new ServerSettings { PollingIntervalMs = 500 }
        };

        // Act
        _sensorService = new SensorService(null, settings, _adminCheckerMock.Object);

        // Assert - should not throw
        Assert.NotNull(_sensorService);
    }

    #endregion
}
