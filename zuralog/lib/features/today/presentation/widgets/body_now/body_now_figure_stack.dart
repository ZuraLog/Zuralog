// zuralog/lib/features/today/presentation/widgets/body_now/body_now_figure_stack.dart
/// Dual front+back body silhouette for the hero.
///
/// Each figure breathes on a 4.2s cycle, offset by half a period so they
/// don't pulse in lockstep. Muscle colouring is delegated to
/// [MuscleHighlightDiagram.zones].
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/body/domain/body_state.dart';
import 'package:zuralog/features/body/domain/muscle_state.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;
import 'package:zuralog/shared/widgets/muscle_highlight_diagram.dart';

const double _figureHeight = 220;
const Duration _breatheDuration = Duration(milliseconds: 4200);

/// Base silhouette colour. The widget's default (`surfaceRaised`) is only
/// ~9 RGB steps above the hero card surface, so the figure was almost
/// invisible. Blending text-secondary onto the card gives a clearly
/// visible mid-grey body without competing with the state-colour zones.
Color _bodyBase(AppColorsOf colors) =>
    colors.textSecondary.withValues(alpha: 0.45);

class BodyNowFigureStack extends StatefulWidget {
  const BodyNowFigureStack({super.key, required this.state});

  final BodyState state;

  @override
  State<BodyNowFigureStack> createState() => _BodyNowFigureStackState();
}

class _BodyNowFigureStackState extends State<BodyNowFigureStack>
    with TickerProviderStateMixin {
  late final AnimationController _frontCtrl;
  late final AnimationController _backCtrl;

  @override
  void initState() {
    super.initState();
    _frontCtrl =
        AnimationController(vsync: this, duration: _breatheDuration)
          ..repeat(reverse: true);
    _backCtrl = AnimationController(
      vsync: this,
      duration: _breatheDuration,
      value: 0.5,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _frontCtrl.dispose();
    _backCtrl.dispose();
    super.dispose();
  }

  Map<MuscleGroup, Color> _zoneMap() {
    final map = <MuscleGroup, Color>{};
    widget.state.muscles.forEach((group, state) {
      final color = switch (state) {
        MuscleState.fresh => AppColors.categoryActivity,
        MuscleState.worked => AppColors.categoryNutrition,
        MuscleState.sore => AppColors.categoryHeart,
        MuscleState.neutral => null,
      };
      if (color != null) map[group] = color;
    });
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final zones = _zoneMap();
    final colors = AppColorsOf(context);
    final base = _bodyBase(colors);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    Widget fig(MuscleHighlightDiagram diagram, AnimationController ctrl) {
      if (reducedMotion) {
        return SizedBox(height: _figureHeight, child: diagram);
      }
      return AnimatedBuilder(
        animation: ctrl,
        builder: (_, child) {
          final eased = Curves.easeInOut.transform(ctrl.value);
          final offset = -2.0 * eased;
          final scale = 1.0 + 0.008 * eased;
          return Transform.translate(
            offset: Offset(0, offset),
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: SizedBox(height: _figureHeight, child: diagram),
      );
    }

    // Inset the row so the two figures sit closer to the card's centre
    // instead of flush against the outer edges. The Expanded children
    // still split the remaining width evenly, so both figures stay the
    // same size and aligned to each other.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(children: [
              fig(
                MuscleHighlightDiagram.zones(
                  zones: zones,
                  baseColor: base,
                  onlyFront: true,
                  strokeless: true,
                ),
                _frontCtrl,
              ),
              const SizedBox(height: 2),
              const _FigureLabel(text: 'Front'),
            ]),
          ),
          Expanded(
            child: Column(children: [
              fig(
                MuscleHighlightDiagram.zones(
                  zones: zones,
                  baseColor: base,
                  onlyBack: true,
                  strokeless: true,
                ),
                _backCtrl,
              ),
              const SizedBox(height: 2),
              const _FigureLabel(text: 'Back'),
            ]),
          ),
        ],
      ),
    );
  }
}

class _FigureLabel extends StatelessWidget {
  const _FigureLabel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: colors.textSecondary.withValues(alpha: 0.7),
      ),
    );
  }
}
