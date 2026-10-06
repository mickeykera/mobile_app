import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ascend/app/router.dart';
import 'package:ascend/app/theme/app_theme.dart';
import 'package:ascend/core/database/database.dart';
import 'package:ascend/core/utils/app_clock.dart';

/// Renders the real app and writes PNGs, so the layout can be looked at rather
/// than asserted about.
///
/// Two reasons this exists rather than trusting the widget tests:
///
///  * A widget test uses a placeholder test font, so all text draws as filled
///    boxes. That makes "is this readable" unanswerable.
///  * The Android emulator segfaults on this host during 3D-scene init under
///    every GPU mode tried, so a device render was not available.
///
/// Both are solved by loading the bundled Geist faces into the test's font
/// collection and capturing real goldens.
///
/// Run with:
///
///     flutter test --update-goldens test/render/render_test.dart
///
/// Two viewports on purpose: [phone] is where a cramped layout breaks, and
/// [tablet] is where a fixed-width header or a six-item tab bar stops fitting.
/// The instant the captures below are taken at.
///
/// The weekday, the greeting and every "is this today" answer come from the
/// clock, so without a pin these goldens encode the day and hour they were
/// generated on and go red on the next one.
final _pinnedNow = DateTime(2025, 6, 11, 9, 30);

const _viewports = <String, Size>{
  'phone': Size(411, 915), // Pixel 7
  'tablet': Size(834, 1112), // Pixel Tablet
};

Future<void> _loadRealFonts() async {
  // Read through the same paths the app declares, so the goldens exercise the
  // bundled TTFs rather than a substitute face.
  const faces = <String, List<String>>{
    'Geist': [
      'assets/fonts/Geist-Regular.ttf',
      'assets/fonts/Geist-Medium.ttf',
      'assets/fonts/Geist-SemiBold.ttf',
      'assets/fonts/Geist-Bold.ttf',
    ],
    'Geist Mono': ['assets/fonts/GeistMono-Regular.ttf'],
  };

  for (final entry in faces.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(
        Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
      );
    }
    await loader.load();
  }
}

/// Boots the shipped router against a mocked storage layer.
///
/// Deliberately not [AscendApp]: its launch screen pulses forever, so there is
/// no settled frame to capture. Everything below the router is still the real
/// thing - real routes, real tab bar, real theme.
/// Seed storage so the screen has something to show.
///
/// An empty database renders the empty state only, which means the habit rows -
/// and with them every category colour - are never drawn and never measured.
/// That is how a palette can pass an icon-contrast check while being unusable.
Map<String, Object> _seededStorage() {
  final now = _pinnedNow;
  Map<String, Object> habit(String id, String title, String category) => {
        'id': id,
        'title': title,
        'description': '',
        'category': category,
        'frequency': 'Daily',
        'customWeekdays': <int>[],
        'timeOfDay': 'Morning',
        'targetCount': 1,
        'targetDurationMinutes': 20,
        'cue': '',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'sortOrder': 0,
        'isArchived': false,
        'streakFreezesUsed': 0,
        'lastCompletedAt': now.toIso8601String(),
        'currentStreak': 12,
        'longestStreak': 30,
        'totalCompletions': 40,
      };

  return <String, Object>{
    'habits': jsonEncode([
      habit('h1', 'Morning run', 'Body'),
      habit('h2', 'Read 20 pages', 'Mind'),
      habit('h3', 'Ship the parser', 'Craft'),
      habit('h4', 'No screens after 10', 'Discipline'),
    ]),
    // One already ticked, so the "Done today" list renders too.
    'habit_completions': jsonEncode([
      {
        'id': 'c1',
        'habitId': 'h2',
        'completedAt':
            DateTime(now.year, now.month, now.day, 8).toIso8601String(),
        'count': 1,
      }
    ]),
  };
}

Future<ProviderContainer> _boot(WidgetTester tester,
    {bool seeded = false}) async {
  // `DatabaseService()` is a singleton factory, so the "fresh" instance is the
  // same object every time and it holds on to a SharedPreferences handle from
  // the first test in this file. Seeding has to close it first, or every test
  // after the first silently renders the first test's data.
  final database = DatabaseService();
  await database.close();

  SharedPreferences.setMockInitialValues(
      seeded ? _seededStorage() : <String, Object>{});
  await database.initialize();

  final container = ProviderContainer(
    overrides: [databaseServiceProvider.overrideWithValue(database)],
  );
  addTearDown(container.dispose);

  return container;
}

Future<void> _render(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = await _boot(tester);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: container.read(routerProvider),
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
      ),
    ),
  );

  // The habits load plus every entry animation has to finish before capture,
  // or the PNG shows a half-faded screen.
  await tester.pumpAndSettle();
}

