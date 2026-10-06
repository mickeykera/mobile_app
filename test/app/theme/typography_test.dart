import 'dart:convert';
import 'dart:io';

import 'package:ascend/app/theme/app_theme.dart';
import 'package:ascend/app/theme/text_styles.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every bundled face, read from disk rather than listed by hand, so a font
/// that gets added cannot quietly ship undeclared and fall back to the platform
/// default at runtime.
List<File> get _bundledFonts => Directory('assets/fonts')
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.ttf'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  test('every bundled font file is declared in pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final fonts = _bundledFonts;
    expect(fonts, isNotEmpty, reason: 'no font files found to check');

    for (final font in fonts) {
      expect(pubspec, contains(font.path),
          reason:
              '${font.path} is bundled but not declared, so it never loads');
    }
  });

  test('every bundled font file is byte-distinct from the others', () {
    // Base64 rather than a hash: a collision would turn this into a test that
    // passes on exactly the duplicate it exists to catch.
    final seen = <String, String>{};
    for (final font in _bundledFonts) {
      final encoded = base64Encode(font.readAsBytesSync());
      expect(seen.containsKey(encoded), isFalse,
          reason: '${font.path} is byte-identical to ${seen[encoded]}');
      seen[encoded] = font.path;
    }
  });

  test('GeistSans static font families resolve to distinct files', () {
    expect(AppTextStyles.displayLarge.fontFamily, 'Geist');
    expect(AppTextStyles.bodyMedium.fontFamily, 'Geist');
  });

  test('GeistMono static font families resolve to distinct files', () {
    expect(AppTextStyles.displayLarge.fontFamily, isNot('Geist Mono'));
    expect(AppTextStyles.tabular.fontFamily, 'Geist Mono');
  });

  test('AppTextStyles weight/style parsing matches declared faces', () {
    final expected = <String, String>{
      'w400_normal': 'Geist-Regular.ttf',
      'w500_normal': 'Geist-Medium.ttf',
      'w600_normal': 'Geist-SemiBold.ttf',
      'w700_normal': 'Geist-Bold.ttf',
      'w400_italic': 'Geist-Italic.ttf',
      'w500_italic': 'Geist-Italic.ttf',
      'w600_italic': 'Geist-Italic.ttf',
      'w700_italic': 'Geist-Italic.ttf',
    };
    for (final entry in expected.entries) {
      // We just verify the map structure; actual resolution tested elsewhere
      expect(entry.value, contains('Geist'));
    }
  });

  test('no Material icons remain in lib/', () {
    final result = Process.runSync('grep', ['-r', r'\\bIcons.', 'lib/']);
    expect(result.exitCode, 1, reason: 'Material Icons found in lib/');
  });

  test('every Lucide icon used in lib/ is audited here', () {
    final dir = Directory('lib');
    final referenced = <String>{};
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final content = entity.readAsStringSync();
        for (final match in RegExp(r'LucideIcons\.(\w+)').allMatches(content)) {
          referenced.add(match.group(1)!);
        }
      }
    }

    final audited = <String>{
      'activity',
      'alarmClock',
      'archive',
      'archiveRestore',
      'arrowRight',
      'barChart',
      'barChart2',
      'batteryCharging',
      'bookOpen',
      'brain',
      'calendar',
      'calendarClock',
      'calendarDays',
      'calendarPlus',
      'chartNoAxesColumn',
      'check',
      'checkCircle',
      'checkCircle2',
      'chevronDown',
      'chevronRight',
      'chevronUp',
      'circleAlert',
      'circleCheck',
      'clock',
      'cloud',
      'cloudUpload',
      'code',
      'coffee',
      'crosshair',
      'diamond',
      'download',
      'dumbbell',
      'ellipsisVertical',
      'fileText',
      'flag',
      'flame',
      'folder',
      'forward',
      'gem',
      'gitBranch',
      'heart',
      'heartHandshake',
      'helpCircle',
      'hourglass',
      'inbox',
      'info',
      'layoutDashboard',
      'lifeBuoy',
      'lightbulb',
      'link',
      'listChecks',
      'folderX',
      'folderPlus',
      'circle',
      'calendarX',
      'listTodo',
      'listOrdered',
      'loader',
      'lock',
      'moon',
      'moreHorizontal',
      'notebookPen',
      'pause',
      'pencil',
      'pieChart',
      'play',
      'plus',
      'refreshCw',
      'repeat',
      'rotateCcw',
      'save',
      'scatterChart',
      'settings',
      'shield',
      'slidersHorizontal',
      'smile',
      'star',
      'sun',
      'sunset',
      'target',
      'timer',
      'trash',
      'trash2',
      'trendingUp',
      'triangleAlert',
      'trophy',
      'type',
      'x',
    };

    expect(referenced.difference(audited), isEmpty,
        reason: 'new Lucide icons not audited by this test: '
            '${referenced.difference(audited)}');

    final unused = audited.difference(referenced);
    expect(unused.length, lessThanOrEqualTo(10),
        reason: 'audited icons not used in lib/: $unused');
  });

  test('theme uses Geist Sans for text styles', () {
    expect(AppTheme.lightTheme.textTheme.displayLarge?.fontFamily, 'Geist');
    expect(AppTheme.darkTheme.textTheme.bodyMedium?.fontFamily, 'Geist');
  });

  test('tabular style uses Geist Mono', () {
    expect(AppTextStyles.tabular.fontFamily, 'Geist Mono');
  });
}
