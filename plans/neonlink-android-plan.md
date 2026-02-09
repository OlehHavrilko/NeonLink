# NeonLink Android App - План Разработки v2.0 (Flutter)

## Архитектура Приложения

```mermaid
flowchart TB
    subgraph UI Layer
        ConnectionScreen[Connection Screen]
        Dashboard[Dashboard - 4 режима]
        ControlPanel[Control Panel]
        ThemeStore[Theme Store]
        Settings[Settings]
    end

    subgraph State Management - Riverpod 3.x
        TelemetryProvider[TelemetryProvider]
        ConnectionProvider[ConnectionProvider]
        ThemeProvider[ThemeProvider]
        SettingsProvider[SettingsProvider]
    end

    subgraph Services - Thread-Safe
        WebSocketService[WebSocket Service - Exponential Backoff]
        DiscoveryService[UDP Broadcast Discovery]
        LocalStorage[SharedPreferences + Hive]
        WakelockService[Wakelock Service]
        NotificationService[Local Notifications]
    end

    subgraph OLED Protection
        OledProtector[Pixel Shift Service]
        ThemeRotator[Theme Rotation]
    end

    subgraph Error Handling
        ErrorBoundary[Error Boundary]
        CrashReporter[Crash Reporter]
    end

    ConnectionScreen --> ConnectionProvider
    Dashboard --> TelemetryProvider
    Dashboard --> OLED Protection
    Dashboard --> WakelockService
    TelemetryProvider --> WebSocketService
    ConnectionProvider --> DiscoveryService
    WebSocketService --> ErrorBoundary
    ThemeProvider --> OLED Protection
    ThemeStore --> LocalStorage
```

## Структура Проекта

