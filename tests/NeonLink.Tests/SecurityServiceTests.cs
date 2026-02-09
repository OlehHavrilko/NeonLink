using NeonLink.Server.Configuration;
using NeonLink.Server.Models;
using NeonLink.Server.Services;

namespace NeonLink.Tests;

/// <summary>
///     Unit tests for SecurityService
/// </summary>
public class SecurityServiceTests
{
    private readonly SecurityService _securityService;
    private readonly Settings _settings;

    public SecurityServiceTests()
    {
        _settings = new Settings
        {
            Security = new SecuritySettings
            {
                AllowExternalIp = false,
                RateLimitPerMinute = 10,
                DangerousCommandsEnabled = false,
                AllowedCommands = new List<string>
                {
                    "get_status",
                    "ping",
                    "get_config",
                    "set_polling_interval"
                }
            },
            Server = new ServerSettings
            {
                MaxConnections = 5
            }
        };

        _securityService = new SecurityService(null, _settings);
    }

    #region IsConnectionAllowed Tests

    [Fact]
    public void IsConnectionAllowed_EmptyIp_ReturnsFalse()
    {
        // Arrange
        var emptyIp = string.Empty;

        // Act
        var result = _securityService.IsConnectionAllowed(emptyIp);

        // Assert
        Assert.False(result);
    }

    [Fact]
    public void IsConnectionAllowed_WhitespaceIp_ReturnsFalse()
    {
        // Arrange
        var whitespaceIp = "   ";

        // Act
        var result = _securityService.IsConnectionAllowed(whitespaceIp);

        // Assert
        Assert.False(result);
    }

    [Fact]
    public void IsConnectionAllowed_PrivateIp10Range_ReturnsTrue()
    {
        // Arrange
        var privateIp = "10.0.0.1";

        // Act
        var result = _securityService.IsConnectionAllowed(privateIp);

        // Assert
        Assert.True(result);
    }

    [Fact]
    public void IsConnectionAllowed_PrivateIp172Range_ReturnsTrue()
    {
        // Arrange
        var privateIp = "172.16.0.1";

        // Act
        var result = _securityService.IsConnectionAllowed(privateIp);

        // Assert
        Assert.True(result);
    }

    [Fact]
    public void IsConnectionAllowed_PrivateIp192Range_ReturnsTrue()
    {
        // Arrange
        var privateIp = "192.168.1.1";

        // Act
        var result = _securityService.IsConnectionAllowed(privateIp);

        // Assert
        Assert.True(result);
    }

    [Fact]
    public void IsConnectionAllowed_Loopback_ReturnsTrue()
    {
        // Arrange
        var loopbackIp = "127.0.0.1";

        // Act
        var result = _securityService.IsConnectionAllowed(loopbackIp);

        // Assert
        Assert.True(result);
    }

    [Fact]
    public void IsConnectionAllowed_ExternalIp_ReturnsFalse()
    {
        // Arrange
        var externalIp = "8.8.8.8";

        // Act
        var result = _securityService.IsConnectionAllowed(externalIp);

        // Assert
        Assert.False(result);
    }

    [Fact]
    public void IsConnectionAllowed_InvalidIp_ReturnsFalse()
    {
        // Arrange
        var invalidIp = "not-an-ip";

        // Act
        var result = _securityService.IsConnectionAllowed(invalidIp);

        // Assert
        Assert.False(result);
    }

    [Fact]
    public void IsConnectionAllowed_ExternalIpWithAllowExternalIpTrue_ReturnsTrue()
    {
        // Arrange
        var settings = new Settings
        {
            Security = new SecuritySettings
            {
                AllowExternalIp = true,
                RateLimitPerMinute = 10,
                DangerousCommandsEnabled = false,
                AllowedCommands = new List<string> { "ping" }
            },
            Server = new ServerSettings { MaxConnections = 5 }
        };

        var service = new SecurityService(null, settings);
        var externalIp = "8.8.8.8";

        // Act
        var result = service.IsConnectionAllowed(externalIp);

        // Assert
        Assert.True(result);
    }

    #endregion

    #region IsPrivateIP Static Tests

