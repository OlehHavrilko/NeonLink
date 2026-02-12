using System.Collections.Concurrent;
using System.Net;
using System.Text.Json;
using NeonLink.Server.Configuration;
using NeonLink.Server.Models;
using NeonLink.Server.Utilities;

namespace NeonLink.Server.Services;

/// <summary>
///     Сервис безопасности - IP validation, rate limiting, command whitelist
///     Согласно плану v2.0 - критически важно: ОБЯЗАТЕЛЬНО, не опционально
/// </summary>
public class SecurityService
{
    private readonly ILogger<SecurityService>? _logger;
    private readonly Settings _settings;
    
    // Rate limiting: ConcurrentDictionary with timestamp lists (improved from List+lock)
    private readonly ConcurrentDictionary<string, ConcurrentQueue<DateTime>> _requestLog = new();
    
    // Command whitelist - быстрая проверка
    private readonly HashSet<string> _safeCommands;
    private readonly HashSet<string> _dangerousCommands;
    
    // Connected clients tracking
    private readonly ConcurrentDictionary<string, ClientInfo> _connectedClients = new();
    private int _connectedCount;

    public SecurityService(ILogger<SecurityService>? logger, Settings settings)
    {
        _logger = logger;
        _settings = settings;
        
        // Инициализация whitelist из конфигурации
        _safeCommands = new HashSet<string>(
            settings.Security.AllowedCommands,
            StringComparer.OrdinalIgnoreCase);
        
        // Опасные команды
        _dangerousCommands = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "shutdown",
            "restart",
            "execute",
            "systemctl",
            "poweroff",
            "reboot"
        };