```
neonlink_app/
├── lib/
│   ├── main.dart                      # Entry point + Error handling
│   ├── app.dart                       # App configuration + providers
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_constants.dart     # URLs, timeouts, limits
│   │   │   ├── theme_constants.dart   # Colors, fonts, animations
│   │   │   └── error_constants.dart   # Error codes, messages
│   │   ├── errors/
│   │   │   ├── exceptions.dart        # Custom exceptions
│   │   │   └── failure.dart           # Either/Result pattern
│   │   ├── utils/
│   │   │   ├── formatters.dart        # Number formatting
│   │   │   ├── validators.dart        # IP validation
│   │   │   └── debouncers.dart        # Throttle, Debounce
│   │   ├── theme/
│   │   │   ├── neon_theme.dart        # Theme model
│   │   │   └── theme_loader.dart      # JSON theme loader
│   │   └── l10n/
│   │       ├── app_en.arb
│   │       ├── app_ru.arb
│   │       ├── app_zh.arb
│   │       ├── app_de.arb
│   │       └── app_es.arb
│   │
│   ├── data/
│   │   ├── models/
│   │   │   ├── telemetry_data.dart    # JSON model + json_serializable
│   │   │   ├── command_models.dart    # Command models
│   │   │   ├── hardware_info.dart     # Hardware info
│   │   │   ├── connection_history.dart
│   │   │   └── theme_model.dart       # Theme JSON model
│   │   ├── repositories/
│   │   │   ├── telemetry_repository.dart
│   │   │   ├── connection_repository.dart
│   │   │   └── settings_repository.dart
│   │   └── sources/
│   │       ├── websocket_source.dart  # WebSocketChannel wrapper
│   │       ├── discovery_source.dart  # UDP broadcast listener
│   │       └── local_storage.dart     # SharedPreferences + Hive
│   │
│   ├── domain/
│   │   ├── entities/
│   │   │   ├── cpu_info.dart
│   │   │   ├── gpu_info.dart
│   │   │   ├── ram_info.dart
│   │   │   └── storage_info.dart
│   │   ├── usecases/
│   │   │   ├── get_telemetry_usecase.dart
│   │   │   ├── connect_to_pc_usecase.dart
│   │   │   └── send_command_usecase.dart
│   │   └── interfaces/
│   │       └── i_websocket_service.dart
│   │
│   ├── presentation/
│   │   ├── shared/
│   │   │   ├── widgets/
│   │   │   │   ├── circular_gauge.dart    # CustomPainter
│   │   │   │   ├── sparkline_chart.dart   # fl_chart wrapper
│   │   │   │   ├── status_indicator.dart   # Green/Yellow/Red
│   │   │   │   ├── animated_number.dart    # TweenAnimationBuilder
│   │   │   │   └── error_boundary.dart    # Global error catch
│   │   │   └── theme_wrapper.dart
│   │   │
│   │   ├── screens/
│   │   │   ├── connection/
│   │   │   │   ├── connection_screen.dart
│   │   │   │   ├── connection_viewmodel.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── discovery_card.dart
│   │   │   │       ├── qr_scanner_overlay.dart
│   │   │   │       └── manual_input.dart
│   │   │   │
│   │   │   ├── dashboard/
│   │   │   │   ├── dashboard_screen.dart
│   │   │   │   ├── dashboard_viewmodel.dart
│   │   │   │   ├── widgets/
│   │   │   │   │   ├── cpu_gauge.dart
│   │   │   │   │   ├── gpu_gauge.dart
│   │   │   │   │   ├── ram_gauge.dart
│   │   │   │   │   └── metrics_table.dart
│   │   │   │   └── modes/
│   │   │   │       ├── circular_gauges_mode.dart
│   │   │   │       ├── compact_mode.dart
│   │   │   │       ├── graph_mode.dart
│   │   │   │       └── gaming_mode.dart
│   │   │   │
│   │   │   ├── control/
│   │   │   │   ├── control_screen.dart
│   │   │   │   ├── control_viewmodel.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── fan_curves_editor.dart
│   │   │   │       ├── rgb_color_picker.dart
│   │   │   │       └── power_profiles.dart
│   │   │   │
│   │   │   ├── themes/
│   │   │   │   ├── theme_store_screen.dart
│   │   │   │   ├── theme_preview.dart
│   │   │   │   └── theme_card.dart
│   │   │   │
│   │   │   └── settings/
│   │   │       ├── settings_screen.dart
│   │   │       └── settings_viewmodel.dart
│   │   │
│   │   └── navigation/
│   │       └── app_router.dart         # GoRouter configuration
│   │
│   ├── services/
│   │   ├── websocket_service.dart     # WebSocket + Reconnection
│   │   ├── discovery_service.dart     # UDP Broadcast Listener
│   │   ├── theme_service.dart        # Theme management
│   │   ├── wakelock_service.dart     # Always-on screen
│   │   ├── notification_service.dart  # Local notifications
│   │   ├── oled_protection_service.dart # Pixel shift
│   │   ├── battery_service.dart      # Battery optimization
│   │   └── connectivity_service.dart # Network changes
│   │
│   └── providers/
│       ├── telemetry_provider.dart     # Riverpod Notifier
│       ├── connection_provider.dart   # Riverpod Notifier
│       ├── theme_provider.dart        # Riverpod Notifier
│       └── settings_provider.dart     # Riverpod Notifier
│
├── assets/
│   ├── themes/
│   │   ├── cyberpunk.json
│   │   ├── matrix.json
│   │   ├── racing_red.json
│   │   └── apple_minimal.json
│   ├── images/
│   │   ├── tray_icon.png
│   │   └── placeholder_pc.png
│   └── fonts/
│       ├── Orbitron-Regular.ttf
│       ├── Rajdhani-Regular.ttf
│       └── JetBrainsMono-Regular.ttf
│
├── test/
│   ├── unit/
│   │   ├── telemetry_data_test.dart
│   │   ├── websocket_service_test.dart
│   │   ├── theme_service_test.dart
│   │   └── utils_test.dart
│   └── widget/
│       └── dashboard_screen_test.dart
│
├── integration_test/
│   └── app_test.dart
│
├── pubspec.yaml
├── analysis_options.yaml
└── android/
    └── app/src/main/AndroidManifest.xml
```

## Детальный План Задач

### Этап 1: Foundation - ИСПРАВЛЕНО

