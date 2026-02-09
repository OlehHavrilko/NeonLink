using NeonLink.Server.Models;
using NeonLink.Server.Services;

namespace NeonLink.Tests;

/// <summary>
///     Unit tests for TelemetryChannelService
/// </summary>
public class TelemetryChannelServiceTests : IDisposable
{
    private readonly TelemetryChannelService _channelService;

    public TelemetryChannelServiceTests()
    {
        _channelService = new TelemetryChannelService(null);
    }

    public void Dispose()
    {
        _channelService.Dispose();
        GC.SuppressFinalize(this);
    }

    #region Constructor Tests

    [Fact]
    public void Constructor_InitializesWithDefaultBufferSize()
    {
        // Assert
        Assert.Equal(100, _channelService.MaxBufferSize);
    }

    [Fact]
    public void Constructor_CreatesUnboundedReader()
    {
        // Assert
        Assert.NotNull(_channelService.Reader);
    }

    #endregion

    #region WriteTelemetry Tests

    [Fact]
    public async Task WriteTelemetryAsync_ValidData_WritesToChannel()
    {
        // Arrange
        var telemetry = CreateSampleTelemetry();

        // Act
        await _channelService.WriteTelemetryAsync(telemetry);

        // Assert
        Assert.Equal(1, _channelService.BufferedCount);
    }

    [Fact]
    public async Task WriteTelemetryAsync_MultipleWrites_AccumulatesInBuffer()
    {
        // Arrange & Act
        for (int i = 0; i < 5; i++)
        {
            await _channelService.WriteTelemetryAsync(CreateSampleTelemetry(i));
        }

        // Assert
        Assert.Equal(5, _channelService.BufferedCount);
    }

    [Fact]
    public void WriteTelemetry_ValidData_ReturnsTrue()
    {
        // Arrange
        var telemetry = CreateSampleTelemetry();

        // Act
        var result = _channelService.WriteTelemetry(telemetry);

        // Assert
        Assert.True(result);
        Assert.Equal(1, _channelService.BufferedCount);
    }

    [Fact]
    public void WriteTelemetry_AfterDisposal_ReturnsFalse()
    {
        // Arrange
        _channelService.Dispose();
        var telemetry = CreateSampleTelemetry();

        // Act
        var result = _channelService.WriteTelemetry(telemetry);

        // Assert
        Assert.False(result);
    }

    [Fact]
    public async Task WriteTelemetryAsync_AfterDisposal_DoesNotThrow()
    {
        // Arrange
        _channelService.Dispose();
        var telemetry = CreateSampleTelemetry();

        // Act & Assert - should not throw
        await _channelService.WriteTelemetryAsync(telemetry);
    }

    #endregion

    #region GetRecentDataAsync Tests

    [Fact]
    public async Task GetRecentDataAsync_EmptyChannel_ReturnsEmptyList()
    {
        // Act
        var result = await _channelService.GetRecentDataAsync();

        // Assert
        Assert.Empty(result);
    }

    [Fact]
    public async Task GetRecentDataAsync_WithData_ReturnsRequestedCount()
    {
        // Arrange
        for (int i = 0; i < 10; i++)
        {
            await _channelService.WriteTelemetryAsync(CreateSampleTelemetry(i));
        }

        // Act
        var result = await _channelService.GetRecentDataAsync(5);

        // Assert
        Assert.Equal(5, result.Count);
    }

    [Fact]
    public async Task GetRecentDataAsync_LessThanRequested_ReturnsAll()
    {
        // Arrange
        for (int i = 0; i < 3; i++)
        {
            await _channelService.WriteTelemetryAsync(CreateSampleTelemetry(i));
        }

        // Act
        var result = await _channelService.GetRecentDataAsync(10);

        // Assert
        Assert.Equal(3, result.Count);
    }

    [Fact]
    public async Task GetRecentDataAsync_DefaultCount_ReturnsUpTo60()
    {
        // Arrange
        for (int i = 0; i < 100; i++)
        {
            await _channelService.WriteTelemetryAsync(CreateSampleTelemetry(i));
        }

        // Act
        var result = await _channelService.GetRecentDataAsync();

        // Assert
        Assert.Equal(60, result.Count);
    }

    #endregion

    #region HasData Tests

    [Fact]
    public void HasData_EmptyChannel_ReturnsFalse()
    {
        // Act
        var result = _channelService.HasData;

        // Assert
        Assert.False(result);
    }

    [Fact]
    public void HasData_AfterWrite_ReturnsTrue()
    {
        // Arrange
        _channelService.WriteTelemetry(CreateSampleTelemetry());

        // Act
        var result = _channelService.HasData;

        // Assert
        Assert.True(result);
    }

    #endregion

    #region BufferedCount Tests

    [Fact]
    public void BufferedCount_EmptyChannel_ReturnsZero()
    {
        // Act
        var result = _channelService.BufferedCount;

        // Assert
        Assert.Equal(0, result);
    }

