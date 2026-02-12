import 'package:json_annotation/json_annotation.dart';

part 'telemetry_data.g.dart';

/// Главный класс телеметрии, получаемый от сервера
/// Версия API: 1.0.0
@JsonSerializable()
class TelemetryData {
  /// Версия API для совместимости клиента и сервера
  final String version;
  
  final int timestamp;
  final SystemInfo system;
  final GamingInfo? gaming;
  final String adminLevel;

  TelemetryData({
    this.version = '1.0.0',
    required this.timestamp,
    required this.system,
    this.gaming,
    this.adminLevel = 'Full',
  });

  factory TelemetryData.fromJson(Map<String, dynamic> json) =>
      _$TelemetryDataFromJson(json);

  Map<String, dynamic> toJson() => _$TelemetryDataToJson(this);
}

/// Информация о системе
@JsonSerializable()
class SystemInfo {
  final CpuInfo cpu;
  final GpuInfo gpu;
  final RamInfo ram;
  final List<StorageInfo> storage;
  final NetworkInfo? network;

  SystemInfo({
    required this.cpu,
    required this.gpu,
    required this.ram,
    required this.storage,
    this.network,
  });

  factory SystemInfo.fromJson(Map<String, dynamic> json) =>
      _$SystemInfoFromJson(json);

  Map<String, dynamic> toJson() => _$SystemInfoToJson(this);
}

/// Информация о CPU
@JsonSerializable()
class CpuInfo {
  final String name;
  final double usage;
  final double temp;
  final double clock;
  final double? power;
  final List<CpuCoreInfo> cores;

  CpuInfo({
    this.name = '',
    this.usage = 0,
    this.temp = 0,
    this.clock = 0,
    this.power,
    this.cores = const [],
  });

  factory CpuInfo.fromJson(Map<String, dynamic> json) =>
      _$CpuInfoFromJson(json);

  Map<String, dynamic> toJson() => _$CpuInfoToJson(this);
}

/// Информация о ядре CPU
@JsonSerializable()
class CpuCoreInfo {
  final int id;
  final double usage;
  final double? temp;
  final double? clock;

  CpuCoreInfo({
    required this.id,
    this.usage = 0,
    this.temp,
    this.clock,
  });

  factory CpuCoreInfo.fromJson(Map<String, dynamic> json) =>
      _$CpuCoreInfoFromJson(json);

  Map<String, dynamic> toJson() => _$CpuCoreInfoToJson(this);
}

/// Информация о GPU
@JsonSerializable()
class GpuInfo {
  final String name;
  final String type;
  final double usage;
  final double temp;
  final double vramUsed;
  final double vramTotal;
  final double clock;
  final double? memoryClock;
  final double? power;
  final int? fanSpeed;

  GpuInfo({
    this.name = '',
    this.type = '',
    this.usage = 0,
    this.temp = 0,
    this.vramUsed = 0,
    this.vramTotal = 0,
    this.clock = 0,
    this.memoryClock,
    this.power,
    this.fanSpeed,
  });

  factory GpuInfo.fromJson(Map<String, dynamic> json) =>
      _$GpuInfoFromJson(json);

  Map<String, dynamic> toJson() => _$GpuInfoToJson(this);

  /// Вычисляемое поле: процент использования VRAM
  double get vramUsagePercent => 
      vramTotal > 0 ? (vramUsed / vramTotal) * 100 : 0;
}

/// Информация о RAM
@JsonSerializable()
class RamInfo {
  final double used;
  final double total;
  final int? speed;

  RamInfo({
    this.used = 0,
    this.total = 0,
    this.speed,
  });

  factory RamInfo.fromJson(Map<String, dynamic> json) =>
      _$RamInfoFromJson(json);

  Map<String, dynamic> toJson() => _$RamInfoToJson(this);

  /// Вычисляемое поле: доступная память
  double get available => total - used;

  /// Вычисляемое поле: процент использования
  double get usedPercent => total > 0 ? (used / total) * 100 : 0;
}

/// Информация о накопителе
@JsonSerializable()
class StorageInfo {
  final String name;
  final double? temp;
  final int? health;
  final StorageSmartData? smart;

  StorageInfo({
    this.name = '',
    this.temp,
    this.health,
    this.smart,
  });

  factory StorageInfo.fromJson(Map<String, dynamic> json) =>
      _$StorageInfoFromJson(json);

  Map<String, dynamic> toJson() => _$StorageInfoToJson(this);
}

/// SMART данные накопителя
@JsonSerializable()
class StorageSmartData {
  final int? tbw;
  final int? powerOnHours;
  final int? reallocatedSectors;
  final int? temperature;

  StorageSmartData({
    this.tbw,
    this.powerOnHours,
    this.reallocatedSectors,
    this.temperature,
  });

  factory StorageSmartData.fromJson(Map<String, dynamic> json) =>
      _$StorageSmartDataFromJson(json);

  Map<String, dynamic> toJson() => _$StorageSmartDataToJson(this);
}

/// Информация о сети
@JsonSerializable()
class NetworkInfo {
  final double download;
  final double upload;
  final int ping;
  final String? ip;

  NetworkInfo({
    this.download = 0,
    this.upload = 0,
    this.ping = 0,
    this.ip,
  });

  factory NetworkInfo.fromJson(Map<String, dynamic> json) =>
      _$NetworkInfoFromJson(json);

  Map<String, dynamic> toJson() => _$NetworkInfoToJson(this);
}

/// Информация о игровом режиме
@JsonSerializable()
class GamingInfo {
  final bool active;
  final int? fps;
  final int? fps1Low;
  final double? frametime;
  final String? activeProcess;

  GamingInfo({
    this.active = false,
    this.fps,
    this.fps1Low,
    this.frametime,
    this.activeProcess,
  });

  factory GamingInfo.fromJson(Map<String, dynamic> json) =>
      _$GamingInfoFromJson(json);

  Map<String, dynamic> toJson() => _$GamingInfoToJson(this);
}
