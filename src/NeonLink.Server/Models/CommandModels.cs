using System.Text.Json.Serialization;

namespace NeonLink.Server.Models;

/// <summary>
///     Входящая команда от Android клиента
/// </summary>
public class CommandRequest
{
    [JsonPropertyName("command")]
    public string Command { get; set; } = string.Empty;

    [JsonPropertyName("params")]
    public Dictionary<string, object>? Params { get; set; }
}

/// <summary>
///     Ответ на команду
/// </summary>
public class CommandResponse
{
    [JsonPropertyName("success")]
    public bool Success { get; set; }

    [JsonPropertyName("command")]
    public string Command { get; set; } = string.Empty;

    [JsonPropertyName("result")]
    public object? Result { get; set; }

    [JsonPropertyName("error")]
    public string? Error { get; set; }

    [JsonPropertyName("timestamp")]
    public long Timestamp { get; set; }
}

/// <summary>
///     Параметры команды set_polling_interval
/// </summary>
public class SetPollingIntervalParams
{
    [JsonPropertyName("intervalMs")]
    public int IntervalMs { get; set; }
}

/// <summary>
///     Параметры команды get_status
/// </summary>
public class GetStatusParams
{
    [JsonPropertyName("includeHistory")]
    public bool IncludeHistory { get; set; } = false;
}

/// <summary>
///     Параметры команды rgb_effect
/// </summary>
public class RgbEffectParams
{
    [JsonPropertyName("effect")]
    public string Effect { get; set; } = "static";

    [JsonPropertyName("color")]
    public string Color { get; set; } = "#00F0FF";

    [JsonPropertyName("speed")]
    public int? Speed { get; set; }

    [JsonPropertyName("brightness")]
    public int? Brightness { get; set; }
}

/// <summary>
///     Параметры команды set_fan_speed
/// </summary>
public class SetFanSpeedParams
{
    [JsonPropertyName("profile")]
    public string Profile { get; set; } = "auto";

    [JsonPropertyName("fan")]
    public string? Fan { get; set; }

    [JsonPropertyName("speed")]
    public int? Speed { get; set; }
}

/// <summary>
///     Параметры команды get_config
/// </summary>
public class GetConfigParams
{
    [JsonPropertyName("section")]
    public string? Section { get; set; }
}

/// <summary>
///     Параметры команды set_config
/// </summary>
public class SetConfigParams
{
    [JsonPropertyName("key")]
    public string Key { get; set; } = string.Empty;

    [JsonPropertyName("value")]
    public object Value { get; set; } = string.Empty;
}

/// <summary>
///     Результат get_status команды
/// </summary>
public class GetStatusResult
{
    [JsonPropertyName("connected")]
    public bool Connected { get; set; }

    [JsonPropertyName("clientsConnected")]
    public int ClientsConnected { get; set; }

    [JsonPropertyName("uptime")]
    public long Uptime { get; set; }

    [JsonPropertyName("adminLevel")]
    public string AdminLevel { get; set; } = string.Empty;

    [JsonPropertyName("version")]
    public string Version { get; set; } = "1.0.0";
}

/// <summary>
///     Результат get_config команды
/// </summary>
public class GetConfigResult
{
    [JsonPropertyName("server")]
    public ServerConfig Server { get; set; } = new();

    [JsonPropertyName("hardware")]
    public HardwareConfig Hardware { get; set; } = new();

    [JsonPropertyName("gaming")]
    public GamingConfig Gaming { get; set; } = new();
}

public class ServerConfig
{
    public int Port { get; set; }
    public int PollingIntervalMs { get; set; }
    public int MaxConnections { get; set; }
}

public class HardwareConfig
{
    public bool EnableCpu { get; set; }
    public bool EnableGpu { get; set; }
    public bool EnableRam { get; set; }
    public bool EnableStorage { get; set; }
    public bool EnableNetwork { get; set; }
}

public class GamingConfig
{
    public bool EnableGamingDetection { get; set; }
    public double GpuUsageThreshold { get; set; }
    public double CpuUsageThreshold { get; set; }
}
