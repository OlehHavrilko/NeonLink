using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using NeonLink.Server.Configuration;
using NeonLink.Server.Services;
using Serilog;
using Serilog.Events;

namespace NeonLink.Server;

/// <summary>
///     Главный класс приложения NeonLink Server
/// </summary>
public class Program
{
    private static ILogger<Program>? _logger;
    private static IHost? _host;
    private static readonly CancellationTokenSource _cts = new();

    public static async Task Main(string[] args)
    {
        try
        {
            // Инициализация логирования
            InitializeLogging();

            _logger?.LogInformation("Starting NeonLink Server v1.0.0");

            // Загрузка конфигурации
            var configuration = LoadConfiguration();
            var settings = configuration.Get<Settings>() ?? new Settings();

            // Проверка прав администратора
            var adminChecker = new AdminRightsChecker(null);
            var adminResult = adminChecker.CheckAdminLevel();

            _logger?.LogInformation(
                "Admin level: {Level}, Available sensors: {Sensors}",
                adminResult.Level,
                string.Join(", ", adminResult.AvailableSensors));

            // Настройка и запуск хоста
            _host = CreateHostBuilder(args, settings, adminChecker).Build();

            // Запуск сервисов
            await _host.StartAsync(_cts.Token);

            _logger?.LogInformation("NeonLink Server started successfully");
            _logger?.LogInformation("WebSocket endpoint: ws://*:{Port}/ws", settings.Server.Port);
            _logger?.LogInformation("Press Ctrl+C to stop...");

            // Ожидание сигнала завершения
            await WaitForShutdownAsync();

            _logger?.LogInformation("Shutting down...");
            await _host.StopAsync(TimeSpan.FromSeconds(10));
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Fatal error during startup");
            throw;
        }
        finally
        {
            Log.CloseAndFlush();
        }
    }

    /// <summary>
    ///     Инициализация Serilog логирования
    /// </summary>
    private static void InitializeLogging()
    {
        var logsDirectory = "logs";

        // Создать директорию для логов если не существует
        if (!Directory.Exists(logsDirectory))
        {
            Directory.CreateDirectory(logsDirectory);
        }

        Log.Logger = new LoggerConfiguration()
            .MinimumLevel.Is(Enum.Parse<LogEventLevel>(
                GetEnvironmentVariable("NEONLINK_LOG_LEVEL", "Information")))
            .WriteTo.Console(
                outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}")
            .WriteTo.File(
                path: Path.Combine(logsDirectory, "neonlink-.txt"),
                rollingInterval: RollingInterval.Day,
                retainedFileCountLimit: 7,
                outputTemplate: "[{Timestamp:yyyy-MM-dd HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}")
            .CreateLogger();

        _logger = new Logger<Program>(new LoggerFactory());
    }

    /// <summary>
    ///     Загрузка конфигурации
    /// </summary>
    private static IConfiguration LoadConfiguration()
    {
        return new ConfigurationBuilder()
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("appsettings.json", optional: true, reloadOnChange: false)
            .AddJsonFile($"appsettings.{Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Production"}.json",
                optional: true, reloadOnChange: false)
            .AddEnvironmentVariables()
            .Build();
    }

    /// <summary>
    ///     Создание хоста
    /// </summary>
    private static IHostBuilder CreateHostBuilder(
        string[] args,
        Settings settings,
        AdminRightsChecker adminChecker)
    {
        return Host.CreateDefaultBuilder(args)
            .UseSerilog()
            .ConfigureWebHostDefaults(webBuilder =>
            {
                webBuilder.UseUrls($"http://*:{settings.Server.Port}");
                webBuilder.UseStartup<Startup>();
            })
            .ConfigureServices(services =>
            {
                // Регистрация сервисов
                services.AddSingleton(settings);
                services.AddSingleton<IAdminRightsChecker, AdminRightsChecker>();
                services.AddSingleton<TelemetryChannelService>();
                services.AddSingleton<SecurityService>();
                services.AddSingleton<SensorService>();
                services.AddSingleton<CacheService>();
                services.AddSingleton<CommandService>();
                services.AddSingleton<WebSocketService>();
            });
    }

    /// <summary>
    ///     Ожидание сигнала завершения
    /// </summary>
    private static async Task WaitForShutdownAsync()
    {
        try
        {
            // Ожидание Ctrl+C или SIGTERM
            await Task.Delay(-1, _cts.Token);
        }
        catch (OperationCanceledException)
        {
            // Нормальное завершение
        }
    }

    /// <summary>
    ///     Получение переменной окружения с默认值
    /// </summary>
    private static string GetEnvironmentVariable(string name, string defaultValue)
    {
        return Environment.GetEnvironmentVariable(name) ?? defaultValue;
    }
}

/// <summary>
///     Startup класс для настройки HTTP pipeline
/// </summary>
public class Startup
{
    public void ConfigureServices(IServiceCollection services)
    {
        // Добавление CORS для разработки
        services.AddCors(options =>
        {
            options.AddPolicy("AllowAll", policy =>
            {
                policy.AllowAnyOrigin()
                    .AllowAnyMethod()
                    .AllowAnyHeader();
            });
        });

        // Добавление контроллеров (для REST API если нужно)
        services.AddControllers();
    }

    public void Configure(
        IApplicationBuilder app, 
        IWebHostEnvironment env,
        WebSocketService wsService,
        ILogger<Startup> logger)
    {
        if (env.IsDevelopment())
        {
            app.UseDeveloperExceptionPage();
        }

        app.UseCors("AllowAll");

        // WebSocket middleware
        app.UseWebSockets(new WebSocketOptions
        {
            KeepAliveInterval = TimeSpan.FromSeconds(30)
        });

        app.UseRouting();
        app.UseEndpoints(endpoints =>
        {
            endpoints.MapControllers();
            endpoints.Map("/ws", async context =>
            {
                if (context.WebSockets.IsWebSocketRequest)
                {
                    var remoteIp = context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
                    using var socket = await context.WebSockets.AcceptWebSocketAsync();
                    await wsService.AcceptConnectionAsync(socket, remoteIp);
                }
                else
                {
                    context.Response.StatusCode = 400;
                }
            });
        });

        // Запуск broadcasting телеметрии в фоновом режиме
        _ = Task.Run(async () =>
        {
            logger.LogInformation("Starting telemetry broadcasting");
            await wsService.StartTelemetryBroadcastingAsync();
        });
    }
}
