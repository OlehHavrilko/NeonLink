using System.Threading;
using System.Threading.Tasks;

namespace NeonLink.Server.Utilities;

/// <summary>
///     Вспомогательные методы для thread-safe операций
///     Согласно плану v2.0 - критически важно для LibreHardwareMonitor
/// </summary>
public static class ThreadSafeHelper
{
    /// <summary>
    ///     Асинхронный lock с использованием SemaphoreSlim
    ///     В отличие от lock(), поддерживает await
    /// </summary>
    public static async Task<T> WithLockAsync<T>(
        this SemaphoreSlim semaphore,
        Func<Task<T>> action)
    {
        await semaphore.WaitAsync();
        try
        {
            return await action();
        }
        finally
        {
            semaphore.Release();
        }
    }

    /// <summary>
    ///     Асинхронный lock без возврата значения
    /// </summary>
    public static async Task WithLockAsync(
        this SemaphoreSlim semaphore,
        Func<Task> action)
    {
        await semaphore.WaitAsync();
        try
        {
            await action();
        }
        finally
        {
            semaphore.Release();
        }
    }

    /// <summary>
    ///     Синхронный lock с возвратом значения
    /// </summary>
    public static T WithLock<T>(this SemaphoreSlim semaphore, Func<T> action)
    {
        semaphore.Wait();
        try
        {
            return action();
        }
        finally
        {
            semaphore.Release();
        }
    }

    /// <summary>
    ///     Синхронный lock без возврата значения
    /// </summary>
    public static void WithLock(this SemaphoreSlim semaphore, Action action)
    {
        semaphore.Wait();
        try
        {
            action();
        }
        finally
        {
            semaphore.Release();
        }
    }
}

/// <summary>
///     Асинхронный lazy initializer для thread-safe однократной инициализации
/// </summary>
public class AsyncLazy<T>
{
    private readonly SemaphoreSlim _mutex = new(1, 1);
    private readonly Func<Task<T>> _factory;
    private volatile bool _initialized;
    private T? _value;

    public AsyncLazy(Func<T> factory)
    {
        _factory = () => Task.Run(factory);
    }

    public AsyncLazy(Func<Task<T>> factory)
    {
        _factory = factory;
    }

    public Task<T> Value => _initialized ? Task.FromResult(_value!) : InitializeAsync();

    private async Task<T> InitializeAsync()
    {
        await _mutex.WaitAsync();
        try
        {
            if (!_initialized)
            {
                _value = await _factory();
                _initialized = true;
            }
            return _value!;
        }
        finally
        {
            _mutex.Release();
        }
    }

    /// <summary>
    ///     Синхронный доступ к значению (если уже инициализировано)
    /// </summary>
    public bool TryGetValue(out T? value)
    {
        value = _initialized ? _value : default;
        return _initialized;
    }
}

/// <summary>
///     Thread-safe кэш с expiration
/// </summary>
public class ThreadSafeCache<TKey, TValue> where TKey : notnull
{
    private readonly Dictionary<TKey, CacheEntry<TValue>> _cache = new();
    private readonly SemaphoreSlim _mutex = new(1, 1);
    private readonly TimeSpan _defaultExpiration;
    private readonly Func<TKey, TValue> _valueFactory;

    public ThreadSafeCache(
        Func<TKey, TValue> valueFactory,
        TimeSpan? defaultExpiration = null)
    {
        _valueFactory = valueFactory;
        _defaultExpiration = defaultExpiration ?? TimeSpan.FromMinutes(5);
    }

    public TValue Get(TKey key, TimeSpan? expiration = null)
    {
        return _mutex.WithLock(() =>
        {
            expiration ??= _defaultExpiration;

            if (_cache.TryGetValue(key, out var entry))
            {
                if (DateTime.UtcNow - entry.Created < expiration)
                {
                    return entry.Value;
                }
                _cache.Remove(key);
            }

            var value = _valueFactory(key);
            _cache[key] = new CacheEntry<TValue>(value);
            return value;
        });
    }

    public async Task<TValue> GetAsync(TKey key, TimeSpan? expiration = null)
    {
        return await _mutex.WithLockAsync(async () =>
        {
            expiration ??= _defaultExpiration;

            if (_cache.TryGetValue(key, out var entry))
            {
                if (DateTime.UtcNow - entry.Created < expiration)
                {
                    return entry.Value;
                }
                _cache.Remove(key);
            }

            var value = await Task.Run(() => _valueFactory(key));
            _cache[key] = new CacheEntry<TValue>(value);
            return value;
        });
    }

    public void Invalidate(TKey key)
    {
        _mutex.WithLock(() => _cache.Remove(key));
    }

    public void Clear()
    {
        _mutex.WithLock(() => _cache.Clear());
    }

    private class CacheEntry<T>
    {
        public T Value { get; }
        public DateTime Created { get; }

        public CacheEntry(T value)
        {
            Value = value;
            Created = DateTime.UtcNow;
        }
    }
}
