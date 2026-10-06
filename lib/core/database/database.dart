import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  /// The shape of the persisted JSON this build understands.
  ///
  /// Stamped on first launch and migrated forward one step at a time. Readers
  /// tolerate an absent version (treated as 0, i.e. data from before
  /// versioning), so introducing this key needs no one-off migration pass.
  static const int currentSchemaVersion = 5;
  static const String _schemaVersionKey = 'schema_version';

  /// Persistence keys introduced by schema v2.
  static const String goalsKey = 'goals';
  static const String projectsKey = 'projects';

  /// Persistence key introduced by schema v4.
  static const String tasksKey = 'tasks';

  /// Persistence key for habit records.
  static const String habitsKey = 'habits';

  Future<void> initialize() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    await ensureSchemaVersion();
    _isInitialized = true;
  }

  /// The schema version recorded on this install, or 0 when none was written.
  int getSchemaVersion() => getInt(_schemaVersionKey) ?? 0;

  /// Brings persisted data up to [currentSchemaVersion], one step at a time.
  ///
  /// Each step only adds what its version introduces and never rewrites an
  /// existing key, so re-running - after a crash mid-migration, or on every
  /// launch - is safe. Steps run in order from the recorded version, so an
  /// install that skipped a release still applies each intervening step once.
  Future<void> ensureSchemaVersion() async {
    var version = getSchemaVersion();
    if (version >= currentSchemaVersion) return;

    if (version < 1) {
      // v0 -> v1: introduce versioning itself. No data changes.
      version = 1;
    }
    if (version < 2) {
      // v1 -> v2: add the goal/project collections. Habit, completion, focus
      // and journal data is left untouched.
      await _seedJsonListIfAbsent(goalsKey);
      await _seedJsonListIfAbsent(projectsKey);
      version = 2;
    }
    if (version < 3) {
      // v2 -> v3: habits may reference a project and/or goal. Both links are
      // optional on the habit record, and "absent" already means "unfiled", so
      // existing habits need no rewrite - only the version moves.
      version = 3;
    }
    if (version < 4) {
      // v3 -> v4: add the task collection. Completion rows gain the optional
      // itemId/itemType fields and focus sessions gain the optional
      // taskId/projectId/outcome fields; all are optional, so existing rows are
      // left byte-identical and only the new collection is seeded.
      await _seedJsonListIfAbsent(tasksKey);
      version = 4;
    }
    if (version < 5) {
      // v4 -> v5: add the habits collection key if absent (it exists from v1
      // but may not be seeded on very old installs). Habit records gain the
      // optional `taskId` field for the Habit -> Task migration; since it is
      // optional, no existing records need rewriting - only the version moves.
      await _seedJsonListIfAbsent(habitsKey);
      version = 5;
    }

    await setInt(_schemaVersionKey, version);
  }

  /// Writes an empty JSON list at [key] only when nothing is stored there.
  ///
  /// The `containsKey` guard is what makes the v2 step idempotent: a second run
  /// must not overwrite a list the user has since filled.
  Future<void> _seedJsonListIfAbsent(String key) async {
    if (_prefs?.containsKey(key) ?? false) return;
    await setJsonList(key, const []);
  }

  Future<void> close() async {
    _prefs = null;
    _isInitialized = false;
  }

  Future<void> clearAllData() async {
    await _prefs?.clear();
  }

  Future<int> getDatabaseSize() async {
    if (_prefs == null) return 0;
    return _prefs!.getKeys().length;
  }

  Future<void> setString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  String? getString(String key) {
    return _prefs?.getString(key);
  }

  Future<void> setInt(String key, int value) async {
    await _prefs?.setInt(key, value);
  }

  int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  Future<void> setStringList(String key, List<String> value) async {
    await _prefs?.setStringList(key, value);
  }

  List<String>? getStringList(String key) {
    return _prefs?.getStringList(key);
  }

  Future<void> remove(String key) async {
    await _prefs?.remove(key);
  }

  Future<void> clear() async {
    await _prefs?.clear();
  }

  Set<String> getKeys() {
    return _prefs?.getKeys() ?? {};
  }

  Future<void> setJson(String key, Map<String, dynamic> value) async {
    await _prefs?.setString(key, jsonEncode(value));
  }

  Map<String, dynamic>? getJson(String key) {
    final str = _prefs?.getString(key);
    if (str == null) return null;
    return jsonDecode(str) as Map<String, dynamic>;
  }

  Future<void> setJsonList(String key, List<Map<String, dynamic>> value) async {
    await _prefs?.setString(key, jsonEncode(value));
  }

  List<Map<String, dynamic>>? getJsonList(String key) {
    final str = _prefs?.getString(key);
    if (str == null) return null;
    final list = jsonDecode(str) as List;
    return list.cast<Map<String, dynamic>>();
  }
}

final databaseServiceProvider =
    Provider<DatabaseService>((ref) => DatabaseService());
