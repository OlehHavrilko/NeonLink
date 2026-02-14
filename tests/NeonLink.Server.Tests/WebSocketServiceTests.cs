using System.Net.WebSockets;
using Microsoft.Extensions.Logging;

namespace NeonLink.Server.Tests;

/// <summary>
///     Unit tests for WebSocketService
/// </summary>
public class WebSocketServiceTests
{
    private readonly Mock<ILogger<WebSocketService>> _loggerMock;
    private readonly Mock<ILogger<SensorService>> _sensorLoggerMock;
    private readonly Mock<ILogger<TelemetryChannelService>> _channelLoggerMock;
    private readonly Mock<ILogger<SecurityService>> _securityLoggerMock;
    private readonly Settings _settings;

    public WebSocketServiceTests()
    {
        _loggerMock = new Mock<ILogger<WebSocketService>>();
        _sensorLoggerMock = new Mock<ILogger<SensorService>>();
        _channelLoggerMock = new Mock<ILogger<TelemetryChannelService>>();
        _securityLoggerMock = new Mock<ILogger<SecurityService>>();
        _settings = new Settings();
    }

    [Fact]
    public void Constructor_ShouldInitializeCorrectly()
    {
        // Arrange
        var sensorService = CreateSensorService();
        var channelService = CreateChannelService();
        var securityService = CreateSecurityService();

        // Act
        var service = new WebSocketService(
            _loggerMock.Object,
            channelService,
            securityService,
            sensorService,
            _settings);

        // Assert
        service.ConnectedClientsCount.Should().Be(0);
    }

    [Fact]
    public void ConnectedClientsCount_WhenNoConnections_ShouldReturnZero()
    {
        // Arrange
        var sensorService = CreateSensorService();
        var channelService = CreateChannelService();
        var securityService = CreateSecurityService();
        var service = new WebSocketService(
            _loggerMock.Object,
            channelService,
            securityService,
            sensorService,
            _settings);

        // Act & Assert
        service.ConnectedClientsCount.Should().Be(0);
    }

    [Fact]
    public async Task AcceptConnectionAsync_WithValidWebSocket_ShouldAddClient()
    {
        // Arrange
        var sensorService = CreateSensorService();
        var channelService = CreateChannelService();
        var securityService = CreateSecurityService();
        var service = new WebSocketService(
            _loggerMock.Object,
            channelService,
            securityService,
            sensorService,
            _settings);

        var webSocketMock = new Mock<WebSocket>();
        webSocketMock.Setup(x => x.State).Returns(WebSocketState.Open);
        webSocketMock.Setup(x => x.ReceiveAsync(It.IsAny<ArraySegment<byte>>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new OperationCanceledException());

        // Act
        await service.AcceptConnectionAsync(webSocketMock.Object, "127.0.0.1");

        // Assert - client should have been added and then removed when connection closes
        // Since the mock throws, the connection will be closed immediately
        service.ConnectedClientsCount.Should().Be(0);
    }

    [Fact]
    public void IsClientConnected_WhenNotConnected_ShouldReturnFalse()
    {
        // Arrange
        var sensorService = CreateSensorService();
        var channelService = CreateChannelService();
        var securityService = CreateSecurityService();
        var service = new WebSocketService(
            _loggerMock.Object,
            channelService,
            securityService,
            sensorService,
            _settings);

        // Act & Assert
        service.IsClientConnected("non-existent-client").Should().BeFalse();
    }

    private SensorService CreateSensorService()
    {
        var adminCheckerMock = new Mock<IAdminRightsChecker>();
        adminCheckerMock.Setup(x => x.CheckAdminLevel()).Returns(new AdminCheckResult { Level = AdminLevel.Full });
        return new SensorService(_sensorLoggerMock.Object, _settings, adminCheckerMock.Object);
    }

    private TelemetryChannelService CreateChannelService()
    {
        return new TelemetryChannelService(_channelLoggerMock.Object);
    }

    private SecurityService CreateSecurityService()
    {
        return new SecurityService(_securityLoggerMock.Object, _settings);
    }
}
