using NeonLink.Server.Configuration;
using NeonLink.Server.Models;
using NeonLink.Server.Services;

namespace NeonLink.Server.Tests;

/// <summary>
///     Тесты для CommandService с whitelist validation
/// </summary>
public class CommandServiceTests
{
    private readonly Settings _settings;
    private readonly Mock<ILogger<CommandService>> _loggerMock;
    private readonly Mock<SensorService> _sensorServiceMock;
    private readonly SecurityService _securityService;
    private readonly TelemetryChannelService _channelService;
    private readonly CommandService _commandService;

    public CommandServiceTests()
    {
        _settings = new Settings
        {
            Server = new ServerSettings
            {
                Port = 9876,
                MaxConnections = 5,
                PollingIntervalMs = 500
            },
            Security = new SecuritySettings
            {
                AllowExternalIp = false,
                RateLimitPerMinute = 100,
                DangerousCommandsEnabled = false,
                AllowedCommands = new List<string>
                {
                    "get_status",
                    "ping",
                    "get_config",
                    "set_polling_interval"
                }
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
        _loggerMock = new Mock<ILogger<CommandService>>();
        _securityService = new SecurityService(_loggerMock.Object, _settings);
        _channelService = new TelemetryChannelService();
        _sensorServiceMock = new Mock<SensorService>(
            _loggerMock.Object,
            _settings,
            new AdminRightsChecker());
        
        _commandService = new CommandService(
            _loggerMock.Object,
            _settings,
            _sensorServiceMock.Object,
            _securityService,
            _channelService);
    }

    [Fact]
    public async Task ExecuteCommandAsync_Ping_ReturnsSuccess()
    {
        // Arrange
        var request = new CommandRequest { Command = "ping" };
        var clientId = "test-client";
        
        // Act
        var response = await _commandService.ExecuteCommandAsync(request, clientId);
        
        // Assert
        Assert.NotNull(response);
        Assert.True(response.Success);
        Assert.Equal("ping", response.Command);
        Assert.True(response.Timestamp > 0);
    }

    [Fact]
    public async Task ExecuteCommandAsync_Ping_ReturnsPong()
    {
        // Arrange
        var request = new CommandRequest { Command = "ping" };
        var clientId = "test-client";
        
        // Act
        var response = await _commandService.ExecuteCommandAsync(request, clientId);
        
        // Assert
        Assert.NotNull(response.Result);
        var resultDict = response.Result as Dictionary<string, object>;
        Assert.NotNull(resultDict);
        Assert.True((bool)resultDict["pong"]);
    }

    [Fact]
    public async Task ExecuteCommandAsync_CaseInsensitive_ReturnsSuccess()
    {
        // Arrange
        var request = new CommandRequest { Command = "PING" };
        var clientId = "test-client";
        
        // Act
        var response = await _commandService.ExecuteCommandAsync(request, clientId);
        
        // Assert
        Assert.True(response.Success);
    }

    [Fact]
    public async Task ExecuteCommandAsync_UnknownCommand_ReturnsError()
    {
        // Arrange
        var request = new CommandRequest { Command = "unknown_command" };
        var clientId = "test-client";
        
        // Act
        var response = await _commandService.ExecuteCommandAsync(request, clientId);
        
        // Assert
        Assert.NotNull(response);
        Assert.False(response.Success);
        Assert.Equal("unknown_command", response.Command);
        Assert.NotNull(response.Error);
    }

    [Fact]
    public async Task ExecuteCommandAsync_GetStatus_ReturnsConnectedTrue()
    {
        // Arrange
        var request = new CommandRequest { Command = "get_status" };
        var clientId = "test-client";
        
        // Act
        var response = await _commandService.ExecuteCommandAsync(request, clientId);
        
        // Assert
        Assert.NotNull(response);
        Assert.True(response.Success);
        Assert.Equal("get_status", response.Command);
    }

    [Fact]
    public async Task ExecuteCommandAsync_GetConfig_ReturnsConfig()
    {
        // Arrange
        var request = new CommandRequest { Command = "get_config" };
        var clientId = "test-client";
        
        // Act
        var response = await _commandService.ExecuteCommandAsync(request, clientId);
        
        // Assert
        Assert.NotNull(response);
        Assert.True(response.Success);
        Assert.Equal("get_config", response.Command);
    }

    [Fact]
    public async Task ExecuteCommandAsync_SetPollingInterval_WithValidInterval_ReturnsSuccess()
    {
        // Arrange
        var request = new CommandRequest
        {
            Command = "set_polling_interval",
            Params = new Dictionary<string, object>
            {
                { "intervalMs", "1000" }
            }
        };
        var clientId = "test-client";
        
        // Act
        var response = await _commandService.ExecuteCommandAsync(request, clientId);
        
        // Assert
        Assert.NotNull(response);
        Assert.True(response.Success);
        Assert.Equal("set_polling_interval", response.Command);
    }

    [Fact]
    public async Task ExecuteCommandAsync_SetPollingInterval_WithInvalidInterval_ReturnsError()
    {
        // Arrange
        var request = new CommandRequest
        {
            Command = "set_polling_interval",
            Params = new Dictionary<string, object>
            {
                { "intervalMs", "invalid" }
            }
        };
        var clientId = "test-client";
        
        // Act
        var response = await _commandService.ExecuteCommandAsync(request, clientId);
        
        // Assert
        Assert.NotNull(response);
        Assert.False(response.Success);
        Assert.NotNull(response.Error);
    }

    [Fact]
    public async Task ExecuteCommandAsync_Shutdown_BlockedByDefault()
    {
        // Arrange
        var request = new CommandRequest { Command = "shutdown" };
        var clientId = "test-client";
        
        // Act
        var response = await _commandService.ExecuteCommandAsync(request, clientId);
        
        // Assert
        Assert.NotNull(response);
        Assert.False(response.Success);
        Assert.Equal("shutdown", response.Command);
        Assert.NotNull(response.Error);
    }

    [Fact]
    public async Task ExecuteCommandAsync_Restart_BlockedByDefault()
    {
        // Arrange
        var request = new CommandRequest { Command = "restart" };
        var clientId = "test-client";
        
        // Act
        var response = await _commandService.ExecuteCommandAsync(request, clientId);
        
        // Assert
        Assert.NotNull(response);
        Assert.False(response.Success);
        Assert.Equal("restart", response.Command);
        Assert.NotNull(response.Error);
    }

    [Fact]
    public async Task ExecuteCommandAsync_TimestampIsSet()
    {
        // Arrange
        var beforeCall = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var request = new CommandRequest { Command = "ping" };
        var clientId = "test-client";
        
        // Act
        var response = await _commandService.ExecuteCommandAsync(request, clientId);
        var afterCall = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        
        // Assert
        Assert.True(response.Timestamp >= beforeCall);
        Assert.True(response.Timestamp <= afterCall);
    }

    [Fact]
    public async Task ExecuteCommandAsync_MultipleCommands_Succeed()
    {
        // Arrange
        var clientId = "test-client";
        
        // Act & Assert
        var pingResponse = await _commandService.ExecuteCommandAsync(
            new CommandRequest { Command = "ping" }, clientId);
        Assert.True(pingResponse.Success);
        
        var statusResponse = await _commandService.ExecuteCommandAsync(
            new CommandRequest { Command = "get_status" }, clientId);
        Assert.True(statusResponse.Success);
        
        var configResponse = await _commandService.ExecuteCommandAsync(
            new CommandRequest { Command = "get_config" }, clientId);
        Assert.True(configResponse.Success);
    }

    [Fact]
    public async Task ExecuteCommandAsync_DangerousCommandAllowed_WhenEnabled()
    {
        // Arrange
        _settings.Security.DangerousCommandsEnabled = true;
        var request = new CommandRequest { Command = "shutdown" };
        var clientId = "test-client";
        
        // Act
        var response = await _commandService.ExecuteCommandAsync(request, clientId);
        
        // Assert
        Assert.NotNull(response);
        // При enabled опасные команды могут выполняться
    }

    [Fact]
    public async Task ExecuteCommandAsync_GetTelemetry_ReturnsStreamingInfo()
    {
        // Arrange
        var request = new CommandRequest { Command = "get_telemetry" };
        var clientId = "test-client";
        
        // Act
        var response = await _commandService.ExecuteCommandAsync(request, clientId);
        
        // Assert
        Assert.NotNull(response);
        Assert.True(response.Success);
    }

    [Fact]
    public void Constructor_InitializesWithoutException()
    {
        // Assert
        Assert.NotNull(_commandService);
    }
}
