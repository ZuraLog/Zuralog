/// Zuralog Design System — Component Showcase Screen.
///
/// A scrollable screen that displays every design system "lego" component
/// in all its variants and states. Accessible via /debug/components.
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_artifact_card.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_blob.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_ghost_banner.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_suggestion_card.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_thinking_layer.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_user_message.dart';
import 'package:zuralog/features/data/presentation/widgets/tile_visualizations.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

class ComponentShowcaseScreen extends ConsumerStatefulWidget {
  const ComponentShowcaseScreen({super.key});

  @override
  ConsumerState<ComponentShowcaseScreen> createState() =>
      _ComponentShowcaseScreenState();
}

class _ComponentShowcaseScreenState
    extends ConsumerState<ComponentShowcaseScreen> {
  // ── Theme colors (set at top of build, used by builder helpers) ─────────
  AppColorsOf? _colors;

  // ── State for interactive demos ──────────────────────────────────────────
  bool _toggleValue = true;
  bool _toggleOff = false;
  bool _checkboxValue = true;
  bool _checkboxOff = false;
  double _sliderValue = 0.6;
  String? _radioValue = 'daily';
  int _segmentIndex = 0;
  Set<String> _activeChips = {'Sleep', 'Heart'};
  String? _selectValue;
  int _stepperValue = 5;
  final double _progressValue = 0.67;
  Set<String> _toggleGroupValues = {'mon', 'fri'};
  int _ratingValue = 3;
  DateTime? _selectedDate = DateTime.now();
  int _staggerKey = 0;
  int _navBarActiveIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    _colors = colors;
    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spaceMdPlus),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          color: colors.textPrimary,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Builder(builder: (context) {
                          final isDark =
                              Theme.of(context).brightness == Brightness.dark;
                          return ZIconButton(
                            icon: isDark
                                ? Icons.light_mode
                                : Icons.dark_mode,
                            isSage: true,
                            semanticLabel: isDark ? 'Switch to light mode' : 'Switch to dark mode',
                            onPressed: () {
                              final newMode =
                                  isDark ? ThemeMode.light : ThemeMode.dark;
                              ref
                                  .read(themeModeProvider.notifier)
                                  .setTheme(newMode);
                            },
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    Text(
                      'Component Showcase',
                      style: AppTextStyles.displayLarge
                          .copyWith(color: colors.textPrimary),
                    ),
                    const SizedBox(height: AppDimens.spaceXs),
                    Text(
                      'Every design system lego in one place',
                      style: AppTextStyles.bodyLarge
                          .copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),

            // ── Sections ──────────────────────────────────────────────────
            _sliverSection('Foundations', colors),
            _sliverChild(_buildFoundations()),

            _sliverSection('Buttons', colors),
            _sliverChild(_buildButtons()),

            _sliverSection('Cards', colors),
            _sliverChild(_buildCards()),

            _sliverSection('Inputs & Selection', colors),
            _sliverChild(_buildInputs()),

            _sliverSection('Feedback', colors),
            _sliverChild(_buildFeedback()),

            _sliverSection('Display', colors),
            _sliverChild(_buildDisplay()),

            _sliverSection('Special Surfaces', colors),
            _sliverChild(_buildSpecialSurfaces()),

            _sliverSection('Navigation & Layout', colors),
            _sliverChild(_buildNavigationLayout()),

            _sliverSection('Coach Components', colors),
            _sliverChild(_buildCoachComponents()),

            // ── Footer ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spaceXxl),
                child: Center(
                  child: Text(
                    'Zuralog Design System · 2026',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: colors.textSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _sliverSection(String title, AppColorsOf colors) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMdPlus,
          AppDimens.spaceLg,
          AppDimens.spaceMdPlus,
          AppDimens.spaceSm,
        ),
        child: Text(
          title,
          style:
              AppTextStyles.displaySmall.copyWith(color: colors.primary),
        ),
      ),
    );
  }

  Widget _sliverChild(Widget child) {
    return SliverToBoxAdapter(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppDimens.spaceMdPlus),
        child: child,
      ),
    );
  }

  Widget _label(String text, AppColorsOf colors) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppDimens.spaceMd,
        bottom: AppDimens.spaceSm,
      ),
      child: Text(
        text,
        style: AppTextStyles.labelMedium
            .copyWith(color: colors.textSecondary),
      ),
    );
  }

  Widget _gap([double h = AppDimens.spaceSm]) => SizedBox(height: h);

  // ── 1. FOUNDATIONS ──────────────────────────────────────────────────────

  Widget _buildFoundations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Canvas & Elevation', _colors!),
        for (final entry in [
          ('Canvas', _colors!.canvas),
          ('Surface', _colors!.surface),
          ('Surface Raised', _colors!.surfaceRaised),
          ('Surface Overlay', _colors!.surfaceOverlay),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                color: entry.$2,
                borderRadius: BorderRadius.circular(AppDimens.shapeXs),
                border: Border.all(
                  color: _colors!.border,
                ),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.$1,
                      style: AppTextStyles.labelMedium
                          .copyWith(color: _colors!.textPrimary)),
                  Text(
                      '#${entry.$2.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                      style: AppTextStyles.labelSmall.copyWith(
                          color: _colors!.textSecondary,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
          ),

        _label('Accent Colors', _colors!),
        Row(
          children: [
            _colorSwatch('Sage', _colors!.primary),
            _colorSwatch('Warm White', _colors!.warmWhite),
          ],
        ),

        _label('Health Categories', _colors!),
        Wrap(
          spacing: AppDimens.spaceSm,
          runSpacing: AppDimens.spaceSm,
          children: [
            _categoryDot('Activity', AppColors.categoryActivity),
            _categoryDot('Sleep', AppColors.categorySleep),
            _categoryDot('Heart', AppColors.categoryHeart),
            _categoryDot('Nutrition', AppColors.categoryNutrition),
            _categoryDot('Body', AppColors.categoryBody),
            _categoryDot('Vitals', AppColors.categoryVitals),
            _categoryDot('Wellness', AppColors.categoryWellness),
            _categoryDot('Cycle', AppColors.categoryCycle),
            _categoryDot('Mobility', AppColors.categoryMobility),
            _categoryDot('Environment', AppColors.categoryEnvironment),
          ],
        ),

        _label('Status Colors', _colors!),
        Wrap(
          spacing: AppDimens.spaceMd,
          runSpacing: AppDimens.spaceSm,
          children: [
            _statusDot('Success', AppColors.success, ZPatternVariant.sage),
            _statusDot('Warning', AppColors.warning, ZPatternVariant.amber),
            _statusDot('Error', AppColors.error, ZPatternVariant.crimson),
            _statusDot('Syncing', AppColors.syncing, ZPatternVariant.skyBlue),
          ],
        ),

        _label('Typography', _colors!),
        Text('Display Large (34pt Bold)',
            style: AppTextStyles.displayLarge
                .copyWith(color: _colors!.textPrimary)),
        Text('Display Medium (28pt SemiBold)',
            style: AppTextStyles.displayMedium
                .copyWith(color: _colors!.textPrimary)),
        Text('Display Small (24pt SemiBold)',
            style: AppTextStyles.displaySmall
                .copyWith(color: _colors!.textPrimary)),
        Text('Title Large (20pt Medium)',
            style: AppTextStyles.titleLarge
                .copyWith(color: _colors!.textPrimary)),
        Text('Title Medium (17pt Medium)',
            style: AppTextStyles.titleMedium
                .copyWith(color: _colors!.textPrimary)),
        Text('Body Large (16pt Regular)',
            style: AppTextStyles.bodyLarge
                .copyWith(color: _colors!.textPrimary)),
        Text('Body Medium (14pt Regular)',
            style: AppTextStyles.bodyMedium
                .copyWith(color: _colors!.textPrimary)),
        Text('Body Small (12pt Regular)',
            style: AppTextStyles.bodySmall
                .copyWith(color: _colors!.textPrimary)),
        Text('Label Large (15pt SemiBold)',
            style: AppTextStyles.labelLarge
                .copyWith(color: _colors!.textPrimary)),
        Text('Label Medium (13pt Medium)',
            style: AppTextStyles.labelMedium
                .copyWith(color: _colors!.textPrimary)),
        Text('Label Small (11pt Medium)',
            style: AppTextStyles.labelSmall
                .copyWith(color: _colors!.textPrimary)),

        _label('Pattern Typography', _colors!),
        // Bold (animated drift) — display-lg
        ZPatternText(
          text: 'Zuralog Health',
          style: AppTextStyles.displayLarge,
          variant: ZPatternVariant.sage,
          animate: true,
        ),
        _gap(),
        // Semibold (static) — display-md
        ZPatternText(
          text: 'AI Wellness Coach',
          style: AppTextStyles.displayMedium,
          variant: ZPatternVariant.sage,
        ),
        _gap(),
        // Semibold (static) — display-sm
        ZPatternText(
          text: 'Your Health Journey',
          style: AppTextStyles.displaySmall,
          variant: ZPatternVariant.sage,
        ),

        _label('Pattern Color Variants', _colors!),
        // Sage
        ZPatternText(
          text: 'Sage Pattern',
          style: AppTextStyles.displayMedium,
          variant: ZPatternVariant.sage,
        ),
        _gap(),
        // Crimson
        ZPatternText(
          text: 'Crimson Pattern',
          style: AppTextStyles.displayMedium,
          variant: ZPatternVariant.crimson,
        ),
        _gap(),
        // Amber
        ZPatternText(
          text: 'Amber Pattern',
          style: AppTextStyles.displayMedium,
          variant: ZPatternVariant.amber,
        ),
        _gap(),
        // Original
        ZPatternText(
          text: 'Original Pattern',
          style: AppTextStyles.displayMedium,
          variant: ZPatternVariant.original,
        ),

        _label('Solid Text (comparison)', _colors!),
        Text('Solid Sage',
            style: AppTextStyles.displayMedium
                .copyWith(color: _colors!.primary)),
        _gap(),
        Text(
            'Body text stays solid — patterns are only for display-size headings where the letterforms are large enough.',
            style: AppTextStyles.bodyLarge
                .copyWith(color: AppColorsOf(context).textPrimary)),

        _label('Spacing', _colors!),
        _spacingBar('XXS (2px)', AppDimens.spaceXxs),
        _spacingBar('XS (4px)', AppDimens.spaceXs),
        _spacingBar('SM (8px)', AppDimens.spaceSm),
        _spacingBar('MD (16px)', AppDimens.spaceMd),
        _spacingBar('MD+ (20px)', AppDimens.spaceMdPlus),
        _spacingBar('LG (24px)', AppDimens.spaceLg),
        _spacingBar('XL (32px)', AppDimens.spaceXl),
        _spacingBar('XXL (48px)', AppDimens.spaceXxl),

        _label('Shape (Border Radius)', _colors!),
        Wrap(
          spacing: AppDimens.spaceSm,
          runSpacing: AppDimens.spaceSm,
          children: [
            _radiusBox('XS 8', AppDimens.shapeXs),
            _radiusBox('SM 12', AppDimens.shapeSm),
            _radiusBox('MD 16', AppDimens.shapeMd),
            _radiusBox('LG 20', AppDimens.shapeLg),
            _radiusBox('XL 28', AppDimens.shapeXl),
            _radiusBox('Pill', AppDimens.shapePill),
          ],
        ),
      ],
    );
  }

  Widget _colorSwatch(String name, Color color) {
    final hex =
        '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppDimens.shapeXs),
                border: Border.all(
                  color: _colors!.border,
                  width: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(name,
                style: AppTextStyles.labelSmall
                    .copyWith(color: _colors!.textSecondary)),
            Text(hex,
                style: AppTextStyles.labelSmall.copyWith(
                    color: _colors!.textSecondary,
                    fontSize: 9,
                    fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }

  Widget _categoryDot(String name, Color color) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(height: 2),
        Text(name,
            style: AppTextStyles.labelSmall
                .copyWith(color: _colors!.textSecondary, fontSize: 9)),
      ],
    );
  }

  Widget _statusDot(String name, Color color, ZPatternVariant variant) {
    return Column(
      children: [
        ClipOval(
          child: SizedBox(
            width: 32,
            height: 32,
            child: Image.asset(
              variant.assetPath,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(name,
            style: AppTextStyles.labelSmall
                .copyWith(color: _colors!.textSecondary)),
      ],
    );
  }

  Widget _spacingBar(String label, double width) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: _colors!.textSecondary)),
          ),
          Container(
            width: width * 3, // visual scale
            height: 12,
            decoration: BoxDecoration(
              color: _colors!.primary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _radiusBox(String label, double radius) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _colors!.surfaceRaised,
            borderRadius: BorderRadius.circular(radius.clamp(0, 24)),
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: AppTextStyles.labelSmall
                .copyWith(color: _colors!.textSecondary)),
      ],
    );
  }

  // ── 2. BUTTONS ────────────────────────────────────────────────────────

  Widget _buildButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Primary — all sizes', _colors!),
        ZButton(label: 'Large Primary', onPressed: () {}),
        _gap(),
        ZButton(
            label: 'Medium Primary',
            size: ZButtonSize.medium,
            onPressed: () {}),
        _gap(),
        ZButton(
            label: 'Small Primary',
            size: ZButtonSize.small,
            onPressed: () {}),

        _label('Destructive', _colors!),
        ZButton(
            label: 'Delete Account',
            variant: ZButtonVariant.destructive,
            onPressed: () {}),

        _label('Secondary', _colors!),
        ZButton(
            label: 'View Details',
            variant: ZButtonVariant.secondary,
            onPressed: () {}),

        _label('Text', _colors!),
        ZButton(
            label: 'See all →',
            variant: ZButtonVariant.text,
            onPressed: () {},
            isFullWidth: false),

        _label('With icons', _colors!),
        ZButton(label: 'Log Activity', icon: Icons.add, onPressed: () {}),
        _gap(),
        ZButton(
            label: 'Settings',
            variant: ZButtonVariant.secondary,
            icon: Icons.settings,
            onPressed: () {}),

        _label('States', _colors!),
        ZButton(label: 'Disabled', onPressed: null),
        _gap(),
        const ZButton(label: 'Loading...', isLoading: true),

        _label('Icon Button', _colors!),
        Row(
          children: [
            ZIconButton(icon: Icons.favorite, onPressed: () {}, semanticLabel: 'Like'),
            const SizedBox(width: AppDimens.spaceSm),
            ZIconButton(
                icon: Icons.share, onPressed: () {}, isSage: true, semanticLabel: 'Share'),
            const SizedBox(width: AppDimens.spaceSm),
            ZIconButton(
                icon: Icons.more_vert, onPressed: () {}, filled: false, semanticLabel: 'More options'),
          ],
        ),

        _label('FAB', _colors!),
        Align(
          alignment: Alignment.centerRight,
          child: ZLogFab(onPressed: () {}),
        ),
      ],
    );
  }

  // ── 3. CARDS ──────────────────────────────────────────────────────────

  Widget _buildCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Hero Card (pattern 10%)', _colors!),
        ZuralogCard(
          variant: ZCardVariant.hero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Health Score',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: _colors!.textSecondary)),
              Text('87',
                  style: AppTextStyles.displayLarge
                      .copyWith(color: _colors!.primary)),
            ],
          ),
        ),

        _label('Feature Card (pattern 7%)', _colors!),
        ZuralogCard(
          variant: ZCardVariant.feature,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI Insight',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: _colors!.primary)),
              const SizedBox(height: AppDimens.spaceXs),
              Text(
                'Your sleep quality improved 12% this week. Keep up the consistent bedtime routine!',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: _colors!.textPrimary),
              ),
            ],
          ),
        ),

        _label('Category Feature Cards', _colors!),
        ZuralogCard(
          variant: ZCardVariant.feature,
          category: AppColors.categorySleep,
          child: Text('Sleep Insight',
              style: AppTextStyles.titleMedium
                  .copyWith(color: _colors!.textPrimary)),
        ),
        _gap(),
        ZuralogCard(
          variant: ZCardVariant.feature,
          category: AppColors.categoryHeart,
          child: Text('Heart Rate Insight',
              style: AppTextStyles.titleMedium
                  .copyWith(color: _colors!.textPrimary)),
        ),

        _label('Data Card (no pattern)', _colors!),
        ZuralogCard(
          variant: ZCardVariant.data,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Steps Today',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: _colors!.textSecondary)),
              Text('8,432',
                  style: AppTextStyles.titleLarge
                      .copyWith(color: _colors!.textPrimary)),
            ],
          ),
        ),

        _label('Topographic Card', _colors!),
        ZTopographicCard(
          child: Text('Legacy topographic card',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: _colors!.textPrimary)),
        ),
      ],
    );
  }

  // ── 4. INPUTS & SELECTION ─────────────────────────────────────────────

  Widget _buildInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Toggle', _colors!),
        ZToggle(
          value: _toggleValue,
          onChanged: (v) => setState(() => _toggleValue = v),
          label: 'Push Notifications',
        ),
        _gap(),
        ZToggle(
          value: _toggleOff,
          onChanged: (v) => setState(() => _toggleOff = v),
          label: 'Dark Mode',
        ),
        _gap(),
        const ZToggle(value: true, label: 'Disabled (on)', enabled: false),

        _label('Checkbox', _colors!),
        ZCheckbox(
          value: _checkboxValue,
          onChanged: (v) => setState(() => _checkboxValue = v),
          label: 'Accept terms and conditions',
        ),
        _gap(),
        ZCheckbox(
          value: _checkboxOff,
          onChanged: (v) => setState(() => _checkboxOff = v),
          label: 'Send me updates',
        ),
        _gap(),
        const ZCheckbox(value: true, label: 'Disabled', enabled: false),

        _label('Slider', _colors!),
        ZSlider(
          value: _sliderValue,
          onChanged: (v) => setState(() => _sliderValue = v),
          label: 'Volume: ${(_sliderValue * 100).round()}%',
        ),

        _label('Radio Group', _colors!),
        ZRadioGroup<String>(
          value: _radioValue,
          onChanged: (v) => setState(() => _radioValue = v),
          options: const [
            ZRadioOption(value: 'daily', label: 'Daily'),
            ZRadioOption(value: 'weekly', label: 'Weekly'),
            ZRadioOption(value: 'monthly', label: 'Monthly'),
          ],
        ),

        _label('Segmented Control', _colors!),
        ZSegmentedControl(
          selectedIndex: _segmentIndex,
          onChanged: (i) => setState(() => _segmentIndex = i),
          segments: const ['Day', 'Week', 'Month', 'Year'],
        ),

        _label('Chips', _colors!),
        Wrap(
          spacing: AppDimens.spaceSm,
          children: [
            for (final chip in ['Sleep', 'Heart', 'Activity', 'Nutrition', 'Body'])
              ZChip(
                label: chip,
                isActive: _activeChips.contains(chip),
                onTap: () => setState(() {
                  _activeChips = Set.of(_activeChips);
                  if (_activeChips.contains(chip)) {
                    _activeChips.remove(chip);
                  } else {
                    _activeChips.add(chip);
                  }
                }),
              ),
          ],
        ),

        _label('Select / Dropdown', _colors!),
        ZSelect(
          value: _selectValue,
          onChanged: (v) => setState(() => _selectValue = v),
          options: const ['Daily', 'Weekly', 'Monthly', 'Yearly'],
          placeholder: 'Choose frequency',
          label: 'Report Frequency',
        ),

        _label('Text Area', _colors!),
        const ZTextArea(
          placeholder: 'How are you feeling today?',
          label: 'Health Note',
        ),

        _label('Search Bar', _colors!),
        ZSearchBar(
          onChanged: (v) {},
          placeholder: 'Search metrics...',
        ),

        _label('Number Stepper', _colors!),
        ZNumberStepper(
          value: _stepperValue,
          onChanged: (v) => setState(() => _stepperValue = v),
          min: 0,
          max: 20,
        ),

        _label('Text Field (existing)', _colors!),
        const AppTextField(
          labelText: 'Email',
          hintText: 'you@example.com',
        ),

        _label('Toggle Group', _colors!),
        ZToggleGroup<String>(
          items: const [
            ZToggleGroupItem(value: 'mon', label: 'Mon'),
            ZToggleGroupItem(value: 'wed', label: 'Wed'),
            ZToggleGroupItem(value: 'fri', label: 'Fri'),
            ZToggleGroupItem(value: 'sat', label: 'Sat'),
          ],
          selectedValues: _toggleGroupValues,
          onChanged: (v) => setState(() => _toggleGroupValues = v),
        ),

        _label('OTP / PIN Input', _colors!),
        ZOtpInput(
          onCompleted: (code) {},
          onChanged: (code) {},
        ),

        _label('Password Field', _colors!),
        const ZPasswordField(
          label: 'Password',
          hint: 'Enter your password',
        ),

        _label('Rating Bar', _colors!),
        ZRatingBar(
          rating: _ratingValue,
          onChanged: (v) => setState(() => _ratingValue = v),
        ),

        _label('Calendar', _colors!),
        ZCalendar(
          selectedDate: _selectedDate,
          onDateSelected: (d) => setState(() => _selectedDate = d),
        ),
      ],
    );
  }

  // ── 5. FEEDBACK ───────────────────────────────────────────────────────

  Widget _buildFeedback() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Toast (tap to trigger)', _colors!),
        Row(
          children: [
            Expanded(
              child: ZButton(
                label: 'Success',
                size: ZButtonSize.small,
                onPressed: () =>
                    ZToast.success(context, 'Activity logged!'),
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Expanded(
              child: ZButton(
                label: 'Error',
                size: ZButtonSize.small,
                variant: ZButtonVariant.destructive,
                onPressed: () =>
                    ZToast.error(context, 'Failed to sync'),
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Expanded(
              child: ZButton(
                label: 'Warning',
                size: ZButtonSize.small,
                variant: ZButtonVariant.secondary,
                onPressed: () =>
                    ZToast.warning(context, 'Storage almost full'),
              ),
            ),
          ],
        ),

        _label('Alert Dialog (tap to trigger)', _colors!),
        ZButton(
          label: 'Show Dialog',
          variant: ZButtonVariant.secondary,
          onPressed: () => ZAlertDialog.show(
            context,
            title: 'Delete Entry?',
            body: 'This action cannot be undone. Your sleep data for today will be permanently removed.',
            confirmLabel: 'Delete',
            isDestructive: true,
          ),
        ),

        _label('Bottom Sheet (tap to trigger)', _colors!),
        ZButton(
          label: 'Show Bottom Sheet',
          variant: ZButtonVariant.secondary,
          onPressed: () => ZBottomSheet.show(
            context,
            title: 'Log Activity',
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Choose an activity to log',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: _colors!.textSecondary)),
                  const SizedBox(height: AppDimens.spaceMd),
                  ZButton(label: 'Sleep', onPressed: () => Navigator.pop(context)),
                  const SizedBox(height: AppDimens.spaceSm),
                  ZButton(
                      label: 'Exercise',
                      variant: ZButtonVariant.secondary,
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
          ),
        ),

        _label('Badge', _colors!),
        Row(
          children: [
            const ZBadge(label: '3', variant: ZBadgeVariant.error),
            const SizedBox(width: AppDimens.spaceMd),
            const ZBadge(label: 'New', variant: ZBadgeVariant.sage),
            const SizedBox(width: AppDimens.spaceMd),
            const ZBadge(label: '12', variant: ZBadgeVariant.neutral),
          ],
        ),

        _label('Tooltip (long press the text)', _colors!),
        ZTooltip(
          message: 'Your health score is calculated from 10 categories',
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm,
            ),
            decoration: BoxDecoration(
              color: _colors!.surfaceRaised,
              borderRadius: BorderRadius.circular(AppDimens.shapeXs),
            ),
            child: Text('Long press me',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: _colors!.textPrimary)),
          ),
        ),

        _label('Progress Bar', _colors!),
        ZProgressBar(
          value: _progressValue,
          label: 'Syncing Fitbit...',
          valueLabel: '${(_progressValue * 100).round()}%',
        ),
        _gap(),
        const ZProgressBar(value: 0.25, label: 'Steps goal'),
        _gap(),
        const ZProgressBar(value: 1.0, label: 'Complete!', valueLabel: '100%'),

        _label('Alert Banners', _colors!),
        const ZAlertBanner(
          variant: ZAlertVariant.info,
          message: 'Syncing your data with Fitbit...',
        ),
        _gap(),
        const ZAlertBanner(
          variant: ZAlertVariant.success,
          title: 'Connected',
          message: 'Apple Health is now syncing automatically.',
        ),
        _gap(),
        const ZAlertBanner(
          variant: ZAlertVariant.warning,
          message: 'Your subscription expires in 3 days.',
        ),
        _gap(),
        ZAlertBanner(
          variant: ZAlertVariant.error,
          title: 'Sync Failed',
          message: 'Could not connect to Fitbit. Please try again.',
          onDismiss: () {},
        ),

        _label('Skeleton Loader', _colors!),
        const ZLoadingSkeleton(width: double.infinity, height: 80),

        _label('Circular Progress', _colors!),
        Row(
          children: [
            const ZCircularProgress(),
            const SizedBox(width: AppDimens.spaceMd),
            const ZCircularProgress(size: 24, strokeWidth: 2),
            const SizedBox(width: AppDimens.spaceMd),
            const ZCircularProgress(value: 0.7, size: 40),
          ],
        ),

        _label('Pull-to-Refresh (wraps scrollable content)', _colors!),
        Text('ZPullToRefresh wraps a scrollable child with a Sage spinner',
            style: AppTextStyles.bodySmall.copyWith(color: _colors!.textSecondary)),
      ],
    );
  }

  // ── 6. DISPLAY ────────────────────────────────────────────────────────

  Widget _buildDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Avatar — all sizes', _colors!),
        Row(
          children: [
            const ZAvatar(initials: 'AJ', avatarSize: ZAvatarSize.lg),
            const SizedBox(width: AppDimens.spaceMd),
            const ZAvatar(initials: 'AJ', avatarSize: ZAvatarSize.md),
            const SizedBox(width: AppDimens.spaceMd),
            const ZAvatar(initials: 'AJ', avatarSize: ZAvatarSize.sm),
          ],
        ),

        _label('Divider', _colors!),
        const ZDivider(),
        _gap(),
        const ZDivider(inset: 16),

        _label('Accordion', _colors!),
        ZAccordion(
          items: [
            ZAccordionItem(
              title: 'Sleep Details',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deep Sleep: 2h 15m',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: _colors!.textPrimary)),
                  Text('REM: 1h 45m',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: _colors!.textPrimary)),
                  Text('Light: 3h 30m',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: _colors!.textPrimary)),
                ],
              ),
            ),
            ZAccordionItem(
              title: 'HRV Trends',
              content: Text(
                'Your HRV has been steadily improving over the past 2 weeks.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: _colors!.textPrimary),
              ),
            ),
          ],
        ),

        _label('Collapsible', _colors!),
        ZCollapsible(
          header: Text('Weekly Step Breakdown',
              style: AppTextStyles.titleMedium
                  .copyWith(color: _colors!.textPrimary)),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'])
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppDimens.spaceXs),
                  child: Text('$day: ${7000 + day.hashCode % 5000} steps',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: _colors!.textSecondary)),
                ),
            ],
          ),
        ),

        _label('Context Menu (long press)', _colors!),
        ZContextMenu(
          items: [
            ZContextMenuItem(
                label: 'Copy Data', icon: Icons.copy, onTap: () {}),
            ZContextMenuItem(
                label: 'Share Summary', icon: Icons.share, onTap: () {}),
            ZContextMenuItem(
              label: 'Delete Entry',
              icon: Icons.delete,
              onTap: () {},
              isDestructive: true,
            ),
          ],
          child: ZuralogCard(
            variant: ZCardVariant.data,
            child: Text('Long press this card for options',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: _colors!.textPrimary)),
          ),
        ),

        _label('List Item', _colors!),
        ZuralogCard(
          variant: ZCardVariant.plain,
          child: Column(
            children: [
              ZListItem(
                icon: Icons.directions_walk,
                title: 'Steps',
                subtitle: '8,432 today',
                onTap: () {},
              ),
              ZListItem(
                icon: Icons.bedtime,
                title: 'Sleep',
                subtitle: '7h 23m last night',
                onTap: () {},
              ),
              ZListItem(
                icon: Icons.favorite,
                title: 'Heart Rate',
                subtitle: '72 bpm avg',
                showDivider: false,
                onTap: () {},
              ),
            ],
          ),
        ),

        _label('Carousel', _colors!),
        // Note: Carousel extends beyond section padding
        ZCarousel(
          height: 140,
          children: [
            for (final item in ['Sleep Score', 'Activity Ring', 'Heart Rate', 'Nutrition'])
              ZuralogCard(
                variant: ZCardVariant.data,
                child: Center(
                  child: Text(item,
                      style: AppTextStyles.titleMedium.copyWith(color: _colors!.textPrimary)),
                ),
              ),
          ],
        ),

        _label('Chart Container', _colors!),
        ZChartContainer(
          title: 'Weekly Steps',
          subtitle: 'Last 7 days',
          child: Center(
            child: Text('Chart goes here',
                style: AppTextStyles.bodyMedium.copyWith(color: _colors!.textSecondary)),
          ),
        ),

        _label('Data Table', _colors!),
        ZDataTable(
          columns: const [
            ZDataColumn(label: 'Metric'),
            ZDataColumn(label: 'Value', alignment: Alignment.centerRight),
            ZDataColumn(label: 'Change', alignment: Alignment.centerRight),
          ],
          rows: [
            ZDataRow(cells: [
              Text('Steps', style: AppTextStyles.bodyMedium.copyWith(color: _colors!.textPrimary)),
              Text('8,432', style: AppTextStyles.bodyMedium.copyWith(color: _colors!.textPrimary)),
              Text('+12%', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.success)),
            ]),
            ZDataRow(cells: [
              Text('Sleep', style: AppTextStyles.bodyMedium.copyWith(color: _colors!.textPrimary)),
              Text('7h 23m', style: AppTextStyles.bodyMedium.copyWith(color: _colors!.textPrimary)),
              Text('-5%', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.statusError)),
            ]),
            ZDataRow(cells: [
              Text('Heart Rate', style: AppTextStyles.bodyMedium.copyWith(color: _colors!.textPrimary)),
              Text('72 bpm', style: AppTextStyles.bodyMedium.copyWith(color: _colors!.textPrimary)),
              Text('—', style: AppTextStyles.bodyMedium.copyWith(color: _colors!.textSecondary)),
            ]),
          ],
        ),

        _label('Empty State', _colors!),
        ZEmptyState(
          icon: Icons.bedtime_outlined,
          title: 'No sleep data yet',
          message:
              'Connect a sleep tracker or log your sleep manually to see insights here.',
          actionLabel: 'Log Sleep',
          onAction: () {},
        ),

        _label('Error State', _colors!),
        const ZErrorState(
          message: 'We couldn\'t load your data. Please try again.',
        ),
        _gap(),
        ZErrorState(
          message: 'Connection lost',
          onRetry: () {},
        ),
      ],
    );
  }

  // ── 7. SPECIAL SURFACES ───────────────────────────────────────────────

  Widget _buildSpecialSurfaces() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Onboarding Card', _colors!),
        ZOnboardingCard(
          title: 'Welcome to Zuralog',
          body:
              'Your AI health assistant that helps you understand your body better through data-driven insights.',
          ctaLabel: 'Get Started',
          icon: Icons.favorite,
          onCtaTap: () {},
        ),

        _label('Hero Banner', _colors!),
        ZHeroBanner(
          height: 180,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Your Health Journey',
                  style: AppTextStyles.displaySmall.copyWith(color: _colors!.textPrimary)),
              const SizedBox(height: AppDimens.spaceXs),
              Text('Track, understand, improve',
                  style: AppTextStyles.bodyMedium.copyWith(color: _colors!.textSecondary)),
            ],
          ),
        ),

        _label('Staggered Animation (tap to replay)', _colors!),
        ZStaggeredList(
          key: ValueKey(_staggerKey),
          children: [
            for (final label in ['Card 1 — First', 'Card 2 — Staggered', 'Card 3 — Cascade'])
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
                child: ZuralogCard(
                  variant: ZCardVariant.data,
                  child: Text(label,
                      style: AppTextStyles.bodyMedium.copyWith(color: _colors!.textPrimary)),
                ),
              ),
          ],
        ),
        _gap(),
        ZButton(
          label: 'Replay Animation',
          variant: ZButtonVariant.secondary,
          size: ZButtonSize.small,
          onPressed: () => setState(() => _staggerKey++),
        ),

        _label('Pattern Overlay Demo', _colors!),
        _gap(AppDimens.spaceSm),
        for (final opacity in [0.04, 0.07, 0.10, 0.15])
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.shapeLg),
              child: SizedBox(
                height: 64,
                child: Stack(
                  children: [
                    Container(color: _colors!.surface),
                    Positioned.fill(
                      child: ZPatternOverlay(
                        opacity: opacity,
                        blendMode: BlendMode.screen,
                      ),
                    ),
                    Center(
                      child: Text(
                        'Screen blend · ${(opacity * 100).round()}% opacity',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: _colors!.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        _label('Pattern Variants', _colors!),
        _gap(AppDimens.spaceSm),
        Wrap(
          spacing: AppDimens.spaceSm,
          runSpacing: AppDimens.spaceSm,
          children: [
            for (final v in [
              (ZPatternVariant.sage, 'Sage', _colors!.primary),
              (ZPatternVariant.crimson, 'Crimson', AppColors.error),
              (ZPatternVariant.periwinkle, 'Periwinkle', AppColors.categorySleep),
              (ZPatternVariant.rose, 'Rose', AppColors.categoryHeart),
              (ZPatternVariant.amber, 'Amber', AppColors.categoryNutrition),
            ])
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.shapeSm),
                child: SizedBox(
                  width: 100,
                  height: 60,
                  child: Stack(
                    children: [
                      Container(color: v.$3),
                      Positioned.fill(
                        child: ZPatternOverlay(
                          variant: v.$1,
                          opacity: 0.15,
                          blendMode: BlendMode.colorBurn,
                        ),
                      ),
                      Center(
                        child: Text(
                          v.$2,
                          style: AppTextStyles.labelSmall
                              .copyWith(color: _colors!.textOnSage),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        // ── 8. CHART VISUALIZATIONS ────────────────────────────────────────
        _gap(AppDimens.spaceLg),
        Text(
          '8. ZChart System',
          style: AppTextStyles.displaySmall.copyWith(color: _colors!.textPrimary),
        ),
        _gap(),
        Text(
          'All 7 chart types shown in all 3 tile sizes. '
          'Each has a "Full" variant with data and an "Empty" variant with no data.',
          style: AppTextStyles.bodySmall.copyWith(color: _colors!.textSecondary),
        ),

        // ── Line Chart ──────────────────────────────────────────────────
        _label('Line Chart — Full', _colors!),
        _ChartShowcaseRow(
          color: AppColors.categoryHeart,
          configs: [
            (TileSize.square, _kLineChartFull),
            (TileSize.wide, _kLineChartFull),
            (TileSize.tall, _kLineChartFull),
          ],
        ),
        _label('Line Chart — Empty', _colors!),
        _ChartShowcaseRow(
          color: AppColors.categoryHeart,
          configs: [
            (TileSize.square, _kLineChartEmpty),
            (TileSize.wide, _kLineChartEmpty),
            (TileSize.tall, _kLineChartEmpty),
          ],
        ),

        // ── Bar Chart ───────────────────────────────────────────────────
        _label('Bar Chart — Full', _colors!),
        _ChartShowcaseRow(
          color: AppColors.categoryActivity,
          configs: [
            (TileSize.square, _kBarChartFull),
            (TileSize.wide, _kBarChartFull),
            (TileSize.tall, _kBarChartFull),
          ],
        ),
        _label('Bar Chart — Empty', _colors!),
        _ChartShowcaseRow(
          color: AppColors.categoryActivity,
          configs: [
            (TileSize.square, _kBarChartEmpty),
            (TileSize.wide, _kBarChartEmpty),
            (TileSize.tall, _kBarChartEmpty),
          ],
        ),

        // ── Area Chart ──────────────────────────────────────────────────
        _label('Area Chart — Full', _colors!),
        _ChartShowcaseRow(
          color: AppColors.categorySleep,
          configs: [
            (TileSize.square, _kAreaChartFull),
            (TileSize.wide, _kAreaChartFull),
            (TileSize.tall, _kAreaChartFull),
          ],
        ),
        _label('Area Chart — Empty', _colors!),
        _ChartShowcaseRow(
          color: AppColors.categorySleep,
          configs: [
            (TileSize.square, _kAreaChartEmpty),
            (TileSize.wide, _kAreaChartEmpty),
            (TileSize.tall, _kAreaChartEmpty),
          ],
        ),

        // ── Ring / Donut ────────────────────────────────────────────────
        _label('Ring Chart — Full', _colors!),
        _ChartShowcaseRow(
          color: AppColors.categoryActivity,
          configs: [
            (TileSize.square, _kRingFull),
            (TileSize.wide, _kRingFull),
            (TileSize.tall, _kRingFullWithBars),
          ],
        ),
        _label('Ring Chart — Empty (0%)', _colors!),
        _ChartShowcaseRow(
          color: AppColors.categoryActivity,
          configs: [
            (TileSize.square, _kRingEmpty),
            (TileSize.wide, _kRingEmpty),
            (TileSize.tall, _kRingEmpty),
          ],
        ),

        // ── Gauge ───────────────────────────────────────────────────────
        _label('Gauge — Full', _colors!),
        _ChartShowcaseRow(
          color: AppColors.categoryHeart,
          configs: [
            (TileSize.square, _kGaugeFull),
            (TileSize.wide, _kGaugeFull),
            (TileSize.tall, _kGaugeFull),
          ],
        ),
        _label('Gauge — Empty (min value)', _colors!),
        _ChartShowcaseRow(
          color: AppColors.categoryHeart,
          configs: [
            (TileSize.square, _kGaugeEmpty),
            (TileSize.wide, _kGaugeEmpty),
            (TileSize.tall, _kGaugeEmpty),
          ],
        ),

        // ── Fill Gauge ──────────────────────────────────────────────────
        _label('Fill Gauge — Full', _colors!),
        _ChartShowcaseRow(
          color: AppColors.categoryBody,
          configs: [
            (TileSize.square, _kFillGaugeFull),
            (TileSize.wide, _kFillGaugeFullWide),
            (TileSize.tall, _kFillGaugeFullTall),
          ],
        ),
        _label('Fill Gauge — Empty (0)', _colors!),
        _ChartShowcaseRow(
          color: AppColors.categoryBody,
          configs: [
            (TileSize.square, _kFillGaugeEmpty),
            (TileSize.wide, _kFillGaugeEmpty),
            (TileSize.tall, _kFillGaugeEmpty),
          ],
        ),

        // ── Segmented Bar ───────────────────────────────────────────────
        _label('Segmented Bar — Full', _colors!),
        _ChartShowcaseRow(
          color: AppColors.categorySleep,
          configs: [
            (TileSize.square, _kSegBarFull),
            (TileSize.wide, _kSegBarFull),
            (TileSize.tall, _kSegBarFull),
          ],
        ),
        _label('Segmented Bar — Empty', _colors!),
        _ChartShowcaseRow(
          color: AppColors.categorySleep,
          configs: [
            (TileSize.square, _kSegBarEmpty),
            (TileSize.wide, _kSegBarEmpty),
            (TileSize.tall, _kSegBarEmpty),
          ],
        ),

        _gap(AppDimens.spaceXxl),

        // ── 9. CHART — NEW MODES ─────────────────────────────────────────
        _gap(AppDimens.spaceLg),
        Text(
          '9. Chart — New Modes',
          style: AppTextStyles.displaySmall.copyWith(color: _colors!.textPrimary),
        ),
        _gap(),
        Text(
          'Sparkline, mini progress, full-mode hero chart, and comparison overlay.',
          style: AppTextStyles.bodySmall.copyWith(color: _colors!.textSecondary),
        ),
        _buildChartNewModes(),
      ],
    );
  }

  // ── 8b. CHART — NEW MODES ───────────────────────────────────────────────

  Widget _buildChartNewModes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Sparkline ─────────────────────────────────────────────────────
        _label('Sparkline — inline trend shape (16px, no chrome)', _colors!),
        Row(
          children: [
            _sparklineCell('Line', _kSparkLine, AppColors.categoryHeart),
            const SizedBox(width: AppDimens.spaceXs),
            _sparklineCell('Area', _kSparkArea, AppColors.categorySleep),
            const SizedBox(width: AppDimens.spaceXs),
            _sparklineCell('Bar', _kSparkBar, AppColors.categoryActivity),
            const SizedBox(width: AppDimens.spaceXs),
            _sparklineCell('Seg Bar', _kSparkSeg, AppColors.categoryWellness),
          ],
        ),

        // ── Mini Progress ─────────────────────────────────────────────────
        _label('Mini Progress — ring (24 / 28 / 32px) + linear', _colors!),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ZMiniProgress(
              value: 6240,
              goal: 10000,
              color: AppColors.categoryActivity,
              variant: MiniProgressVariant.ring,
              size: 24,
            ),
            const SizedBox(width: AppDimens.spaceMd),
            ZMiniProgress(
              value: 6240,
              goal: 10000,
              color: AppColors.categoryActivity,
              variant: MiniProgressVariant.ring,
              size: 28,
            ),
            const SizedBox(width: AppDimens.spaceMd),
            ZMiniProgress(
              value: 6240,
              goal: 10000,
              color: AppColors.categoryActivity,
              variant: MiniProgressVariant.ring,
              size: 32,
            ),
            const SizedBox(width: AppDimens.spaceLg),
            Expanded(
              child: ZMiniProgress(
                value: 1.8,
                goal: 2.5,
                color: AppColors.categoryBody,
                variant: MiniProgressVariant.linear,
              ),
            ),
          ],
        ),

        // ── Full Mode — Line ──────────────────────────────────────────────
        _label('Full Mode — line chart with scrub crosshair', _colors!),
        Container(
          decoration: BoxDecoration(
            color: AppColorsOf(context).surface,
            borderRadius: BorderRadius.circular(AppDimens.shapeMd),
          ),
          padding: const EdgeInsets.all(AppDimens.spaceSm),
          child: ZChart(
            config: _kFullLineChart,
            mode: ChartMode.full,
            color: AppColors.categoryHeart,
            unit: 'bpm',
          ),
        ),

        // ── Full Mode — Bar ───────────────────────────────────────────────
        _label('Full Mode — bar chart with tap-to-tooltip', _colors!),
        Container(
          decoration: BoxDecoration(
            color: AppColorsOf(context).surface,
            borderRadius: BorderRadius.circular(AppDimens.shapeMd),
          ),
          padding: const EdgeInsets.all(AppDimens.spaceSm),
          child: ZChart(
            config: _kBarChartFull,
            mode: ChartMode.full,
            color: AppColors.categoryActivity,
            unit: 'steps',
          ),
        ),

        // ── Full Mode — Area ──────────────────────────────────────────────
        _label('Full Mode — area chart', _colors!),
        Container(
          decoration: BoxDecoration(
            color: AppColorsOf(context).surface,
            borderRadius: BorderRadius.circular(AppDimens.shapeMd),
          ),
          padding: const EdgeInsets.all(AppDimens.spaceSm),
          child: ZChart(
            config: _kAreaChartFull,
            mode: ChartMode.full,
            color: AppColors.categorySleep,
            unit: 'h',
          ),
        ),

        // ── Full Mode — Ring ──────────────────────────────────────────────
        _label('Full Mode — ring / donut', _colors!),
        Container(
          decoration: BoxDecoration(
            color: AppColorsOf(context).surface,
            borderRadius: BorderRadius.circular(AppDimens.shapeMd),
          ),
          padding: const EdgeInsets.all(AppDimens.spaceSm),
          child: ZChart(
            config: _kRingFull,
            mode: ChartMode.full,
            color: AppColors.categoryActivity,
            unit: 'steps',
          ),
        ),

        // ── Full Mode — Gauge ─────────────────────────────────────────────
        _label('Full Mode — gauge', _colors!),
        Container(
          decoration: BoxDecoration(
            color: AppColorsOf(context).surface,
            borderRadius: BorderRadius.circular(AppDimens.shapeMd),
          ),
          padding: const EdgeInsets.all(AppDimens.spaceSm),
          child: ZChart(
            config: _kGaugeFull,
            mode: ChartMode.full,
            color: AppColors.categoryHeart,
            unit: 'bpm',
          ),
        ),

        // ── Full Mode — Fill Gauge ────────────────────────────────────────
        _label('Full Mode — fill gauge (tank)', _colors!),
        Container(
          decoration: BoxDecoration(
            color: AppColorsOf(context).surface,
            borderRadius: BorderRadius.circular(AppDimens.shapeMd),
          ),
          padding: const EdgeInsets.all(AppDimens.spaceSm),
          child: ZChart(
            config: _kFillGaugeFull,
            mode: ChartMode.full,
            color: AppColors.categoryBody,
            unit: 'L',
          ),
        ),

        // ── Full Mode — Segmented Bar ─────────────────────────────────────
        _label('Full Mode — segmented bar (tap a segment)', _colors!),
        Container(
          decoration: BoxDecoration(
            color: AppColorsOf(context).surface,
            borderRadius: BorderRadius.circular(AppDimens.shapeMd),
          ),
          padding: const EdgeInsets.all(AppDimens.spaceSm),
          child: ZChart(
            config: _kSegBarFull,
            mode: ChartMode.full,
            color: AppColors.categorySleep,
          ),
        ),

        // ── Full Mode — Empty state ───────────────────────────────────────
        _label('Full Mode — empty state (no data)', _colors!),
        Container(
          decoration: BoxDecoration(
            color: AppColorsOf(context).surface,
            borderRadius: BorderRadius.circular(AppDimens.shapeMd),
          ),
          padding: const EdgeInsets.all(AppDimens.spaceSm),
          child: SizedBox(
            height: 200,
            child: ZChart(
              config: _kLineChartEmpty,
              mode: ChartMode.full,
              color: AppColors.categoryHeart,
            ),
          ),
        ),

        // ── Comparison Mode — Line ────────────────────────────────────────
        _label('Comparison Mode — two periods overlaid', _colors!),
        Container(
          decoration: BoxDecoration(
            color: AppColorsOf(context).surface,
            borderRadius: BorderRadius.circular(AppDimens.shapeMd),
          ),
          padding: const EdgeInsets.all(AppDimens.spaceSm),
          child: ZChart(
            config: _kComparisonPrimary,
            mode: ChartMode.comparison,
            color: AppColors.categoryHeart,
            unit: 'bpm',
            comparisonConfig: _kComparisonSecondary,
          ),
        ),

        // ── Mini — via ZChart ─────────────────────────────────────────────
        _label('Mini Mode — ZChart.mini on RingConfig and FillGaugeConfig', _colors!),
        Row(
          children: [
            ZChart(
              config: _kRingFull,
              mode: ChartMode.mini,
              color: AppColors.categoryActivity,
            ),
            const SizedBox(width: AppDimens.spaceLg),
            Expanded(
              child: ZChart(
                config: _kFillGaugeFull,
                mode: ChartMode.mini,
                color: AppColors.categoryBody,
              ),
            ),
          ],
        ),

        _gap(AppDimens.spaceLg),
      ],
    );
  }

  // ── 8. NAVIGATION & LAYOUT ──────────────────────────────────────────────

  Widget _buildNavigationLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top App Bar ───────────────────────────────────────────────────
        _label('Top App Bar — with subtitle', _colors!),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.shapeMd),
          child: SizedBox(
            height: kToolbarHeight + 20,
            child: Scaffold(
              backgroundColor: _colors!.canvas,
              appBar: const ZuralogAppBar(
                title: 'Today',
                subtitle: 'Mon, 29 Mar',
              ),
              body: const SizedBox.shrink(),
            ),
          ),
        ),
        _gap(AppDimens.spaceSm),
        _label('Top App Bar — title only', _colors!),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.shapeMd),
          child: SizedBox(
            height: kToolbarHeight,
            child: Scaffold(
              backgroundColor: _colors!.canvas,
              appBar: const ZuralogAppBar(title: 'Progress'),
              body: const SizedBox.shrink(),
            ),
          ),
        ),
        _gap(),

        // ── Bottom Navigation Bar ─────────────────────────────────────────
        _label('Bottom Nav Bar — frosted pill (interactive)', _colors!),
        Container(
          height: 100,
          decoration: BoxDecoration(
            color: _colors!.canvas,
            borderRadius: BorderRadius.circular(AppDimens.shapeMd),
            border: Border.all(color: _colors!.border),
          ),
          alignment: Alignment.center,
          child: _buildNavBarReplica(),
        ),
        _gap(),

        // ── Side Panel ────────────────────────────────────────────────────
        _label('Side Panel — navigation drawer', _colors!),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.shapeMd),
            child: SizedBox(
              width: 280,
              child: Material(
                // SYNC: mirrors ProfileSidePanelWidget surface
                color: Theme.of(context).colorScheme.surface,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimens.spaceMd,
                        AppDimens.spaceLg,
                        AppDimens.spaceMd,
                        AppDimens.spaceMd,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor:
                                _colors!.primary.withValues(alpha: 0.85),
                            child: Text(
                              'Z',
                              style: AppTextStyles.displaySmall.copyWith(
                                color: _colors!.textOnSage,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppDimens.spaceSm),
                          Text(
                            'Zura User',
                            style: AppTextStyles.titleMedium.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppDimens.spaceXs),
                          Text(
                            'user@zuralog.com',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                        height: 1, thickness: 1, color: _colors!.border),
                    const SizedBox(height: AppDimens.spaceSm),
                    for (final item in [
                      (Icons.person_outline_rounded, 'Account'),
                      (Icons.notifications_none_rounded, 'Notifications'),
                      (Icons.palette_outlined, 'Appearance'),
                      (Icons.psychology_outlined, 'Coach'),
                    ])
                      ListTile(
                        leading: Icon(
                          item.$1,
                          color:
                              Theme.of(context).colorScheme.onSurface,
                          size: AppDimens.iconMd,
                        ),
                        title: Text(
                          item.$2,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: _colors!.textTertiary,
                          size: AppDimens.iconSm,
                        ),
                        dense: true,
                        visualDensity: VisualDensity.compact,
                      ),
                    const SizedBox(height: AppDimens.spaceSm),
                  ],
                ),
              ),
            ),
          ),
        ),
        _gap(AppDimens.spaceLg),
      ],
    );
  }

  // ── COACH COMPONENTS ─────────────────────────────────────────────────────

  Widget _buildCoachComponents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── CoachBlob — all 3 states × 2 sizes ─────────────────────────
        _label('Blob — Idle / Thinking / Talking (80px)', _colors!),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: const [
            CoachBlob(state: BlobState.idle, size: 80),
            SizedBox(width: AppDimens.spaceLg),
            CoachBlob(state: BlobState.thinking, size: 80),
            SizedBox(width: AppDimens.spaceLg),
            CoachBlob(state: BlobState.talking, size: 80),
          ],
        ),
        _gap(),
        _label('Blob — Idle / Thinking / Talking (28px)', _colors!),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: const [
            CoachBlob(state: BlobState.idle, size: 28),
            SizedBox(width: AppDimens.spaceLg),
            CoachBlob(state: BlobState.thinking, size: 28),
            SizedBox(width: AppDimens.spaceLg),
            CoachBlob(state: BlobState.talking, size: 28),
          ],
        ),
        _gap(),

        // ── CoachSuggestionCard ─────────────────────────────────────────
        _label('Suggestion Card', _colors!),
        CoachSuggestionCard(
          icon: Icons.bedtime_rounded,
          title: 'How did I sleep last night?',
          subtitle:
              'Zura will check your recent sleep data and give you a plain summary.',
          onTap: () {},
        ),
        _gap(),

        // ── CoachArtifactCard — all 3 types + divider ───────────────────
        _label('Artifact Cards', _colors!),
        const CoachArtifactDivider(),
        const CoachArtifactCard(
          type: ArtifactType.memory,
          description: 'User prefers morning workouts before breakfast.',
        ),
        const CoachArtifactCard(
          type: ArtifactType.journal,
          description: 'Logged: Felt energised after 7h sleep.',
        ),
        const CoachArtifactCard(
          type: ArtifactType.dataCheck,
          description:
              'Read: Steps (8 432), Heart rate (62 bpm), Sleep (7h 12m).',
        ),
        _gap(),

        // ── CoachUserMessage ────────────────────────────────────────────
        _label('User Message Bubble', _colors!),
        CoachUserMessage(
          content: 'How did I sleep last night?',
          onEdit: () {},
        ),
        _gap(),

        // ── CoachThinkingLayer — collapsed ──────────────────────────────
        _label('Thinking Layer (collapsed)', _colors!),
        const CoachThinkingLayer(steps: []),
        _gap(),

        // ── CoachGhostBanner ────────────────────────────────────────────
        _label('Ghost Banner', _colors!),
        CoachGhostBanner(onExit: () {}),
        _gap(),
      ],
    );
  }

  // SYNC: mirrors _FrostedNavigationBar in app_shell.dart
  Widget _buildNavBarReplica() {
    final colors = _colors!;
    final activePillBg =
        colors.primary.withValues(alpha: colors.isDark ? 0.12 : 1.0);
    final activeItemColor =
        colors.isDark ? colors.primary : colors.textOnSage;

    const tabs = [
      (Icons.wb_sunny_outlined, Icons.wb_sunny_rounded, 'Today'),
      (Icons.grid_view_outlined, Icons.grid_view_rounded, 'Data'),
      (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Coach'),
      (Icons.track_changes_outlined, Icons.track_changes_rounded, 'Progress'),
      (Icons.trending_up_rounded, Icons.trending_up_rounded, 'Trends'),
    ];

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.shapePill),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppDimens.navBarBlurSigma,
            sigmaY: AppDimens.navBarBlurSigma,
          ),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: AppDimens.navBarFrostOpacity),
              borderRadius: BorderRadius.circular(AppDimens.shapePill),
            ),
            child: Row(
              children: List.generate(tabs.length, (index) {
                final isActive = index == _navBarActiveIndex;
                final tab = tabs[index];
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        setState(() => _navBarActiveIndex = index),
                    child: SizedBox(
                      height: 64,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? activePillBg
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              AppDimens.shapePill,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isActive ? tab.$2 : tab.$1,
                                size: 22,
                                color: isActive
                                    ? activeItemColor
                                    : colors.textSecondary,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tab.$3,
                                style:
                                    AppTextStyles.labelMedium.copyWith(
                                  color: isActive
                                      ? activeItemColor
                                      : colors.textSecondary,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sparklineCell(
    String label,
    TileVisualizationConfig config,
    Color color,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColorsOf(context).textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: AppColorsOf(context).surface,
              borderRadius: BorderRadius.circular(AppDimens.shapeXs),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: ZChart(
              config: config,
              mode: ChartMode.sparkline,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Chart Showcase Helpers
// ══════════════════════════════════════════════════════════════════════════════

/// Renders a row of 3 tile sizes for a given chart config.
class _ChartShowcaseRow extends StatelessWidget {
  const _ChartShowcaseRow({
    required this.color,
    required this.configs,
  });

  final Color color;
  final List<(TileSize, TileVisualizationConfig)> configs;

  static const _sizeLabels = {
    TileSize.square: '1×1  Square',
    TileSize.wide: '2×1  Wide',
    TileSize.tall: '1×2  Tall',
  };

  // Width/height for each tile size when rendered on its own row.
  static (double, double) _dims(TileSize size) => switch (size) {
        TileSize.square => (140, 140),
        TileSize.wide   => (double.infinity, 110),
        TileSize.tall   => (160, 220),
      };

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < configs.length; i++) ...[
          if (i > 0) const SizedBox(height: AppDimens.spaceSm),
          Text(
            _sizeLabels[configs[i].$1] ?? '',
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          () {
            final (w, h) = _dims(configs[i].$1);
            return Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppDimens.shapeMd),
              ),
              padding: const EdgeInsets.all(AppDimens.spaceSm),
              child: buildTileVisualization(
                config: configs[i].$2,
                categoryColor: color,
                size: configs[i].$1,
              ),
            );
          }(),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Mock Chart Data — Full (with data)
// ══════════════════════════════════════════════════════════════════════════════

// Helper dates for mock data (DateTime isn't const-constructible with arithmetic).
final _kD7 = DateTime(2026, 3, 22);
final _kD6 = DateTime(2026, 3, 23);
final _kD5 = DateTime(2026, 3, 24);
final _kD4 = DateTime(2026, 3, 25);
final _kD3 = DateTime(2026, 3, 26);
final _kD2 = DateTime(2026, 3, 27);
final _kD1 = DateTime(2026, 3, 28);

final _kLineChartFull = LineChartConfig(
  points: [
    ChartPoint(date: _kD7, value: 68),
    ChartPoint(date: _kD6, value: 72),
    ChartPoint(date: _kD5, value: 65),
    ChartPoint(date: _kD4, value: 78),
    ChartPoint(date: _kD3, value: 74),
    ChartPoint(date: _kD2, value: 71),
    ChartPoint(date: _kD1, value: 76),
  ],
  referenceLine: 72,
  rangeMin: 60,
  rangeMax: 85,
);

const _kBarChartFull = BarChartConfig(
  bars: [
    BarPoint(label: 'M', value: 8432, isToday: false),
    BarPoint(label: 'T', value: 6218, isToday: false),
    BarPoint(label: 'W', value: 9105, isToday: false),
    BarPoint(label: 'T', value: 7340, isToday: false),
    BarPoint(label: 'F', value: 10230, isToday: false),
    BarPoint(label: 'S', value: 5621, isToday: false),
    BarPoint(label: 'S', value: 8910, isToday: true),
  ],
  goalValue: 10000,
  showAvgLine: true,
);

final _kAreaChartFull = AreaChartConfig(
  points: [
    ChartPoint(date: _kD7, value: 7.2),
    ChartPoint(date: _kD6, value: 6.8),
    ChartPoint(date: _kD5, value: 8.1),
    ChartPoint(date: _kD4, value: 7.5),
    ChartPoint(date: _kD3, value: 6.9),
    ChartPoint(date: _kD2, value: 7.8),
    ChartPoint(date: _kD1, value: 7.4),
  ],
  targetLine: 8.0,
  fillOpacity: 0.15,
  delta: 0.03,
  positiveIsUp: true,
);

const _kRingFull = RingConfig(
  value: 6240,
  maxValue: 8000,
  unit: 'steps',
);

const _kRingFullWithBars = RingConfig(
  value: 6240,
  maxValue: 8000,
  unit: 'steps',
  weeklyBars: [
    BarPoint(label: 'M', value: 7200, isToday: false),
    BarPoint(label: 'T', value: 5800, isToday: false),
    BarPoint(label: 'W', value: 8400, isToday: false),
    BarPoint(label: 'T', value: 6100, isToday: false),
    BarPoint(label: 'F', value: 9200, isToday: false),
    BarPoint(label: 'S', value: 4300, isToday: false),
    BarPoint(label: 'S', value: 6240, isToday: true),
  ],
);

const _kGaugeFull = GaugeConfig(
  value: 72,
  minValue: 40,
  maxValue: 120,
  zones: [
    GaugeZone(min: 40, max: 60, label: 'Low', color: Color(0xFF5E5CE6)),
    GaugeZone(min: 60, max: 80, label: 'Normal', color: Color(0xFF30D158)),
    GaugeZone(min: 80, max: 100, label: 'Elevated', color: Color(0xFFFF9F0A)),
    GaugeZone(min: 100, max: 120, label: 'High', color: Color(0xFFFF375F)),
  ],
);

const _kFillGaugeFull = FillGaugeConfig(
  value: 1.8,
  maxValue: 2.5,
  unit: 'L',
);

const _kFillGaugeFullWide = FillGaugeConfig(
  value: 1.8,
  maxValue: 2.5,
  unit: 'L',
  unitIcon: '💧',
  unitSize: 0.3,
);

const _kFillGaugeFullTall = FillGaugeConfig(
  value: 1.8,
  maxValue: 2.5,
  unit: 'L',
  unitIcon: '💧',
  unitSize: 0.3,
);

const _kSegBarFull = SegmentedBarConfig(
  totalLabel: '7h 22m',
  segments: [
    Segment(label: 'Deep', value: 95, color: Color(0xFF3634A3)),
    Segment(label: 'Core', value: 210, color: Color(0xFF5E5CE6)),
    Segment(label: 'REM', value: 82, color: Color(0xFF8E8CE8)),
    Segment(label: 'Awake', value: 55, color: Color(0xFFBFBEF0)),
  ],
);

// ══════════════════════════════════════════════════════════════════════════════
// Mock Chart Data — Empty (no data)
// ══════════════════════════════════════════════════════════════════════════════

const _kLineChartEmpty = LineChartConfig(points: []);

const _kBarChartEmpty = BarChartConfig(bars: []);

const _kAreaChartEmpty = AreaChartConfig(points: []);

const _kRingEmpty = RingConfig(value: 0, maxValue: 8000, unit: 'steps');

const _kGaugeEmpty = GaugeConfig(
  value: 40,
  minValue: 40,
  maxValue: 120,
  zones: [
    GaugeZone(min: 40, max: 60, label: 'Low', color: Color(0xFF5E5CE6)),
    GaugeZone(min: 60, max: 80, label: 'Normal', color: Color(0xFF30D158)),
    GaugeZone(min: 80, max: 100, label: 'Elevated', color: Color(0xFFFF9F0A)),
    GaugeZone(min: 100, max: 120, label: 'High', color: Color(0xFFFF375F)),
  ],
);

const _kFillGaugeEmpty = FillGaugeConfig(value: 0, maxValue: 2.5, unit: 'L');

const _kSegBarEmpty = SegmentedBarConfig(totalLabel: '—', segments: []);

// ══════════════════════════════════════════════════════════════════════════════
// Mock Chart Data — Extended Modes (sparkline, full, comparison)
// ══════════════════════════════════════════════════════════════════════════════

// 30-day heart rate data for full-mode and sparkline demos.
final _kFullLineChart = LineChartConfig(
  points: [
    ChartPoint(date: DateTime(2026, 2, 27), value: 68),
    ChartPoint(date: DateTime(2026, 2, 28), value: 71),
    ChartPoint(date: DateTime(2026, 3, 1), value: 74),
    ChartPoint(date: DateTime(2026, 3, 2), value: 70),
    ChartPoint(date: DateTime(2026, 3, 3), value: 72),
    ChartPoint(date: DateTime(2026, 3, 4), value: 69),
    ChartPoint(date: DateTime(2026, 3, 5), value: 73),
    ChartPoint(date: DateTime(2026, 3, 6), value: 76),
    ChartPoint(date: DateTime(2026, 3, 7), value: 74),
    ChartPoint(date: DateTime(2026, 3, 8), value: 71),
    ChartPoint(date: DateTime(2026, 3, 9), value: 68),
    ChartPoint(date: DateTime(2026, 3, 10), value: 72),
    ChartPoint(date: DateTime(2026, 3, 11), value: 75),
    ChartPoint(date: DateTime(2026, 3, 12), value: 73),
    ChartPoint(date: DateTime(2026, 3, 13), value: 70),
    ChartPoint(date: DateTime(2026, 3, 14), value: 67),
    ChartPoint(date: DateTime(2026, 3, 15), value: 71),
    ChartPoint(date: DateTime(2026, 3, 16), value: 74),
    ChartPoint(date: DateTime(2026, 3, 17), value: 76),
    ChartPoint(date: DateTime(2026, 3, 18), value: 72),
    ChartPoint(date: DateTime(2026, 3, 19), value: 69),
    ChartPoint(date: DateTime(2026, 3, 20), value: 73),
    ChartPoint(date: DateTime(2026, 3, 21), value: 75),
    ChartPoint(date: DateTime(2026, 3, 22), value: 71),
    ChartPoint(date: DateTime(2026, 3, 23), value: 68),
    ChartPoint(date: DateTime(2026, 3, 24), value: 74),
    ChartPoint(date: DateTime(2026, 3, 25), value: 77),
    ChartPoint(date: DateTime(2026, 3, 26), value: 73),
    ChartPoint(date: DateTime(2026, 3, 27), value: 71),
    ChartPoint(date: DateTime(2026, 3, 28), value: 76),
  ],
  referenceLine: 72,
);

// Comparison primary: this week's heart rate.
final _kComparisonPrimary = LineChartConfig(
  points: [
    ChartPoint(date: DateTime(2026, 3, 22), value: 68),
    ChartPoint(date: DateTime(2026, 3, 23), value: 72),
    ChartPoint(date: DateTime(2026, 3, 24), value: 65),
    ChartPoint(date: DateTime(2026, 3, 25), value: 78),
    ChartPoint(date: DateTime(2026, 3, 26), value: 74),
    ChartPoint(date: DateTime(2026, 3, 27), value: 71),
    ChartPoint(date: DateTime(2026, 3, 28), value: 76),
  ],
);

// Comparison secondary: previous week's heart rate.
final _kComparisonSecondary = LineChartConfig(
  points: [
    ChartPoint(date: DateTime(2026, 3, 15), value: 74),
    ChartPoint(date: DateTime(2026, 3, 16), value: 69),
    ChartPoint(date: DateTime(2026, 3, 17), value: 73),
    ChartPoint(date: DateTime(2026, 3, 18), value: 77),
    ChartPoint(date: DateTime(2026, 3, 19), value: 70),
    ChartPoint(date: DateTime(2026, 3, 20), value: 68),
    ChartPoint(date: DateTime(2026, 3, 21), value: 72),
  ],
);

// Sparkline configs — 7 data points, no labels, just shape.
final _kSparkLine = LineChartConfig(
  points: [
    ChartPoint(date: DateTime(2026, 3, 22), value: 68),
    ChartPoint(date: DateTime(2026, 3, 23), value: 72),
    ChartPoint(date: DateTime(2026, 3, 24), value: 65),
    ChartPoint(date: DateTime(2026, 3, 25), value: 78),
    ChartPoint(date: DateTime(2026, 3, 26), value: 74),
    ChartPoint(date: DateTime(2026, 3, 27), value: 71),
    ChartPoint(date: DateTime(2026, 3, 28), value: 76),
  ],
);

final _kSparkArea = AreaChartConfig(
  points: [
    ChartPoint(date: DateTime(2026, 3, 22), value: 7.2),
    ChartPoint(date: DateTime(2026, 3, 23), value: 6.8),
    ChartPoint(date: DateTime(2026, 3, 24), value: 8.1),
    ChartPoint(date: DateTime(2026, 3, 25), value: 7.5),
    ChartPoint(date: DateTime(2026, 3, 26), value: 6.9),
    ChartPoint(date: DateTime(2026, 3, 27), value: 7.8),
    ChartPoint(date: DateTime(2026, 3, 28), value: 7.4),
  ],
  fillOpacity: 0.15,
);

const _kSparkBar = BarChartConfig(
  bars: [
    BarPoint(label: 'M', value: 8432, isToday: false),
    BarPoint(label: 'T', value: 6218, isToday: false),
    BarPoint(label: 'W', value: 9105, isToday: false),
    BarPoint(label: 'T', value: 7340, isToday: false),
    BarPoint(label: 'F', value: 10230, isToday: false),
    BarPoint(label: 'S', value: 5621, isToday: false),
    BarPoint(label: 'S', value: 8910, isToday: true),
  ],
);

const _kSparkSeg = SegmentedBarConfig(
  totalLabel: '7h 22m',
  segments: [
    Segment(label: 'Deep', value: 95, color: Color(0xFF3634A3)),
    Segment(label: 'Core', value: 210, color: Color(0xFF5E5CE6)),
    Segment(label: 'REM', value: 82, color: Color(0xFF8E8CE8)),
    Segment(label: 'Awake', value: 55, color: Color(0xFFBFBEF0)),
  ],
);
