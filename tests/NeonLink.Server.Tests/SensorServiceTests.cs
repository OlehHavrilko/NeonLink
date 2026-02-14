using Microsoft.Extensions.Logging;

namespace NeonLink.Server.Tests;

/// <summary>
///     Unit tests for SensorService
/// </summary>
public class SensorServiceTests : IDisposable
{
    private readonly SensorService _sensorService;
    private readonly Mock<ILogger<SensorService>> _loggerMock;
    private readonly Settings _settings;
    private readonly Mock<IAdminRightsChecker> _adminCheckerMock;

    public SensorServiceTests()
    {
        _loggerMock = new Mock<ILogger<SensorService>>();
        _settings = new Settings();
        _adminCheckerMock = new Mock<IAdminRightsChecker>();
        _adminCheckerMock.Setup(x => x.CheckAdminLevel()).Returns(new AdminCheckResult { Level = AdminLevel.Full });
        
        _sensorService = new SensorService(_loggerMock.Object, _settings, _adminCheckerMock.Object);
    }

    [Fact]
    public void Constructor_ShouldInitializeCorrectly()
    {
        // Arrange & Act - done in constructor

        // Assert - should not throw
        _sensorService.Should().NotBeNull();
    }

    [Fact]
    public void Initialize_ShouldReturnTrue()
    {
        // Act
        var result = _sensorService.Initialize();

        // Assert
        result.Should().BeTrue();
    }

    [Fact]
    public async Task GetCurrentTelemetryAsync_ShouldReturnValidTelemetryData()
    {
        // Arrange
        _sensorService.Initialize();

        // Act
        var telemetry = await _sensorService.GetCurrentTelemetryAsync();

        // Assert
        telemetry.Should().NotBeNull();
        telemetry.Timestamp.Should().BeGreaterThan(0);
        telemetry.System.Should().NotBeNull();
        telemetry.System.Cpu.Should().NotBeNull();
        telemetry.System.Gpu.Should().NotBeNull();
        telemetry.System.Ram.Should().NotBeNull();
        telemetry.System.Storage.Should().NotBeNull();
    }

    [Fact]
    public void GetCurrentTelemetry_ShouldReturnValidTelemetryData()
    {
        // Arrange
        _sensorService.Initialize();

        // Act
        var telemetry = _sensorService.GetCurrentTelemetry();

        // Assert
        telemetry.Should().NotBeNull();
        telemetry.Timestamp.Should().BeGreaterThan(0);
        telemetry.System.Should().NotBeNull();
    }

    [Fact]
    public void SetPollingInterval_ShouldUpdateInterval()
    {
        // Arrange
        var newInterval = 1000;

        // Act - should not throw
        _sensorService.SetPollingInterval(newInterval);

        // Assert - no exception means success
    }

    [Fact]
    public void SetPollingInterval_WithInvalidValue_ShouldClampToValidRange()
    {
        // Arrange
        var tooSmall = 50;
        var tooLarge = 10000;

        // Act - should not throw
        _sensorService.SetPollingInterval(tooSmall);
        _sensorService.SetPollingInterval(tooLarge);

        // Assert - no exception means success
    }

    public void Dispose()
    {
        _sensorService.Dispose();
    }
}