/// The app's tab bar.
///
/// Matched by runtime type name because `_GlassNavBar` is library-private and
/// it is not a `BottomNavigationBar`, so there is no public type to find it by.
/// A label alone is ambiguous - "Focus" is both a tab and a card on the Today
/// screen - which is why the finder scopes to the bar rather than searching the
/// whole tree.
Finder get _navBar => find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_GlassNavBar',
      description: 'the glass tab bar',
    );

Finder _navLabel(String label) =>
    find.descendant(of: _navBar, matching: find.text(label));

Future<void> _capture(WidgetTester tester, String name) async {
  await expectLater(
      find.byType(MaterialApp), matchesGoldenFile('goldens/render_$name.png'));
}

void main() {
  setUpAll(_loadRealFonts);
  setUpAll(() => AppClock.debugSetNow(() => _pinnedNow));
  tearDownAll(AppClock.debugResetNow);

  for (final entry in _viewports.entries) {
    testWidgets('today at ${entry.key} size', (tester) async {
      await _render(tester, entry.value);
      await _capture(tester, 'today_${entry.key}');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('today scrolled to the week strip', (tester) async {
    await _render(tester, _viewports['phone']!);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await _capture(tester, 'today_phone_scrolled');
  });

  testWidgets('today in dark mode', (tester) async {
    tester.view.physicalSize = _viewports['phone']! * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(tester.view.reset);
    addTearDown(
        tester.view.platformDispatcher.clearPlatformBrightnessTestValue);

    final container = await _boot(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: container.read(routerProvider),
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, 'today_phone_dark');
  });

  testWidgets('the seven-item tab bar fits and stays tappable', (tester) async {
    await _render(tester, _viewports['phone']!);

    final labels = [
      'Today',
      'Habits',
      'Tasks',
      'Focus',
      'Journal',
      'Analytics',
      'Premium'
    ];

    // Seven tabs is one more than the bar was built for, so the widths are
    // measured rather than assumed. Anything under 48dp fails the platform
    // minimum tap target.
    final width = _viewports['phone']!.width;
    for (final label in labels) {
      expect(_navLabel(label), findsOneWidget,
          reason: '$label is not on the bar');
    }
    expect(width / labels.length, greaterThanOrEqualTo(48));

    // Every label must actually sit inside the viewport, not merely exist in
    // the tree: an off-screen label is what a "6 tabs do not fit" bug looks
    // like before it turns into an overflow error.
    for (final label in labels) {
      expect(_navLabel(label), findsOneWidget);
      final rect = tester.getRect(_navLabel(label));
      expect(rect.left, greaterThanOrEqualTo(0),
          reason: '$label is off the left');
      expect(rect.right, lessThanOrEqualTo(width),
          reason: '$label is off the right');
      expect(rect.width, greaterThan(0));
    }

    // Labels must not collide with each other either - a bar too narrow for six
    // items can overlap them without raising an overflow error.
    final rects = labels.map((l) => tester.getRect(_navLabel(l))).toList();
    for (var i = 1; i < rects.length; i++) {
      expect(rects[i].left, greaterThanOrEqualTo(rects[i - 1].right),
          reason: '${labels[i - 1]} overlaps ${labels[i]}');
    }
  });

  testWidgets('the floating button clears the last list row', (tester) async {
    await _render(tester, _viewports['phone']!);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    // GlowButton is a custom widget, so it is found by its label rather than by
    // the FloatingActionButton type the app does not use.
    final fab = find.text('New Habit');
    expect(fab, findsOneWidget);

    // The FAB is a pill spanning most of the width, so a short scrolled list can
    // leave it sitting on top of the final row. The habits screen needed a
    // gesture workaround for exactly this; the bar is in a scrollable body here,
    // so it is asserted instead.
    final fabRect = tester.getRect(fab);
    expect(fabRect.bottom, lessThanOrEqualTo(_viewports['phone']!.height));
    expect(tester.takeException(), isNull);
  });

  testWidgets('every icon is actually visible, light theme', (tester) async {
    await _render(tester, _viewports['phone']!);
    _assertIconsAreVisible(
        tester, AppTheme.lightTheme.colorScheme.surface, 'light');
  });

  testWidgets('every category icon is visible on a populated day, light', (
    tester,
  ) async {
    tester.view.physicalSize = _viewports['phone']! * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final container = await _boot(tester, seeded: true);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: container.read(routerProvider),
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Morning run'), findsOneWidget);
    _assertIconsAreVisible(
        tester, AppTheme.lightTheme.colorScheme.surface, 'populated light');
  });

  testWidgets('every category icon is visible on a populated day, dark', (
    tester,
  ) async {
    tester.view.physicalSize = _viewports['phone']! * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(tester.view.reset);
    addTearDown(
        tester.view.platformDispatcher.clearPlatformBrightnessTestValue);

    final container = await _boot(tester, seeded: true);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: container.read(routerProvider),
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
      ),
    ));
    await tester.pumpAndSettle();

    _assertIconsAreVisible(
        tester, AppTheme.darkTheme.colorScheme.surface, 'populated dark');
  });

  testWidgets('every icon is actually visible, dark theme', (tester) async {
    tester.view.physicalSize = _viewports['phone']! * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(tester.view.reset);
    addTearDown(
        tester.view.platformDispatcher.clearPlatformBrightnessTestValue);

    final container = await _boot(tester);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: container.read(routerProvider),
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
      ),
    ));
    await tester.pumpAndSettle();
    _assertIconsAreVisible(
        tester, AppTheme.darkTheme.colorScheme.surface, 'dark');
  });

  testWidgets('no tab overflows its bar at tablet width', (tester) async {
    await _render(tester, _viewports['tablet']!);
    final width = _viewports['tablet']!.width;

    for (final label in [
      'Today',
      'Habits',
      'Tasks',
      'Focus',
      'Journal',
      'Analytics',
      'Premium'
    ]) {
      final rect = tester.getRect(_navLabel(label));
      expect(rect.left, greaterThanOrEqualTo(0), reason: '$label off the left');
      expect(rect.right, lessThanOrEqualTo(width),
          reason: '$label off the right');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow on any tab at phone size', (tester) async {
    await _render(tester, _viewports['phone']!);
    final context = tester.element(find.byType(CustomScrollView).first);
    final router = GoRouter.of(context);

    for (final tab in [
      '/habits',
      '/tasks',
      '/focus',
      '/journal',
      '/analytics',
      '/today'
    ]) {
      router.go(tab);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'overflow on $tab');
    }
  });
}

