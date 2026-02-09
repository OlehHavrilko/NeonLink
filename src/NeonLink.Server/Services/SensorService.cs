using LibreHardwareMonitor.Hardware;
using NeonLink.Server.Configuration;
using NeonLink.Server.Models;
using NeonLink.Server.Utilities;

namespace NeonLink.Server.Services;

/// <summary>
///     Сервис для сбора данных сенсоров с LibreHardwareMonitor
///     Согласно плану v2.0 - критически важно: thread-safety с SemaphoreSlim
/// </summary>
public class SensorService : IDisposable
{
    private readonly ILogger<SensorService>? _logger;
    private readonly Settings _settings;
    private readonly IAdminRightsChecker _adminChecker;
    
    // Thread-safety: SemaphoreSlim для защиты доступа к Computer
    private readonly SemaphoreSlim _lock = new(1, 1);
    private readonly Computer _computer;
    private bool _disposed;

    // Кеш неизменяемых данных
    private readonly ThreadSafeCache<string, string> _hardwareCache;
    private DateTime _lastUpdate = DateTime.MinValue;
    private TimeSpan _pollingInterval;

    // Visitor для обновления сенсоров
    private readonly UpdateVisitor _visitor = new();

    public SensorService(
        ILogger<SensorService>? logger,
        Settings settings,
        IAdminRightsChecker adminChecker)
    {
        _logger = logger;
        _settings = settings;
        _adminChecker = adminChecker;
        
        // Инициализация LibreHardwareMonitor
        _computer = new Computer
        {
            IsCpuEnabled = _settings.Hardware.EnableCpu,
            IsGpuEnabled = _settings.Hardware.EnableGpu,
            IsMemoryEnabled = _settings.Hardware.EnableRam,
            IsStorageEnabled = _settings.Hardware.EnableStorage,
            IsNetworkEnabled = _settings.Hardware.EnableNetwork
        };

        _pollingInterval = TimeSpan.FromMilliseconds(_settings.Server.PollingIntervalMs);
        
        // Кеш для неизменяемых данных (model names, etc.)
        _hardwareCache = new ThreadSafeCache<string, string>(
            key => string.Empty,
            TimeSpan.FromHours(1));

        _logger?.LogInformation("SensorService initialized with admin level: {Level}",
            adminChecker.CheckAdminLevel().Level);
    }

    /// <summary>
    ///     Инициализация сенсоров
    /// </summary>
    public bool Initialize()
    {
        return _lock.WithLock(() =>
        {
            try
            {
                _computer.Open();
                _computer.Accept(_visitor);
                _logger?.LogInformation("Hardware monitoring started");
                return true;
            }
            catch (Exception ex)
            {
                _logger?.LogError(ex, "Failed to initialize hardware monitoring");
                return false;
            }
        });
    }

    /// <summary>
    ///     Получить текущую телеметрию (thread-safe)
    /// </summary>
    public async Task<TelemetryData> GetCurrentTelemetryAsync()
    {
        return await _lock.WithLockAsync(async () =>
        {
            try
            {
                // Rate limiting: не обновлять слишком часто
                if (DateTime.UtcNow - _lastUpdate < _pollingInterval)
                {
                    return CreateCachedTelemetry();
                }

                // Обновить все сенсоры
                foreach (var hardware in _computer.Hardware)
                {
                    hardware.Update();
                    _visitor.VisitHardware(hardware);
                }

                _lastUpdate = DateTime.UtcNow;
                return ExtractTelemetryData();
            }
            catch (Exception ex)
            {
                _logger?.LogError(ex, "Error getting telemetry");
                return CreateCachedTelemetry();
            }
        });
    }

