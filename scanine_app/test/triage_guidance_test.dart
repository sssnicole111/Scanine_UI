import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanine_app/models/guidance_data.dart';

void main() {
  group('Triage Guidance Data Integrity', () {
    test('Expected category counts per condition', () {
      final fad = kConditionProtocols['FAD']!;
      expect(fad.startHere.length, 3, reason: 'FAD startHere count');
      expect(fad.doNot.length, 8, reason: 'FAD doNot count');
      expect(fad.monitoring.length, 10, reason: 'FAD monitoring count');
      expect(fad.homeCare.length, 10, reason: 'FAD homeCare count');
      expect(fad.totalSteps, 31, reason: 'FAD total steps');

      final ringworm = kConditionProtocols['Ringworm']!;
      expect(ringworm.startHere.length, 3, reason: 'Ringworm startHere count');
      expect(ringworm.doNot.length, 8, reason: 'Ringworm doNot count');
      expect(ringworm.monitoring.length, 7, reason: 'Ringworm monitoring count');
      expect(ringworm.homeCare.length, 13, reason: 'Ringworm homeCare count');
      expect(ringworm.totalSteps, 31, reason: 'Ringworm total steps');

      final hotspot = kConditionProtocols['Hotspot']!;
      expect(hotspot.startHere.length, 3, reason: 'Hotspot startHere count');
      expect(hotspot.doNot.length, 7, reason: 'Hotspot doNot count');
      expect(hotspot.monitoring.length, 15, reason: 'Hotspot monitoring count');
      expect(hotspot.homeCare.length, 6, reason: 'Hotspot homeCare count');
      expect(hotspot.totalSteps, 31, reason: 'Hotspot total steps');
    });

    test('No step appears in multiple lists within any condition', () {
      for (final entry in kConditionProtocols.entries) {
        final p = entry.value;
        final seenActions = <String>{};

        for (final list in [p.startHere, p.doNot, p.homeCare, p.monitoring]) {
          for (final step in list) {
            expect(
              seenActions.add(step.action),
              isTrue,
              reason: 'Duplicate action found in ${entry.key}: "${step.action}"',
            );
          }
        }
        expect(seenActions.length, 31, reason: '${entry.key} must have exactly 31 unique actions');
      }
    });

    test('All steps match exported original text exactly', () {
      final exportFile = File('guidance_export.txt');
      expect(exportFile.existsSync(), isTrue, reason: 'guidance_export.txt must exist');
      final lines = exportFile
          .readAsLinesSync()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      // 3 section headers + 93 steps = 96 lines
      expect(lines.length, 96);

      // Verify FAD
      final fadHeaderIdx = lines.indexOf('Flea Allergy Dermatitis (FAD)');
      expect(fadHeaderIdx, isNonNegative);
      final fadLines = lines.sublist(fadHeaderIdx + 1, fadHeaderIdx + 32);
      final fadProtocol = kConditionProtocols['FAD']!;
      final fadAllSteps = [
        ...fadProtocol.startHere,
        ...fadProtocol.doNot,
        ...fadProtocol.homeCare,
        ...fadProtocol.monitoring,
      ];
      for (final step in fadAllSteps) {
        final fullText = '${step.action} ${step.reason}'.trim();
        expect(
          fadLines.contains(fullText),
          isTrue,
          reason: 'FAD step "$fullText" not found in original export',
        );
      }

      // Verify Ringworm
      final rwHeaderIdx = lines.indexOf('Ringworm (Dermatophytosis)');
      expect(rwHeaderIdx, isNonNegative);
      final rwLines = lines.sublist(rwHeaderIdx + 1, rwHeaderIdx + 32);
      final rwProtocol = kConditionProtocols['Ringworm']!;
      final rwAllSteps = [
        ...rwProtocol.startHere,
        ...rwProtocol.doNot,
        ...rwProtocol.homeCare,
        ...rwProtocol.monitoring,
      ];
      for (final step in rwAllSteps) {
        final fullText = '${step.action} ${step.reason}'.trim();
        expect(
          rwLines.contains(fullText),
          isTrue,
          reason: 'Ringworm step "$fullText" not found in original export',
        );
      }

      // Verify Hotspot
      final hsHeaderIdx = lines.indexOf('Hot Spots (Acute Moist Dermatitis)');
      expect(hsHeaderIdx, isNonNegative);
      final hsLines = lines.sublist(hsHeaderIdx + 1, hsHeaderIdx + 32);
      final hsProtocol = kConditionProtocols['Hotspot']!;
      final hsAllSteps = [
        ...hsProtocol.startHere,
        ...hsProtocol.doNot,
        ...hsProtocol.homeCare,
        ...hsProtocol.monitoring,
      ];
      for (final step in hsAllSteps) {
        final fullText = '${step.action} ${step.reason}'.trim();
        expect(
          hsLines.contains(fullText),
          isTrue,
          reason: 'Hotspot step "$fullText" not found in original export',
        );
      }
    });
  });
}

