using System.Text.Json;
using System.Text.Json.Serialization;

namespace NeonLink.Server.Utilities;

/// <summary>
///     Вспомогательный класс для JSON сериализации/десериализации
///     Согласно плану v2.0 - кастомные настройки для WebSocket
/// </summary>
public static class JsonHelper
{
    /// <summary>
    ///     Настройки сериализации для WebSocket communication
    /// </summary>
    public static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        WriteIndented = false, // Компактный JSON для WebSocket
        PropertyNameCaseInsensitive = true, // Для десериализации команд
        Converters =
        {
            new JsonStringEnumConverter(JsonNamingPolicy.CamelCase)
        }
    };

    /// <summary>
    ///     Сериализовать объект в JSON строку
    /// </summary>
    public static string Serialize<T>(T data)
    {
        return JsonSerializer.Serialize(data, Options);
    }

    /// <summary>
    ///     Десериализовать JSON строку в объект
    /// </summary>
    public static T? Deserialize<T>(string json)
    {
        return JsonSerializer.Deserialize<T>(json, Options);
    }

    /// <summary>
    ///     Попытка десериализовать JSON строку в объект
    /// </summary>
    public static bool TryDeserialize<T>(string json, out T? result)
    {
        try
        {
            result = Deserialize<T>(json);
            return result != null;
        }
        catch
        {
            result = default;
            return false;
        }
    }

    /// <summary>
    ///     Создать ответ об ошибке
    /// </summary>
    public static string CreateErrorResponse(string message, string? details = null)
    {
        var error = new ErrorResponse
        {
            Success = false,
            Error = message,
            Details = details,
            Timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds()
        };
        return Serialize(error);
    }

    /// <summary>
    ///     Создать успешный ответ
    /// </summary>
    public static string CreateSuccessResponse<T>(string command, T result)
    {
        var response = new CommandResponse<T>
        {
            Success = true,
            Command = command,
            Result = result,
            Timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds()
        };
        return Serialize(response);
    }
}

/// <summary>
///     Базовый класс для всех ответов
/// </summary>
public abstract class BaseResponse
{
    public bool Success { get; set; }
    public long Timestamp { get; set; }
    public string? Error { get; set; }
    public string? Details { get; set; }
}

/// <summary>
///     Ответ на команду
/// </summary>
public class CommandResponse<T> : BaseResponse
{
    public string Command { get; set; } = string.Empty;
    public T? Result { get; set; }
}

/// <summary>
///     Ответ об ошибке
/// </summary>
public class ErrorResponse : BaseResponse
{
}
