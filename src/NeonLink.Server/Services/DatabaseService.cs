using System.Data;
using Dapper;
using Npgsql;
using Microsoft.Extensions.Configuration;

namespace NeonLink.Server.Services;

public interface IDatabaseService
{
    Task InitializeAsync();
    Task<IEnumerable<T>> QueryAsync<T>(string sql, object? param = null);
    Task<T?> QueryFirstOrDefaultAsync<T>(string sql, object? param = null);
    Task<int> ExecuteAsync(string sql, object? param = null);
    Task<T> ExecuteScalarAsync<T>(string sql, object? param = null);
}

public class DatabaseService : IDatabaseService
{
    private readonly string _connectionString;
    private readonly ILogger<DatabaseService> _logger;
    private NpgsqlConnection? _connection;

    public DatabaseService(IConfiguration configuration, ILogger<DatabaseService> logger)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection") 
            ?? throw new InvalidOperationException("DefaultConnection not configured");
        _logger = logger;
    }

    private NpgsqlConnection GetConnection()
    {
        if (_connection == null || _connection.State != ConnectionState.Open)
        {
            _connection = new NpgsqlConnection(_connectionString);
            _connection.Open();
        }
        return _connection;
    }

    public async Task InitializeAsync()
    {
        try
        {
            _logger.LogInformation("Initializing database connection...");
            var connection = new NpgsqlConnection(_connectionString);
            await connection.OpenAsync();
            
            // Test connection
            await connection.ExecuteScalarAsync("SELECT 1");
            
            _logger.LogInformation("Database connection established successfully");
            await connection.CloseAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize database connection");
            throw;
        }
    }

    public async Task<IEnumerable<T>> QueryAsync<T>(string sql, object? param = null)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        return await connection.QueryAsync<T>(sql, param);
    }

    public async Task<T?> QueryFirstOrDefaultAsync<T>(string sql, object? param = null)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        return await connection.QueryFirstOrDefaultAsync<T>(sql, param);
    }

    public async Task<int> ExecuteAsync(string sql, object? param = null)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        return await connection.ExecuteAsync(sql, param);
    }

    public async Task<T> ExecuteScalarAsync<T>(string sql, object? param = null)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        return await connection.ExecuteScalarAsync<T>(sql, param);
    }
}

// Service for telemetry data
public interface ITelemetryRepository
{
    Task SaveTelemetryDataAsync(TelemetryRecord record);
    Task<IEnumerable<TelemetryRecord>> GetRecentTelemetryAsync(int limit = 100);
    Task<IEnumerable<TelemetryRecord>> GetTelemetryByTimeRangeAsync(DateTime start, DateTime end);
    Task<IEnumerable<TelemetryRecord>> GetTelemetryBySensorAsync(string sensorName, int limit = 100);
}

public class TelemetryRecord
{
    public Guid Id { get; set; }
    public DateTime Timestamp { get; set; }
    public string SensorName { get; set; } = string.Empty;
    public decimal SensorValue { get; set; }
    public string? SensorUnit { get; set; }
    public string? Category { get; set; }
    public string? DeviceId { get; set; }
    public string? Metadata { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class TelemetryRepository : ITelemetryRepository
{
    private readonly IDatabaseService _db;
    private readonly ILogger<TelemetryRepository> _logger;

    public TelemetryRepository(IDatabaseService db, ILogger<TelemetryRepository> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task SaveTelemetryDataAsync(TelemetryRecord record)
    {
        const string sql = @"
            INSERT INTO telemetry_data (id, timestamp, sensor_name, sensor_value, sensor_unit, category, device_id, metadata, created_at)
            VALUES (@Id, @Timestamp, @SensorName, @SensorValue, @SensorUnit, @Category, @DeviceId, @Metadata, @CreatedAt)";

        try
        {
            await _db.ExecuteAsync(sql, record);
            _logger.LogDebug("Saved telemetry data: {SensorName} = {SensorValue}", record.SensorName, record.SensorValue);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to save telemetry data");
        }
    }

    public async Task<IEnumerable<TelemetryRecord>> GetRecentTelemetryAsync(int limit = 100)
    {
        const string sql = @"
            SELECT * FROM telemetry_data 
            ORDER BY timestamp DESC 
            LIMIT @Limit";

        return await _db.QueryAsync<TelemetryRecord>(sql, new { Limit = limit });
    }

    public async Task<IEnumerable<TelemetryRecord>> GetTelemetryByTimeRangeAsync(DateTime start, DateTime end)
    {
        const string sql = @"
            SELECT * FROM telemetry_data 
            WHERE timestamp BETWEEN @Start AND @End
            ORDER BY timestamp DESC";

        return await _db.QueryAsync<TelemetryRecord>(sql, new { Start = start, End = end });
    }

    public async Task<IEnumerable<TelemetryRecord>> GetTelemetryBySensorAsync(string sensorName, int limit = 100)
    {
        const string sql = @"
            SELECT * FROM telemetry_data 
            WHERE sensor_name = @SensorName
            ORDER BY timestamp DESC 
            LIMIT @Limit";

        return await _db.QueryAsync<TelemetryRecord>(sql, new { SensorName = sensorName, Limit = limit });
    }
}

// Service for settings
public interface ISettingsRepository
{
    Task<string?> GetSettingAsync(string key);
    Task SetSettingAsync(string key, string value);
    Task<IEnumerable<SettingRecord>> GetAllSettingsAsync();
}

public class SettingRecord
{
    public Guid Id { get; set; }
    public string Key { get; set; } = string.Empty;
    public string Value { get; set; } = string.Empty;
    public string ValueType { get; set; } = "string";
    public string? Description { get; set; }
    public string? Category { get; set; }
    public bool IsEncrypted { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class SettingsRepository : ISettingsRepository
{
    private readonly IDatabaseService _db;
    private readonly ILogger<SettingsRepository> _logger;

    public SettingsRepository(IDatabaseService db, ILogger<SettingsRepository> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<string?> GetSettingAsync(string key)
    {
        const string sql = "SELECT value FROM settings WHERE key = @Key";
        return await _db.QueryFirstOrDefaultAsync<string>(sql, new { Key = key });
    }

    public async Task SetSettingAsync(string key, string value)
    {
        const string sql = @"
            INSERT INTO settings (id, key, value, updated_at)
            VALUES (@Id, @Key, @Value, @UpdatedAt)
            ON CONFLICT (key) DO UPDATE SET value = @Value, updated_at = @UpdatedAt";

        await _db.ExecuteAsync(sql, new { Id = Guid.NewGuid(), Key = key, Value = value, UpdatedAt = DateTime.UtcNow });
    }

    public async Task<IEnumerable<SettingRecord>> GetAllSettingsAsync()
    {
        const string sql = "SELECT * FROM settings ORDER BY category, key";
        return await _db.QueryAsync<SettingRecord>(sql);
    }
}
