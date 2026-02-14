// Обратная совместимость - реэкспорт новых провайдеров
export 'network_connection_provider.dart';
export 'ui_state_provider.dart';

// Для обратной совместимости с существующим кодом
// Рекомендуется использовать networkConnectionProvider и connectionUiProvider напрямую
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'network_connection_provider.dart';
import 'ui_state_provider.dart';

/// Deprecated: Используйте networkConnectionProvider вместо этого
@Deprecated('Use networkConnectionProvider instead')
final connectionProvider = networkConnectionProvider;

/// Deprecated: Используйте NetworkState вместо этого
@Deprecated('Use NetworkState instead')
typedef ConnectionState = NetworkState;

/// Deprecated: Используйте NetworkStatus вместо этого
@Deprecated('Use NetworkStatus instead')
typedef ConnectionStatus = NetworkStatus;
