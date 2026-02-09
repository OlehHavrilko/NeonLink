using NeonLink.Server.Configuration;
using NeonLink.Server.Models;
using NeonLink.Server.Services;

namespace NeonLink.Server.Tests;

/// <summary>
///     Тесты для SecurityService
/// </summary>
public class SecurityServiceTests
{
    private readonly Settings _settings;
    private readonly Mock<ILogger<SecurityService>> _loggerMock;

    public SecurityServiceTests()
    {
        _settings = new Settings
        {
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
            Server = new ServerSettings
            {
                MaxConnections = 5
            }
        };
        _loggerMock = new Mock<ILogger<SecurityService>>();
    }

    [Fact]
    public void IsPrivateIP_PrivateRanges_ReturnsTrue()
    {
        // Arrange
        var service = new SecurityService(_loggerMock.Object, _settings);
        
        // Act & Assert
        Assert.True(service.IsPrivateIP(IPAddress.Parse("10.0.0.1")));
        Assert.True(service.IsPrivateIP(IPAddress.Parse("10.255.255.255")));
        Assert.True(service.IsPrivateIP(IPAddress.Parse("172.16.0.1")));
        Assert.True(service.IsPrivateIP(IPAddress.Parse("172.31.255.255")));
        Assert.True(service.IsPrivateIP(IPAddress.Parse("192.168.0.1")));
        Assert.True(service.IsPrivateIP(IPAddress.Parse("192.168.255.255")));
        Assert.True(service.IsPrivateIP(IPAddress.Loopback));
    }

    [Fact]
    public void IsPrivateIP_PublicRanges_ReturnsFalse()
    {
        // Arrange
        var service = new SecurityService(_loggerMock.Object, _settings);
        
        // Act & Assert
        Assert.False(service.IsPrivateIP(IPAddress.Parse("8.8.8.8")));
        Assert.False(service.IsPrivateIP(IPAddress.Parse("1.1.1.1")));
        Assert.False(service.IsPrivateIP(IPAddress.Parse("203.0.113.1")));
    }

    [Fact]
    public void IsConnectionAllowed_LocalIp_ReturnsTrue()
    {
        // Arrange
        var service = new SecurityService(_loggerMock.Object, _settings);
        
        // Act
        var result = service.IsConnectionAllowed("192.168.1.100");
        
        // Assert
        Assert.True(result);
    }

    [Fact]
    public void IsConnectionAllowed_ExternalIp_ReturnsFalse()
    {
        // Arrange
        var service = new SecurityService(_loggerMock.Object, _settings);
        
        // Act
        var result = service.IsConnectionAllowed("8.8.8.8");
        
        // Assert
        Assert.False(result);
    }

    [Fact]
    public void IsConnectionAllowed_EmptyIp_ReturnsFalse()
    {
        // Arrange
        var service = new SecurityService(_loggerMock.Object, _settings);
        
        // Act
        var result = service.IsConnectionAllowed("");
        
        // Assert
        Assert.False(result);
    }

    [Fact]
    public void IsConnectionAllowed_ExternalIpWithAllowExternal_ReturnsTrue()
    {
        // Arrange
        _settings.Security.AllowExternalIp = true;
        var service = new SecurityService(_loggerMock.Object, _settings);
        
        // Act
        var result = service.IsConnectionAllowed("8.8.8.8");
        
        // Assert
        Assert.True(result);
    }

    [Fact]
    public void IsRateLimited_UnderLimit_ReturnsFalse()
    {
        // Arrange
        var service = new SecurityService(_loggerMock.Object, _settings);
        var clientId = "test-client";
        
        // Act - отправляем 50 запросов (меньше лимита в 100)
        for (int i = 0; i < 50; i++)
        {
            service.UpdateClientActivity(clientId);
        }
        
        var result = service.IsRateLimited(clientId);
        
        // Assert
        Assert.False(result);
    }

    [Fact]
    public void IsRateLimited_OverLimit_ReturnsTrue()
    {
        // Arrange
        var service = new SecurityService(_loggerMock.Object, _settings);
        var clientId = "test-client-overlimit";
        
        // Act - отправляем 150 запросов (больше лимита в 100)
        for (int i = 0; i < 150; i++)
        {
            service.UpdateClientActivity(clientId);
        }
        
        var result = service.IsRateLimited(clientId);
        
        // Assert
        Assert.True(result);
    }

    [Fact]
    public void ValidateCommand_ValidCommand_ReturnsSuccess()
    {
        // Arrange
        var service = new SecurityService(_loggerMock.Object, _settings);
        var command = new CommandRequest { Command = "ping" };
        
        // Act
        var result = service.ValidateCommand(command);
        
        // Assert
        Assert.True(result.IsValid);
        Assert.Equal("ping", result.Command);
    }

    [Fact]
    public void ValidateCommand_CaseInsensitive_ReturnsSuccess()
    {
        // Arrange
        var service = new SecurityService(_loggerMock.Object, _settings);
        var command = new CommandRequest { Command = "GET_STATUS" };
        
        // Act
        var result = service.ValidateCommand(command);
        
        // Assert
        Assert.True(result.IsValid);
    }

    [Fact]
    public void ValidateCommand_UnknownCommand_ReturnsError()
    {
        // Arrange
        var service = new SecurityService(_loggerMock.Object, _settings);
        var command = new CommandRequest { Command = "unknown_command" };
        
        // Act
        var result = service.ValidateCommand(command);
        
        // Assert
        Assert.False(result.IsValid);
        Assert.NotNull(result.Error);
    }

    [Fact]
    public void ValidateCommand_DangerousCommandBlocked_ReturnsError()
    {
        // Arrange
        var service = new SecurityService(_loggerMock.Object, _settings);
        var command = new CommandRequest { Command = "shutdown" };
        
        // Act
        var result = service.ValidateCommand(command);
        
        // Assert
        Assert.False(result.IsValid);
        Assert.True(result.IsDangerous);
    }

    [Fact]
    public void ValidateCommand_DangerousCommandAllowed_WhenEnabled()
    {
        // Arrange
        _settings.Security.DangerousCommandsEnabled = true;
        var service = new SecurityService(_loggerMock.Object, _settings);
        var command = new CommandRequest { Command = "shutdown" };
        
        // Act
        var result = service.ValidateCommand(command);
        
        // Assert
        Assert.True(result.IsValid);
        Assert.True(result.IsDangerous);
    }

    [Fact]
    public void RegisterClient_ReturnsClientId()
    {
        // Arrange
        var service = new SecurityService(_loggerMock.Object, _settings);
        
        // Act
        var clientId = service.RegisterClient("192.168.1.100");
        
        // Assert
        Assert.NotNull(clientId);
        Assert.NotEmpty(clientId);
    }

    [Fact]
    public void ConnectedClientsCount_IncrementsOnRegister()
    {
        // Arrange
        var service = new SecurityService(_loggerMock.Object, _settings);
        
        // Act
        service.RegisterClient("192.168.1.1");
        service.RegisterClient("192.168.1.2");
        
        // Assert
        Assert.Equal(2, service.ConnectedClientsCount);
    }

    [Fact]
    public void UnregisterClient_DecrementsCount()
    {
        // Arrange
        var service = new SecurityService(_loggerMock.Object, _settings);
        var clientId = service.RegisterClient("192.168.1.1");
        
        // Act
        service.UnregisterClient(clientId);
        
        // Assert
        Assert.Equal(0, service.ConnectedClientsCount);
    }
}
