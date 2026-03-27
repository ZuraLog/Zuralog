/// Zuralog Design System — Component Showcase Screen.
///
/// A scrollable screen that displays every design system "lego" component
/// in all its variants and states. Accessible via /debug/components.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

class ComponentShowcaseScreen extends ConsumerStatefulWidget {
  const ComponentShowcaseScreen({super.key});

  @override
  ConsumerState<ComponentShowcaseScreen> createState() =>
      _ComponentShowcaseScreenState();
}

class _ComponentShowcaseScreenState
    extends ConsumerState<ComponentShowcaseScreen> {
  // ── State for interactive demos ──────────────────────────────────────────
  bool _toggleValue = true;
  bool _toggleOff = false;
  bool _checkboxValue = true;
  bool _checkboxOff = false;
  double _sliderValue = 0.6;
  String? _radioValue = 'daily';
  int _segmentIndex = 0;
  final Set<String> _activeChips = {'Sleep', 'Heart'};
  String? _selectValue;
  int _stepperValue = 5;
  final double _progressValue = 0.67;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
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
                          color: AppColors.warmWhite,
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
                          .copyWith(color: AppColors.warmWhite),
                    ),
                    const SizedBox(height: AppDimens.spaceXs),
                    Text(
                      'Every design system lego in one place',
                      style: AppTextStyles.bodyLarge
                          .copyWith(color: AppColors.textSecondaryDark),
                    ),
                  ],
                ),
              ),
            ),

            // ── Sections ──────────────────────────────────────────────────
            _sliverSection('Foundations'),
            _sliverChild(_buildFoundations()),

            _sliverSection('Buttons'),
            _sliverChild(_buildButtons()),

            _sliverSection('Cards'),
            _sliverChild(_buildCards()),

            _sliverSection('Inputs & Selection'),
            _sliverChild(_buildInputs()),

            _sliverSection('Feedback'),
            _sliverChild(_buildFeedback()),

            _sliverSection('Display'),
            _sliverChild(_buildDisplay()),

            _sliverSection('Special Surfaces'),
            _sliverChild(_buildSpecialSurfaces()),

            // ── Footer ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spaceXxl),
                child: Center(
                  child: Text(
                    'Zuralog Design System · 2026',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondaryDark),
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

  Widget _sliverSection(String title) {
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
              AppTextStyles.displaySmall.copyWith(color: AppColors.primary),
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

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppDimens.spaceMd,
        bottom: AppDimens.spaceSm,
      ),
      child: Text(
        text,
        style: AppTextStyles.labelMedium
            .copyWith(color: AppColors.textSecondaryDark),
      ),
    );
  }

  Widget _gap([double h = AppDimens.spaceSm]) => SizedBox(height: h);

  // ── 1. FOUNDATIONS ──────────────────────────────────────────────────────

  Widget _buildFoundations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Canvas & Elevation'),
        Row(
          children: [
            _colorSwatch('Canvas', AppColors.canvas),
            _colorSwatch('Surface', AppColors.surface),
            _colorSwatch('Raised', AppColors.surfaceRaised),
            _colorSwatch('Overlay', AppColors.surfaceOverlay),
          ],
        ),

        _label('Accent Colors'),
        Row(
          children: [
            _colorSwatch('Sage', AppColors.primary),
            _colorSwatch('Warm White', AppColors.warmWhite),
          ],
        ),

        _label('Health Categories'),
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

        _label('Status Colors'),
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

        _label('Typography'),
        Text('Display Large (34pt Bold)',
            style: AppTextStyles.displayLarge
                .copyWith(color: AppColors.warmWhite)),
        Text('Display Medium (28pt SemiBold)',
            style: AppTextStyles.displayMedium
                .copyWith(color: AppColors.warmWhite)),
        Text('Display Small (24pt SemiBold)',
            style: AppTextStyles.displaySmall
                .copyWith(color: AppColors.warmWhite)),
        Text('Title Large (20pt Medium)',
            style: AppTextStyles.titleLarge
                .copyWith(color: AppColors.warmWhite)),
        Text('Title Medium (17pt Medium)',
            style: AppTextStyles.titleMedium
                .copyWith(color: AppColors.warmWhite)),
        Text('Body Large (16pt Regular)',
            style: AppTextStyles.bodyLarge
                .copyWith(color: AppColors.warmWhite)),
        Text('Body Medium (14pt Regular)',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.warmWhite)),
        Text('Body Small (12pt Regular)',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.warmWhite)),
        Text('Label Large (15pt SemiBold)',
            style: AppTextStyles.labelLarge
                .copyWith(color: AppColors.warmWhite)),
        Text('Label Medium (13pt Medium)',
            style: AppTextStyles.labelMedium
                .copyWith(color: AppColors.warmWhite)),
        Text('Label Small (11pt Medium)',
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.warmWhite)),

        _label('Spacing'),
        _spacingBar('XXS (2px)', AppDimens.spaceXxs),
        _spacingBar('XS (4px)', AppDimens.spaceXs),
        _spacingBar('SM (8px)', AppDimens.spaceSm),
        _spacingBar('MD (16px)', AppDimens.spaceMd),
        _spacingBar('MD+ (20px)', AppDimens.spaceMdPlus),
        _spacingBar('LG (24px)', AppDimens.spaceLg),
        _spacingBar('XL (32px)', AppDimens.spaceXl),
        _spacingBar('XXL (48px)', AppDimens.spaceXxl),

        _label('Shape (Border Radius)'),
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
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppDimens.shapeXs),
            ),
          ),
          const SizedBox(height: 4),
          Text(name,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textSecondaryDark)),
        ],
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
                .copyWith(color: AppColors.textSecondaryDark, fontSize: 9)),
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
                .copyWith(color: AppColors.textSecondaryDark)),
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
                    .copyWith(color: AppColors.textSecondaryDark)),
          ),
          Container(
            width: width * 3, // visual scale
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.4),
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
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(radius.clamp(0, 24)),
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textSecondaryDark)),
      ],
    );
  }

  // ── 2. BUTTONS ────────────────────────────────────────────────────────

  Widget _buildButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Primary — all sizes'),
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

        _label('Destructive'),
        ZButton(
            label: 'Delete Account',
            variant: ZButtonVariant.destructive,
            onPressed: () {}),

        _label('Secondary'),
        ZButton(
            label: 'View Details',
            variant: ZButtonVariant.secondary,
            onPressed: () {}),

        _label('Text'),
        ZButton(
            label: 'See all →',
            variant: ZButtonVariant.text,
            onPressed: () {},
            isFullWidth: false),

        _label('With icons'),
        ZButton(label: 'Log Activity', icon: Icons.add, onPressed: () {}),
        _gap(),
        ZButton(
            label: 'Settings',
            variant: ZButtonVariant.secondary,
            icon: Icons.settings,
            onPressed: () {}),

        _label('States'),
        ZButton(label: 'Disabled', onPressed: null),
        _gap(),
        const ZButton(label: 'Loading...', isLoading: true),

        _label('Icon Button'),
        Row(
          children: [
            ZIconButton(icon: Icons.favorite, onPressed: () {}),
            const SizedBox(width: AppDimens.spaceSm),
            ZIconButton(
                icon: Icons.share, onPressed: () {}, isSage: true),
            const SizedBox(width: AppDimens.spaceSm),
            ZIconButton(
                icon: Icons.more_vert, onPressed: () {}, filled: false),
          ],
        ),

        _label('FAB'),
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
        _label('Hero Card (pattern 10%)'),
        ZuralogCard(
          variant: ZCardVariant.hero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Health Score',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.textSecondaryDark)),
              Text('87',
                  style: AppTextStyles.displayLarge
                      .copyWith(color: AppColors.primary)),
            ],
          ),
        ),

        _label('Feature Card (pattern 7%)'),
        ZuralogCard(
          variant: ZCardVariant.feature,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI Insight',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.primary)),
              const SizedBox(height: AppDimens.spaceXs),
              Text(
                'Your sleep quality improved 12% this week. Keep up the consistent bedtime routine!',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.warmWhite),
              ),
            ],
          ),
        ),

        _label('Category Feature Cards'),
        ZuralogCard(
          variant: ZCardVariant.feature,
          category: AppColors.categorySleep,
          child: Text('Sleep Insight',
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.warmWhite)),
        ),
        _gap(),
        ZuralogCard(
          variant: ZCardVariant.feature,
          category: AppColors.categoryHeart,
          child: Text('Heart Rate Insight',
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.warmWhite)),
        ),

        _label('Data Card (no pattern)'),
        ZuralogCard(
          variant: ZCardVariant.data,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Steps Today',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondaryDark)),
              Text('8,432',
                  style: AppTextStyles.titleLarge
                      .copyWith(color: AppColors.warmWhite)),
            ],
          ),
        ),

        _label('Topographic Card'),
        ZTopographicCard(
          child: Text('Legacy topographic card',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.warmWhite)),
        ),
      ],
    );
  }

  // ── 4. INPUTS & SELECTION ─────────────────────────────────────────────

  Widget _buildInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Toggle'),
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

        _label('Checkbox'),
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

        _label('Slider'),
        ZSlider(
          value: _sliderValue,
          onChanged: (v) => setState(() => _sliderValue = v),
          label: 'Volume: ${(_sliderValue * 100).round()}%',
        ),

        _label('Radio Group'),
        ZRadioGroup<String>(
          value: _radioValue,
          onChanged: (v) => setState(() => _radioValue = v),
          options: const [
            ZRadioOption(value: 'daily', label: 'Daily'),
            ZRadioOption(value: 'weekly', label: 'Weekly'),
            ZRadioOption(value: 'monthly', label: 'Monthly'),
          ],
        ),

        _label('Segmented Control'),
        ZSegmentedControl(
          selectedIndex: _segmentIndex,
          onChanged: (i) => setState(() => _segmentIndex = i),
          segments: const ['Day', 'Week', 'Month', 'Year'],
        ),

        _label('Chips'),
        Wrap(
          spacing: AppDimens.spaceSm,
          children: [
            for (final chip in ['Sleep', 'Heart', 'Activity', 'Nutrition', 'Body'])
              ZChip(
                label: chip,
                isActive: _activeChips.contains(chip),
                onTap: () => setState(() {
                  if (_activeChips.contains(chip)) {
                    _activeChips.remove(chip);
                  } else {
                    _activeChips.add(chip);
                  }
                }),
              ),
          ],
        ),

        _label('Select / Dropdown'),
        ZSelect(
          value: _selectValue,
          onChanged: (v) => setState(() => _selectValue = v),
          options: const ['Daily', 'Weekly', 'Monthly', 'Yearly'],
          placeholder: 'Choose frequency',
          label: 'Report Frequency',
        ),

        _label('Text Area'),
        const ZTextArea(
          placeholder: 'How are you feeling today?',
          label: 'Health Note',
        ),

        _label('Search Bar'),
        ZSearchBar(
          onChanged: (v) {},
          placeholder: 'Search metrics...',
        ),

        _label('Number Stepper'),
        ZNumberStepper(
          value: _stepperValue,
          onChanged: (v) => setState(() => _stepperValue = v),
          min: 0,
          max: 20,
        ),

        _label('Text Field (existing)'),
        const AppTextField(
          labelText: 'Email',
          hintText: 'you@example.com',
        ),
      ],
    );
  }

  // ── 5. FEEDBACK ───────────────────────────────────────────────────────

  Widget _buildFeedback() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Toast (tap to trigger)'),
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

        _label('Alert Dialog (tap to trigger)'),
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

        _label('Bottom Sheet (tap to trigger)'),
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
                          .copyWith(color: AppColors.textSecondaryDark)),
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

        _label('Badge'),
        Row(
          children: [
            const ZBadge(label: '3', variant: ZBadgeVariant.error),
            const SizedBox(width: AppDimens.spaceMd),
            const ZBadge(label: 'New', variant: ZBadgeVariant.sage),
            const SizedBox(width: AppDimens.spaceMd),
            const ZBadge(label: '12', variant: ZBadgeVariant.neutral),
          ],
        ),

        _label('Tooltip (long press the text)'),
        ZTooltip(
          message: 'Your health score is calculated from 10 categories',
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppDimens.shapeXs),
            ),
            child: Text('Long press me',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.warmWhite)),
          ),
        ),

        _label('Progress Bar'),
        ZProgressBar(
          value: _progressValue,
          label: 'Syncing Fitbit...',
          valueLabel: '${(_progressValue * 100).round()}%',
        ),
        _gap(),
        const ZProgressBar(value: 0.25, label: 'Steps goal'),
        _gap(),
        const ZProgressBar(value: 1.0, label: 'Complete!', valueLabel: '100%'),

        _label('Alert Banners'),
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

        _label('Skeleton Loader'),
        const ZLoadingSkeleton(width: double.infinity, height: 80),
      ],
    );
  }

  // ── 6. DISPLAY ────────────────────────────────────────────────────────

  Widget _buildDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Avatar — all sizes'),
        Row(
          children: [
            const ZAvatar(initials: 'AJ', avatarSize: ZAvatarSize.lg),
            const SizedBox(width: AppDimens.spaceMd),
            const ZAvatar(initials: 'AJ', avatarSize: ZAvatarSize.md),
            const SizedBox(width: AppDimens.spaceMd),
            const ZAvatar(initials: 'AJ', avatarSize: ZAvatarSize.sm),
          ],
        ),

        _label('Divider'),
        const ZDivider(),
        _gap(),
        const ZDivider(inset: 16),

        _label('Accordion'),
        ZAccordion(
          items: [
            ZAccordionItem(
              title: 'Sleep Details',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deep Sleep: 2h 15m',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.warmWhite)),
                  Text('REM: 1h 45m',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.warmWhite)),
                  Text('Light: 3h 30m',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.warmWhite)),
                ],
              ),
            ),
            ZAccordionItem(
              title: 'HRV Trends',
              content: Text(
                'Your HRV has been steadily improving over the past 2 weeks.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.warmWhite),
              ),
            ),
          ],
        ),

        _label('Collapsible'),
        ZCollapsible(
          header: Text('Weekly Step Breakdown',
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.warmWhite)),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'])
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppDimens.spaceXs),
                  child: Text('$day: ${7000 + day.hashCode % 5000} steps',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondaryDark)),
                ),
            ],
          ),
        ),

        _label('Context Menu (long press)'),
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
                    .copyWith(color: AppColors.warmWhite)),
          ),
        ),

        _label('Empty State'),
        ZEmptyState(
          icon: Icons.bedtime_outlined,
          title: 'No sleep data yet',
          message:
              'Connect a sleep tracker or log your sleep manually to see insights here.',
          actionLabel: 'Log Sleep',
          onAction: () {},
        ),

        _label('Error State'),
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
        _label('Onboarding Card'),
        ZOnboardingCard(
          title: 'Welcome to Zuralog',
          body:
              'Your AI health assistant that helps you understand your body better through data-driven insights.',
          ctaLabel: 'Get Started',
          icon: Icons.favorite,
          onCtaTap: () {},
        ),

        _label('Pattern Overlay Demo'),
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
                    Container(color: AppColors.surface),
                    ZPatternOverlay(
                      opacity: opacity,
                      blendMode: BlendMode.screen,
                    ),
                    Center(
                      child: Text(
                        'Screen blend · ${(opacity * 100).round()}% opacity',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: AppColors.warmWhite),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        _label('Pattern Variants'),
        _gap(AppDimens.spaceSm),
        Wrap(
          spacing: AppDimens.spaceSm,
          runSpacing: AppDimens.spaceSm,
          children: [
            for (final v in [
              (ZPatternVariant.sage, 'Sage', AppColors.primary),
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
                      ZPatternOverlay(
                        variant: v.$1,
                        opacity: 0.15,
                        blendMode: BlendMode.colorBurn,
                      ),
                      Center(
                        child: Text(
                          v.$2,
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textOnSage),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        _gap(AppDimens.spaceXxl),
      ],
    );
  }
}
