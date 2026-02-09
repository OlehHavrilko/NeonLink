using System.Diagnostics;
using NeonLink.Server.Configuration;
using NeonLink.Server.Models;

namespace NeonLink.Server.Services;

/// <summary>
///     Сервис обработки команд от Android клиента
///     Согласно плану v2.0: Command Processor с whitelist validation
/// </summary>
public class CommandService
{
    private readonly ILogger<CommandService>? _logger;
    private readonly Settings _settings;
    private readonly SensorService _sensorService;
    private readonly SecurityService _securityService;
    private readonly TelemetryChannelService _channelService;
    
    // Время запуска для uptime
    private readonly DateTime _startTime;

    public CommandService(
        ILogger<CommandService>? logger,
        Settings settings,
        SensorService sensorService,
        SecurityService securityService,
        TelemetryChannelService channelService)
    {
        _logger = logger;
        _settings = settings;
        _sensorService = sensorService;
        _securityService = securityService;
        _channelService = channelService;
        _startTime = DateTime.UtcNow;

        _logger?.LogInformation("CommandService initialized");
    }

    /// <summary>
    ///     Обработать команду
    /// </summary>
    public async Task<CommandResponse> ExecuteCommandAsync(CommandRequest request, string clientId)
    {
        // Валидация через whitelist
        var validation = _securityService.ValidateCommand(request);
        
        if (!validation.IsValid)
        {
            return CreateErrorResponse(request.Command, validation.Error ?? "Command not allowed");
        }

        try
        {
            var command = validation.Command ?? request.Command.ToLowerInvariant();
            
            return command switch
            {
                // Safe commands
                "ping" => CreateSuccessResponse(request.Command, new
                {
                    pong = true,
                    timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds()
                }),
                
                "get_status" => CreateSuccessResponse(request.Command, await HandleGetStatusAsync()),
                
                "get_config" => CreateSuccessResponse(request.Command, HandleGetConfig()),
                
                "set_polling_interval" => CreateSuccessResponse(request.Command, HandleSetPollingInterval(request)),
                
                "get_telemetry" => CreateSuccessResponse(request.Command, new
                {
                    streaming = true,
                    channelBuffered = _channelService.BufferedCount,
                    maxBufferSize = _channelService.MaxBufferSize
                }),
                
                // Dangerous commands (require permission)
                "shutdown" => HandleShutdown(),
                "restart" => HandleRestart(),
                
                // Unknown
                _ => CreateErrorResponse(request.Command, "Unknown command")
            };
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Error executing command {Command}", request.Command);
            return CreateErrorResponse(request.Command, $"Execution error: {ex.Message}");
        }
    }

    /// <summary>
    ///     get_status → текущая телеметрия и статус сервера
    /// </summary>
    private async Task<ExtendedGetStatusResult> HandleGetStatusAsync()
    {
        var telemetry = await _sensorService.GetCurrentTelemetryAsync();
        
        return new ExtendedGetStatusResult
        {
            Connected = true,
            ClientsConnected = _securityService.ConnectedClientsCount,
            Uptime = (long)(DateTime.UtcNow - _startTime).TotalSeconds,
            AdminLevel = telemetry.AdminLevel,
            Version = "1.0.0",
            Cpu = new CpuStatus
            {
                Usage = telemetry.System.Cpu.Usage,
                Temp = telemetry.System.Cpu.Temp,
                Name = telemetry.System.Cpu.Name
            },
            Gpu = new GpuStatus
            {
                Usage = telemetry.System.Gpu.Usage,
                Temp = telemetry.System.Gpu.Temp,
                Name = telemetry.System.Gpu.Name
            },
            Ram = new RamStatus
            {
                Used = telemetry.System.Ram.Used,
                Total = telemetry.System.Ram.Total,
                UsedPercent = telemetry.System.Ram.UsedPercent
            },
            Gaming = telemetry.Gaming != null ? new GamingStatus
            {
                IsActive = telemetry.Gaming.IsActive,
                Fps = telemetry.Gaming.Fps,
                Fps1Low = telemetry.Gaming.Fps1Low,
                ActiveProcess = telemetry.Gaming.ActiveProcess
            } : null
        };
    }

