/// ZuraLog — Log Meal Bottom Sheet.
///
/// The primary entry point for logging a meal. Supports two modes:
///
/// - **Quick mode**: Describe food in natural language, search the database,
///   or pick from recently logged foods. One tap to save.
/// - **Guided mode**: Same input paths, but AI-parsed items get extra
///   refinement controls on the Meal Review screen.
///
/// AI paths (describe, camera, barcode) close this sheet and open
/// [MealReviewScreen]. Non-AI paths (search, manual, recents) stay inline
/// with the food list and save button.
///
/// Opened via [LogMealSheet.show].
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:zuralog/core/storage/prefs_service.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/presentation/meal_review_screen.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';
import 'package:zuralog/shared/widgets/feedback/z_alert_banner.dart';
import 'package:zuralog/shared/widgets/feedback/z_toast.dart';
import 'package:zuralog/shared/widgets/inputs/z_chip.dart';
import 'package:zuralog/shared/widgets/inputs/z_labeled_number_field.dart';
import 'package:zuralog/shared/widgets/inputs/z_labeled_text_field.dart';
import 'package:zuralog/shared/widgets/inputs/z_search_bar.dart';
import 'package:zuralog/shared/widgets/inputs/z_segmented_control.dart';
import 'package:zuralog/shared/widgets/inputs/z_text_area.dart';
import 'package:zuralog/shared/widgets/layout/section_header.dart';
import 'package:zuralog/shared/widgets/nutrition/z_meal_type_picker.dart';
import 'package:zuralog/shared/widgets/z_divider.dart';

/// SharedPreferences key for persisting the Quick/Guided mode choice.
const _kModePrefsKey = 'nutrition_logging_mode';

/// Bottom sheet for logging a meal via natural-language description, food
/// search, or recent food shortcuts.
class LogMealSheet extends ConsumerStatefulWidget {
  const LogMealSheet({super.key});

  /// Opens the sheet as a modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => const LogMealSheet(),
    );
  }

  @override
  ConsumerState<LogMealSheet> createState() => _LogMealSheetState();
}

class _LogMealSheetState extends ConsumerState<LogMealSheet> {
  // ── State ──────────────────────────────────────────────────────────────────

  /// 0 = Quick, 1 = Guided.
  int _modeIndex = 0;

  /// Whether the save-as-template inline form is visible.
  bool _showSaveTemplate = false;

  /// Whether the save-template action is currently running.
  bool _isSavingTemplate = false;

  /// Controller for the template name text field.
  final _templateNameController = TextEditingController();

  /// Selected meal type — auto-suggested on init based on the current hour.
  MealType? _selectedMealType;

  /// Controller for the "describe what you ate" text area.
  final _describeController = TextEditingController();

  /// Controller for the food search bar.
  final _searchController = TextEditingController();

  /// Debounce timer for search queries.
  Timer? _searchDebounce;

  /// Foods the user has assembled for saving (non-AI paths: search, manual, recents).
  final List<MealFood> _mealFoods = [];

  /// Whether the save operation is currently running.
  bool _isSaving = false;

  /// Whether the user is in manual entry mode (instead of AI description).
  bool _isManualMode = false;

  /// Whether the barcode scanner overlay is visible.
  bool _showBarcodeScanner = false;

  /// Error message from the most recent barcode lookup, if any.
  String? _barcodeError;

  // ── Manual entry controllers ──────────────────────────────────────────────