#### 1.1 Настройка Проекта (ИСПРАВЛЕНО)
- [ ] Инициализировать Flutter проект: `flutter create neonlink_app`
- [ ] Настроить `pubspec.yaml` с зависимостями:
  ```yaml
  dependencies:
    flutter:
      sdk: flutter
    flutter_localizations:
      sdk: flutter
    intl: ^0.19.0
    
    # State Management - Riverpod 3.x (ИСПРАВЛЕНО)
    flutter_riverpod: ^3.0.0
    riverpod_annotation: ^2.3.0
    
    # Charts (ИСПРАВЛЕНО)
    fl_chart: ^0.68.0
    
    # WebSocket (ИСПРАВЛЕНО - детализировано)
    web_socket_channel: ^3.0.0
    
    # JSON Serialization (ИСПРАВЛЕНО)
    json_annotation: ^4.9.0
    
    # Local Storage
    shared_preferences: ^2.2.0
    hive: ^2.2.3
    
    # WakeLock
    wakelock_plus: ^0.1.0
    
    # QR Scanner + Permissions
    qr_code_scanner: ^1.0.0
    permission_handler: ^11.0.0
    
    # Navigation
    go_router: ^14.0.0
    
    # Animations
    flutter_animate: ^4.5.0
    
    # Network + Connectivity
    connectivity_plus: ^5.0.0
    
    # Local Notifications (ИСПРАВЛЕНО)
    flutter_local_notifications: ^16.0.0
  
  dev_dependencies:
    flutter_test:
      sdk: flutter
    flutter_lints: ^3.0.0
    
    # JSON Generation (ИСПРАВЛЕНО - добавлен!)
    json_serializable: ^6.8.0
    build_runner: ^2.4.8
    
    # Riverpod Code Generation (ИСПРАВЛЕНО)
    riverpod_generator: ^2.3.0
  ```
- [ ] Добавить кастомные шрифты (Orbitron, Rajdhani, JetBrains Mono)
- [ ] Настроить `analysis_options.yaml` для строгого linting
- [ ] Настроить `l10n.yaml` для генерации локализации

#### 1.2 JSON Serialization (ИСПРАВЛЕНО)
- [ ] Создать `data/models/telemetry_data.dart`:
  ```dart
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
  ```
- [ ] Запустить генерацию: `flutter pub run build_runner build`
- [ ] Создать `core/utils/formatters.dart`:
  ```dart
  String formatTemperature(double celsius, TemperatureUnit unit) {
    switch (unit) {
      case TemperatureUnit.celsius:
        return '${celsius.toStringAsFixed(1)}°C';
      case TemperatureUnit.fahrenheit:
        return '${(celsius * 9/5 + 32).toStringAsFixed(1)}°F';
      case TemperatureUnit.kelvin:
        return '${(celsius + 273.15).toStringAsFixed(1)}K';
    }
  }
  
  String formatBytes(double megabytes) {
    if (megabytes >= 1024) {
      return '${(megabytes / 1024).toStringAsFixed(2)} GB';
    }
    return '${megabytes.toStringAsFixed(1)} MB';
  }
  ```

#### 1.3 Константы
- [ ] Создать `core/constants/app_constants.dart`:
  ```dart
  class AppConstants {
    static const defaultPort = 9876;
    static const discoveryPort = 9877; // UDP broadcast port
    static const connectionTimeout = Duration(seconds: 10);
    static const reconnectionDelayBase = Duration(seconds: 1);
    static const maxReconnectAttempts = 5;
    static const heartbeatInterval = Duration(seconds: 10);
    static const pollingInterval = Duration(milliseconds: 500);
    static const pingTimeout = Duration(seconds: 5);
    
    // Battery optimization
    static const updateThrottleThreshold = 1.0; // Only update if change > 1%
    static const oledShiftInterval = Duration(minutes: 1);
  }
  ```

---

### Этап 2: State Management (Riverpod 3.x) - ИСПРАВЛЕНО

