// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'telemetry_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TelemetryData _$TelemetryDataFromJson(Map<String, dynamic> json) =>
    TelemetryData(
      version: json['version'] as String? ?? '1.0.0',
      timestamp: (json['timestamp'] as num).toInt(),
      system: SystemInfo.fromJson(json['system'] as Map<String, dynamic>),
      gaming: json['gaming'] == null
          ? null
          : GamingInfo.fromJson(json['gaming'] as Map<String, dynamic>),
      adminLevel: json['adminLevel'] as String? ?? 'Full',
    );

Map<String, dynamic> _$TelemetryDataToJson(TelemetryData instance) =>
    <String, dynamic>{
      'version': instance.version,
      'timestamp': instance.timestamp,
      'system': instance.system,
      'gaming': instance.gaming,
      'adminLevel': instance.adminLevel,
    };

SystemInfo _$SystemInfoFromJson(Map<String, dynamic> json) => SystemInfo(
      cpu: CpuInfo.fromJson(json['cpu'] as Map<String, dynamic>),
      gpu: GpuInfo.fromJson(json['gpu'] as Map<String, dynamic>),
      ram: RamInfo.fromJson(json['ram'] as Map<String, dynamic>),
      storage: (json['storage'] as List<dynamic>)
          .map((e) => StorageInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      network: json['network'] == null
          ? null
          : NetworkInfo.fromJson(json['network'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SystemInfoToJson(SystemInfo instance) =>
    <String, dynamic>{
      'cpu': instance.cpu,
      'gpu': instance.gpu,
      'ram': instance.ram,
      'storage': instance.storage,
      'network': instance.network,
    };

CpuInfo _$CpuInfoFromJson(Map<String, dynamic> json) => CpuInfo(
      name: json['name'] as String? ?? '',
      usage: (json['usage'] as num?)?.toDouble() ?? 0,
      temp: (json['temp'] as num?)?.toDouble() ?? 0,
      clock: (json['clock'] as num?)?.toDouble() ?? 0,
      power: (json['power'] as num?)?.toDouble(),
      cores: (json['cores'] as List<dynamic>?)
              ?.map((e) => CpuCoreInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$CpuInfoToJson(CpuInfo instance) => <String, dynamic>{
      'name': instance.name,
      'usage': instance.usage,
      'temp': instance.temp,
      'clock': instance.clock,
      'power': instance.power,
      'cores': instance.cores,
    };

CpuCoreInfo _$CpuCoreInfoFromJson(Map<String, dynamic> json) => CpuCoreInfo(
      id: (json['id'] as num).toInt(),
      usage: (json['usage'] as num?)?.toDouble() ?? 0,
      temp: (json['temp'] as num?)?.toDouble(),
      clock: (json['clock'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$CpuCoreInfoToJson(CpuCoreInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'usage': instance.usage,
      'temp': instance.temp,
      'clock': instance.clock,
    };

GpuInfo _$GpuInfoFromJson(Map<String, dynamic> json) => GpuInfo(
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      usage: (json['usage'] as num?)?.toDouble() ?? 0,
      temp: (json['temp'] as num?)?.toDouble() ?? 0,
      vramUsed: (json['vramUsed'] as num?)?.toDouble() ?? 0,
      vramTotal: (json['vramTotal'] as num?)?.toDouble() ?? 0,
      clock: (json['clock'] as num?)?.toDouble() ?? 0,
      memoryClock: (json['memoryClock'] as num?)?.toDouble(),
      power: (json['power'] as num?)?.toDouble(),
      fanSpeed: (json['fanSpeed'] as num?)?.toInt(),
    );

Map<String, dynamic> _$GpuInfoToJson(GpuInfo instance) => <String, dynamic>{
      'name': instance.name,
      'type': instance.type,
      'usage': instance.usage,
      'temp': instance.temp,
      'vramUsed': instance.vramUsed,
      'vramTotal': instance.vramTotal,
      'clock': instance.clock,
      'memoryClock': instance.memoryClock,
      'power': instance.power,
      'fanSpeed': instance.fanSpeed,
    };

RamInfo _$RamInfoFromJson(Map<String, dynamic> json) => RamInfo(
      used: (json['used'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      speed: (json['speed'] as num?)?.toInt(),
    );

Map<String, dynamic> _$RamInfoToJson(RamInfo instance) => <String, dynamic>{
      'used': instance.used,
      'total': instance.total,
      'speed': instance.speed,
    };

StorageInfo _$StorageInfoFromJson(Map<String, dynamic> json) => StorageInfo(
      name: json['name'] as String? ?? '',
      temp: (json['temp'] as num?)?.toDouble(),
      health: (json['health'] as num?)?.toInt(),
      smart: json['smart'] == null
          ? null
          : StorageSmartData.fromJson(json['smart'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$StorageInfoToJson(StorageInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'temp': instance.temp,
      'health': instance.health,
      'smart': instance.smart,
    };

StorageSmartData _$StorageSmartDataFromJson(Map<String, dynamic> json) =>
    StorageSmartData(
      tbw: (json['tbw'] as num?)?.toInt(),
      powerOnHours: (json['powerOnHours'] as num?)?.toInt(),
      reallocatedSectors: (json['reallocatedSectors'] as num?)?.toInt(),
      temperature: (json['temperature'] as num?)?.toInt(),
    );

Map<String, dynamic> _$StorageSmartDataToJson(StorageSmartData instance) =>
    <String, dynamic>{
      'tbw': instance.tbw,
      'powerOnHours': instance.powerOnHours,
      'reallocatedSectors': instance.reallocatedSectors,
      'temperature': instance.temperature,
    };

NetworkInfo _$NetworkInfoFromJson(Map<String, dynamic> json) => NetworkInfo(
      download: (json['download'] as num?)?.toDouble() ?? 0,
      upload: (json['upload'] as num?)?.toDouble() ?? 0,
      ping: (json['ping'] as num?)?.toInt() ?? 0,
      ip: json['ip'] as String?,
    );

Map<String, dynamic> _$NetworkInfoToJson(NetworkInfo instance) =>
    <String, dynamic>{
      'download': instance.download,
      'upload': instance.upload,
      'ping': instance.ping,
      'ip': instance.ip,
    };

GamingInfo _$GamingInfoFromJson(Map<String, dynamic> json) => GamingInfo(
      active: json['active'] as bool? ?? false,
      fps: (json['fps'] as num?)?.toInt(),
      fps1Low: (json['fps1Low'] as num?)?.toInt(),
      frametime: (json['frametime'] as num?)?.toDouble(),
      activeProcess: json['activeProcess'] as String?,
    );

Map<String, dynamic> _$GamingInfoToJson(GamingInfo instance) =>
    <String, dynamic>{
      'active': instance.active,
      'fps': instance.fps,
      'fps1Low': instance.fps1Low,
      'frametime': instance.frametime,
      'activeProcess': instance.activeProcess,
    };
