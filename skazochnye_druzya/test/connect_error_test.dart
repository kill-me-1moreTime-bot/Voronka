import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skazochnye_druzya/session/conversation_controller.dart';

void main() {
  String text(Object e) => ConversationController.connectErrorText(e);

  test('таймаут — про интернет и VPN', () {
    expect(text(TimeoutException('x', const Duration(seconds: 10))),
        contains('VPN'));
  });

  test('нет сети — про мобильную сеть', () {
    expect(text(const SocketException('Failed host lookup')),
        startsWith('Нет интернета'));
  });

  test('отказ в доступе — про ключ', () {
    expect(text(Exception('was not upgraded to websocket: 401')),
        contains('ключ'));
  });

  test('прочее — смотреть журнал', () {
    expect(text(Exception('что-то')), contains('журнал'));
  });
}
