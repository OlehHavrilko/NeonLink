namespace NeonLink.Server.Configuration;

/// <summary>
///     Главная конфигурация приложения
/// </summary>
public class Settings
{
    public ServerSettings Server { get; set; } = new();
    public SecuritySettings Security { get; set; } = new();
    public HardwareSettings Hardware { get; set; } = new();
    public GamingSettings Gaming { get; set; } = new();
    public LoggingSettings Logging { get; set; } = new();
    public OledSettings OLED { get; set; } = new();
    public string AllowedHosts { get; set; } = "*";
}

/// <summary>
///     Настройки сервера
/// </summary>
public class ServerSettings
{
    public int Port { get; set; } = 9876;
    public int DiscoveryPort { get; set; } = 9877;
    public int MaxConnections { get; set; } = 5;
    public int PollingIntervalMs { get; set; } = 500;
    public int HeartbeatIntervalMs { get; set; } = 10000;
    public int ReconnectionDelayMs { get; set; } = 1000;
    public int MaxReconnectAttempts { get; set; } = 5;
}

/// <summary>
///     Настройки безопасности
/// </summary>
public class SecuritySettings
{
    public bool AllowExternalIp { get; set; } = false;
    public int RateLimitPerMinute { get; set; } = 100;
    public bool DangerousCommandsEnabled { get; set; } = false;
    public List<string> AllowedCommands { get; set; } = new()
    {
        "get_status",
        "ping",
        "get_config",
        "set_polling_interval"
    };
}

/// <summary>
///     Настройки оборудования
/// </summary>
public class HardwareSettings
{
    public bool EnableCpu { get; set; } = true;
    public bool EnableGpu { get; set; } = true;
    public bool EnableRam { get; set; } = true;
    public bool EnableStorage { get; set; } = true;
    public bool EnableNetwork { get; set; } = true;
    public bool EnableGamingDetection { get; set; } = true;
}

/// <summary>
///     Настройки игрового режима
/// </summary>
public class GamingSettings
{
    public List<string> ProcessWhitelist { get; set; } = new()
    {
        "cs2.exe",
        "RDR2.exe",
        "eldenring.exe",
        "valorant.exe",
        "fortnite.exe",
        "apexlegends.exe"
    };
    public double GpuUsageThreshold { get; set; } = 85.0;
    public double CpuUsageThreshold { get; set; } = 40.0;
}

/// <summary>
///     Настройки логирования
/// </summary>
public class LoggingSettings
{
    public string LogDirectory { get; set; } = "logs";
    public string LogFile { get; set; } = "neonlink-.txt";
    public string LogLevel { get; set; } = "Information";
    public bool ConsoleEnabled { get; set; } = true;
    public bool FileEnabled { get; set; } = true;
    public int RetainFileCountLimit { get; set; } = 7;
}

/// <summary>
///     Настройки OLED защиты
/// </summary>
public class OledSettings
{
    public bool ProtectionEnabled { get; set; } = false;
}