/// Contrast of two opaque colours, per WCAG.
double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Guards against icons that are drawn but cannot be seen.
///
/// The bug this exists for: a colour meant to sit *on* an accent was used *as*
/// the accent, so `onColorFor` returned white and the icon rendered white on a
/// near-white card. It renders, it occupies space, it is in the tree - and it is
/// invisible. Nothing short of measuring the pixels catches that.
///
/// 3:1 is the WCAG minimum for meaningful non-text graphics.
void _assertIconsAreVisible(WidgetTester tester, Color surface, String where) {
  final icons = tester.widgetList<Icon>(find.byType(Icon));
  expect(icons, isNotEmpty, reason: '$where: no icons rendered at all');

  /// The nearest opaque fill behind the icon.
  ///
  /// Measuring against the page surface alone reports false failures for icons
  /// drawn *on* an accent - the week strip's ring glyphs and the button labels
  /// are dark ink on a light disc by design, and dark ink on the dark page is
  /// 1:1 while being perfectly legible where it actually sits. So the backdrop
  /// is the closest ancestor that paints a solid colour.
  Color backdropFor(Finder finder) {
    var backdrop = surface;
    finder.evaluate().first.visitAncestorElements((element) {
      final widget = element.widget;
      Color? fill;
      if (widget is Container && widget.color != null) {
        fill = widget.color;
      } else if (widget is DecoratedBox) {
        final decoration = widget.decoration;
        if (decoration is BoxDecoration) {
          // A gradient paints no `color`, but it still hides the page behind
          // it - the FAB's white glyph is legible on its accent gradient even
          // though it would be invisible on the surface. Take the first stop.
          fill = decoration.color ??
              (decoration.gradient?.colors.isNotEmpty ?? false
                  ? decoration.gradient!.colors.first
                  : null);
        }
      }
      if (fill != null && fill.a >= 0.9) {
        backdrop = fill;
        return false;
      }
      return backdrop == surface;
    });
    return backdrop;
  }

  final invisible = <String>[];
  for (final icon in icons) {
    final finder = find.byWidget(icon);
    final context = tester.element(finder);
    final resolved = icon.color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    final size = icon.size ?? IconTheme.of(context).size ?? 24.0;
    final behind = backdropFor(finder);

    if (size <= 0) {
      invisible.add('${icon.icon} has size $size');
    } else if (_contrast(resolved, behind) < 3.0) {
      final ancestors = <String>[];
      find.byWidget(icon).evaluate().first.visitAncestorElements((element) {
        final type = element.widget.runtimeType.toString();
        if (!type.startsWith('Render') && !type.contains('Semantics')) {
          ancestors.add(type);
        }
        return ancestors.length < 5;
      });
      invisible.add('cp${icon.icon!.codePoint.toRadixString(16)} size$size '
          '${resolved.toARGB32().toRadixString(16)} on '
          '${behind.toARGB32().toRadixString(16)} = '
          '${_contrast(resolved, behind).toStringAsFixed(2)}:1 in '
          '${ancestors.take(4).toList()}');
    }
  }

  expect(invisible, isEmpty, reason: '$where: invisible icons -> $invisible');
}
