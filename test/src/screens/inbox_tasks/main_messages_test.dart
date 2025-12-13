import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:obsi/src/screens/inbox_tasks/main_messages.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';

class MockSettingsController extends Mock implements SettingsController {
  @override
  int get rateDialogCounter => super.noSuchMethod(
        Invocation.getter(#rateDialogCounter),
        returnValue: 0,
        returnValueForMissingStub: 0,
      );

  @override
  Future<void> updateRateDialogCounter(int value) => super.noSuchMethod(
        Invocation.method(#updateRateDialogCounter, [value]),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      );
}

void main() {
  group('showMessageForUser', () {
    late MockSettingsController mockSettingsController;

    setUp(() {
      mockSettingsController = MockSettingsController();
      SettingsController.setInstance(mockSettingsController);
    });

    testWidgets(
        'should show dialog for iOS when zeroDate is null and rateDialogCounter is 0',
        (WidgetTester tester) async {
      when(mockSettingsController.zeroDate).thenReturn(null);
      when(mockSettingsController.rateDialogCounter)
          .thenReturn(0); // Mock explicitly

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS), // Mock platform as iOS
        home: Builder(
          builder: (context) {
            MainMessages.showMessageForUser(context);
            return Container();
          },
        ),
      ));

      // Debug: Check if the dialog is displayed
      await tester
          .pumpAndSettle(); // Ensure all animations and dialogs are settled
      // expect(
      //     find.text('Obsi in App Store'), findsOneWidget); // Verify dialog text

      // Verify dialog is shown and close it
      verify(mockSettingsController.updateRateDialogCounter(1)).called(1);
      //await tester.tap(find.text('Later'));
      //await tester.pumpAndSettle();
    }, skip: true); // Mark test as ignored

    testWidgets('should not show dialog for iOS when zeroDate is not null',
        (WidgetTester tester) async {
      when(mockSettingsController.zeroDate).thenReturn(DateTime.now());
      when(mockSettingsController.rateDialogCounter)
          .thenReturn(0); // Mock explicitly

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS), // Mock platform as iOS
        home: Builder(
          builder: (context) {
            final result = MainMessages.showMessageForUser(context);
            expect(result, false);
            return Container();
          },
        ),
      ));

      // Verify no dialog is shown
      expect(find.text('Obsi in App Store'), findsNothing);
      verifyNever(mockSettingsController.updateRateDialogCounter(1));
    }, skip: true); // Mark test as ignored

    testWidgets('should not show dialog for non-iOS platforms',
        (WidgetTester tester) async {
      when(mockSettingsController.zeroDate).thenReturn(null);
      when(mockSettingsController.rateDialogCounter)
          .thenReturn(0); // Mock explicitly

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
            platform: TargetPlatform.android), // Mock platform as Android
        home: Builder(
          builder: (context) {
            final result = MainMessages.showMessageForUser(context);
            expect(result, false);
            return Container();
          },
        ),
      ));

      // Verify no dialog is shown
      expect(find.text('Obsi in App Store'), findsNothing);
      verifyNever(mockSettingsController.updateRateDialogCounter(1));
    }, skip: true); // Mark test as ignored
  });
}
