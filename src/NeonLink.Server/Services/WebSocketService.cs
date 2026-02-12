using System.Collections.Concurrent;
using System.Net;
using System.Net.WebSockets;
using System.Text;
using Microsoft.Extensions.Logging;
using NeonLink.Server.Configuration;
using NeonLink.Server.Models;
using NeonLink.Server.Utilities;

namespace NeonLink.Server.Services;

/// <summary>
///     WebSocket сервер для коммуникации с Android клиентом
///     Согласно плану v2.0 - конкретная реализация с System.Net.WebSockets
/// </summary>
public class WebSocketService : IDisposable
{
    private readonly ILogger<WebSocketService>? _logger;
    private readonly TelemetryChannelService _channelService;
    private readonly SecurityService _securityService;
    private readonly SensorService _sensorService;
    private readonly Settings _settings;
    
    // Активные подключения
    private readonly ConcurrentDictionary<string, WebSocket> _clients = new();
    private readonly SemaphoreSlim _connectionLock = new(5, 5); // Max 5 connections
    
    private readonly CancellationTokenSource _cts = new();
    private bool _disposed;

    // Время запуска для uptime
    private readonly DateTime _startTime;

    public WebSocketService(
        ILogger<WebSocketService>? logger,
        TelemetryChannelService channelService,
        SecurityService securityService,
        SensorService sensorService,
        Settings settings)
    {
        _logger = logger;
        _channelService = channelService;
        _securityService = securityService;
        _sensorService = sensorService;
        _settings = settings;
        _startTime = DateTime.UtcNow;

        _logger?.LogInformation("WebSocketService initialized");
    }

    /// <summary>
    ///     Принять WebSocket соединение
    /// </summary>
    public async Task<bool> AcceptConnectionAsync(
        WebSocket socket,
        string remoteIp,
        string? clientId = null)
    {
        // Проверка лимита подключений
        if (_clients.Count >= _settings.Server.MaxConnections)
        {
            _logger?.LogWarning("Max connections reached, rejecting {Ip}", remoteIp);
            await CloseSocketAsync(socket, "Max connections reached");
            return false;
        }

        // Проверка IP
        if (!_securityService.IsConnectionAllowed(remoteIp))
        {
            _logger?.LogWarning("Connection from non-local IP rejected: {Ip}", remoteIp);
            await CloseSocketAsync(socket, "Connection not allowed");
            return false;
        }

        // Получение или создание ID клиента
        var actualClientId = clientId ?? _securityService.RegisterClient(remoteIp);

        // Попытка добавить в semaphore
        if (!await _connectionLock.WaitAsync(5000, _cts.Token))
        {
            _logger?.LogWarning("Connection timeout for client {Id}", actualClientId);
            await CloseSocketAsync(socket, "Connection timeout");
            return false;
        }

        try
        {
            // Добавление клиента
            _clients.TryAdd(actualClientId, socket);
            
            _logger?.LogInformation(
                "WebSocket connected: {Id} from {Ip}, total: {Count}",
                actualClientId, remoteIp, _clients.Count);

            // Отправка начального статуса клиенту
            await SendInitialStatusAsync(socket, actualClientId);

            // Запуск обработки
            await HandleConnectionAsync(socket, actualClientId);

            return true;
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Error handling WebSocket connection for {Id}", actualClientId);
            return false;
        }
        finally
        {
            // Удаление клиента
            RemoveClient(actualClientId);
            _connectionLock.Release();
        }
    }

    /// <summary>
    ///     Отправка начального статуса при подключении
    /// </summary>
    private async Task SendInitialStatusAsync(WebSocket socket, string clientId)
    {
        var status = new
        {
            connected = true,
            clientId,
            server = "NeonLink Server",
            version = "1.0.0",
            timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds()
        };
        
        var response = JsonHelper.CreateSuccessResponse("connect", status);
        await SendMessageAsync(socket, clientId, response);
    }

