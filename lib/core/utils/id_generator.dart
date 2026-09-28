import 'package:uuid/uuid.dart';

class IdGenerator {
  static const Uuid _uuid = Uuid();

  static String generate() => _uuid.v4();
  static String generateShort() => _uuid.v4().substring(0, 8);

  static String generateHabitId() => 'habit_${generateShort()}';
  static String generateCompletionId() => 'completion_${generateShort()}';
  static String generateSessionId() => 'session_${generateShort()}';
  static String generateEntryId() => 'entry_${generateShort()}';
}
