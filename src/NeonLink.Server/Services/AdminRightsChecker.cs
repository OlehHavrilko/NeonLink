using System.Management;
using System.Security.Principal;

namespace NeonLink.Server.Services;

/// <summary>
///     Interface for admin rights checking
/// </summary>
public interface IAdminRightsChecker
{
    bool IsRunningAsAdmin();
    AdminCheckResult CheckAdminLevel();
    string GetUserMessage(AdminLevel level);
    bool IsSensorAvailable(string sensorName, AdminLevel level);
}

/// <summary>
///     Уровни прав администратора
/// </summary>
public enum AdminLevel
{
    /// <summary>Полные права - все сенсоры доступны</summary>
    Full,
    
    /// <summary>Ограниченные права - CPU, GPU, RAM без fan control</summary>
    Limited,
    
    /// <summary>Минимальные права - только базовые метрики</summary>
    Minimal
}

/// <summary>
///     Результат проверки прав администратора
/// </summary>
public class AdminCheckResult
{
    public AdminLevel Level { get; set; }
    public bool IsAdmin { get; set; }
    public List<string> AvailableSensors { get; set; } = new();
    public List<string> MissingSensors { get; set; } = new();
    public string Message { get; set; } = string.Empty;
}

/// <summary>
///     Проверка прав администратора и graceful degradation
///     Согласно плану v2.0 - критически важно для LibreHardwareMonitor
/// </summary>
public class AdminRightsChecker : IAdminRightsChecker
{
    private readonly ILogger<AdminRightsChecker>? _logger;

    public AdminRightsChecker(ILogger<AdminRightsChecker>? logger = null)
    {
        _logger = logger;
    }

    /// <summary>
    ///     Проверить, запущен ли процесс с правами администратора
    /// </summary>
    public virtual bool IsRunningAsAdmin()
    {
        try
        {
            return new WindowsPrincipal(WindowsIdentity.GetCurrent())
                .IsInRole(WindowsBuiltInRole.Administrator);
        }
        catch
        {
            return false;
        }
    }

    /// <summary>
    ///     Получить полный результат проверки прав
    /// </summary>
    public virtual AdminCheckResult CheckAdminLevel()
    {
        var isAdmin = IsRunningAsAdmin();
        var result = new AdminCheckResult
        {
            IsAdmin = isAdmin,
            Level = isAdmin ? AdminLevel.Full : AdminLevel.Limited
        };

        // Проверяем доступность WMI
        try
        {
            using var wmiQuery = new ManagementObjectSearcher(
                "SELECT * FROM Win32_OperatingSystem");
            wmiQuery.Get();
        }
        catch (UnauthorizedAccessException)
        {
            result.Level = AdminLevel.Minimal;
            _logger?.LogWarning("WMI access denied - limited sensor availability");
        }
        catch (ManagementException)
        {
            _logger?.LogWarning("WMI query failed - some sensors may be unavailable");
        }

        // Определяем доступные сенсоры
        result.AvailableSensors.Add("CPU Basic");
        result.MissingSensors.Clear();

        if (result.Level == AdminLevel.Full)
        {
            result.AvailableSensors.AddRange(new[]
            {
                "CPU Full",
                "GPU All",
                "RAM Full",
                "Storage SMART",
                "Fan Control",
                "VRM Sensors"
            });
            result.Message = "Full admin access - all sensors available";
        }
        else if (result.Level == AdminLevel.Limited)
        {
            result.AvailableSensors.AddRange(new[]
            {
                "CPU Basic",
                "GPU Basic",
                "RAM Basic",
                "Storage Temperature"
            });
            result.MissingSensors.AddRange(new[]
            {
                "Fan Control (requires admin)",
                "VRM Sensors (requires admin)",
                "Advanced Power Metrics"
            });
            result.Message = "Limited access - fan control disabled";
        }
        else
        {
            result.AvailableSensors.Add("CPU Temperature Only");
            result.MissingSensors.AddRange(new[]
            {
                "GPU Sensors",
                "RAM Usage",
                "Storage SMART",
                "Fan Control"
            });
            result.Message = "Minimal access - basic temperature only";
        }

        _logger?.LogInformation(
            "Admin level: {Level}, Available sensors: {Sensors}",
            result.Level,
            string.Join(", ", result.AvailableSensors));

        return result;
    }

    /// <summary>
    ///     Получить сообщение для пользователя о правах
    /// </summary>
    public virtual string GetUserMessage(AdminLevel level)
    {
        return level switch
        {
            AdminLevel.Full => "✓ Full admin access - all features enabled",
            AdminLevel.Limited =>
                "⚠ Running without admin rights\n" +
                "Fan control and advanced sensors are disabled.\n" +
                "For full functionality, run as administrator.",
            AdminLevel.Minimal =>
                "⚠ Limited access detected\n" +
                "Only basic CPU temperature is available.\n" +
                "Run as administrator for full features.",
            _ => "Unknown access level"
        };
    }

    /// <summary>
    ///     Проверить, доступен ли определенный сенсор
    /// </summary>
    public virtual bool IsSensorAvailable(string sensorName, AdminLevel level)
    {
        var fullSensors = new HashSet<string>
        {
            "cpu", "gpu", "ram", "storage", "fan", "vrm", "network"
        };
        
        var limitedSensors = new HashSet<string>
        {
            "cpu", "gpu", "ram", "storage"
        };
        
        var minimalSensors = new HashSet<string>
        {
            "cpu"
        };

        return level switch
        {
            AdminLevel.Full => fullSensors.Contains(sensorName.ToLower()),
            AdminLevel.Limited => limitedSensors.Contains(sensorName.ToLower()),
            AdminLevel.Minimal => minimalSensors.Contains(sensorName.ToLower()),
            _ => false
        };
    }
}
