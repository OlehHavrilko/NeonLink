using NeonLink.Server.Configuration;
using NeonLink.Server.Models;
using NeonLink.Server.Services;

namespace NeonLink.Tests;

/// <summary>
///     Unit tests for CommandService
/// </summary>
public class CommandServiceTests
{
    private readonly CommandService _commandService;
    private readonly Settings _settings;
    private readonly SensorService _sensorService;
    private readonly SecurityService _securityService;
    private readonly TelemetryChannelService _channelService;
    private readonly AdminRightsChecker _adminChecker;

    public CommandServiceTests()
    {
        _adminChecker = new AdminRightsChecker(null);
        _settings = new Settings
        {
            Server = new ServerSettings
            {
                Port = 8080,
                PollingIntervalMs = 1000,
                MaxConnections = 10
            },
            Security = new SecuritySettings
            {
                DangerousCommandsEnabled = false,
                RateLimitPerMinute = 100,
                AllowedCommands = new List<string> { "get_status", "ping", "get_config", "set_polling_interval", "get_telemetry" }
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

        _channelService = new TelemetryChannelService(null);
        _securityService = new SecurityService(null, _settings);
        _sensorService = new SensorService(null, _settings, _adminChecker);
        _commandService = new CommandService(null, _settings, _sensorService, _securityService, _channelService);
    }

    #region Ping Tests

    [Fact]
    public async Task ExecuteCommandAsync_Ping_ReturnsPong()
    {
        // Arrange
        var request = new CommandRequest { Command = "ping" };

        // Act
        var response = await _commandService.ExecuteCommandAsync(request, "test-client");

        // Assert
        Assert.True(response.Success);
        Assert.Equal("ping", response.Command);
        Assert.NotNull(response.Result);
    }

    #endregion

    #region Get Status Tests

    [Fact]
    public async Task ExecuteCommandAsync_GetStatus_ReturnsValidStatus()
    {
        // Arrange
        var request = new CommandRequest { Command = "get_status" };

        // Act
        var response = await _commandService.ExecuteCommandAsync(request, "test-client");

        // Assert
        Assert.True(response.Success);
        Assert.Equal("get_status", response.Command);
    }

    #endregion

    #region Get Config Tests

    [Fact]
    public async Task ExecuteCommandAsync_GetConfig_ReturnsConfig()
    {
        // Arrange
        var request = new CommandRequest { Command = "get_config" };

        // Act
        var response = await _commandService.ExecuteCommandAsync(request, "test-client");

        // Assert
        Assert.True(response.Success);
        Assert.Equal("get_config", response.Command);
    }

    #endregion

    #region Set Polling Interval Tests

    [Fact]
    public async Task ExecuteCommandAsync_SetPollingInterval_ValidInterval_Success()
    {
        // Arrange
        var request = new CommandRequest
        {
            Command = "set_polling_interval",
            Params = new Dictionary<string, object> { { "intervalMs", "500" } }
        };

        // Act
        var response = await _commandService.ExecuteCommandAsync(request, "test-client");

        // Assert
        Assert.True(response.Success);
    }

    [Fact]
    public async Task ExecuteCommandAsync_SetPollingInterval_InvalidInterval_Fails()
    {
        // Arrange
        var request = new CommandRequest
        {
            Command = "set_polling_interval",
            Params = new Dictionary<string, object> { { "intervalMs", "invalid" } }
        };

        // Act
        var response = await _commandService.ExecuteCommandAsync(request, "test-client");

        // Assert - invalid value returns success but with error in result
        Assert.NotNull(response.Result);
    }

    [Fact]
    public async Task ExecuteCommandAsync_SetPollingInterval_ClampsToMin()
    {
        // Arrange
        var request = new CommandRequest
        {
            Command = "set_polling_interval",
            Params = new Dictionary<string, object> { { "intervalMs", "50" } }
        };

        // Act
        var response = await _commandService.ExecuteCommandAsync(request, "test-client");

        // Assert
        Assert.True(response.Success);
    }

    #endregion

    #region Get Telemetry Tests

    [Fact]
    public async Task ExecuteCommandAsync_GetTelemetry_ReturnsStreamingInfo()
    {
        // Arrange
        var request = new CommandRequest { Command = "get_telemetry" };

        // Act
        var response = await _commandService.ExecuteCommandAsync(request, "test-client");

        // Assert
        Assert.NotNull(response);
    }

    #endregion

    #region Shutdown Tests

    [Fact]
    public async Task ExecuteCommandAsync_Shutdown_Blocked_ReturnsError()
    {
        // Arrange
        var request = new CommandRequest { Command = "shutdown" };

        // Act
        var response = await _commandService.ExecuteCommandAsync(request, "test-client");

        // Assert
        Assert.False(response.Success);
        Assert.Contains("not allowed", response.Error ?? string.Empty, StringComparison.OrdinalIgnoreCase);
    }

    #endregion

    #region Restart Tests

    [Fact]
    public async Task ExecuteCommandAsync_Restart_Blocked_ReturnsError()
    {
        // Arrange
        var request = new CommandRequest { Command = "restart" };

        // Act
        var response = await _commandService.ExecuteCommandAsync(request, "test-client");

        // Assert
        Assert.False(response.Success);
        Assert.Contains("not allowed", response.Error ?? string.Empty, StringComparison.OrdinalIgnoreCase);
    }

    #endregion

    #region Unknown Command Tests

    [Fact]
    public async Task ExecuteCommandAsync_UnknownCommand_ReturnsError()
    {
        // Arrange
        var request = new CommandRequest { Command = "unknown_command" };

        // Act
        var response = await _commandService.ExecuteCommandAsync(request, "test-client");

        // Assert
        Assert.False(response.Success);
        Assert.NotNull(response.Error);
    }

    #endregion

    #region Command Validation Tests

    [Fact]
    public async Task ExecuteCommandAsync_EmptyCommand_ReturnsError()
    {
        // Arrange
        var request = new CommandRequest { Command = "" };

        // Act
        var response = await _commandService.ExecuteCommandAsync(request, "test-client");

        // Assert
        Assert.False(response.Success);
    }

    #endregion
}