    /// <summary>
    ///     Получить телеметрию синхронно (thread-safe)
    /// </summary>
    public TelemetryData GetCurrentTelemetry()
    {
        return _lock.WithLock(() =>
        {
            try
            {
                if (DateTime.UtcNow - _lastUpdate < _pollingInterval)
                {
                    return CreateCachedTelemetry();
                }

                foreach (var hardware in _computer.Hardware)
                {
                    hardware.Update();
                    _visitor.VisitHardware(hardware);
                }

                _lastUpdate = DateTime.UtcNow;
                return ExtractTelemetryData();
            }
            catch (Exception ex)
            {
                _logger?.LogError(ex, "Error getting telemetry");
                return CreateCachedTelemetry();
            }
        });
    }

    /// <summary>
    ///     Установить интервал опроса
    /// </summary>
    public void SetPollingInterval(int intervalMs)
    {
        _pollingInterval = TimeSpan.FromMilliseconds(Math.Clamp(intervalMs, 100, 5000));
        _logger?.LogInformation("Polling interval set to {Interval}ms", intervalMs);
    }

    /// <summary>
    ///     Извлечь данные телеметрии из сенсоров
    /// </summary>
    private TelemetryData ExtractTelemetryData()
    {
        var adminLevel = _adminChecker.CheckAdminLevel().Level;

        return new TelemetryData
        {
            Timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
            System = new SystemInfo
            {
                Cpu = ExtractCpuInfo(adminLevel),
                Gpu = ExtractGpuInfo(adminLevel),
                Ram = ExtractRamInfo(adminLevel),
                Storage = ExtractStorageInfo(adminLevel),
                Network = ExtractNetworkInfo(adminLevel)
            },
            Gaming = ExtractGamingInfo(),
            AdminLevel = adminLevel.ToString()
        };
    }

    /// <summary>
    ///     Создать кешированную телеметрию (при ошибках)
    /// </summary>
    private TelemetryData CreateCachedTelemetry()
    {
        return new TelemetryData
        {
            Timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
            System = new SystemInfo(),
            AdminLevel = _adminChecker.CheckAdminLevel().Level.ToString()
        };
    }

    /// <summary>
    ///     Извлечь информацию о CPU
    /// </summary>
    private CpuInfo ExtractCpuInfo(AdminLevel level)
    {
        var cpuInfo = new CpuInfo();

        foreach (var hardware in _computer.Hardware)
        {
            if (hardware.HardwareType != HardwareType.Cpu)
                continue;

            cpuInfo.Name = hardware.Name;

            foreach (var sensor in hardware.Sensors)
            {
                cpuInfo.Name = hardware.Name;

                if (sensor.SensorType == SensorType.Load && sensor.Name == "CPU Total")
                {
                    cpuInfo.Usage = sensor.Value ?? 0;
                }
                else if (sensor.SensorType == SensorType.Temperature)
                {
                    cpuInfo.Temp = sensor.Value ?? 0;
                }
                else if (sensor.SensorType == SensorType.Clock)
                {
                    cpuInfo.Clock = sensor.Value ?? 0;
                }
                else if (sensor.SensorType == SensorType.Power)
                {
                    cpuInfo.Power = sensor.Value;
                }
            }

            // Извлечь информацию о ядрах
            foreach (var subHardware in hardware.SubHardware)
            {
                if (subHardware.HardwareType == HardwareType.Cpu)
                {
                    foreach (var sensor in subHardware.Sensors)
                    {
                        if (sensor.SensorType == SensorType.Load)
                        {
                            var coreId = ExtractCoreId(sensor.Name);
                            if (coreId.HasValue)
                            {
                                while (cpuInfo.Cores.Count <= coreId.Value)
                                {
                                    cpuInfo.Cores.Add(new CpuCoreInfo());
                                }

                                var core = cpuInfo.Cores[coreId.Value];
                                core.Id = coreId.Value;
                                core.Usage = sensor.Value ?? 0;
                            }
                        }
                    }
                }
            }
        }

        return cpuInfo;
    }

