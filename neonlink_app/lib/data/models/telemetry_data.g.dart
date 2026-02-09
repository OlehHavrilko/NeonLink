// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'telemetry_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TelemetryData _$TelemetryDataFromJson(Map<String, dynamic> json) {
  return TelemetryData(
    timestamp: json['timestamp'] as int,
    system: SystemInfo.fromJson(json['system'] as Map<String, dynamic>),
    gaming: json['gaming'] == null
        ? null
        : GamingInfo.fromJson(json['gaming'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$TelemetryDataToJson(TelemetryData instance) {
  return <String, dynamic>{
    'timestamp': instance.timestamp,
    'system': instance.system.toJson(),
    'gaming': instance.gaming?.toJson(),
  };
}

SystemInfo _$SystemInfoFromJson(Map<String, dynamic> json) {
  return SystemInfo(
    cpu: CpuInfo.fromJson(json['cpu'] as Map<String, dynamic>),
    gpu: GpuInfo.fromJson(json['gpu'] as Map<String, dynamic>),
    ram: RamInfo.fromJson(json['ram'] as Map<String, dynamic>),
    storage: StorageInfo.fromJson(json['storage'] as Map<String, dynamic>),
    network: NetworkInfo.fromJson(json['network'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$SystemInfoToJson(SystemInfo instance) {
  return <String, dynamic>{
    'cpu': instance.cpu.toJson(),
    'gpu': instance.gpu.toJson(),
    'ram': instance.ram.toJson(),
    'storage': instance.storage.toJson(),
    'network': instance.network.toJson(),
  };
}

CpuInfo _$CpuInfoFromJson(Map<String, dynamic> json) {
  return CpuInfo(
    usage: (json['usage'] as num).toDouble(),
    temp: (json['temp'] as num).toDouble(),
    cores: json['cores'] as int,
    clockSpeed: (json['clockSpeed'] as num).toDouble(),
  );
}

Map<String, dynamic> _$CpuInfoToJson(CpuInfo instance) {
  return <String, dynamic>{
    'usage': instance.usage,
    'temp': instance.temp,
    'cores': instance.cores,
    'clockSpeed': instance.clockSpeed,
  };
}

GpuInfo _$GpuInfoFromJson(Map<String, dynamic> json) {
  return GpuInfo(
    usage: (json['usage'] as num).toDouble(),
    temp: (json['temp'] as num).toDouble(),
    memory: json['memory'] as int,
    vram: json['vram'] as int,
  );
}

Map<String, dynamic> _$GpuInfoToJson(GpuInfo instance) {
  return <String, dynamic>{
    'usage': instance.usage,
    'temp': instance.temp,
    'memory': instance.memory,
    'vram': instance.vram,
  };
}

RamInfo _$RamInfoFromJson(Map<String, dynamic> json) {
  return RamInfo(
    usedPercent: (json['usedPercent'] as num).toDouble(),
    usedGb: (json['usedGb'] as num).toDouble(),
    totalGb: (json['totalGb'] as num).toDouble(),
  );
}

Map<String, dynamic> _$RamInfoToJson(RamInfo instance) {
  return <String, dynamic>{
    'usedPercent': instance.usedPercent,
    'usedGb': instance.usedGb,
    'totalGb': instance.totalGb,
  };
}

StorageInfo _$StorageInfoFromJson(Map<String, dynamic> json) {
  return StorageInfo(
    usedPercent: (json['usedPercent'] as num).toDouble(),
    usedGb: (json['usedGb'] as num).toDouble(),
    totalGb: (json['totalGb'] as num).toDouble(),
    readSpeed: json['readSpeed'] as int,
    writeSpeed: json['writeSpeed'] as int,
  );
}

Map<String, dynamic> _$StorageInfoToJson(StorageInfo instance) {
  return <String, dynamic>{
    'usedPercent': instance.usedPercent,
    'usedGb': instance.usedGb,
    'totalGb': instance.totalGb,
    'readSpeed': instance.readSpeed,
    'writeSpeed': instance.writeSpeed,
  };
}

NetworkInfo _$NetworkInfoFromJson(Map<String, dynamic> json) {
  return NetworkInfo(
    downloadSpeed: json['downloadSpeed'] as int,
    uploadSpeed: json['uploadSpeed'] as int,
    ip: json['ip'] as String,
  );
}

Map<String, dynamic> _$NetworkInfoToJson(NetworkInfo instance) {
  return <String, dynamic>{
    'downloadSpeed': instance.downloadSpeed,
    'uploadSpeed': instance.uploadSpeed,
    'ip': instance.ip,
  };
}

GamingInfo _$GamingInfoFromJson(Map<String, dynamic> json) {
  return GamingInfo(
    active: json['active'] as bool,
    activeProcess: json['activeProcess'] as String?,
    fps: json['fps'] as int?,
    frameTime: json['frameTime'] as int?,
  );
}

Map<String, dynamic> _$GamingInfoToJson(GamingInfo instance) {
  return <String, dynamic>{
    'active': instance.active,
    'activeProcess': instance.activeProcess,
    'fps': instance.fps,
    'frameTime': instance.frameTime,
  };
}