#### 2.1 Telemetry Provider
- [ ] Создать `providers/telemetry_provider.dart`:
  ```dart
  @riverpod
  class TelemetryProvider extends AutoDisposeNotifier<TelemetryData?> {
    TelemetryData? _lastData;
  
    @override
    TelemetryData? build() => null;
  
    void updateData(TelemetryData newData) {
      // Throttle: обновлять UI только если изменение > 1%
      if (_lastData != null) {
        final cpuDiff = (newData.system.cpu.usage - 
            _lastData!.system.cpu.usage).abs();
        if (cpuDiff < AppConstants.updateThrottleThreshold) {
          return; // Skip UI update
        }
      }
      
      _lastData = newData;
      state = newData;
    }
  
    // Computed values
    double get cpuUsage => state?.system.cpu.usage ?? 0;
    double get gpuUsage => state?.system.gpu.usage ?? 0;
    double get ramUsage => state?.system.ram.usedPercent ?? 0;
    double get gpuTemp => state?.system.gpu.temp ?? 0;
    int? get fps => state?.gaming?.fps;
  }
  ```

#### 2.2 Connection Provider
- [ ] Создать `providers/connection_provider.dart`:
  ```dart
  @riverpod
  class ConnectionProvider extends Notifier<ConnectionState> {
    @override
    ConnectionState build() {
      ref.listenSelf((_, __) {
        // Auto-reconnect on state change
      });
      return ConnectionState.disconnected();
    }
  
    Future<void> connect(String ip, int port) async {
      state = state.copyWith(status: ConnectionStatus.connecting);
      
      try {
        final service = ref.read(webSocketServiceProvider);
        await service.connect(ip, port);
        state = state.copyWith(
          status: ConnectionStatus.connected,
          ip: ip,
          port: port,
        );
      } catch (e) {
        state = state.copyWith(
          status: ConnectionStatus.error,
          error: e.toString(),
        );
      }
    }
  
    void disconnect() {
      ref.read(webSocketServiceProvider).disconnect();
      state = ConnectionState.disconnected();
    }
  }
  ```

#### 2.3 Theme Provider
- [ ] Создать `providers/theme_provider.dart` с OLED protection интеграцией

#### 2.4 Settings Provider
- [ ] Создать `providers/settings_provider.dart` с persistence

---

### Этап 3: Services - ИСПРАВЛЕНО

#### 3.1 WebSocket Service (ИСПРАВЛЕНО - критично)
- [ ] Создать `services/websocket_service.dart`:
  ```dart
  class WebSocketService {
    WebSocketChannel? _channel;
    Timer? _reconnectTimer;
    Timer? _heartbeatTimer;
    int _reconnectAttempts = 0;
    String? _lastIp;
    int? _lastPort;
    final _messageController = StreamController<TelemetryData>();
    
    Stream<TelemetryData> get telemetryStream => _messageController.stream;
  
    Future<void> connect(String ip, int port) async {
      _lastIp = ip;
      _lastPort = port;
      _reconnectAttempts = 0;
      
      try {
        _channel = WebSocketChannel.connect(
          Uri.parse('ws://$ip:$port/ws'),
        );
        
        // Heartbeat каждые 10 секунд
        _heartbeatTimer = Timer.periodic(
          AppConstants.heartbeatInterval,
          (_) => _sendPing(),
        );
        
        // Слушать сообщения
        _channel!.stream.listen(
          _onMessage,
          onError: (_) => _handleDisconnect(),
          onDone: () => _handleDisconnect(),
        );
        
        // Проверка connected
        await _channel!.ready.timeout(AppConstants.pingTimeout);
      } catch (e) {
        _handleDisconnect();
        rethrow;
      }
    }
  
    void _handleDisconnect() {
      _heartbeatTimer?.cancel();
      
      if (_reconnectAttempts >= AppConstants.maxReconnectAttempts) {
        // Уведомить пользователя: "Connection lost"
        return;
      }
      
      _reconnectAttempts++;
      
      // Exponential backoff: 1s, 2s, 4s, 8s, 16s
      final delay = Duration(
        seconds: pow(2, _reconnectAttempts - 1).toInt(),
      );
      
      _reconnectTimer = Timer(delay, () {
        if (_lastIp != null && _lastPort != null) {
          connect(_lastIp!, _lastPort!);
        }
      });
    }
  
    void _sendPing() {
      if (_channel != null) {
        _channel!.sink.add(jsonEncode({'command': 'ping'}));
      }
    }
  
    void _onMessage(dynamic message) {
      try {
        final data = TelemetryData.fromJson(jsonDecode(message));
        _messageController.add(data);
      } catch (e) {
        // Log parsing error
      }
    }
  
    @override
    void dispose() {
      _reconnectTimer?.cancel();
      _heartbeatTimer?.cancel();
      _channel?.sink.close();
      _messageController.close();
    }
  }
  ```

