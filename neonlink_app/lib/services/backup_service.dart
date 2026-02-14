import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings backup service
class BackupService {
  static BackupService? _instance;

  BackupService._();

  static BackupService get instance {
    _instance ??= BackupService._();
    return _instance!;
  }

  /// Keys to backup
  static const List<String> _settingsKeys = [
    'server_ip',
    'server_port',
    'auto_connect',
    'refresh_interval',
    'theme_mode',
    'notifications_enabled',
    'log_retention_days',
  ];

  /// Export settings to JSON
  Future<Map<String, dynamic>> exportSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = <String, dynamic>{};

    for (final key in _settingsKeys) {
      final value = prefs.get(key);
      if (value != null) {
        settings[key] = value;
      }
    }

    return settings;
  }

  /// Import settings from JSON
  Future<bool> importSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      for (final key in _settingsKeys) {
        if (settings.containsKey(key)) {
          final value = settings[key];
          if (value is String) {
            await prefs.setString(key, value);
          } else if (value is int) {
            await prefs.setInt(key, value);
          } else if (value is double) {
            await prefs.setDouble(key, value);
          } else if (value is bool) {
            await prefs.setBool(key, value);
          }
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Save backup to file
  Future<String> createBackup() async {
    final settings = await exportSettings();
    final json = const JsonEncoder.withIndent('  ').convert(settings);
    
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${directory.path}/neonlink_backup_$timestamp.json');
    
    await file.writeAsString(json);
    
    return file.path;
  }

  /// Load backup from file
  Future<Map<String, dynamic>?> loadBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Share backup file
  Future<void> shareBackup() async {
    final filePath = await createBackup();
    await Share.shareXFiles([XFile(filePath)], subject: 'NeonLink Backup');
  }

  /// Clear all settings
  Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Get settings as JSON string
  Future<String> getSettingsJson() async {
    final settings = await exportSettings();
    return const JsonEncoder.withIndent('  ').convert(settings);
  }
}
