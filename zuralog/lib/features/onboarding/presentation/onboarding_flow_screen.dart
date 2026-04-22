/// Zuralog — OnboardingFlowScreen compatibility shim.
///
/// The old 8-step wizard has been replaced by [PersonalizationFlowScreen]
/// (Phase 3 personalization wizard). This file keeps the [OnboardingFlowScreen]
/// class name alive so that [AppRouter] and any other import sites keep
/// compiling without changes during the transition.
///
/// Once [AppRouter] is updated to import [PersonalizationFlowScreen] directly,
/// remove this file.
// ignore_for_file: unused_import
library;

import 'package:flutter/material.dart';
import 'personalization_flow_screen.dart';

/// Forwards to [PersonalizationFlowScreen] so existing router imports keep
/// compiling without any changes.
class OnboardingFlowScreen extends PersonalizationFlowScreen {
  const OnboardingFlowScreen({super.key});
}
