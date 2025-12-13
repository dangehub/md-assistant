import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class MainMessages {
  static void showDialogIfNeeded(BuildContext context) {
    return; // TODO: disabled rating dialog
    if (!_showRatingDialogIfNeeded(context)) {
      Logger().i('showDialogIfNeeded: false');
    }
  }

  static bool _showRatingDialogIfNeeded(BuildContext context) {
    var settingsController = SettingsController.getInstance();
    var zeroDate = settingsController.zeroDate;
    var rateDialogCounter = settingsController.rateDialogCounter;
    // settingsController.updateRateDialogCounter(0);
    if (rateDialogCounter >= 3) {
      return false; // Dialog should not be shown more than 3 times
    }

    var currentDate = DateTime.now();
    if (zeroDate == null) {
      return false;
    }

    int daysSinceZeroDate = currentDate.difference(zeroDate).inDays;
    int requiredDays;

    if (rateDialogCounter == 0) {
      requiredDays = 15; // First dialog after 10 days
    } else if (rateDialogCounter == 1) {
      requiredDays = 45; // Second dialog after 30 days
    } else {
      requiredDays = 90; // Third dialog after 90 days
    }

    // Extract platform information before showing the dialog
    final platform = Theme.of(context).platform;

    if (daysSinceZeroDate < requiredDays) {
      return false;
    }

    _showDialog(
      'Enjoying Obsi?',
      'Please rate us ⭐⭐⭐⭐⭐!',
      context,
      primaryButtonText: 'Rate now',
      primaryButtonHandler: () async {
        await settingsController.updateRateDialogCounter(rateDialogCounter + 1);
        try {
          final url = platform == TargetPlatform.iOS
              ? "https://apps.apple.com/app/id6740782775"
              : "https://play.google.com/store/apps/details?id=com.scanworks.obsi";

          if (await canLaunchUrl(Uri.parse(url))) {
            launchUrl(Uri.parse(url));
            Navigator.pop(context);
          } else {
            Logger().e('Could not launch URL: $url');
          }
        } catch (e) {
          Logger().e('Error launching URL: $e');
        }
      },
      secondaryButtonText: 'Later',
      secondaryButtonHandler: () => Navigator.pop(context),
    );
    return true;
  }

// This dialog should be show only once on test version for iOS
  static bool showMessageForUser(BuildContext context) {
    var settingsController = SettingsController.getInstance();
    var zeroDate = settingsController.zeroDate;
    var rateDialogCounter = settingsController.rateDialogCounter;
    // Extract platform information before showing the dialog
    final platform = Theme.of(context).platform;

    if (platform == TargetPlatform.iOS &&
        (zeroDate == null || rateDialogCounter == 0)) {
      settingsController.updateRateDialogCounter(rateDialogCounter + 1);
      _showDialog(
        'Obsi in App Store',
        'Hey, thanks so much for trying out Obsi on TestFlight!\nI seriously appreciate the support — after posting on Reddit, about 100 of you joined the test, which is amazing! \nObsi is now available in the App Store! 🎉\n\nPlease rate it to support ⭐⭐⭐⭐⭐ !',
        context,
        primaryButtonText: 'Rate now',
        primaryButtonHandler: () async {
          try {
            final url = platform == TargetPlatform.iOS
                ? "https://apps.apple.com/app/id6740782775"
                : "https://play.google.com/store/apps/details?id=com.scanworks.obsi";

            if (await canLaunchUrl(Uri.parse(url))) {
              launchUrl(Uri.parse(url));
              Navigator.pop(context);
            } else {
              Logger().e('Could not launch URL: $url');
            }
          } catch (e) {
            Logger().e('Error launching URL: $e');
          }
        },
        secondaryButtonText: 'Later',
        secondaryButtonHandler: () => Navigator.pop(context),
      );
      return true;
    }
    return false;
  }

  static Future _showDialog(
    String title,
    String message,
    BuildContext context, {
    required String primaryButtonText,
    required VoidCallback primaryButtonHandler,
    required String secondaryButtonText,
    required VoidCallback secondaryButtonHandler,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: secondaryButtonHandler,
            child: Text(secondaryButtonText),
          ),
          TextButton(
            onPressed: primaryButtonHandler,
            child: Text(primaryButtonText),
          ),
        ],
      ),
    );
  }
}
