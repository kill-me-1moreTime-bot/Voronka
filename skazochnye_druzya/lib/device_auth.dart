import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

import 'debug_log.dart';

enum AuthOutcome {
  /// Взрослый подтвердил: отпечаток, лицо, PIN или графический ключ.
  ok,

  /// Отменил или не подошёл палец — просто ничего не открываем.
  cancelled,

  /// На телефоне нет блокировки экрана — вход удержанием, как раньше.
  unavailable,
}

/// Вход для взрослых через блокировку телефона. Вынесено отдельно,
/// чтобы в тестах подставлять заглушку.
abstract class DeviceAuth {
  static DeviceAuth instance = LocalDeviceAuth();

  Future<bool> supported();
  Future<AuthOutcome> unlock();
}

class LocalDeviceAuth implements DeviceAuth {
  final _auth = LocalAuthentication();

  @override
  Future<bool> supported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AuthOutcome> unlock() async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Настройки для взрослых',
        // Не только отпечаток: если палец не подходит, можно PIN-кодом.
        biometricOnly: false,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Для взрослых',
            signInHint: 'Приложите палец',
            cancelButton: 'Отмена',
          ),
        ],
      );
      return ok ? AuthOutcome.ok : AuthOutcome.cancelled;
    } on LocalAuthException catch (e) {
      DebugLog.add('[Вход] ${e.code.name}');
      return switch (e.code) {
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.uiUnavailable =>
          AuthOutcome.unavailable,
        _ => AuthOutcome.cancelled,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('[Вход] $e');
      return AuthOutcome.unavailable;
    }
  }
}