#### 3.2 Discovery Service (ИСПРАВЛЕНО - UDP Broadcast)
- [ ] Создать `services/discovery_service.dart`:
  ```dart
  class DiscoveryService {
    RawDatagramSocket? _socket;
    final _discoveryController = StreamController<DiscoveredPC>();
    
    Stream<DiscoveredPC> get discoveredPCs => _discoveryController.stream;
  
    Future<void> startDiscovery() async {
      try {
        _socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          AppConstants.discoveryPort,
        );
        
        _socket!.listen((event) {
          if (event == RawSocketEvent.read) {
            final datagram = _socket!.receive();
            if (datagram != null) {
              final message = String.fromCharCodes(datagram.data);
              // Parse "NEONLINK:IP:PORT"
              if (message.startsWith('NEONLINK:')) {
                final parts = message.split(':');
                if (parts.length == 3) {
                  _discoveryController.add(DiscoveredPC(
                    ip: parts[1],
                    port: int.parse(parts[2]),
                    name: 'Unknown PC',
                    discoveredAt: DateTime.now(),
                  ));
                }
              }
            }
          }
        });
      } catch (e) {
        // Log error
      }
    }
  
    void stopDiscovery() {
      _socket?.close();
      _discoveryController.close();
    }
  }
  ```

#### 3.3 Notification Service (ИСПРАВЛЕНО)
- [ ] Создать `services/notification_service.dart`:
  ```dart
  class NotificationService {
    final FlutterLocalNotificationsPlugin plugin;
    
    Future<void> init() async {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      await plugin.initialize(const InitializationSettings(
        android: androidSettings,
      ));
    }
    
    void showTemperatureAlert(int temp, int threshold) {
      if (temp > threshold) {
        plugin.show(
          0,
          'High Temperature!',
          'GPU: $temp°C (threshold: $threshold°C)',
          NotificationDetails(
            android: AndroidNotificationDetails(
              'temperature_alerts',
              'Temperature Alerts',
              importance: Importance.high,
              priority: Priority.high,
              vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
            ),
          ),
        );
      }
    }
  }
  ```

#### 3.4 OLED Protection Service (ИСПРАВЛЕНО)
- [ ] Создать `services/oled_protection_service.dart`:
  ```dart
  class OledProtectionService {
    Timer? _shiftTimer;
    Offset _currentShift = Offset.zero;
    final Random _random = Random();
    
    void enable() {
      // Микро-сдвиг каждую минуту на 2-5 пикселей
      _shiftTimer = Timer.periodic(
        AppConstants.oledShiftInterval,
        (_) {
          _currentShift = Offset(
            (_random.nextInt(10) - 5).toDouble(),
            (_random.nextInt(10) - 5).toDouble(),
          );
          // Trigger rebuild через provider
        },
      );
    }
    
    void disable() {
      _shiftTimer?.cancel();
      _currentShift = Offset.zero;
    }
    
    Offset get currentShift => _currentShift;
  }
  ```

#### 3.5 Battery Optimization Service (ИСПРАВЛЕНО)
- [ ] Создать `services/battery_service.dart`:
  ```dart
  class BatteryService {
    // Снизить brightness в Always-On режиме
    Future<void> reduceBrightness() async {
      await ScreenBrightness().setApplicationScreenBrightness(0.15);
    }
    
    // Получить текущий battery level
    Future<int> getBatteryLevel() async {
      final battery = await DeviceInfo().batteryLevel;
      return battery;
    }
    
    // Проверить если low power mode
    bool isLowPowerMode = false;
  }
  ```

---

### Этап 4: UI Components - ИСПРАВЛЕНО