    /// <summary>
    ///     Извлечь информацию о GPU
    /// </summary>
    private GpuInfo ExtractGpuInfo(AdminLevel level)
    {
        var gpuInfo = new GpuInfo();

        foreach (var hardware in _computer.Hardware)
        {
            if (hardware.HardwareType != HardwareType.GpuAmd &&
                hardware.HardwareType != HardwareType.GpuNvidia)
                continue;

            gpuInfo.Name = hardware.Name;
            gpuInfo.Type = hardware.HardwareType.ToString().Replace("Gpu", "");

            foreach (var sensor in hardware.Sensors)
            {
                switch (sensor.SensorType)
                {
                    case SensorType.Load:
                        if (sensor.Name.Contains("Core") || sensor.Name == "GPU")
                            gpuInfo.Usage = sensor.Value ?? 0;
                        break;
                    case SensorType.Temperature:
                        gpuInfo.Temp = sensor.Value ?? 0;
                        break;
                    case SensorType.Clock:
                        if (sensor.Name.Contains("Core") || sensor.Name.Contains("Shader"))
                            gpuInfo.Clock = sensor.Value ?? 0;
                        else if (sensor.Name.Contains("Memory"))
                            gpuInfo.MemoryClock = sensor.Value;
                        break;
                    case SensorType.SmallData:
                        if (sensor.Name.Contains("Memory Used"))
                            gpuInfo.VramUsed = (sensor.Value ?? 0) / 1024; // MB to GB
                        else if (sensor.Name.Contains("Memory Total"))
                            gpuInfo.VramTotal = (sensor.Value ?? 0) / 1024;
                        break;
                    case SensorType.Power:
                        gpuInfo.Power = sensor.Value;
                        break;
                    case SensorType.Control:
                        if (sensor.Name.Contains("Fan"))
                            gpuInfo.FanSpeed = (int?)(sensor.Value);
                        break;
                }
            }
        }

        return gpuInfo;
    }

    /// <summary>
    ///     Извлечь информацию о RAM
    /// </summary>
    private RamInfo ExtractRamInfo(AdminLevel level)
    {
        var ramInfo = new RamInfo();

        foreach (var hardware in _computer.Hardware)
        {
            if (hardware.HardwareType != HardwareType.Memory)
                continue;

            // Попытка получить из WMI если LibreHardwareMonitor не дает
            try
            {
                using var wmi = new System.Management.ManagementObjectSearcher(
                    "SELECT TotalVisibleMemorySize FROM Win32_OperatingSystem");
                foreach (var obj in wmi.Get())
                {
                    ramInfo.Total = (double)(ulong)obj["TotalVisibleMemorySize"] / 1024; // KB to GB
                    break;
                }
            }
            catch
            {
                ramInfo.Total = 16.0; // Default fallback
            }

            foreach (var sensor in hardware.Sensors)
            {
                if (sensor.SensorType == SensorType.Load)
                {
                    ramInfo.Used = (sensor.Value ?? 0) * ramInfo.Total / 100;
                }
                else if (sensor.SensorType == SensorType.SmallData && sensor.Name.Contains("Speed"))
                {
                    ramInfo.Speed = (int?)(sensor.Value);
                }
            }
        }

        return ramInfo;
    }

    /// <summary>
    ///     Извлечь информацию о накопителях
    /// </summary>
    private List<StorageInfo> ExtractStorageInfo(AdminLevel level)
    {
        var storageList = new List<StorageInfo>();

        foreach (var hardware in _computer.Hardware)
        {
            if (hardware.HardwareType != HardwareType.Storage)
                continue;

            var storageInfo = new StorageInfo
            {
                Name = hardware.Name
            };

            foreach (var sensor in hardware.Sensors)
            {
                if (sensor.SensorType == SensorType.Temperature)
                {
                    storageInfo.Temp = sensor.Value;
                }
                else if (sensor.SensorType == SensorType.Level && 
                         (sensor.Name.Contains("Health") || sensor.Name.Contains("Life")))
                {
                    storageInfo.Health = (int?)(sensor.Value);
                }
            }

            storageList.Add(storageInfo);
        }

        return storageList;
    }

