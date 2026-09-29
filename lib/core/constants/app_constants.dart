import 'category_type.dart';

class AppConstants {
  static const String appName = 'Ascend';
  static const String appVersion = '1.0.0';

  static const Duration habitReminderDefaultTime = Duration(hours: 8);
  static const int maxHabitsPerCategory = 10;
  static const int freeTierMaxHabits = 7;
  static const int defaultPomodoroWorkMinutes = 25;
  static const int defaultPomodoroBreakMinutes = 5;
  static const int defaultLongBreakMinutes = 15;
  static const int pomodoroSessionsBeforeLongBreak = 4;

  static const int maxJournalEntryLength = 5000;
  static const int maxReflectionPrompts = 5;

  static const int streakFreezeCost = 1;
  static const int maxStreakFreezes = 3;

  /// `final` rather than `const` because [CategoryType.getAllTitles] builds
  /// the list at runtime; a const list would require duplicating the four
  /// titles here and risk them drifting out of sync with the enum.
  static final List<String> habitCategories = CategoryType.getAllTitles();

  static const String timeOfDayMorning = 'Morning';
  static const String timeOfDayAfternoon = 'Afternoon';
  static const String timeOfDayEvening = 'Evening';
  static const List<String> timeOfDayTags = [
    timeOfDayMorning,
    timeOfDayAfternoon,
    timeOfDayEvening,
  ];

  static const String frequencyDaily = 'Daily';
  static const String frequencyWeekdays = 'Weekdays';
  static const String frequencyWeekends = 'Weekends';
  static const String frequencyCustom = 'Custom';
  static const List<String> frequencies = [
    frequencyDaily,
    frequencyWeekdays,
    frequencyWeekends,
    frequencyCustom,
  ];

  static const String focusModePomodoro = 'Pomodoro';
  static const String focusModeCustom = 'Custom';
  static const String focusModeStopwatch = 'Stopwatch';
  static const List<String> focusModes = [
    focusModePomodoro,
    focusModeCustom,
    focusModeStopwatch,
  ];

  static const String reflectionMorning = 'Morning';
  static const String reflectionEvening = 'Evening';
  static const List<String> reflectionTypes = [
    reflectionMorning,
    reflectionEvening,
  ];

  static const String moodVeryLow = 'Very Low';
  static const String moodLow = 'Low';
  static const String moodNeutral = 'Neutral';
  static const String moodHigh = 'High';
  static const String moodVeryHigh = 'Very High';
  static const List<String> moodLevels = [
    moodVeryLow,
    moodLow,
    moodNeutral,
    moodHigh,
    moodVeryHigh,
  ];

  static const String energyVeryLow = 'Very Low';
  static const String energyLow = 'Low';
  static const String energyNeutral = 'Neutral';
  static const String energyHigh = 'High';
  static const String energyVeryHigh = 'Very High';
  static const List<String> energyLevels = [
    energyVeryLow,
    energyLow,
    energyNeutral,
    energyHigh,
    energyVeryHigh,
  ];

  static const List<String> morningPrompts = [
    'What are your 3 core priorities for today?',
    'What mindset will you bring to today\'s challenges?',
    'What potential friction points do you anticipate?',
    'How will you measure success today?',
    'What one thing, if completed, would make today a win?',
  ];

  static const List<String> eveningPrompts = [
    'What went well today?',
    'What caused friction or resistance?',
    'What did you learn about yourself?',
    'What are you grateful for today?',
    'What will you do differently tomorrow?',
  ];

  static const String analyticsPeriodWeek = 'Week';
  static const String analyticsPeriodMonth = 'Month';
  static const String analyticsPeriodQuarter = 'Quarter';
  static const String analyticsPeriodYear = 'Year';
  static const List<String> analyticsPeriods = [
    analyticsPeriodWeek,
    analyticsPeriodMonth,
    analyticsPeriodQuarter,
    analyticsPeriodYear,
  ];

  static const int heatmapWeeksToShow = 12;
  static const int maxBadgeCount = 20;
}
