/// Life Logger Edge Agent — Local Database (Drift).
///
/// Provides an offline-first SQLite database for caching chat messages
/// and health metrics locally. Built with Drift for type-safe queries,
/// reactive streams, and automatic schema migrations.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

part 'local_db.g.dart';

/// Table definition for locally cached chat messages.
///
/// Messages are stored offline and synced with the Cloud Brain
/// when connectivity is available.
class Messages extends Table {
  /// Auto-incrementing primary key.
  IntColumn get id => integer().autoIncrement()();

  /// The text content of the message.
  TextColumn get content => text()();

  /// The role of the message sender: 'user' or 'assistant'.
  TextColumn get role => text()();

  /// When the message was created.
  DateTimeColumn get createdAt => dateTime()();
}

/// The local Drift database for offline data caching.
///
/// Currently contains only the [Messages] table. Additional tables
/// (e.g., cached health metrics) will be added in later phases.
@DriftDatabase(tables: [Messages])
class LocalDb extends _$LocalDb {
  /// Creates a new [LocalDb] instance.
  ///
  /// Uses a lazy opener to resolve the correct app documents directory
  /// at runtime (sandboxed on iOS/Android).
  LocalDb() : super(_openConnection());

  /// The current schema version.
  ///
  /// Increment this when adding migration steps.
  @override
  int get schemaVersion => 1;

  /// Retrieves all cached messages, ordered by creation time.
  ///
  /// Returns: A list of all [Message] records.
  Future<List<Message>> getAllMessages() =>
      (select(messages)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();

  /// Inserts a new message into the local cache.
  ///
  /// [msg] is a [MessagesCompanion] with the message data.
  /// Returns: The auto-generated row ID.
  Future<int> insertMessage(MessagesCompanion msg) =>
      into(messages).insert(msg);

  /// Deletes all cached messages (used for "Clear DB" harness action).
  Future<int> clearMessages() => delete(messages).go();
}

/// Opens the native SQLite database connection.
///
/// The database file is stored in the app's documents directory,
/// which is sandboxed on both iOS and Android.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(
      '${dbFolder.path}${Platform.pathSeparator}life_logger.db',
    );
    return NativeDatabase.createInBackground(file);
  });
}