    [Theory]
    [InlineData("10.0.0.0", true)]
    [InlineData("10.255.255.255", true)]
    [InlineData("10.123.45.67", true)]
    [InlineData("172.16.0.0", true)]
    [InlineData("172.31.255.255", true)]
    [InlineData("172.20.30.40", true)]
    [InlineData("192.168.0.0", true)]
    [InlineData("192.168.255.255", true)]
    [InlineData("192.168.1.100", true)]
    [InlineData("127.0.0.1", true)]
    [InlineData("8.8.8.8", false)]
    [InlineData("203.0.113.50", false)]
    [InlineData("1.1.1.1", false)]
    public void IsPrivateIP_VariousIps_ReturnsCorrectResult(string ip, bool expected)
    {
        // Arrange
        var ipAddress = System.Net.IPAddress.Parse(ip);

        // Act
        var result = SecurityService.IsPrivateIP(ipAddress);

        // Assert
        Assert.Equal(expected, result);
    }

    #endregion

    #region ValidateCommand Tests

    [Fact]
    public void ValidateCommand_EmptyCommand_ReturnsInvalid()
    {
        // Arrange
        var command = new CommandRequest { Command = "" };

        // Act
        var result = _securityService.ValidateCommand(command);

        // Assert
        Assert.False(result.IsValid);
        Assert.Equal("Command is empty", result.Error);
    }

    [Fact]
    public void ValidateCommand_WhitespaceCommand_ReturnsInvalid()
    {
        // Arrange
        var command = new CommandRequest { Command = "   " };

        // Act
        var result = _securityService.ValidateCommand(command);

        // Assert
        Assert.False(result.IsValid);
    }

    [Fact]
    public void ValidateCommand_ValidCommand_ReturnsValid()
    {
        // Arrange
        var command = new CommandRequest { Command = "get_status" };

        // Act
        var result = _securityService.ValidateCommand(command);

        // Assert
        Assert.True(result.IsValid);
        Assert.Equal("get_status", result.Command);
    }

    [Fact]
    public void ValidateCommand_ValidCommandCaseInsensitive_ReturnsValid()
    {
        // Arrange
        var command = new CommandRequest { Command = "GET_STATUS" };

        // Act
        var result = _securityService.ValidateCommand(command);

        // Assert
        Assert.True(result.IsValid);
        Assert.Equal("get_status", result.Command);
    }

    [Fact]
    public void ValidateCommand_UnknownCommand_ReturnsInvalid()
    {
        // Arrange
        var command = new CommandRequest { Command = "unknown_command" };

        // Act
        var result = _securityService.ValidateCommand(command);

        // Assert
        Assert.False(result.IsValid);
        Assert.Contains("not recognized", result.Error);
    }

    [Fact]
    public void ValidateCommand_DangerousCommandBlocked_ReturnsInvalid()
    {
        // Arrange
        var command = new CommandRequest { Command = "shutdown" };

        // Act
        var result = _securityService.ValidateCommand(command);

        // Assert
        Assert.False(result.IsValid);
        Assert.True(result.IsDangerous);
        Assert.Contains("not allowed", result.Error);
    }

    [Fact]
    public void ValidateCommand_DangerousCommandAllowedWhenEnabled_ReturnsValidWithWarning()
    {
        // Arrange
        var settings = new Settings
        {
            Security = new SecuritySettings
            {
                AllowExternalIp = false,
                RateLimitPerMinute = 10,
                DangerousCommandsEnabled = true,
                AllowedCommands = new List<string> { "ping" }
            },
            Server = new ServerSettings { MaxConnections = 5 }
        };

        var service = new SecurityService(null, settings);
        var command = new CommandRequest { Command = "shutdown" };

        // Act
        var result = service.ValidateCommand(command);

        // Assert
        Assert.True(result.IsValid);
        Assert.True(result.IsDangerous);
        Assert.Contains("Dangerous command executed", result.Warning);
    }

    [Theory]
    [InlineData("shutdown")]
    [InlineData("restart")]
    [InlineData("execute")]
    [InlineData("systemctl")]
    [InlineData("poweroff")]
    [InlineData("reboot")]
    public void ValidateCommand_DangerousCommandsAreBlocked(string dangerousCommand)
    {
        // Arrange
        var command = new CommandRequest { Command = dangerousCommand };

        // Act
        var result = _securityService.ValidateCommand(command);

        // Assert
        Assert.False(result.IsValid);
        Assert.True(result.IsDangerous);
    }