    /// <summary>
    ///     Обработка соединения - receive loop
    /// </summary>
    private async Task HandleConnectionAsync(WebSocket socket, string clientId)
    {
        var buffer = new byte[4096];

        try
        {
            while (!_cts.Token.IsCancellationRequested && socket.State == WebSocketState.Open)
            {
                // Получение сообщения
                WebSocketReceiveResult result;
                var messageBuilder = new StringBuilder();

                do
                {
                    result = await socket.ReceiveAsync(
                        new ArraySegment<byte>(buffer),
                        _cts.Token);

                    if (result.MessageType == WebSocketMessageType.Close)
                    {
                        _logger?.LogInformation("Client {Id} disconnected: {Status}", 
                            clientId, result.CloseStatusDescription);
                        return;
                    }

                    if (result.MessageType == WebSocketMessageType.Text)
                    {
                        messageBuilder.Append(
                            Encoding.UTF8.GetString(buffer, 0, result.Count));
                    }
                } while (!result.EndOfMessage);

                var message = messageBuilder.ToString();
                
                if (!string.IsNullOrEmpty(message))
                {
                    await ProcessMessageAsync(socket, clientId, message);
                }
            }
        }
        catch (WebSocketException ex) when (ex.WebSocketErrorCode == WebSocketError.ConnectionClosedPrematurely)
        {
            _logger?.LogDebug("Connection closed prematurely by client {Id}", clientId);
        }
        catch (OperationCanceledException)
        {
            // Нормальное завершение
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Error in WebSocket loop for client {Id}", clientId);
        }
        finally
        {
            RemoveClient(clientId);
        }
    }

    /// <summary>
    ///     Обработка входящего сообщения
    /// </summary>
    private async Task ProcessMessageAsync(
        WebSocket socket,
        string clientId,
        string message)
    {
        _securityService.UpdateClientActivity(clientId);

        // Rate limiting check
        if (_securityService.IsRateLimited(clientId))
        {
            await SendErrorAsync(socket, clientId, "Rate limit exceeded");
            return;
        }

        // Десериализация команды
        if (!JsonHelper.TryDeserialize<CommandRequest>(message, out var command))
        {
            await SendErrorAsync(socket, clientId, "Invalid command format");
            return;
        }

        if (command == null)
        {
            await SendErrorAsync(socket, clientId, "Command is null");
            return;
        }

        // Валидация команды через whitelist
        var validation = _securityService.ValidateCommand(command);
        if (!validation.IsValid)
        {
            await SendErrorAsync(socket, clientId, validation.Error ?? "Command not allowed");
            return;
        }

        // Логирование команды
        _logger?.LogDebug("Command from {Id}: {Command}", clientId, command.Command);

        // Выполнение команды
        await ExecuteCommandAsync(socket, clientId, command, validation);
    }

    /// <summary>
    ///     Выполнение команды
    /// </summary>
    private async Task ExecuteCommandAsync(
        WebSocket socket,
        string clientId,
        CommandRequest command,
        CommandValidationResult validation)
    {
        try
        {
            var result = command.Command.ToLowerInvariant() switch
            {
                "ping" => new { pong = true, timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds() },
                
                "get_status" => new GetStatusResult
                {
                    Connected = true,
                    ClientsConnected = _clients.Count,
                    Uptime = (long)(DateTime.UtcNow - _startTime).TotalSeconds,
                    AdminLevel = "Full",
                    Version = "1.0.0"
                },
                
                "get_config" => _securityService.GetStats(),
                
                "get_telemetry" => new { streaming = true },
                
                "set_polling_interval" => HandleSetPollingInterval(command),
                
                _ => throw new ArgumentException($"Unknown command: {command.Command}")
            };

            var response = JsonHelper.CreateSuccessResponse(command.Command, result);
            await SendMessageAsync(socket, clientId, response);
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Error executing command {Command}", command.Command);
            await SendErrorAsync(socket, clientId, $"Error: {ex.Message}");
        }
    }

    /// <summary>
    ///     Обработка set_polling_interval
    /// </summary>
    private object HandleSetPollingInterval(CommandRequest command)
    {
        if (command.Params?.TryGetValue("intervalMs", out var intervalValue) == true)
        {
            var interval = intervalValue?.ToString();
            if (int.TryParse(interval, out var ms))
            {
                ms = Math.Clamp(ms, 100, 5000);
                _sensorService.SetPollingInterval(ms);
                _logger?.LogInformation("Polling interval updated to {Interval}ms by client", ms);
                return new { success = true, intervalMs = ms };
            }
        }
        return new { success = false, error = "Invalid interval" };
    }

    /// <summary>
    ///     Отправка сообщения клиенту
    /// </summary>
    private async Task SendMessageAsync(WebSocket socket, string clientId, string message)
    {
        try
        {
            if (socket.State != WebSocketState.Open)
                return;

            var bytes = Encoding.UTF8.GetBytes(message);
            await socket.SendAsync(
                new ArraySegment<byte>(bytes),
                WebSocketMessageType.Text,
                true,
                _cts.Token);
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Error sending message to {Id}", clientId);
        }
    }