        _logger?.LogInformation("SecurityService initialized with {Count} allowed commands",
            _safeCommands.Count);
    }

    /// <summary>
    ///     Проверить IP адрес - только локальная сеть
    /// </summary>
    public bool IsConnectionAllowed(string remoteIp)
    {
        if (string.IsNullOrWhiteSpace(remoteIp))
        {
            _logger?.LogWarning("Empty IP address rejected");
            return false;
        }

        // Разрешить внешние IP если настроено (для разработки)
        if (_settings.Security.AllowExternalIp)
        {
            _logger?.LogDebug("External IP allowed by configuration: {Ip}", remoteIp);
            return true;
        }

        // Проверка что IP из локальной сети
        if (!IPAddress.TryParse(remoteIp, out var ip))
        {
            _logger?.LogWarning("Invalid IP address: {Ip}", remoteIp);
            return false;
        }

        var isPrivate = IsPrivateIP(ip);
        
        if (!isPrivate)
        {
            _logger?.LogWarning("External IP rejected: {Ip}", remoteIp);
        }
        
        return isPrivate;
    }

    /// <summary>
    ///     Проверить, является ли IP адрес приватным
    /// </summary>
    public static bool IsPrivateIP(IPAddress ip)
    {
        var bytes = ip.GetAddressBytes();
        
        // 10.0.0.0/8
        if (bytes[0] == 10)
            return true;
        
        // 172.16.0.0/12
        if (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31)
            return true;
        
        // 192.168.0.0/16
        if (bytes[0] == 192 && bytes[1] == 168)
            return true;
        
        // localhost
        if (IPAddress.IsLoopback(ip))
            return true;
        
        return false;
    }

    /// <summary>
    ///     Проверить rate limiting (optimized with ConcurrentQueue)
    /// </summary>
    public bool IsRateLimited(string clientId)
    {
        var now = DateTime.UtcNow;
        var windowStart = now.AddMinutes(-1);
        
        var queue = _requestLog.GetOrAdd(clientId, _ => new ConcurrentQueue<DateTime>());
        
        // Remove old entries (> 1 minute) - thread-safe without lock
        while (queue.TryPeek(out var timestamp) && timestamp < windowStart)
        {
            queue.TryDequeue(out _);
        }
        
        var count = queue.Count;
        
        // DEBUG: Log rate limit check
        _logger?.LogDebug("[DEBUG] Rate limit check for {Client}: {Count}/{Limit} requests", 
            clientId, count, _settings.Security.RateLimitPerMinute);
        
        // Add current request
        queue.Enqueue(now);
        
        var isLimited = count >= _settings.Security.RateLimitPerMinute;
        
        if (isLimited)
        {
            _logger?.LogWarning("Rate limit exceeded for client {Client}: {Count} req/min",
                clientId, count);
        }
        
        return isLimited;
    }

    /// <summary>
    ///     Проверить, разрешена ли команда
    /// </summary>
    public CommandValidationResult ValidateCommand(CommandRequest command)
    {
        if (string.IsNullOrWhiteSpace(command.Command))
        {
            return new CommandValidationResult
            {
                IsValid = false,
                Error = "Command is empty"
            };
        }

        var normalizedCommand = command.Command.Trim().ToLowerInvariant();

        // Проверка на dangerous команды
        if (_dangerousCommands.Contains(normalizedCommand))
        {
            if (_settings.Security.DangerousCommandsEnabled)
            {
                _logger?.LogWarning("Dangerous command executed: {Command}", command.Command);
                return new CommandValidationResult
                {
                    IsValid = true,
                    IsDangerous = true,
                    Warning = "Dangerous command executed"
                };
            }
            
            _logger?.LogWarning("Dangerous command blocked: {Command}", command.Command);
            return new CommandValidationResult
            {
                IsValid = false,
                Error = $"Command '{command.Command}' is not allowed",
                IsDangerous = true
            };
        }

        // Проверка whitelist
        if (!_safeCommands.Contains(normalizedCommand))
        {
            _logger?.LogWarning("Unknown command blocked: {Command}", command.Command);
            return new CommandValidationResult
            {
                IsValid = false,
                Error = $"Command '{command.Command}' is not recognized"
            };
        }

        return new CommandValidationResult
        {
            IsValid = true,
            Command = normalizedCommand
        };
    }

    /// <summary>
    ///     Зарегистрировать подключение клиента
    /// </summary>
    public string RegisterClient(string ipAddress, string? clientId = null)
    {
        var id = clientId ?? Guid.NewGuid().ToString()[..8];
        
        var clientInfo = new ClientInfo
        {
            Id = id,
            IpAddress = ipAddress,
            ConnectedAt = DateTime.UtcNow,
            LastActivity = DateTime.UtcNow
        };
        
        _connectedClients.TryAdd(id, clientInfo);
        Interlocked.Increment(ref _connectedCount);
        
        _logger?.LogInformation("Client connected: {Id} from {Ip}", id, ipAddress);
        
        return id;
    }

    /// <summary>
    ///     Обновить активность клиента
    /// </summary>
    public void UpdateClientActivity(string clientId)
    {
        if (_connectedClients.TryGetValue(clientId, out var client))
        {
            client.LastActivity = DateTime.UtcNow;
        }
    }

    /// <summary>
    ///     Отключить клиента
    /// </summary>
    public void UnregisterClient(string clientId)
    {
        if (_connectedClients.TryRemove(clientId, out _))
        {
            Interlocked.Decrement(ref _connectedCount);
            _logger?.LogInformation("Client disconnected: {Id}", clientId);
        }
    }

    /// <summary>
    ///     Получить количество подключенных клиентов
    /// </summary>
    public int ConnectedClientsCount => Math.Min(
        _connectedClients.Count,
        _settings.Server.MaxConnections);

    /// <summary>
    ///     Проверить, можно ли принять новое подключение
    /// </summary>
    public bool CanAcceptConnection()
    {
        return _connectedClients.Count < _settings.Server.MaxConnections;
    }

    /// <summary>
    ///     Очистить устаревшие соединения
    /// </summary>
    public void CleanupInactiveClients(TimeSpan timeout)
    {
        var cutoff = DateTime.UtcNow - timeout;
        
        foreach (var (id, client) in _connectedClients)
        {
            if (client.LastActivity < cutoff)
            {
                UnregisterClient(id);
                _logger?.LogInformation("Inactive client removed: {Id}", id);
            }
        }
    }

    /// <summary>
    ///     Получить статистику безопасности
    /// </summary>
    public SecurityStats GetStats()
    {
        return new SecurityStats
        {
            ConnectedClients = _connectedClients.Count,
            MaxClients = _settings.Server.MaxConnections,
            RateLimitPerMinute = _settings.Security.RateLimitPerMinute,
            AllowExternalIp = _settings.Security.AllowExternalIp,
            DangerousCommandsEnabled = _settings.Security.DangerousCommandsEnabled
        };
    }
}

/// <summary>
///     Результат валидации команды
/// </summary>
public class CommandValidationResult
{
    public bool IsValid { get; set; }
    public bool IsDangerous { get; set; }
    public string? Error { get; set; }
    public string? Warning { get; set; }
    public string? Command { get; set; }
}

/// <summary>
///     Информация о клиенте
/// </summary>
public class ClientInfo
{
    public string Id { get; set; } = string.Empty;
    public string IpAddress { get; set; } = string.Empty;
    public DateTime ConnectedAt { get; set; }
    public DateTime LastActivity { get; set; }
}

/// <summary>
///     Статистика безопасности
/// </summary>
public class SecurityStats
{
    public int ConnectedClients { get; set; }
    public int MaxClients { get; set; }
    public int RateLimitPerMinute { get; set; }
    public bool AllowExternalIp { get; set; }
    public bool DangerousCommandsEnabled { get; set; }
}