  final _manualName = TextEditingController();
  final _manualCalories = TextEditingController();
  final _manualProtein = TextEditingController();
  final _manualCarbs = TextEditingController();
  final _manualFat = TextEditingController();

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _selectedMealType = _autoSuggestMealType();
    _loadModePreference();
  }

  @override
  void dispose() {
    _describeController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    _manualName.dispose();
    _manualCalories.dispose();
    _manualProtein.dispose();
    _manualCarbs.dispose();
    _manualFat.dispose();
    _templateNameController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool get _canSave => _mealFoods.isNotEmpty;

  /// Returns a meal type based on the current hour of the day.
  MealType _autoSuggestMealType() {
    final hour = DateTime.now().hour;
    if (hour < 10) return MealType.breakfast;
    if (hour < 14) return MealType.lunch;
    if (hour < 17) return MealType.snack;
    return MealType.dinner;
  }

  /// Joins the first 3 food names with " + ".
  String _generateMealName() {
    final names = _mealFoods.take(3).map((f) => f.name);
    return names.join(' + ');
  }

  /// Loads the persisted Quick/Guided mode preference.
  void _loadModePreference() {
    final prefs = ref.read(prefsProvider);
    final savedMode = prefs.getInt(_kModePrefsKey) ?? 0;
    if (mounted) setState(() => _modeIndex = savedMode);
  }

  /// Saves the Quick/Guided mode preference and updates state.
  void _onModeChanged(int index) {
    setState(() => _modeIndex = index);
    ref.read(prefsProvider).setInt(_kModePrefsKey, index);
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Adds a food item from the manual entry form fields.
  void _addManualFood() {
    final name = _manualName.text.trim();
    final cal = double.tryParse(_manualCalories.text) ?? 0;
    final protein = double.tryParse(_manualProtein.text) ?? 0;
    final carbs = double.tryParse(_manualCarbs.text) ?? 0;
    final fat = double.tryParse(_manualFat.text) ?? 0;

    if (name.isEmpty) return; // Name is required.

    setState(() {
      _mealFoods.add(MealFood(
        name: name,
        portionGrams: 1,
        portionUnit: 'serving',
        caloriesKcal: cal.round(),
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
      ));
      // Clear the fields for the next food.
      _manualName.clear();
      _manualCalories.clear();
      _manualProtein.clear();
      _manualCarbs.clear();
      _manualFat.clear();
    });
  }

  /// Closes this sheet and opens the Meal Review Screen for AI text parsing.
  Future<void> _handleParse() async {
    final description = _describeController.text.trim();
    if (description.isEmpty) return;

    // Close this sheet first.
    Navigator.of(context).pop();

    // Open the Meal Review Screen.
    MealReviewScreen.show(
      context,
      MealReviewArgs(
        inputType: MealReviewInputType.describe,
        descriptionText: description,
        initialMealType: _selectedMealType ?? _autoSuggestMealType(),
        isGuidedMode: _modeIndex == 1,
      ),
    );
  }

  /// Picks a photo from the camera or gallery and opens the Meal Review Screen.
  Future<void> _pickAndScanImage(ImageSource source) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: source, imageQuality: 85);
    if (xFile == null) return;

    final file = File(xFile.path);

    // Close this sheet first.
    if (mounted) Navigator.of(context).pop();

    // Open the Meal Review Screen.
    if (mounted) {
      MealReviewScreen.show(
        context,
        MealReviewArgs(
          inputType: MealReviewInputType.camera,
          imageFile: file,
          initialMealType: _selectedMealType ?? _autoSuggestMealType(),
          isGuidedMode: _modeIndex == 1,
        ),
      );
    }
  }

  /// Handles a barcode detection event from the scanner overlay.
  /// Closes the scanner, looks the product up, and opens the Meal Review
  /// Screen on success.
  Future<void> _handleBarcodeScan(BarcodeCapture capture) async {
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    // Close the scanner immediately so it does not fire again.
    setState(() => _showBarcodeScanner = false);

    try {
      final result =
          await ref.read(nutritionRepositoryProvider).lookupBarcode(code);
      if (!mounted) return;

      if (result != null) {
        // Close this sheet.
        Navigator.of(context).pop();
        // Open Meal Review with the barcode result.
        MealReviewScreen.show(
          context,
          MealReviewArgs(
            inputType: MealReviewInputType.barcode,
            barcodeResult: result,
            initialMealType: _selectedMealType ?? _autoSuggestMealType(),
            isGuidedMode: _modeIndex == 1,
          ),
        );
      } else {
        setState(() {
          _barcodeError =
              'Product not found. Try taking a photo instead.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _barcodeError = 'Could not look up the barcode. Please try again.';
      });
    }
  }

  /// Updates the food search query with a 300ms debounce.
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(foodSearchQueryProvider.notifier).state = query.trim();
    });
  }

  /// Adds a [FoodSearchResult] to the meal foods list.
  void _addSearchResult(FoodSearchResult result) {
    setState(() => _mealFoods.add(result.toMealFood()));
  }

  /// Adds a [RecentFood] to the meal foods list.
  void _addRecentFood(RecentFood recent) {
    setState(() => _mealFoods.add(recent.toMealFood()));
  }

  /// Removes a food at the given index.
  void _removeFood(int index) {
    setState(() => _mealFoods.removeAt(index));
  }

  /// Saves the meal and closes the sheet.
  Future<void> _handleSave() async {
    if (!_canSave) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(nutritionRepositoryProvider);

      await repo.createMeal(
        mealType: (_selectedMealType ?? _autoSuggestMealType()).name,
        name: _generateMealName(),
        loggedAt: DateTime.now(),
        foods: _mealFoods,
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      // Invalidate providers after the sheet is dismissed so the home screen
      // refreshes with the new meal.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.invalidate(todayMealsProvider);
        ref.invalidate(nutritionDaySummaryProvider);
        ref.invalidate(recentFoodsProvider);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ZToast.error(context, 'Failed to save meal. Please try again.');
    }
  }

  /// Fills [_mealFoods] with the foods from [template] and selects its meal type.
  void _applyTemplate(MealTemplate template) {
    setState(() {
      _mealFoods
        ..clear()
        ..addAll(template.foods);
      final parsed = MealType.values.cast<MealType?>().firstWhere(
        (t) => t?.name == template.mealType,
        orElse: () => null,
      );
      if (parsed != null) _selectedMealType = parsed;
    });
  }

  /// Saves the current [_mealFoods] as a new template under the name the user
  /// typed, then dismisses the inline form.
  Future<void> _handleSaveTemplate() async {
    final name = _templateNameController.text.trim();
    if (name.isEmpty || _mealFoods.isEmpty) return;

    setState(() => _isSavingTemplate = true);

    try {
      await ref.read(nutritionRepositoryProvider).saveTemplate(
            name: name,
            mealType: (_selectedMealType ?? _autoSuggestMealType()).name,
            foods: List.unmodifiable(_mealFoods),
          );
      if (!mounted) return;
      ref.invalidate(mealTemplatesProvider);
      setState(() {
        _showSaveTemplate = false;
        _isSavingTemplate = false;
        _templateNameController.clear();
      });
      ZToast.success(context, 'Template "$name" saved!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingTemplate = false);
      ZToast.error(context, 'Could not save template. Please try again.');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    // Sheet renders above the nav bar via useRootNavigator: true.
    // Only keyboard inset needs accounting.
    final bottomPad = keyboardInset;

    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimens.shapeXl),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────────────────────
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: AppDimens.spaceSm),
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Log a meal',
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Quick / Guided toggle ────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: ZSegmentedControl(
              selectedIndex: _modeIndex,
              onChanged: _onModeChanged,
              segments: const ['Quick', 'Guided'],
            ),
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // ── Scrollable body ──────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Camera / Scan food section ─────────────────────────
                  const SectionHeader(title: 'Scan food'),
                  const SizedBox(height: AppDimens.spaceSm),
                  Row(
                    children: [
                      _ScanOption(
                        icon: Icons.camera_alt_outlined,
                        label: 'Camera',
                        onTap: () =>
                            _pickAndScanImage(ImageSource.camera),
                      ),
                      const SizedBox(width: AppDimens.spaceSm),
                      _ScanOption(
                        icon: Icons.photo_library_outlined,
                        label: 'Photos',
                        onTap: () =>
                            _pickAndScanImage(ImageSource.gallery),
                      ),
                      const SizedBox(width: AppDimens.spaceSm),
                      _ScanOption(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'Barcode',
                        onTap: () =>
                            setState(() => _showBarcodeScanner = true),
                      ),
                    ],
                  ),

                  // Barcode error banner.
                  if (_barcodeError != null) ...[
                    const SizedBox(height: AppDimens.spaceSm),
                    ZAlertBanner(
                      variant: ZAlertVariant.error,
                      message: _barcodeError!,
                      onDismiss: () =>
                          setState(() => _barcodeError = null),
                    ),
                  ],

                  // Barcode scanner overlay.
                  if (_showBarcodeScanner) ...[
                    const SizedBox(height: AppDimens.spaceSm),
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AppDimens.shapeMd),
                        border: Border.all(color: colors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          MobileScanner(
                              onDetect: _handleBarcodeScan),
                          Positioned(
                            top: AppDimens.spaceSm,
                            right: AppDimens.spaceSm,
                            child: GestureDetector(
                              onTap: () => setState(
                                  () => _showBarcodeScanner = false),
                              child: Container(
                                padding: const EdgeInsets.all(
                                    AppDimens.spaceXs),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(
                                      AppDimens.shapeXs),
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppDimens.spaceLg),

                  // ── Search section ──────────────────────────────────────
                  ZSearchBar(
                    controller: _searchController,
                    placeholder: 'Search for a food...',
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  _buildSearchResults(),

                  const SizedBox(height: AppDimens.spaceLg),

                  // ── OR divider ──────────────────────────────────────────
                  _buildOrDivider(),

                  const SizedBox(height: AppDimens.spaceLg),

                  // ── Describe / Manual entry section ─────────────────────
                  if (_isManualMode) ...[
                    const SectionHeader(title: 'Enter nutrition manually'),
                    const SizedBox(height: AppDimens.spaceSm),
                    ZLabeledTextField(
                      label: 'Food name',
                      controller: _manualName,
                      hint: 'e.g. Chicken breast',
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    ZLabeledNumberField(
                      label: 'Calories',
                      unit: 'kcal',
                      allowDecimal: false,
                      controller: _manualCalories,
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    Row(
                      children: [
                        Expanded(
                          child: ZLabeledNumberField(
                            label: 'Protein',
                            unit: 'g',
                            allowDecimal: true,
                            controller: _manualProtein,
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceSm),
                        Expanded(
                          child: ZLabeledNumberField(
                            label: 'Carbs',
                            unit: 'g',
                            allowDecimal: true,
                            controller: _manualCarbs,
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceSm),
                        Expanded(
                          child: ZLabeledNumberField(
                            label: 'Fat',
                            unit: 'g',
                            allowDecimal: true,
                            controller: _manualFat,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    ZButton(
                      label: 'Add food',
                      variant: ZButtonVariant.secondary,
                      size: ZButtonSize.medium,
                      onPressed: _addManualFood,
                    ),
                  ] else ...[
                    const SectionHeader(title: 'Describe what you ate'),
                    const SizedBox(height: AppDimens.spaceSm),
                    ZTextArea(
                      controller: _describeController,
                      placeholder:
                          'e.g. grilled chicken with rice and a side salad',
                      minLines: 3,
                      maxLines: 4,
                    ),

                    const SizedBox(height: AppDimens.spaceSm),

                    ZButton(
                      label: 'Parse with AI',
                      icon: Icons.auto_awesome_outlined,
                      variant: ZButtonVariant.secondary,
                      size: ZButtonSize.medium,
                      onPressed: _handleParse,
                    ),
                  ],

                  // ── Manual / AI mode toggle ────────────────────────────
                  const SizedBox(height: AppDimens.spaceSm),
                  ZButton(
                    label: _isManualMode
                        ? 'Switch to AI description'
                        : 'Enter nutrition manually',
                    variant: ZButtonVariant.secondary,
                    icon: _isManualMode
                        ? Icons.auto_awesome_outlined
                        : Icons.edit_outlined,
                    onPressed: () =>
                        setState(() => _isManualMode = !_isManualMode),
                  ),

                  const SizedBox(height: AppDimens.spaceLg),

                  // ── Templates section ───────────────────────────────────
                  _buildTemplatesSection(),

                  // ── Recents section ─────────────────────────────────────
                  _buildRecentsSection(),

                  const SizedBox(height: AppDimens.spaceLg),

                  // ── Selected foods list ─────────────────────────────────
                  if (_mealFoods.isNotEmpty) ...[
                    _buildYourMealHeader(),
                    const SizedBox(height: AppDimens.spaceSm),
                    _buildSelectedFoodsList(),
                    // Save-as-template inline form.
                    if (_showSaveTemplate) ...[
                      const SizedBox(height: AppDimens.spaceSm),
                      _buildSaveTemplateForm(),
                    ],
                    const SizedBox(height: AppDimens.spaceLg),
                  ],
                ],
              ),
            ),
          ),

          // ── Meal type picker (just above Save) ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceSm,
              AppDimens.spaceMd,
              0,
            ),
            child: ZMealTypePicker(
              value: _selectedMealType,
              onChanged: (v) => setState(() => _selectedMealType = v),
              label: 'Meal type',
            ),
          ),

          // ── Save button ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceSm,
              AppDimens.spaceMd,
              AppDimens.spaceMd,
            ),
            child: ZButton(
              label: 'Save meal',
              onPressed: _canSave ? _handleSave : null,
              isLoading: _isSaving,
            ),
          ),
        ],
      ),
    );
  }

  // ── Sub-builders ───────────────────────────────────────────────────────────

  /// "or" divider between describe and search.
  Widget _buildOrDivider() {
    final colors = AppColorsOf(context);
    return Row(
      children: [
        const Expanded(child: ZDivider()),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Text(
            'or',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        const Expanded(child: ZDivider()),
      ],
    );
  }

  /// Search results list (watches the provider).
  Widget _buildSearchResults() {
    final searchAsync = ref.watch(foodSearchResultsProvider);
    final query = ref.watch(foodSearchQueryProvider);
    final colors = AppColorsOf(context);

    // Nothing typed yet — hide the results area entirely.
    if (query.trim().length < 2) return const SizedBox.shrink();

    return searchAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
        ),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
        child: Text(
          'Search failed. Try again.',
          style: AppTextStyles.bodySmall.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ),
      data: (results) {
        if (results.isEmpty) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
            child: Text(
              'No foods found',
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: results.map((result) {
            return _SearchResultRow(
              result: result,
              onTap: () => _addSearchResult(result),
            );
          }).toList(),
        );
      },
    );
  }

  /// Horizontal row of saved meal template chips shown above the recents.
  ///
  /// Hidden when the user has no saved templates. Tapping a chip pre-fills
  /// [_mealFoods] with that template's foods so the user can log quickly.
  Widget _buildTemplatesSection() {
    final templatesAsync = ref.watch(mealTemplatesProvider);

    return templatesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (templates) {
        if (templates.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SectionHeader(title: 'Templates'),
            const SizedBox(height: AppDimens.spaceSm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: templates.map((template) {
                  return Padding(
                    padding:
                        const EdgeInsets.only(right: AppDimens.spaceSm),
                    child: ZChip(
                      label: template.name,
                      icon: Icons.bookmark_outline,
                      onTap: () => _applyTemplate(template),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppDimens.spaceLg),
          ],
        );
      },
    );
  }

  /// Row with "Your meal" header and a bookmark icon button to save the
  /// current food list as a template.
  Widget _buildYourMealHeader() {
    final colors = AppColorsOf(context);
    return Row(
      children: [
        const Expanded(child: SectionHeader(title: 'Your meal')),
        if (!_showSaveTemplate)
          GestureDetector(
            onTap: () => setState(() => _showSaveTemplate = true),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.spaceXs),
              child: Icon(
                Icons.bookmark_add_outlined,
                size: 20,
                color: colors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  /// Inline form for naming and saving the current food list as a template.
  Widget _buildSaveTemplateForm() {
    final colors = AppColorsOf(context);
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceSm + 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.shapeSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Save as template',
            style: AppTextStyles.labelMedium.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          ZLabeledTextField(
            label: 'Template name',
            controller: _templateNameController,
            hint: 'e.g. My Lunch',
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Row(
            children: [
              Expanded(
                child: ZButton(
                  label: 'Save template',
                  variant: ZButtonVariant.secondary,
                  size: ZButtonSize.medium,
                  isLoading: _isSavingTemplate,
                  onPressed: _handleSaveTemplate,
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              GestureDetector(
                onTap: () => setState(() {
                  _showSaveTemplate = false;
                  _templateNameController.clear();
                }),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.spaceXs),
                  child: Icon(
                    Icons.close,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Horizontal row of recent food chips.
  Widget _buildRecentsSection() {
    final recentsAsync = ref.watch(recentFoodsProvider);

    return recentsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (recents) {
        if (recents.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SectionHeader(title: 'Recent'),
            const SizedBox(height: AppDimens.spaceSm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: recents.map((food) {
                  return Padding(
                    padding:
                        const EdgeInsets.only(right: AppDimens.spaceSm),
                    child: ZChip(
                      label: food.foodName,
                      onTap: () => _addRecentFood(food),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  /// List of foods currently assembled for saving.
  Widget _buildSelectedFoodsList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _mealFoods.length; i++) ...[
          _buildFoodRow(i),
          if (i < _mealFoods.length - 1)
            const SizedBox(height: AppDimens.spaceSm),
        ],
      ],
    );
  }

  /// A single food row with name, macros, and delete button.
  Widget _buildFoodRow(int index) {
    final food = _mealFoods[index];
    final colors = AppColorsOf(context);

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceSm + 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.shapeSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Name + delete ──────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  food.name,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _removeFood(index),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.spaceXs),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.spaceXs),

          // ── Portion + macros ───────────────────────────────────────────
          Text(
            '${food.portionGrams}${food.portionUnit}'
            '  ·  ${food.caloriesKcal} kcal'
            '  ·  P ${food.proteinG.toStringAsFixed(1)}g'
            '  C ${food.carbsG.toStringAsFixed(1)}g'
            '  F ${food.fatG.toStringAsFixed(1)}g',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Private sub-widgets ──────────────────────────────────────────────────────

/// A single scan-option tile (camera, photos, barcode).
class _ScanOption extends StatelessWidget {
  const _ScanOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
          decoration: BoxDecoration(
            color: AppColors.categoryNutrition.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppDimens.shapeSm),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: AppColors.categoryNutrition,
                  size: AppDimens.iconMd),
              const SizedBox(height: AppDimens.spaceXs),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single search result row with name, serving, and calories.
class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.result,
    required this.onTap,
  });

  final FoodSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
        child: Row(
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 20,
              color: AppColors.categoryNutrition,
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    result.name,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    '${result.servingSize.round()}${result.servingUnit}'
                    '${result.brand != null ? '  ·  ${result.brand}' : ''}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${result.caloriesPerServing.round()} kcal',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.categoryNutrition,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
