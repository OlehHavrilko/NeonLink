import 'package:flutter_test/flutter_test.dart';
import 'package:neonlink_app/data/models/telemetry_data.dart';

/// Интеграционные тесты для проверки синхронизации моделей данных
/// между сервером (.NET) и клиентом (Flutter)
void main() {
  group('TelemetryData Model Synchronization', () {
    test('Server TelemetryData should parse correctly in Flutter', () {
      // Arrange - пример данных от сервера
      final serverJson = {
        'version': '1.0.0',
        'timestamp': 1234567890,
        'system': {
          'cpu': {
            'name': 'AMD Ryzen 9 5900X',
            'usage': 45.5,
            'temp': 65.0,
            'clock': 4200.0,
            'power': 85.0,
            'cores': [
              {'id': 0, 'usage': 50.0, 'temp': 62.0, 'clock': 4200.0},
              {'id': 1, 'usage': 40.0, 'temp': 60.0, 'clock': 4150.0}
            ]
          },
          'gpu': {
            'name': 'NVIDIA RTX 4090',
            'type': 'NVIDIA',
            'usage': 75.0,
            'temp': 70.0,
            'vramUsed': 12.5,
            'vramTotal': 24.0,
            'clock': 2500.0,
            'memoryClock': 2100.0,
            'power': 350.0,
            'fanSpeed': 1500
          },
          'ram': {
            'used': 16.0,
            'total': 32.0,
            'speed': 3600
          },
          'storage': [
            {
              'name': 'Samsung 990 Pro 2TB',
              'temp': 45.0,
              'health': 100,
              'smart': {
                'tbw': 500,
                'powerOnHours': 1000,
                'reallocatedSectors': 0
              }
            }
          ],
          'network': {
            'download': 1.0,
            'upload': 0.5,
            'ping': 5,
            'ip': '192.168.1.100'
          }
        },
        'gaming': {
          'active': true,
          'fps': 120,
          'fps1Low': 95,
          'frametime': 8.33,
          'activeProcess': 'cyberpunk2077.exe'
        },
        'adminLevel': 'Full'
      };

      // Act
      final telemetry = TelemetryData.fromJson(serverJson);

      // Assert - проверка версии
      expect(telemetry.version, '1.0.0');
      
      // Assert - CPU
      expect(telemetry.system.cpu.name, 'AMD Ryzen 9 5900X');
      expect(telemetry.system.cpu.usage, 45.5);
      expect(telemetry.system.cpu.temp, 65.0);
      expect(telemetry.system.cpu.clock, 4200.0);
      expect(telemetry.system.cpu.power, 85.0);
      expect(telemetry.system.cpu.cores, hasLength(2));
      expect(telemetry.system.cpu.cores[0].id, 0);
      expect(telemetry.system.cpu.cores[0].usage, 50.0);
      
      // Assert - GPU
      expect(telemetry.system.gpu.name, 'NVIDIA RTX 4090');
      expect(telemetry.system.gpu.type, 'NVIDIA');
      expect(telemetry.system.gpu.usage, 75.0);
      expect(telemetry.system.gpu.temp, 70.0);
      expect(telemetry.system.gpu.vramUsed, 12.5);
      expect(telemetry.system.gpu.vramTotal, 24.0);
      expect(telemetry.system.gpu.vramUsagePercent, closeTo(52.08, 0.1));
      expect(telemetry.system.gpu.fanSpeed, 1500);
      
      // Assert - RAM
      expect(telemetry.system.ram.used, 16.0);
      expect(telemetry.system.ram.total, 32.0);
      expect(telemetry.system.ram.available, 16.0);
      expect(telemetry.system.ram.usedPercent, 50.0);
      expect(telemetry.system.ram.speed, 3600);
      
      // Assert - Storage
      expect(telemetry.system.storage, hasLength(1));
      expect(telemetry.system.storage[0].name, 'Samsung 990 Pro 2TB');
      expect(telemetry.system.storage[0].temp, 45.0);
      expect(telemetry.system.storage[0].health, 100);
      expect(telemetry.system.storage[0].smart?.tbw, 500);
      
      // Assert - Network
      expect(telemetry.system.network?.download, 1.0);
      expect(telemetry.system.network?.upload, 0.5);
      expect(telemetry.system.network?.ping, 5);
      expect(telemetry.system.network?.ip, '192.168.1.100');
      
      // Assert - Gaming
      expect(telemetry.gaming?.active, true);
      expect(telemetry.gaming?.fps, 120);
      expect(telemetry.gaming?.fps1Low, 95);
      expect(telemetry.gaming?.frametime, 8.33);
      expect(telemetry.gaming?.activeProcess, 'cyberpunk2077.exe');
      
      // Assert - Admin Level
      expect(telemetry.adminLevel, 'Full');
    });

    test('Minimal server data should parse with defaults', () {
      // Arrange - минимальные данные от сервера
      final serverJson = {
        'timestamp': 1234567890,
        'system': {
          'cpu': {
            'name': 'CPU',
            'usage': 0.0,
            'temp': 0.0,
            'clock': 0.0
          },
          'gpu': {
            'name': 'GPU',
            'usage': 0.0,
            'temp': 0.0
          },
          'ram': {
            'used': 0.0,
            'total': 0.0
          },
          'storage': []
        }
      };

      // Act
      final telemetry = TelemetryData.fromJson(serverJson);

      // Assert
      expect(telemetry.version, '1.0.0'); // Default version
      expect(telemetry.system.cpu.name, 'CPU');
      expect(telemetry.system.gpu.name, 'GPU');
      expect(telemetry.system.ram.used, 0.0);
      expect(telemetry.system.storage, isEmpty);
      expect(telemetry.gaming, isNull);
      expect(telemetry.adminLevel, 'Full'); // Default
    });

    test('TelemetryData should serialize back to JSON correctly', () {
      // Arrange - используем JSON как источник данных
      final serverJson = {
        'version': '1.0.0',
        'timestamp': 1234567890,
        'system': {
          'cpu': {
            'name': 'Test CPU',
            'usage': 50.0,
            'temp': 60.0,
            'clock': 3000.0,
            'cores': [
              {'id': 0, 'usage': 50.0}
            ]
          },
          'gpu': {
            'name': 'Test GPU',
            'type': 'NVIDIA',
            'usage': 60.0,
            'temp': 70.0,
            'vramUsed': 8.0,
            'vramTotal': 16.0,
            'clock': 2000.0,
          },
          'ram': {
            'used': 8.0,
            'total': 16.0,
            'speed': 3200,
          },
          'storage': [
            {
              'name': 'Test SSD',
              'temp': 40.0,
              'health': 100,
            }
          ],
          'network': {
            'download': 0.5,
            'upload': 0.25,
            'ping': 10,
            'ip': '192.168.1.1',
          },
        },
        'gaming': {
          'active': false,
        },
        'adminLevel': 'Full',
      };

      // Act
      final telemetry = TelemetryData.fromJson(serverJson);
      final json = telemetry.toJson();
      final backFromJson = TelemetryData.fromJson(json);

      // Assert - round-trip
      expect(backFromJson.version, telemetry.version);
      expect(backFromJson.timestamp, telemetry.timestamp);
      expect(backFromJson.system.cpu.name, telemetry.system.cpu.name);
      expect(backFromJson.system.cpu.usage, telemetry.system.cpu.usage);
      expect(backFromJson.system.gpu.vramUsed, telemetry.system.gpu.vramUsed);
      expect(backFromJson.system.ram.used, telemetry.system.ram.used);
      expect(backFromJson.system.storage.length, telemetry.system.storage.length);
      expect(backFromJson.gaming?.active, telemetry.gaming?.active);
    });

    test('Computed properties should work correctly', () {
      // Arrange - используем JSON
      final serverJson = {
        'timestamp': 0,
        'system': {
          'cpu': {
            'name': '',
            'usage': 50.0,
            'temp': 0.0,
            'clock': 0.0
          },
          'gpu': {
            'name': '',
            'usage': 0.0,
            'temp': 0.0,
            'vramUsed': 8.0,
            'vramTotal': 16.0,
            'clock': 0.0,
          },
          'ram': {
            'used': 8.0,
            'total': 16.0
          },
          'storage': []
        },
      };

      final telemetry = TelemetryData.fromJson(serverJson);

      // Assert - computed properties
      expect(telemetry.system.gpu.vramUsagePercent, 50.0);
      expect(telemetry.system.ram.available, 8.0);
      expect(telemetry.system.ram.usedPercent, 50.0);
    });
  });
}
