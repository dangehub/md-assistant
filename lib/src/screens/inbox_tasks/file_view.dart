import 'package:flutter/material.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/utils.dart';
import 'package:obsi/src/widgets/task_card.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

class FileView extends Card {
  final List<TaskCard> taskCards;
  final String? highlightedText;
  final String vaultName;

  const FileView(
    this.taskCards, {
    super.key,
    this.highlightedText,
    required this.vaultName,
  });

  @override
  Widget build(BuildContext context) {
    String? fileName;

    if (taskCards.isNotEmpty) {
      fileName = taskCards[0].task.taskSource?.fileName;
      if (fileName != null) {
        fileName = p.basenameWithoutExtension(fileName);
      }
    }

    var defaultTextStyle =
        TextStyle(color: Theme.of(context).colorScheme.onSurface);
    var hightlightedTextStyle = DefaultTextStyle.of(context).style.copyWith(
          backgroundColor: Colors.yellow,
          color: Colors.black,
        );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Row(children: [
            Align(alignment: Alignment.centerLeft, child: Text('File: ')),
            GestureDetector(
              onTap: () async {
                if (fileName == null || fileName.isEmpty) return;
                final Uri obsidianUri = Uri.parse(
                    'obsidian://open?vault=$vaultName&file=$fileName');
                if (await canLaunchUrl(obsidianUri)) {
                  await launchUrl(obsidianUri);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Could not open $fileName in Obsidian')),
                  );
                }
              },
              child: Align(
                alignment: Alignment.centerLeft,
                child: fileName != null &&
                        highlightedText != null &&
                        fileName.toLowerCase().contains(highlightedText!)
                    ? RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                          children: buildHighlightedTextSpans(
                              fileName,
                              highlightedText!,
                              defaultTextStyle.copyWith(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                              hightlightedTextStyle),
                        ),
                      )
                    : Text(
                        fileName ?? "",
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
              ),
            )
          ]),
        ),
        ListView(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          children: taskCards,
        ),
      ],
    );
  }
}