    #endregion

    #region Client Management Tests

    [Fact]
    public void RegisterClient_WithClientId_ReturnsProvidedId()
    {
        // Arrange
        var clientId = "test-client-123";

        // Act
        var result = _securityService.RegisterClient("192.168.1.100", clientId);

        // Assert
        Assert.Equal(clientId, result);
    }

    [Fact]
    public void RegisterClient_WithoutClientId_ReturnsGeneratedId()
    {
        // Act
        var result = _securityService.RegisterClient("192.168.1.100");

        // Assert
        Assert.NotNull(result);
        Assert.Equal(8, result.Length);
    }

    [Fact]
    public void UnregisterClient_RemovesClient()
    {
        // Arrange
        var clientId = _securityService.RegisterClient("192.168.1.100");

        // Act
        _securityService.UnregisterClient(clientId);

        // Assert - client should not cause issues
        _securityService.UpdateClientActivity(clientId);
    }

    [Fact]
    public void UpdateClientActivity_WithExistingClient_DoesNotThrow()
    {
        // Arrange
        var clientId = _securityService.RegisterClient("192.168.1.100");

        // Act & Assert
        var exception = Record.Exception(() => _securityService.UpdateClientActivity(clientId));
        Assert.Null(exception);
    }

    #endregion

    #region Connection Management Tests

    [Fact]
    public void CanAcceptConnection_WhenUnderLimit_ReturnsTrue()
    {
        // Act
        var result = _securityService.CanAcceptConnection();

        // Assert
        Assert.True(result);
    }

    [Fact]
    public void ConnectedClientsCount_ReflectsActualConnections()
    {
        // Arrange
        _securityService.RegisterClient("192.168.1.1");
        _securityService.RegisterClient("192.168.1.2");
        _securityService.RegisterClient("192.168.1.3");

        // Act
        var count = _securityService.ConnectedClientsCount;

        // Assert
        Assert.Equal(3, count);
    }

    [Fact]
    public void CleanupInactiveClients_RemovesTimedOutClients()
    {
        // Arrange
        var clientId = _securityService.RegisterClient("192.168.1.1");
        _settings.Server.MaxConnections = 10;

        // Act
        _securityService.CleanupInactiveClients(TimeSpan.Zero);

        // Assert - cleanup should complete without errors
        var stats = _securityService.GetStats();
        Assert.NotNull(stats);
    }

    #endregion

    #region GetStats Tests

    [Fact]
    public void GetStats_ReturnsCorrectStatistics()
    {
        // Arrange
        _securityService.RegisterClient("192.168.1.1");
        _securityService.RegisterClient("192.168.1.2");

        // Act
        var stats = _securityService.GetStats();

        // Assert
        Assert.Equal(2, stats.ConnectedClients);
        Assert.Equal(5, stats.MaxClients);
        Assert.Equal(10, stats.RateLimitPerMinute);
        Assert.False(stats.AllowExternalIp);
        Assert.False(stats.DangerousCommandsEnabled);
    }

    #endregion

    #region Rate Limiting Tests

    [Fact]
    public void IsRateLimited_UnderLimit_ReturnsFalse()
    {
        // Arrange
        var clientId = "test-client-rate";

        // Act - make 5 requests (under limit of 10)
        for (int i = 0; i < 5; i++)
        {
            var isLimited = _securityService.IsRateLimited(clientId);
            Assert.False(isLimited);
        }
    }

    [Fact]
    public void IsRateLimited_AtLimit_ReturnsFalse()
    {
        // Arrange
        var clientId = "test-client-at-limit";

        // Act - make 10 requests (exactly at limit)
        for (int i = 0; i < 10; i++)
        {
            var isLimited = _securityService.IsRateLimited(clientId);
            Assert.False(isLimited);
        }
    }

    [Fact]
    public void IsRateLimited_OverLimit_ReturnsTrue()
    {
        // Arrange
        var clientId = "test-client-over-limit";

        // Act - make 11 requests (over limit of 10)
        for (int i = 0; i < 10; i++)
        {
            _securityService.IsRateLimited(clientId);
        }

        // Assert - 11th request should be limited
        var isLimited = _securityService.IsRateLimited(clientId);
        Assert.True(isLimited);
    }

    #endregion
}
