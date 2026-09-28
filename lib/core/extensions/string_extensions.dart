extension StringExtensions on String {
  String capitalize() =>
      '${this[0].toUpperCase()}${substring(1).toLowerCase()}';

  String capitalizeWords() =>
      split(' ').map((word) => word.capitalize()).join(' ');

  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - suffix.length)}$suffix';
  }

  bool get isNotBlank => trim().isNotEmpty;
  bool get isBlank => trim().isEmpty;

  String get snakeCase => replaceAllMapped(
        RegExp(r'[A-Z]'),
        (match) => '_${match.group(0)!.toLowerCase()}',
      ).replaceFirst(RegExp(r'^_'), '');

  String get camelCase => split('_').map((word) => word.capitalize()).join();

  String get kebabCase => replaceAllMapped(
        RegExp(r'[A-Z]'),
        (match) => '-${match.group(0)!.toLowerCase()}',
      ).replaceFirst(RegExp(r'^-'), '');

  int? tryParseInt() => int.tryParse(this);
  double? tryParseDouble() => double.tryParse(this);
  DateTime? tryParseDateTime() => DateTime.tryParse(this);
}

extension IterableExtensions<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;

  Map<K, List<T>> groupBy<K>(K Function(T) keySelector) {
    final map = <K, List<T>>{};
    for (final element in this) {
      final key = keySelector(element);
      map.putIfAbsent(key, () => []).add(element);
    }
    return map;
  }

  List<T> distinctBy<K>(K Function(T) keySelector) {
    final seen = <K>{};
    return where((element) => seen.add(keySelector(element))).toList();
  }
}

extension ListExtensions<T> on List<T> {
  void swap(int i, int j) {
    if (i >= 0 && i < length && j >= 0 && j < length) {
      final temp = this[i];
      this[i] = this[j];
      this[j] = temp;
    }
  }

  List<T> move(int from, int to) {
    if (from < 0 || from >= length || to < 0 || to >= length) return this;
    final item = removeAt(from);
    insert(to, item);
    return this;
  }
}

extension DurationExtensions on Duration {
  String formatShort() {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String formatLong() {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);

    final parts = <String>[];
    if (hours > 0) parts.add('$hours hour${hours == 1 ? '' : 's'}');
    if (minutes > 0) parts.add('$minutes minute${minutes == 1 ? '' : 's'}');
    if (seconds > 0 || parts.isEmpty) {
      parts.add('$seconds second${seconds == 1 ? '' : 's'}');
    }

    return parts.join(', ');
  }

  String formatTimer() {
    final hours = inHours;
    final minutes = inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