    /// <summary>
    ///     get_config → текущие настройки
    /// </summary>
    private GetConfigResult HandleGetConfig()
    {
        return new GetConfigResult
        {
            Server = new ServerConfig
            {
                Port = _settings.Server.Port,
                PollingIntervalMs = _settings.Server.PollingIntervalMs,
                MaxConnections = _settings.Server.MaxConnections
            },
            Hardware = new HardwareConfig
            {
                EnableCpu = _settings.Hardware.EnableCpu,
                EnableGpu = _settings.Hardware.EnableGpu,
                EnableRam = _settings.Hardware.EnableRam,
                EnableStorage = _settings.Hardware.EnableStorage,
                EnableNetwork = _settings.Hardware.EnableNetwork
            },
            Gaming = new GamingConfig
            {
                EnableGamingDetection = _settings.Hardware.EnableGamingDetection,
                GpuUsageThreshold = _settings.Gaming.GpuUsageThreshold,
                CpuUsageThreshold = _settings.Gaming.CpuUsageThreshold
            }
        };
    }

    /// <summary>
    ///     set_polling_interval → обновить интервал опроса сенсоров
    /// </summary>
    private object HandleSetPollingInterval(CommandRequest request)
    {
        if (request.Params?.TryGetValue("intervalMs", out var intervalValue) == true)
        {
            var interval = intervalValue?.ToString();
            if (int.TryParse(interval, out var ms))
            {
                ms = Math.Clamp(ms, 100, 5000);
                _sensorService.SetPollingInterval(ms);
                _logger?.LogInformation("Polling interval changed to {Interval}ms by client", ms);
                return new { success = true, intervalMs = ms };
            }
        }
        return new { success = false, error = "Invalid interval parameter" };
    }

    /// <summary>
    ///     shutdown → выключение системы (ТРЕБУЕТ PERMISSION)
    /// </summary>
    private CommandResponse HandleShutdown()
    {
        if (!_settings.Security.DangerousCommandsEnabled)
        {
            _logger?.LogWarning("Shutdown command blocked - dangerous commands disabled");
            return CreateErrorResponse("shutdown", "Shutdown command is disabled");
        }

        _logger?.LogWarning("Shutdown command executed by client");
        
        // Запуск выключения в фоновом режиме
        _ = Task.Run(() =>
        {
            Thread.Sleep(2000); // Дать время отправить ответ
            Process.Start("shutdown", "/s /t 0 /f");
        });

        return CreateSuccessResponse("shutdown", new { shutdown = true, message = "System will shutdown" });
    }

    /// <summary>
    ///     restart → перезагрузка системы (ТРЕБУЕТ PERMISSION)
    /// </summary>
    private CommandResponse HandleRestart()
    {
        if (!_settings.Security.DangerousCommandsEnabled)
        {
            _logger?.LogWarning("Restart command blocked - dangerous commands disabled");
            return CreateErrorResponse("restart", "Restart command is disabled");
        }

        _logger?.LogWarning("Restart command executed by client");
        
        // Запуск перезагрузки в фоновом режиме
        _ = Task.Run(() =>
        {
            Thread.Sleep(2000); // Дать время отправить ответ
            Process.Start("shutdown", "/r /t 0 /f");
        });

        return CreateSuccessResponse("restart", new { restart = true, message = "System will restart" });
    }

    /// <summary>
    ///     Создать успешный ответ
    /// </summary>
    private CommandResponse CreateSuccessResponse(string command, object result)
    {
        return new CommandResponse
        {
            Success = true,
            Command = command,
            Result = result,
            Timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds()
        };
    }

    /// <summary>
    ///     Создать ответ об ошибке
    /// </summary>
    private CommandResponse CreateErrorResponse(string command, string error)
    {
        return new CommandResponse
        {
            Success = false,
            Command = command,
            Error = error,
            Timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds()
        };
    }
}

/// <summary>
///     Расширенный статус для get_status
/// </summary>
public class ExtendedGetStatusResult : GetStatusResult
{
    public CpuStatus? Cpu { get; set; }
    public GpuStatus? Gpu { get; set; }
    public RamStatus? Ram { get; set; }
    public GamingStatus? Gaming { get; set; }
}

/// <summary>
///     Расширенный статус CPU
/// </summary>
public class CpuStatus
{
    public double Usage { get; set; }
    public double Temp { get; set; }
    public string Name { get; set; } = string.Empty;
}

/// <summary>
///     Расширенный статус GPU
/// </summary>
public class GpuStatus
{
    public double Usage { get; set; }
    public double Temp { get; set; }
    public string Name { get; set; } = string.Empty;
}

/// <summary>
///     Расширенный статус RAM
/// </summary>
public class RamStatus
{
    public double Used { get; set; }
    public double Total { get; set; }
    public double UsedPercent { get; set; }
}

/// <summary>
///     Расширенный статус Gaming
/// </summary>
public class GamingStatus
{
    public bool IsActive { get; set; }
    public int? Fps { get; set; }
    public int? Fps1Low { get; set; }
    public string? ActiveProcess { get; set; }
}
