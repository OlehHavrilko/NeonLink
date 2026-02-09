class AppConstants {
  // Connection
  static const defaultPort = 9876;
  static const discoveryPort = 9877; // UDP broadcast port
  static const connectionTimeout = Duration(seconds: 10);
  
  // Reconnection
  static const reconnectionDelayBase = Duration(seconds: 1);
  static const maxReconnectAttempts = 5;
  
  // Heartbeat
  static const heartbeatInterval = Duration(seconds: 10);
  static const pingTimeout = Duration(seconds: 5);
  
  // Polling
  static const pollingInterval = Duration(milliseconds: 500);
  
  // Update throttle
  static const updateThrottleThreshold = 1.0; // Only update if change > 1%
  
  // OLED Protection
  static const oledShiftInterval = Duration(minutes: 1);
}
