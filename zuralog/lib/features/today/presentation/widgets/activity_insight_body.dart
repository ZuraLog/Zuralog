/// Activity-variant body. Stubbed until Task 10 — forwards to generic.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/presentation/widgets/generic_insight_body.dart';

List<Widget> activityInsightSlivers(
  BuildContext context,
  WidgetRef ref,
  InsightDetail detail,
) =>
    genericInsightSlivers(context, ref, detail);