#### 4.1 Shared Widgets
- [ ] `CircularGauge` - CustomPainter с gradient zones
- [ ] `SparklineChart` - fl_chart с минимальным redraw
- [ ] `StatusIndicator` - Animated color transition
- [ ] `AnimatedNumber` - TweenAnimationBuilder

#### 4.2 Error Boundary (ИСПРАВЛЕНО)
- [ ] Создать `presentation/shared/widgets/error_boundary.dart`:
  ```dart
  class ErrorBoundary extends StatelessWidget {
    final Widget child;
    
    @override
    Widget build(BuildContext context) {
      return ErrorWidget.builder = (details) {
        return Center(
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              Text('Something went wrong'),
              ElevatedButton(
                onPressed: () => _restartApp(context),
                child: const Text('Restart'),
              ),
            ],
          ),
        );
      };
    }
  }
  ```

---

### Этап 5: Connection Screen - ИСПРАВЛЕНО

#### 5.1 QR Scanner Permissions (ИСПРАВЛЕНО)
- [ ] Добавить `permission_handler` integration:
  ```dart
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.status;
    
    if (status.isGranted) return true;
    
    if (status.isDenied) {
      final result = await Permission.camera.request();
      return result.isGranted;
    }
    
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    
    return false;
  }
  ```
- [ ] Добавить `AndroidManifest.xml` permissions:
  ```xml
  <uses-permission android:name="android.permission.CAMERA" />
  <uses-feature android:name="android.hardware.camera" android:required="false" />
  ```

#### 5.2 Manual Input + Validation
- [ ] Валидация IP адреса через regex
- [ ] Debounce при вводе

#### 5.3 Connection History
- [ ] Сохранение в SharedPreferences
- [ ] Быстрое переподключение

---

### Этап 6: Dashboard Screen - ИСПРАВЛЕНО

#### 6.1 Main Layout
- [ ] Bottom navigation: Dashboard, Control, Themes, Settings
- [ ] Always-on режим при открытии (Wakelock)

#### 6.2 View Modes
- [ ] **CircularGaugesMode** (default)
- [ ] **CompactMode**
- [ ] **GraphMode** - fl_chart с real-time updates
- [ ] **GamingMode** (ИСПРАВЛЕНО):
  ```dart
  class GamingMode extends StatelessWidget {
    @override
    Widget build(BuildContext context) {
      final gaming = ref.watch(telemetryProvider).data?.gaming;
      
      // MVP: Показывать GPU metrics + game detection
      // FPS будет null пока PresentMon не интегрирован
      return Column(
        children: [
          if (gaming?.active == true)
            Text('🎮 ${gaming?.activeProcess ?? "Game detected"}'),
          Text('GPU: ${gpuInfo.temp}°C'),
          if (gaming?.fps != null)
            Text('FPS: ${gaming!.fps}'),
        ],
      );
    }
  }
  ```

