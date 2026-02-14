using System.Runtime.InteropServices;
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
    private readonly Computer? _computer;
    private bool _disposed;
    
    // Linux mock data
    private readonly Random _random = new();
    private bool _isLinux;

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
        
        // Проверяем платформу
        _isLinux = RuntimeInformation.IsOSPlatform(OSPlatform.Linux);
        
        if (_isLinux)
        {
            _logger?.LogInformation("Running on Linux - using mock sensor data");
            _computer = null;
        }
        else
        {
            // Инициализация LibreHardwareMonitor для Windows
            _computer = new Computer
            {
                IsCpuEnabled = _settings.Hardware.EnableCpu,
                IsGpuEnabled = _settings.Hardware.EnableGpu,
                IsMemoryEnabled = _settings.Hardware.EnableRam,
                IsStorageEnabled = _settings.Hardware.EnableStorage,
                IsNetworkEnabled = _settings.Hardware.EnableNetwork
            };
        }

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
        if (_isLinux)
        {
            _logger?.LogInformation("Linux platform - skipping hardware monitoring initialization");
            return true;
        }
        
        return _lock.WithLock(() =>
        {
            try
            {
                _computer?.Open();
                _computer?.Accept(_visitor);
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
    public Task<TelemetryData> GetCurrentTelemetryAsync()
    {
        if (_isLinux)
        {
            return Task.FromResult(CreateLinuxMockTelemetry());
        }
        
        return _lock.WithLockAsync(async () =>
        {
            try
            {
                // Rate limiting: не обновлять слишком часто
                if (DateTime.UtcNow - _lastUpdate < _pollingInterval)
                {
                    return CreateCachedTelemetry();
                }

                // Обновить все сенсоры
                if (_computer != null)
                {
                    foreach (var hardware in _computer.Hardware)
                    {
                        hardware.Update();
                        _visitor.VisitHardware(hardware);
                    }
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
        if (_isLinux)
        {
            return CreateLinuxMockTelemetry();
        }
        
        return _lock.WithLock(() =>
        {
            try
            {
                if (DateTime.UtcNow - _lastUpdate < _pollingInterval)
                {
                    return CreateCachedTelemetry();
                }

                if (_computer != null)
                {
                    foreach (var hardware in _computer.Hardware)
                    {
                        hardware.Update();
                        _visitor.VisitHardware(hardware);
                    }
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
        
        // Extract GPU info once and reuse for gaming detection
        var gpuInfo = ExtractGpuInfo(adminLevel);

        return new TelemetryData
        {
            Timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
            System = new SystemInfo
            {
                Cpu = ExtractCpuInfo(adminLevel),
                Gpu = gpuInfo,  // Reuse extracted GPU info
                Ram = ExtractRamInfo(adminLevel),
                Storage = ExtractStorageInfo(adminLevel),
                Network = ExtractNetworkInfo(adminLevel)
            },
            Gaming = ExtractGamingInfo(gpuInfo),  // Pass GPU info to avoid re-extraction
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

        if (_computer == null) return cpuInfo;

        // DEBUG: Log hardware iteration for CPU detection
        _logger?.LogDebug("Searching for CPU hardware. Total hardware count: {Count}", 
            _computer.Hardware.Count(h => h.HardwareType == HardwareType.Cpu));

        foreach (var hardware in _computer.Hardware)
        {
            if (hardware.HardwareType != HardwareType.Cpu)
                continue;

            cpuInfo.Name = hardware.Name;
            // Debug logging removed - causes compilation issues on Linux

            foreach (var sensor in hardware.Sensors)
            {
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

        if (_computer == null) return gpuInfo;

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

        if (_computer == null) return ramInfo;

        foreach (var hardware in _computer.Hardware)
        {
            if (hardware.HardwareType != HardwareType.Memory)
                continue;

            // Попытка получить из WMI если LibreHardwareMonitor не дает
            try
            {
#if WINDOWS
                using var wmi = new System.Management.ManagementObjectSearcher(
                    "SELECT TotalVisibleMemorySize FROM Win32_OperatingSystem");
                foreach (var obj in wmi.Get())
                {
                    ramInfo.Total = (double)(ulong)obj["TotalVisibleMemorySize"] / 1024; // KB to GB
                    break;
                }
#endif
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

        if (_computer == null) return storageList;

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
        if (_computer == null) return null;

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
    private GamingInfo? ExtractGamingInfo(GpuInfo gpuInfo)
    {
        if (!_settings.Hardware.EnableGamingDetection)
            return null;

        // Gaming detection через GPU usage heuristic
        // GPU info is passed to avoid re-extraction
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

    /// <summary>
    ///     Создать mock телеметрию для Linux
    /// </summary>
    private TelemetryData CreateLinuxMockTelemetry()
    {
        return new TelemetryData
        {
            Timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
            System = new SystemInfo
            {
                Cpu = new CpuInfo
                {
                    Name = "Linux Mock CPU",
                    Usage = _random.Next(5, 30),
                    Temp = 45 + _random.Next(0, 15),
                    Clock = 3600 + _random.Next(-200, 200),
                    Cores = Enumerable.Range(0, 6).Select(i => new CpuCoreInfo
                    {
                        Id = i,
                        Usage = _random.Next(5, 40)
                    }).ToList()
                },
                Gpu = new GpuInfo
                {
                    Name = "Linux Mock GPU",
                    Type = "Mock",
                    Usage = _random.Next(0, 20),
                    Temp = 40 + _random.Next(0, 10),
                    Clock = 1500 + _random.Next(-100, 100),
                    VramTotal = 8,
                    VramUsed = 2 + _random.Next(0, 3)
                },
                Ram = new RamInfo
                {
                    Total = 16,
                    Used = 6 + _random.Next(0, 4),
                    Speed = 3200
                },
                Storage = new List<StorageInfo>
                {
                    new() { Name = "/dev/sda1", Temp = 35 }
                },
                Network = new NetworkInfo
                {
                    Download = _random.Next(0, 100) / 1000.0,
                    Upload = _random.Next(0, 50) / 1000.0
                }
            },
            Gaming = null,
            AdminLevel = "Mock"
        };
    }

    public void Dispose()
    {
        if (_disposed)
            return;

        _lock.Wait();
        try
        {
            if (!_isLinux)
            {
                _computer?.Close();
            }
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
