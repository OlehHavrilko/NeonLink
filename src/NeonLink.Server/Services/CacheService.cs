using System.Collections.Concurrent;
using NeonLink.Server.Configuration;
using NeonLink.Server.Models;

namespace NeonLink.Server.Services;

/// <summary>
///     Сервис кеширования неизменяемых данных оборудования
///     Согласно плану v2.0: thread-safe caching с ReaderWriterLockSlim
/// </summary>
public class CacheService : IDisposable
{
    private readonly ILogger<CacheService>? _logger;
    private readonly Settings _settings;
    
    // ReaderWriterLockSlim для thread-safe доступа
    private readonly ReaderWriterLockSlim _cacheLock = new(LockRecursionPolicy.NoRecursion);
    
    // Кеш оборудования
    private readonly ConcurrentDictionary<string, CachedHardwareInfo> _hardwareCache = new();
    
    // Время последнего обновления hardware
    private DateTime _lastHardwareScan = DateTime.MinValue;
    private TimeSpan _cacheExpiration;
    
    // Флаг disposed
    private bool _disposed;

    public CacheService(ILogger<CacheService>? logger, Settings settings)
    {
        _logger = logger;
        _settings = settings;
        _cacheExpiration = TimeSpan.FromHours(1); // По умолчанию 1 час
        
        _logger?.LogInformation("CacheService initialized");
    }

    /// <summary>
    ///     Получить кешированную информацию о CPU
    /// </summary>
    public string? GetCpuName(string actualName)
    {
        return GetOrAdd("CpuName", actualName, () => actualName);
    }

    /// <summary>
    ///     Получить кешированную информацию о GPU
    /// </summary>
    public string? GetGpuName(string actualName)
    {
        return GetOrAdd("GpuName", actualName, () => actualName);
    }

    /// <summary>
    ///     Получить кешированный размер RAM
    /// </summary>
    public double GetRamTotal(double actualValue)
    {
        return GetOrAdd("RamTotal", actualValue, () => actualValue);
    }

    /// <summary>
    ///     Получить кешированную информацию о накопителе
    /// </summary>
    public StorageInfo? GetStorageInfo(string name, Func<StorageInfo?> fetcher)
    {
        var cacheKey = $"Storage_{name}";
        return _hardwareCache.TryGetValue(cacheKey, out var cached)
            ? cached.Value as StorageInfo
            : GetOrAdd(cacheKey, fetcher(), () => fetcher()) as StorageInfo;
    }

    /// <summary>
    ///     Получить полную кешированную информацию об оборудовании
    /// </summary>
    public CachedHardwareInfo GetCachedHardwareInfo()
    {
        _cacheLock.EnterReadLock();
        try
        {
            return new CachedHardwareInfo
            {
                CpuName = _hardwareCache.TryGetValue("CpuName", out var cpu) ? cpu.Value as string : null,
                GpuName = _hardwareCache.TryGetValue("GpuName", out var gpu) ? gpu.Value as string : null,
                RamTotal = _hardwareCache.TryGetValue("RamTotal", out var ram) ? (double?)(ram.Value ?? 0) : null,
                StorageInfo = _hardwareCache
                    .Where(k => k.Key.StartsWith("Storage_"))
                    .Select(k => k.Value.Value as StorageInfo)
                    .OfType<StorageInfo>()
                    .ToList(),
                LastUpdate = _lastHardwareScan
            };
        }
        finally
        {
            _cacheLock.ExitReadLock();
        }
    }

    /// <summary>
    ///     Проверить, нужно ли обновить кеш
    /// </summary>
    public bool ShouldRefreshCache()
    {
        _cacheLock.EnterReadLock();
        try
        {
            return DateTime.UtcNow - _lastHardwareScan > _cacheExpiration;
        }
        finally
        {
            _cacheLock.ExitReadLock();
        }
    }

    /// <summary>
    ///     Принудительно обновить кеш
    /// </summary>
    public void InvalidateCache()
    {
        _cacheLock.EnterWriteLock();
        try
        {
            _hardwareCache.Clear();
            _lastHardwareScan = DateTime.UtcNow;
            _logger?.LogInformation("Cache invalidated");
        }
        finally
        {
            _cacheLock.ExitWriteLock();
        }
    }

    /// <summary>
    ///     Обновить информацию о hardware (при обнаружении изменений)
    /// </summary>
    public void UpdateHardwareInfo(string key, object value)
    {
        _cacheLock.EnterWriteLock();
        try
        {
            _hardwareCache.AddOrUpdate(key, new CachedHardwareInfo
            {
                Key = key,
                Value = value,
                CachedAt = DateTime.UtcNow
            }, (_, existing) => new CachedHardwareInfo
            {
                Key = key,
                Value = value,
                CachedAt = DateTime.UtcNow
            });
            
            _lastHardwareScan = DateTime.UtcNow;
        }
        finally
        {
            _cacheLock.ExitWriteLock();
        }
    }

    /// <summary>
    ///     Получить или добавить значение в кеш
    /// </summary>
    private TValue GetOrAdd<TValue>(string key, TValue actualValue, Func<TValue> fetcher)
    {
        _cacheLock.EnterReadLock();
        try
        {
            if (_hardwareCache.TryGetValue(key, out var cached) && cached.Value is TValue cachedValue)
            {
                return cachedValue;
            }
        }
        finally
        {
            _cacheLock.ExitReadLock();
        }

        // Если не найден в кеше или истёк, добавляем
        _cacheLock.EnterWriteLock();
        try
        {
            // Double-check после получения write lock
            if (_hardwareCache.TryGetValue(key, out var cached) && cached.Value is TValue cachedValue)
            {
                return cachedValue;
            }

            var newValue = fetcher();
            _hardwareCache.AddOrUpdate(key, new CachedHardwareInfo
            {
                Key = key,
                Value = newValue!,
                CachedAt = DateTime.UtcNow
            }, (_, __) => new CachedHardwareInfo
            {
                Key = key,
                Value = newValue!,
                CachedAt = DateTime.UtcNow
            });

            return newValue;
        }
        finally
        {
            _cacheLock.ExitWriteLock();
        }
    }

    /// <summary>
    ///     Получить размер кеша
    /// </summary>
    public int CacheSize => _hardwareCache.Count;

    /// <summary>
    ///     Получить статистику кеша
    /// </summary>
    public CacheStats GetStats()
    {
        _cacheLock.EnterReadLock();
        try
        {
            return new CacheStats
            {
                ItemsCount = _hardwareCache.Count,
                LastHardwareScan = _lastHardwareScan,
                CacheExpirationMinutes = _cacheExpiration.TotalMinutes
            };
        }
        finally
        {
            _cacheLock.ExitReadLock();
        }
    }

    public void Dispose()
    {
        if (_disposed)
            return;

        _disposed = true;
        _cacheLock.Dispose();
        _logger?.LogInformation("CacheService disposed");
    }
}

/// <summary>
///     Кешированная информация о hardware
/// </summary>
public class CachedHardwareInfo
{
    public string Key { get; set; } = string.Empty;
    public object? Value { get; set; }
    public DateTime CachedAt { get; set; }
    
    // Удобные свойства для получения информации
    public string? CpuName { get; set; }
    public string? GpuName { get; set; }
    public double? RamTotal { get; set; }
    public List<StorageInfo>? StorageInfo { get; set; }
    public DateTime LastUpdate { get; set; }
}

/// <summary>
///     Статистика кеша
/// </summary>
public class CacheStats
{
    public int ItemsCount { get; set; }
    public DateTime LastHardwareScan { get; set; }
    public double CacheExpirationMinutes { get; set; }
}
