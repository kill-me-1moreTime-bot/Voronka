import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skazochnye_druzya/device_auth.dart';
import 'package:skazochnye_druzya/ui/parent_gate.dart';

class FakeAuth implements DeviceAuth {
  FakeAuth({required this.isSupported, required this.result});
  bool isSupported;
  AuthOutcome result;
  int asked = 0;

  @override
  Future<bool> supported() async => isSupported;

  @override
  Future<AuthOutcome> unlock() async {
    asked++;
    return result;
  }
}

void main() {
  late int opened;

  Future<void> pump(WidgetTester t) async {
    opened = 0;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: ParentGate(onUnlocked: () => opened++, deviceAuth: true),
        ),
      ),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('отпечаток подошёл — настройки открываются по нажатию',
      (t) async {
    final auth = FakeAuth(isSupported: true, result: AuthOutcome.ok);
    DeviceAuth.instance = auth;
    await pump(t);
    await t.tap(find.byType(ParentGate));
    await t.pumpAndSettle();
    expect(auth.asked, 1);
    expect(opened, 1);
  });

  testWidgets('отмена — не открываются', (t) async {
    DeviceAuth.instance =
        FakeAuth(isSupported: true, result: AuthOutcome.cancelled);
    await pump(t);
    await t.tap(find.byType(ParentGate));
    await t.pumpAndSettle();
    expect(opened, 0);
  });

  testWidgets('с отпечатком удержание не открывает — малыш не пройдёт',
      (t) async {
    DeviceAuth.instance =
        FakeAuth(isSupported: true, result: AuthOutcome.cancelled);
    await pump(t);
    final g = await t.startGesture(t.getCenter(find.byType(ParentGate)));
    await t.pump(const Duration(milliseconds: 150));
    await t.pump(const Duration(seconds: 2));
    await t.pump(const Duration(seconds: 2));
    await g.up();
    await t.pumpAndSettle();
    expect(opened, 0);
  });

  testWidgets('без блокировки экрана — удержание 3 секунды, как раньше',
      (t) async {
    DeviceAuth.instance =
        FakeAuth(isSupported: false, result: AuthOutcome.unavailable);
    await pump(t);
    final g = await t.startGesture(t.getCenter(find.byType(ParentGate)));
    // Нажатие засчитывается через 0,1 с, потом 3 с удержания.
    await t.pump(const Duration(milliseconds: 150));
    await t.pump(const Duration(milliseconds: 1600));
    await t.pump(const Duration(milliseconds: 1600));
    await g.up();
    await t.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('блокировку сняли — переходит на удержание', (t) async {
    DeviceAuth.instance =
        FakeAuth(isSupported: true, result: AuthOutcome.unavailable);
    await pump(t);
    await t.tap(find.byType(ParentGate));
    await t.pumpAndSettle();
    expect(opened, 0);
    expect(find.textContaining('удерживайте 3 секунды'), findsOneWidget);
  });
}
