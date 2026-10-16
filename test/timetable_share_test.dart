import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/services/timetable_share.dart';

/// Feature 4 tests: rendering the timetable RepaintBoundary to PNG and
/// sharing it through the platform share sheet. Only a minimal widget is
/// pumped — never the full Monthly screen.
void main() {
  testWidgets('renderTimetablePng captures non-empty PNG bytes',
      (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: Container(
                width: 200,
                height: 120,
                color: const Color(0xFF003527),
                child: const Center(child: Text('Timetable')),
              ),
            ),
          ),
        ),
      ),
    );

    // Image capture hangs in testWidgets' FakeAsync zone; the real async
    // zone is required.
    final png = await tester.runAsync(() => renderTimetablePng(key));

    expect(png, isNotNull);
    expect(png!.isNotEmpty, isTrue);
    // PNG magic bytes: 89 50 4E 47.
    expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  test('renderTimetablePng returns null when the key is not attached',
      () async {
    expect(await renderTimetablePng(GlobalKey()), isNull);
  });

  test('shareTimetable writes the file and delegates to shareFn', () async {
    String? capturedPath;
    String? capturedSubject;

    await shareTimetable(
      pngBytes: Uint8List.fromList([1, 2, 3, 4]),
      fileName: 'timetable_share_test.png',
      subject: 'Prayer timetable',
      shareFn: (file, subject) async {
        capturedPath = file.path;
        capturedSubject = subject;
      },
    );

    expect(capturedPath, isNotNull);
    expect(capturedPath, endsWith('timetable_share_test.png'));
    expect(capturedSubject, 'Prayer timetable');

    final written = File(capturedPath!);
    expect(await written.exists(), isTrue);
    expect(await written.readAsBytes(), [1, 2, 3, 4]);

    await written.delete();
  });
}
