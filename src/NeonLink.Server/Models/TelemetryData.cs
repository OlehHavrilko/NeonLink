using System.Text.Json.Serialization;

namespace NeonLink.Server.Models;

/// <summary>
///     Главный класс телеметрии, отправляемый на Android клиент
///     Версия API: 1.0.0
/// </summary>
public class TelemetryData
{
    /// <summary>
    ///     Версия API для совместимости клиента и сервера
    /// </summary>
    [JsonPropertyName("version")]
    public string Version { get; set; } = "1.0.0";

    [JsonPropertyName("timestamp")]
    public long Timestamp { get; set; }

    [JsonPropertyName("system")]
    public SystemInfo System { get; set; } = new();

    [JsonPropertyName("gaming")]
    public GamingInfo? Gaming { get; set; }

    [JsonPropertyName("adminLevel")]
    public string AdminLevel { get; set; } = "Full";
}

/// <summary>
///     Информация о системе
/// </summary>
public class SystemInfo
{
    [JsonPropertyName("cpu")]
    public CpuInfo Cpu { get; set; } = new();

    [JsonPropertyName("gpu")]
    public GpuInfo Gpu { get; set; } = new();

    [JsonPropertyName("ram")]
    public RamInfo Ram { get; set; } = new();

    [JsonPropertyName("storage")]
    public List<StorageInfo> Storage { get; set; } = new();

    [JsonPropertyName("network")]
    public NetworkInfo? Network { get; set; }
}

/// <summary>
///     Информация о CPU
/// </summary>
public class CpuInfo
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("usage")]
    public double Usage { get; set; }

    [JsonPropertyName("temp")]
    public double Temp { get; set; }

    [JsonPropertyName("cores")]
    public List<CpuCoreInfo> Cores { get; set; } = new();

    [JsonPropertyName("clock")]
    public double Clock { get; set; }

    [JsonPropertyName("power")]
    public double? Power { get; set; }
}

/// <summary>
///     Информация о ядре CPU
/// </summary>
public class CpuCoreInfo
{
    [JsonPropertyName("id")]
    public int Id { get; set; }

    [JsonPropertyName("usage")]
    public double Usage { get; set; }

    [JsonPropertyName("temp")]
    public double? Temp { get; set; }

    [JsonPropertyName("clock")]
    public double? Clock { get; set; }
}

/// <summary>
///     Информация о GPU
/// </summary>
public class GpuInfo
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("type")]
    public string Type { get; set; } = string.Empty; // NVIDIA, AMD, Intel

    [JsonPropertyName("usage")]
    public double Usage { get; set; }

    [JsonPropertyName("temp")]
    public double Temp { get; set; }

    [JsonPropertyName("vramUsed")]
    public double VramUsed { get; set; }

    [JsonPropertyName("vramTotal")]
    public double VramTotal { get; set; }

    [JsonPropertyName("clock")]
    public double Clock { get; set; }

    [JsonPropertyName("memoryClock")]
    public double? MemoryClock { get; set; }

    [JsonPropertyName("power")]
    public double? Power { get; set; }

    [JsonPropertyName("fanSpeed")]
    public int? FanSpeed { get; set; }
}

/// <summary>
///     Информация о RAM
/// </summary>
public class RamInfo
{
    [JsonPropertyName("used")]
    public double Used { get; set; }

    [JsonPropertyName("total")]
    public double Total { get; set; }

    [JsonPropertyName("speed")]
    public int? Speed { get; set; }

    [JsonPropertyName("available")]
    public double Available => Total - Used;

    [JsonPropertyName("usedPercent")]
    public double UsedPercent => Total > 0 ? (Used / Total) * 100 : 0;
}

/// <summary>
///     Информация о накопителе
/// </summary>
public class StorageInfo
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("temp")]
    public double? Temp { get; set; }

    [JsonPropertyName("health")]
    public int? Health { get; set; }

    [JsonPropertyName("smart")]
    public StorageSmartData? Smart { get; set; }
}

/// <summary>
///     SMART данные накопителя
/// </summary>
public class StorageSmartData
{
    [JsonPropertyName("tbw")]
    public int? Tbw { get; set; } // Total Bytes Written

    [JsonPropertyName("powerOnHours")]
    public int? PowerOnHours { get; set; }

    [JsonPropertyName("reallocatedSectors")]
    public int? ReallocatedSectors { get; set; }

    [JsonPropertyName("temperature")]
    public int? Temperature { get; set; }
}

/// <summary>
///     Информация о сети
/// </summary>
public class NetworkInfo
{
    [JsonPropertyName("download")]
    public double Download { get; set; }

    [JsonPropertyName("upload")]
    public double Upload { get; set; }

    [JsonPropertyName("ping")]
    public int Ping { get; set; }

    [JsonPropertyName("ip")]
    public string? Ip { get; set; }
}

/// <summary>
///     Информация о игровом режиме
/// </summary>
public class GamingInfo
{
    [JsonPropertyName("active")]
    public bool IsActive { get; set; }

    [JsonPropertyName("fps")]
    public int? Fps { get; set; }

    [JsonPropertyName("fps1Low")]
    public int? Fps1Low { get; set; }

    [JsonPropertyName("frametime")]
    public double? Frametime { get; set; }

    [JsonPropertyName("activeProcess")]
    public string? ActiveProcess { get; set; }
}
