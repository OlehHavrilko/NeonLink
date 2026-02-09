import 'package:json_annotation/json_annotation.dart';

part 'telemetry_data.g.dart';

@JsonSerializable()
class TelemetryData {
  final int timestamp;
  final SystemInfo system;
  final GamingInfo? gaming;

  TelemetryData({
    required this.timestamp,
    required this.system,
    this.gaming,
  });

  factory TelemetryData.fromJson(Map<String, dynamic> json) =>
      _$TelemetryDataFromJson(json);

  Map<String, dynamic> toJson() => _$TelemetryDataToJson(this);
}

@JsonSerializable()
class SystemInfo {
  final CpuInfo cpu;
  final GpuInfo gpu;
  final RamInfo ram;
  final StorageInfo storage;
  final NetworkInfo network;

  SystemInfo({
    required this.cpu,
    required this.gpu,
    required this.ram,
    required this.storage,
    required this.network,
  });

  factory SystemInfo.fromJson(Map<String, dynamic> json) =>
      _$SystemInfoFromJson(json);

  Map<String, dynamic> toJson() => _$SystemInfoToJson(this);
}

@JsonSerializable()
class CpuInfo {
  final double usage;
  final double temp;
  final int cores;
  final double clockSpeed;

  CpuInfo({
    required this.usage,
    required this.temp,
    required this.cores,
    required this.clockSpeed,
  });

  factory CpuInfo.fromJson(Map<String, dynamic> json) =>
      _$CpuInfoFromJson(json);

  Map<String, dynamic> toJson() => _$CpuInfoToJson(this);
}

@JsonSerializable()
class GpuInfo {
  final double usage;
  final double temp;
  final int memory;
  final int vram;

  GpuInfo({
    required this.usage,
    required this.temp,
    required this.memory,
    required this.vram,
  });

  factory GpuInfo.fromJson(Map<String, dynamic> json) =>
      _$GpuInfoFromJson(json);

  Map<String, dynamic> toJson() => _$GpuInfoToJson(this);
}

@JsonSerializable()
class RamInfo {
  final double usedPercent;
  final double usedGb;
  final double totalGb;

  RamInfo({
    required this.usedPercent,
    required this.usedGb,
    required this.totalGb,
  });

  factory RamInfo.fromJson(Map<String, dynamic> json) =>
      _$RamInfoFromJson(json);

  Map<String, dynamic> toJson() => _$RamInfoToJson(this);
}

@JsonSerializable()
class StorageInfo {
  final double usedPercent;
  final double usedGb;
  final double totalGb;
  final int readSpeed;
  final int writeSpeed;

  StorageInfo({
    required this.usedPercent,
    required this.usedGb,
    required this.totalGb,
    required this.readSpeed,
    required this.writeSpeed,
  });

  factory StorageInfo.fromJson(Map<String, dynamic> json) =>
      _$StorageInfoFromJson(json);

  Map<String, dynamic> toJson() => _$StorageInfoToJson(this);
}

@JsonSerializable()
class NetworkInfo {
  final int downloadSpeed;
  final int uploadSpeed;
  final String ip;

  NetworkInfo({
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.ip,
  });

  factory NetworkInfo.fromJson(Map<String, dynamic> json) =>
      _$NetworkInfoFromJson(json);

  Map<String, dynamic> toJson() => _$NetworkInfoToJson(this);
}

@JsonSerializable()
class GamingInfo {
  final bool active;
  final String? activeProcess;
  final int? fps;
  final int? frameTime;

  GamingInfo({
    required this.active,
    this.activeProcess,
    this.fps,
    this.frameTime,
  });

  factory GamingInfo.fromJson(Map<String, dynamic> json) =>
      _$GamingInfoFromJson(json);

  Map<String, dynamic> toJson() => _$GamingInfoToJson(this);
}