    /// <summary>
    ///     Извлечь информацию о сети
    /// </summary>
    private NetworkInfo? ExtractNetworkInfo(AdminLevel level)
    {
        foreach (var hardware in _computer.Hardware)
        {
            if (hardware.HardwareType != HardwareType.Network)
                continue;

            var networkInfo = new NetworkInfo();

            foreach (var sensor in hardware.Sensors)
            {
                if (sensor.SensorType == SensorType.Throughput)
                {
                    if (sensor.Name.Contains("Download") || sensor.Name.Contains("received"))
                        networkInfo.Download = (sensor.Value ?? 0) / 1024 / 1024; // Mbps to Gbps
                    else if (sensor.Name.Contains("Upload") || sensor.Name.Contains("sent"))
                        networkInfo.Upload = (sensor.Value ?? 0) / 1024 / 1024;
                }
            }

            // Ping извлекается отдельно в NetworkService
            return networkInfo;
        }

        return null;
    }

    /// <summary>
    ///     Извлечь информацию об игровом режиме
    /// </summary>
    private GamingInfo? ExtractGamingInfo()
    {
        if (!_settings.Hardware.EnableGamingDetection)
            return null;

        // Gaming detection через GPU usage heuristic
        var gpuInfo = ExtractGpuInfo(_adminChecker.CheckAdminLevel().Level);
        
        var isGaming = gpuInfo.Usage >= _settings.Gaming.GpuUsageThreshold;

        return new GamingInfo
        {
            IsActive = isGaming,
            // FPS estimate через GPU load (упрощенно)
            Fps = isGaming ? EstimateFps(gpuInfo.Usage) : null,
            Fps1Low = isGaming ? EstimateFps1Low(gpuInfo.Usage) : null,
            Frametime = isGaming ? 1000.0 / (EstimateFps(gpuInfo.Usage) ?? 60) : null
        };
    }

    /// <summary>
    ///     Оценить FPS по загрузке GPU
    /// </summary>
    private int? EstimateFps(double gpuUsage)
    {
        // Упрощенная эвристика
        if (gpuUsage >= 95) return 60;
        if (gpuUsage >= 85) return 90;
        if (gpuUsage >= 70) return 120;
        if (gpuUsage >= 50) return 144;
        if (gpuUsage >= 30) return 200;
        return 240;
    }

    /// <summary>
    ///     Оценить 1% Low FPS
    /// </summary>
    private int? EstimateFps1Low(double gpuUsage)
    {
        var fps = EstimateFps(gpuUsage);
        return fps != null ? (int)(fps * 0.85) : null;
    }

    /// <summary>
    ///     Извлечь ID ядра из имени сенсора
    /// </summary>
    private int? ExtractCoreId(string sensorName)
    {
        // Имена типа "Core 0", "Core 1", etc.
        var match = System.Text.RegularExpressions.Regex.Match(sensorName, @"Core\s*(\d+)");
        if (match.Success && int.TryParse(match.Groups[1].Value, out var id))
        {
            return id;
        }
        return null;
    }

    public void Dispose()
    {
        if (_disposed)
            return;

        _lock.Wait();
        try
        {
            _computer.Close();
            _disposed = true;
            _logger?.LogInformation("SensorService disposed");
        }
        finally
        {
            _lock.Release();
        }
    }

    /// <summary>
    ///     Visitor для обновления сенсоров
    /// </summary>
    private class UpdateVisitor : IVisitor
    {
        public void VisitComputer(IComputer computer)
        {
            computer.Traverse(this);
        }

        public void VisitHardware(IHardware hardware)
        {
            hardware.Update();
            foreach (var subHardware in hardware.SubHardware)
            {
                subHardware.Accept(this);
            }
        }

        public void VisitSensor(ISensor sensor) { }
        public void VisitParameter(IParameter parameter) { }
    }
}