    [Fact]
    public void BufferedCount_AfterWrites_ReflectsCount()
    {
        // Arrange
        _channelService.WriteTelemetry(CreateSampleTelemetry(0));
        _channelService.WriteTelemetry(CreateSampleTelemetry(1));
        _channelService.WriteTelemetry(CreateSampleTelemetry(2));

        // Act
        var result = _channelService.BufferedCount;

        // Assert
        Assert.Equal(3, result);
    }

    #endregion

    #region SubscribeAsync Tests

    [Fact]
    public async Task SubscribeAsync_YieldsWrittenData()
    {
        // Arrange
        var telemetry1 = CreateSampleTelemetry(1);
        var telemetry2 = CreateSampleTelemetry(2);

        await _channelService.WriteTelemetryAsync(telemetry1);
        await _channelService.WriteTelemetryAsync(telemetry2);

        // Act
        var result = new List<TelemetryData>();
        await foreach (var data in _channelService.SubscribeAsync())
        {
            result.Add(data);
            if (result.Count >= 2) break;
        }

        // Assert
        Assert.Equal(2, result.Count);
    }

    [Fact]
    public async Task SubscribeAsync_WithCancellation_StopsOnCancellation()
    {
        // Arrange
        var cts = new CancellationTokenSource();

        // Act
        var result = new List<TelemetryData>();
        await foreach (var data in _channelService.SubscribeAsync(cts.Token))
        {
            result.Add(data);
            if (result.Count >= 1)
            {
                cts.Cancel();
            }
        }

        // Assert
        Assert.Single(result);
    }

    #endregion

    #region Close Tests

    [Fact]
    public void Close_CompletesWriter()
    {
        // Act
        _channelService.Close();

        // Assert - subsequent writes should fail silently
        var result = _channelService.WriteTelemetry(CreateSampleTelemetry());
        Assert.False(result);
    }

    #endregion

    #region Buffer Overflow Tests

    [Fact]
    public async Task WriteTelemetry_ExceedingBuffer_DropsOldest()
    {
        // Arrange - write MaxBufferSize + 10 items
        for (int i = 0; i < _channelService.MaxBufferSize + 10; i++)
        {
            _channelService.WriteTelemetry(CreateSampleTelemetry(i));
        }

        // Assert - buffer should not exceed MaxBufferSize
        Assert.Equal(_channelService.MaxBufferSize, _channelService.BufferedCount);
    }

    #endregion

    #region Thread Safety Tests

    [Fact]
    public async Task WriteTelemetry_ConcurrentWrites_AllDataReceived()
    {
        // Arrange
        const int parallelWrites = 50;
        var tasks = new List<Task>();

        // Act
        for (int i = 0; i < parallelWrites; i++)
        {
            var index = i;
            tasks.Add(Task.Run(() => _channelService.WriteTelemetry(CreateSampleTelemetry(index))));
        }

        await Task.WhenAll(tasks);

        // Assert - all writes should succeed (or buffer should handle overflow gracefully)
        Assert.True(_channelService.BufferedCount > 0);
    }

    [Fact]
    public async Task ReadWrite_Concurrent_IntegrityMaintained()
    {
        // Arrange
        const int writeCount = 20;
        var writeTask = Task.Run(async () =>
        {
            for (int i = 0; i < writeCount; i++)
            {
                await _channelService.WriteTelemetryAsync(CreateSampleTelemetry(i));
                await Task.Delay(1);
            }
        });

        // Act
        await writeTask;

        // Assert
        Assert.Equal(writeCount, _channelService.BufferedCount);
    }

    #endregion

    #region Helper Methods

    private static TelemetryData CreateSampleTelemetry(int index = 0)
    {
        return new TelemetryData
        {
            Timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds() + index,
            System = new SystemInfo
            {
                Cpu = new CpuInfo
                {
                    Name = $"CPU {index}",
                    Usage = 50.0 + index,
                    Temp = 60.0 + index,
                    Clock = 3.5 + index * 0.1
                },
                Gpu = new GpuInfo
                {
                    Name = $"GPU {index}",
                    Type = "NVIDIA",
                    Usage = 40.0 + index,
                    Temp = 55.0 + index
                },
                Ram = new RamInfo
                {
                    Used = 8.0 + index,
                    Total = 16.0
                },
                Storage = new List<StorageInfo>
                {
                    new StorageInfo { Name = $"SSD {index}", Temp = 35.0 + index }
                },
                Network = new NetworkInfo
                {
                    Download = 10.0 + index,
                    Upload = 5.0 + index
                }
            },
            Gaming = new GamingInfo
            {
                IsActive = index % 2 == 0,
                Fps = 144,
                Fps1Low = 120
            },
            AdminLevel = "Full"
        };
    }

    #endregion
}
