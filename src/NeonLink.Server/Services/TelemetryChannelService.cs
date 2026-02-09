using System.Threading.Channels;
using NeonLink.Server.Models;

namespace NeonLink.Server.Services;

/// <summary>
///     Producer-Consumer паттерн для телеметрии
///     Согласно плану v2.0 - критически важно для thread-safe data flow
///     Channel<T> обеспе bufferчивает bounded для backpressure
/// </summary>
public class TelemetryChannelService : IDisposable
{
    private readonly ILogger<TelemetryChannelService>? _logger;
    
    // Bounded channel для control backpressure
    // При превышении лимита старые сообщения будут отбрасываться
    private readonly Channel<TelemetryData> _channel;
    
    private readonly CancellationTokenSource _cts = new();
    private bool _disposed;

    /// <summary>
    ///     Поток телеметрии для подписчиков
    /// </summary>
    public ChannelReader<TelemetryData> Reader => _channel.Reader;

    /// <summary>
    ///     Максимальное количество сообщений в буфере
    /// </summary>
    public int MaxBufferSize => 100;

    public TelemetryChannelService(ILogger<TelemetryChannelService>? logger = null)
    {
        _logger = logger;
        
        // Создаем bounded channel
        _channel = Channel.CreateBounded<TelemetryData>(new BoundedChannelOptions(MaxBufferSize)
        {
            // При переполнении - отбрасывать старые сообщения
            FullMode = BoundedChannelFullMode.DropOldest,
            // Разрешить множественных читателей
            SingleReader = false,
            SingleWriter = false
        });

        _logger?.LogInformation("TelemetryChannelService initialized with buffer size: {Size}", MaxBufferSize);
    }

    /// <summary>
    ///     Producer: Записать данные телеметрии в канал
    ///     Вызывается из SensorService
    /// </summary>
    public async Task WriteTelemetryAsync(TelemetryData data)
    {
        if (_disposed)
            return;

        try
        {
            // Попытка записать с таймаутом
            var written = await _channel.Writer.WaitToWriteAsync(_cts.Token);
            
            if (written)
            {
                await _channel.Writer.WriteAsync(data, _cts.Token);
                _logger?.LogDebug("Telemetry written to channel: CPU={Cpu}%, GPU={GPU}%",
                    data.System.Cpu.Usage, data.System.Gpu.Usage);
            }
        }
        catch (ChannelClosedException)
        {
            _logger?.LogWarning("Telemetry channel is closed");
        }
        catch (OperationCanceledException)
        {
            // Нормальное завершение
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Error writing telemetry to channel");
        }
    }

    /// <summary>
    ///     Синхронная запись (для SensorService polling loop)
    /// </summary>
    public bool WriteTelemetry(TelemetryData data)
    {
        if (_disposed)
            return false;

        try
        {
            // Попытка записать синхронно (неблокирующая)
            return _channel.Writer.TryWrite(data);
        }
        catch
        {
            return false;
        }
    }

    /// <summary>
    ///     Получить последние N сообщений
    /// </summary>
    public async Task<List<TelemetryData>> GetRecentDataAsync(int count = 60)
    {
        var result = new List<TelemetryData>();
        var buffer = new List<TelemetryData>(count + 1);

        // Собираем все доступные сообщения
        while (buffer.Count < count + 1 && _channel.Reader.TryRead(out var data))
        {
            buffer.Add(data);
        }

        // Возвращаем последние N сообщений
        var startIndex = Math.Max(0, buffer.Count - count);
        result.AddRange(buffer.Skip(startIndex));

        return result;
    }

    /// <summary>
    ///     Подписаться на поток телеметрии (async enumerable)
    /// </summary>
    public async IAsyncEnumerable<TelemetryData> SubscribeAsync(
        [System.Runtime.CompilerServices.EnumeratorCancellation] CancellationToken ct = default)
    {
        while (!ct.IsCancellationRequested)
        {
            TelemetryData? data = null;
            try
            {
                data = await _channel.Reader.ReadAsync(ct);
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (ChannelClosedException)
            {
                break;
            }
            
            if (data != null)
                yield return data;
        }
    }

    /// <summary>
    ///     Проверить, доступны ли новые данные
    /// </summary>
    public bool HasData => _channel.Reader.TryPeek(out _);

    /// <summary>
    ///     Количество сообщений в буфере
    /// </summary>
    public int BufferedCount => _channel.Reader.Count;

    /// <summary>
    ///     Закрыть канал
    /// </summary>
    public void Close()
    {
        if (!_channel.Writer.TryComplete())
        {
            _logger?.LogDebug("Telemetry channel was already closed");
        }
        else
        {
            _logger?.LogInformation("Telemetry channel closed");
        }
    }

    public void Dispose()
    {
        if (_disposed)
            return;

        _cts.Cancel();
        Close();
        _cts.Dispose();
        _disposed = true;
        _logger?.LogInformation("TelemetryChannelService disposed");
    }
}
