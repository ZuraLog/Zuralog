/// Generates a UUID v4 idempotency key for use with ingest endpoints.
library;

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Returns a new random UUID v4 string suitable as an idempotency key.
String generateIdempotencyKey() => _uuid.v4();