#### 6.3 Performance Optimization (ИСПРАВЛЕНО)
- [ ] Throttle UI updates (skip if change < 1%)
- [ ] RepaintBoundary для isolate repaint
- [ ] const constructors где возможно
- [ ] Pure black (#000000) для AMOLED

---

### Этап 7: Control Panel

#### 7.1 Fan Curves Editor
- [ ] Drag-and-drop график
- [ ] Presets: Quiet, Balanced, Performance

#### 7.2 RGB Control
- [ ] Color picker wheel
- [ ] Эффекты: Static, Breathing, Wave

---

### Этап 8: Theme Store - ИСПРАВЛЕНО

#### 8.1 MVP (ИСПРАВЛЕНО)
- [ ] 4 default темы bundled в assets
- [ ] JSON theme loader
- [ ] Theme preview
- [ ] 1 premium theme unlock через IAP (упрощено)

#### 8.2 Phase 2 (После MVP)
- [ ] Backend API для Theme Store
- [ ] User uploads
- [ ] Community ratings

---

### Этап 9: Settings - ИСПРАВЛЕНО

#### 9.1 Display Settings
- [ ] Always-on screen toggle
- [ ] OLED protection (ИСПРАВЛЕНО: pixel shift + theme rotation)
- [ ] Animation intensity

#### 9.2 Notification Settings (ИСПРАВЛЕНО)
- [ ] flutter_local_notifications integration
- [ ] Temperature threshold slider
- [ ] Vibration pattern

---

### Этап 10: Performance & Testing - ИСПРАВЛЕНО

#### 10.1 Performance Requirements
- [ ] **FPS**: 60 FPS minimum (120 FPS target)
- [ ] **Memory**: < 100 MB RAM usage
- [ ] **Battery**: < 5% drain per hour
- [ ] **Latency**: < 100 ms sensor→display

#### 10.2 Battery Optimization (ИСПРАВЛЕНО)
- [ ] Throttle UI updates (skip if change < 1%)
- [ ] Использовать RepaintBoundary
- [ ] Снизить brightness до 10-20%
- [ ] Pure black (#000000) для AMOLED
- [ ] Profile battery drain через Flutter DevTools

#### 10.3 Unit Tests
- [ ] Тесты моделей с `mockito`
- [ ] Тесты WebSocket service (connect, disconnect, reconnect)
- [ ] Тесты providers

---

### Этап 11: Localization (ИСПРАВЛЕНО - ДОБАВЛЕН)

#### 11.1 Настройка L10n
- [ ] Создать `l10n.yaml`:
  ```yaml
  arb-dir: lib/l10n
  template-arb-file: app_en.arb
  output-localization-file: app_localizations.dart
  ```
- [ ] Создать `lib/l10n/` файлы:
  - `app_en.arb`
  - `app_ru.arb`
  - `app_zh.arb`
  - `app_de.arb`
  - `app_es.arb`

#### 11.2 Переводы
- [ ] Перевести все UI strings
- [ ] Температурные единицы (C/F/K)
- [ ] Числовые форматы

---

### Этап 12: Error Handling (ИСПРАВЛЕНО - ДОБАВЛЕН)

#### 12.1 Global Error Handler
- [ ] `FlutterError.onError` = Crash reporter
- [ ] `runZonedGuarded()` для async errors
- [ ] `ErrorWidget.builder` = User-friendly error screen

#### 12.2 User-Friendly Errors
- [ ] SocketException → "Connection lost. Retrying..."
- [ ] TimeoutException → "Connection timeout. Check Wi-Fi."
- [ ] FormatException → "Invalid data received from PC."

---

## Визуальный Дизайн - Cyberpunk Theme

```dart
class CyberpunkColors {
  static const primary = Color(0xFF00F0FF);      // Neon Cyan
  static const secondary = Color(0xFFFF00AA);    // Neon Magenta
  static const accent = Color(0xFFFFD700);       // Gold
  static const background = Color(0xFF0A0E1A);   // Deep Dark Blue
  static const surface = Color(0xFF1A1F35);      // Dark Slate
  static const text = Color(0xFFE0E0E0);         // Off-White

  // Status zones
  static const safe = Color(0xFF00FF88);
  static const warning = Color(0xFFFFB800);
  static const critical = Color(0xFFFF3366);
}
```

---

## Готовность к Реализации v2.0

**Критические исправления из фидбека:**

✅ **Riverpod** - Обновлён до 3.x + riverpod_generator
✅ **mDNS** - Заменён на UDP Broadcast Listener
✅ **WebSocket** - Детализирован exponential backoff + heartbeat
✅ **JSON** - Добавлены json_serializable + build_runner
✅ **OLED Protection** - Pixel shift service + theme rotation
✅ **Battery** - Throttle updates, RepaintBoundary, brightness reduction
✅ **Gaming Mode** -备注: FPS null в MVP (требует PresentMon)
✅ **Theme Store** - Упрощён до 4 bundled тем в MVP
✅ **QR Scanner** - permission_handler + permanently denied handling
✅ **Notifications** - flutter_local_notifications integration
✅ **Localization** - l10n.yaml + 5 .arb файлов
✅ **Error Handling** - Global error boundary + user-friendly messages

**Добавлено:**
- **Этап 11**: Localization с .arb файлами
- **Этап 12**: Error Handling с crash reporting

План Android v2.0 готов к реализации!