    #region Telemetry Broadcasting

    /// <summary>
    ///     Запуск broadcasting телеметрии всем клиентам
    ///     Читает из TelemetryChannel и рассылает всем подключенным клиентам
    /// </summary>
    public async Task StartTelemetryBroadcastingAsync()
    {
        _logger?.LogInformation("Starting telemetry broadcasting loop");

        try
        {
            await foreach (var telemetry in _channelService.SubscribeAsync(_cts.Token))
            {
                await BroadcastTelemetryAsync(telemetry);
            }
        }
        catch (OperationCanceledException)
        {
            _logger?.LogInformation("Telemetry broadcasting loop cancelled");
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Error in telemetry broadcasting loop");
        }
    }

    /// <summary>
    ///     Рассылка телеметрии всем подключенным клиентам
    /// </summary>
    private async Task BroadcastTelemetryAsync(TelemetryData telemetry)
    {
        if (_clients.IsEmpty)
            return;

        // Создаем компактное сообщение для broadcasting
        var message = JsonHelper.Serialize(telemetry);
        var bytes = Encoding.UTF8.GetBytes(message);
        var tasks = new List<Task>();

        // Отправка всем клиентам параллельно
        foreach (var (clientId, socket) in _clients)
        {
            tasks.Add(BroadcastToClientAsync(socket, clientId, bytes));
        }

        try
        {
            await Task.WhenAll(tasks);
        }
        catch (Exception ex)
        {
            _logger?.LogDebug(ex, "Error broadcasting telemetry to some clients");
        }
    }

    /// <summary>
    ///     Отправка телеметрии одному клиенту
    /// </summary>
    private async Task BroadcastToClientAsync(WebSocket socket, string clientId, byte[] data)
    {
        try
        {
            if (socket.State != WebSocketState.Open)
            {
                RemoveClient(clientId);
                return;
            }

            await socket.SendAsync(
                new ArraySegment<byte>(data),
                WebSocketMessageType.Text,
                true,
                _cts.Token);
        }
        catch (WebSocketException)
        {
            RemoveClient(clientId);
        }
        catch (Exception ex)
        {
            _logger?.LogDebug(ex, "Error broadcasting to client {Id}", clientId);
            RemoveClient(clientId);
        }
    }

    #endregion

    #region Telemetry Streaming (per-client)

    /// <summary>
    ///     Отправка ошибки клиенту
    /// </summary>
    private async Task SendErrorAsync(
        WebSocket socket,
        string clientId,
        string error)
    {
        var response = JsonHelper.CreateErrorResponse(error, "400");
        await SendMessageAsync(socket, clientId, response);
    }

    /// <summary>
    ///     Закрытие сокета
    /// </summary>
    private async Task CloseSocketAsync(
        WebSocket socket,
        string reason)
    {
        try
        {
            if (socket.State == WebSocketState.Open)
            {
                await socket.CloseAsync(
                    WebSocketCloseStatus.NormalClosure,
                    reason,
                    _cts.Token);
            }
        }
        catch (Exception ex)
        {
            _logger?.LogDebug(ex, "Error closing socket: {Reason}", reason);
        }
    }

    /// <summary>
    ///     Удаление клиента
    /// </summary>
    private void RemoveClient(string clientId)
    {
        if (_clients.TryRemove(clientId, out _))
        {
            _securityService.UnregisterClient(clientId);
            _logger?.LogInformation(
                "Client removed: {Id}, remaining: {Count}",
                clientId, _clients.Count);
        }
    }

    /// <summary>
    ///     Получить количество подключенных клиентов
    /// </summary>
    public int ConnectedClientsCount => _clients.Count;

    #endregion

    /// <summary>
    ///     Проверить, подключен ли клиент
    /// </summary>
    public bool IsClientConnected(string clientId)
    {
        return _clients.ContainsKey(clientId);
    }

    public void Dispose()
    {
        if (_disposed)
            return;

        _cts.Cancel();
        
        // Закрыть все соединения
        foreach (var (clientId, socket) in _clients)
        {
            try
            {
                if (socket.State == WebSocketState.Open)
                {
                    socket.CloseAsync(
                        WebSocketCloseStatus.NormalClosure,
                        "Server shutdown",
                        CancellationToken.None).Wait(5000);
                }
            }
            catch
            {
                // ignored
            }
        }

        _clients.Clear();
        _cts.Dispose();
        _disposed = true;
        
        _logger?.LogInformation("WebSocketService disposed");
    }
}
