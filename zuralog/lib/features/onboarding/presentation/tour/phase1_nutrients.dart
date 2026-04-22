library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import './tour_widgets.dart';

// ── NutrientsScreen1 ─────────────────────────────────────────────────────────

class NutrientsScreen1 extends StatefulWidget {
  const NutrientsScreen1({
    super.key,
    required this.progress,
    required this.onNext,
  });

  final double progress;
  final VoidCallback onNext;

  @override
  State<NutrientsScreen1> createState() => _NutrientsScreen1State();
}

class _NutrientsScreen1State extends State<NutrientsScreen1>
    with SingleTickerProviderStateMixin {
  late AnimationController _barCtrl;

  static const _macros = [
    _MacroData(name: 'Protein', current: 128, target: 150, color: AppColors.categoryNutrition),
    _MacroData(name: 'Carbs',   current: 194, target: 220, color: Color(0xFFFFC857)),
    _MacroData(name: 'Fats',    current: 62,  target: 70,  color: Color(0xFFFF7A59)),
    _MacroData(name: 'Fiber',   current: 24,  target: 30,  color: Color(0xFF9FD356)),
  ];

  @override
  void initState() {
    super.initState();
    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _barCtrl.forward();
  }

  @override
  void dispose() {
    _barCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TourScreen(
      topo: true,
      topoColor: AppColors.categoryNutrition,
      topoSeed: 'nut-1',
      topoOpacity: 0.12,
      child: Stack(
        children: [
          TourProgressBar(
            progress: widget.progress,
            color: AppColors.categoryNutrition,
          ),
          TourAppHeader(title: 'Nutrients'),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 120),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      'TODAY. 1,847 KCAL',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                        color: AppColors.categoryNutrition,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 220),
                    child: const Text(
                      'You are fueling well.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 32,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -1.1,
                        height: 1.08,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 400),
                    child: TourStatCard(
                      color: AppColors.categoryNutrition,
                      child: AnimatedBuilder(
                        animation: _barCtrl,
                        builder: (ctx, child) {
                          final prog = CurvedAnimation(
                            parent: _barCtrl,
                            curve: const Cubic(0.22, 1, 0.36, 1),
                          ).value;
                          return Column(
                            children: _macros.asMap().entries.map((entry) {
                              final i = entry.key;
                              final macro = entry.value;
                              final fill = (macro.current / macro.target).clamp(0.0, 1.0) * prog;
                              return Padding(
                                padding: EdgeInsets.only(bottom: i < _macros.length - 1 ? 18 : 0),
                                child: _MacroRow(macro: macro, fill: fill),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ),
                  const Spacer(),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 900),
                    child: TourPrimaryButton(
                      label: 'Continue',
                      onTap: widget.onNext,
                      color: AppColors.categoryNutrition,
                      textColor: AppColors.canvas,
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroData {
  const _MacroData({
    required this.name,
    required this.current,
    required this.target,
    required this.color,
  });

  final String name;
  final int current;
  final int target;
  final Color color;
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.macro, required this.fill});

  final _MacroData macro;
  final double fill;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              macro.name,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const Spacer(),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${macro.current}',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(
                    text: ' / ${macro.target}g',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 6,
            color: Colors.white.withValues(alpha: 0.07),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fill,
              child: Container(
                decoration: BoxDecoration(
                  color: macro.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── NutrientsScreen2 ─────────────────────────────────────────────────────────

class NutrientsScreen2 extends StatefulWidget {
  const NutrientsScreen2({
    super.key,
    required this.progress,
    required this.onNext,
  });

  final double progress;
  final VoidCallback onNext;

  @override
  State<NutrientsScreen2> createState() => _NutrientsScreen2State();
}

class _NutrientsScreen2State extends State<NutrientsScreen2>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textCtrl = TextEditingController();
  String _text = '';
  bool _parsing = false;
  List<Map<String, dynamic>> _parsed = [];
  bool _autoTyped = false;
  late AnimationController _dotCtrl;
  Timer? _typeTimer;
  Timer? _parseTimer;

  static const _sampleText = '2 eggs, toast with avocado, black coffee';

  static const _foodMap = <String, Map<String, dynamic>>{
    'egg':     {'name': '2 eggs, scrambled',       'kcal': 156, 'p': 12, 'c': 2,  'f': 11},
    'toast':   {'name': 'Sourdough toast',          'kcal': 110, 'p': 4,  'c': 20, 'f': 1},
    'avocado': {'name': 'Half avocado',             'kcal': 120, 'p': 1,  'c': 6,  'f': 11},
    'coffee':  {'name': 'Black coffee',             'kcal': 2,   'p': 0,  'c': 0,  'f': 0},
    'chicken': {'name': 'Grilled chicken 150g',     'kcal': 248, 'p': 46, 'c': 0,  'f': 5},
    'quinoa':  {'name': 'Quinoa 1 cup',             'kcal': 222, 'p': 8,  'c': 39, 'f': 4},
    'banana':  {'name': 'Medium banana',            'kcal': 105, 'p': 1,  'c': 27, 'f': 0},
  };

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _startAutoType();
  }

  void _startAutoType() {
    if (_autoTyped) return;
    int i = 0;
    _typeTimer = Timer.periodic(const Duration(milliseconds: 45), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (i < _sampleText.length) {
        setState(() {
          _text = _sampleText.substring(0, i + 1);
          _textCtrl.text = _text;
          _textCtrl.selection = TextSelection.collapsed(offset: _text.length);
        });
        i++;
      } else {
        t.cancel();
        _autoTyped = true;
        _parseTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted) _triggerParse(_text);
        });
      }
    });
  }

  List<Map<String, dynamic>> _parseFoods(String input) {
    final lower = input.toLowerCase();
    return _foodMap.entries
        .where((e) => lower.contains(e.key))
        .map((e) => Map<String, dynamic>.from(e.value))
        .toList();
  }

  void _triggerParse(String input) {
    if (input.trim().isEmpty) return;
    setState(() {
      _parsing = true;
      _parsed = [];
    });
    _parseTimer = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      setState(() {
        _parsing = false;
        _parsed = _parseFoods(input);
      });
    });
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _parseTimer?.cancel();
    _dotCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  int get _totalKcal => _parsed.fold(0, (s, e) => s + (e['kcal'] as int));
  int get _totalP    => _parsed.fold(0, (s, e) => s + (e['p'] as int));
  int get _totalC    => _parsed.fold(0, (s, e) => s + (e['c'] as int));
  int get _totalF    => _parsed.fold(0, (s, e) => s + (e['f'] as int));

  @override
  Widget build(BuildContext context) {
    return TourScreen(
      topo: true,
      topoColor: AppColors.categoryNutrition,
      topoSeed: 'nut-2',
      topoOpacity: 0.08,
      child: Stack(
        children: [
          TourProgressBar(
            progress: widget.progress,
            color: AppColors.categoryNutrition,
          ),
          TourAppHeader(title: 'Log a meal'),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 116),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 80),
                    child: Text(
                      'AI PARSE. TRY IT',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                        color: AppColors.categoryNutrition,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 200),
                    child: const Text(
                      'Just tell me what you ate.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.8,
                        height: 1.1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 320),
                    child: Container(
                      margin: EdgeInsets.zero,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.categoryNutrition.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _textCtrl,
                            maxLines: 2,
                            minLines: 2,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 15,
                              color: Colors.white,
                              height: 1.4,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Describe what you ate...',
                              hintStyle: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 15,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (v) => setState(() => _text = v),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _QuickTryChip(
                                label: 'grilled chicken salad',
                                onTap: () {
                                  setState(() {
                                    _text = 'grilled chicken salad';
                                    _textCtrl.text = _text;
                                    _textCtrl.selection = TextSelection.collapsed(offset: _text.length);
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              _QuickTryChip(
                                label: 'protein shake and banana',
                                onTap: () {
                                  setState(() {
                                    _text = 'protein shake and banana';
                                    _textCtrl.text = _text;
                                    _textCtrl.selection = TextSelection.collapsed(offset: _text.length);
                                  });
                                },
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _text.trim().isEmpty ? null : () => _triggerParse(_text),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _text.trim().isEmpty
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : AppColors.categoryNutrition,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Parse',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _text.trim().isEmpty
                                          ? Colors.white.withValues(alpha: 0.3)
                                          : AppColors.canvas,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _ResultsArea(
                        parsing: _parsing,
                        parsed: _parsed,
                        dotCtrl: _dotCtrl,
                        totalKcal: _totalKcal,
                        totalP: _totalP,
                        totalC: _totalC,
                        totalF: _totalF,
                      ),
                    ),
                  ),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 600),
                    child: TourPrimaryButton(
                      label: _parsed.isNotEmpty ? 'Log meal. Continue' : 'Continue',
                      onTap: widget.onNext,
                      color: AppColors.categoryNutrition,
                      textColor: AppColors.canvas,
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTryChip extends StatelessWidget {
  const _QuickTryChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class _ResultsArea extends StatelessWidget {
  const _ResultsArea({
    required this.parsing,
    required this.parsed,
    required this.dotCtrl,
    required this.totalKcal,
    required this.totalP,
    required this.totalC,
    required this.totalF,
  });

  final bool parsing;
  final List<Map<String, dynamic>> parsed;
  final AnimationController dotCtrl;
  final int totalKcal;
  final int totalP;
  final int totalC;
  final int totalF;

  @override
  Widget build(BuildContext context) {
    if (parsing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: dotCtrl,
              builder: (ctx, child) {
                return Row(
                  children: List.generate(3, (i) {
                    final phase = (dotCtrl.value - i * 0.25).clamp(0.0, 1.0);
                    final opacity = (0.3 + 0.7 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2)).clamp(0.0, 1.0);
                    return Container(
                      margin: const EdgeInsets.only(right: 4),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.categoryNutrition.withValues(alpha: opacity),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(width: 10),
            Text(
              'parsing your meal...',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }
    if (parsed.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...parsed.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return RevealAnimation(
            delay: Duration(milliseconds: i * 80),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item['name'] as String,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    '${item['kcal']} kcal',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      color: AppColors.categoryNutrition,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
        RevealAnimation(
          delay: Duration(milliseconds: parsed.length * 80 + 100),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.categoryNutrition.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.categoryNutrition.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalKcal kcal',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.8,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'P ${totalP}g.  C ${totalC}g.  F ${totalF}g',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ── NutrientsScreen3 ─────────────────────────────────────────────────────────

class NutrientsScreen3 extends StatefulWidget {
  const NutrientsScreen3({
    super.key,
    required this.progress,
    required this.onNext,
  });

  final double progress;
  final VoidCallback onNext;

  @override
  State<NutrientsScreen3> createState() => _NutrientsScreen3State();
}

class _NutrientsScreen3State extends State<NutrientsScreen3>
    with SingleTickerProviderStateMixin {
  int _stage = 0;
  late AnimationController _scanCtrl;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _stage = 1);
    });
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) {
        setState(() => _stage = 2);
        _scanCtrl.stop();
      }
    });
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TourScreen(
      topo: true,
      topoColor: AppColors.categoryNutrition,
      topoSeed: 'nut-3',
      topoOpacity: 0.06,
      child: Stack(
        children: [
          TourProgressBar(
            progress: widget.progress,
            color: AppColors.categoryNutrition,
          ),
          TourAppHeader(title: 'Scan a barcode'),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 116),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 80),
                    child: Text(
                      'SNAP ANYTHING',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                        color: AppColors.categoryNutrition,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 200),
                    child: const Text(
                      'Packaged food? Just scan it.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.7,
                        height: 1.1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 350),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        height: 290,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0A0A),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.categoryNutrition.withValues(alpha: 0.25),
                            width: 0.5,
                          ),
                        ),
                        child: Stack(
                          children: [
                            const Positioned.fill(child: _FakeBarcodeWidget()),
                            const Positioned.fill(child: _ScanCorners()),
                            if (_stage < 2)
                              AnimatedBuilder(
                                animation: _scanCtrl,
                                builder: (ctx, child) => Positioned(
                                  top: 40 + _scanCtrl.value * 190,
                                  left: 40,
                                  right: 40,
                                  child: Container(
                                    height: 2,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          AppColors.categoryNutrition.withValues(alpha: 0.9),
                                          Colors.transparent,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.categoryNutrition.withValues(alpha: 0.6),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (_stage == 2)
                              Positioned.fill(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 400),
                                  opacity: 1.0,
                                  child: Container(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.categoryNutrition,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.black,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        const Text(
                                          'Oat Bar. Apple Cinnamon',
                                          style: TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -0.3,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '190 kcal. 4g protein',
                                          style: TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 14,
                                            color: Colors.white.withValues(alpha: 0.65),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 500),
                    child: Center(
                      child: Text(
                        'Over 2 million packaged foods recognized.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 700),
                    child: TourPrimaryButton(
                      label: 'Continue',
                      onTap: widget.onNext,
                      color: AppColors.categoryNutrition,
                      textColor: AppColors.canvas,
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FakeBarcodeWidget extends StatelessWidget {
  const _FakeBarcodeWidget();

  @override
  Widget build(BuildContext context) {
    const barWidths = [2.0, 1.0, 3.0, 1.0, 2.0, 4.0, 1.0, 2.0, 3.0, 1.0, 2.0, 1.0, 3.0, 2.0, 1.0, 4.0, 1.0, 2.0, 1.0, 3.0];
    return Center(
      child: SizedBox(
        width: 160,
        height: 100,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: barWidths.asMap().entries.map((entry) {
            final i = entry.key;
            final w = entry.value;
            final isDark = i % 2 == 0;
            return Container(
              width: w * 3,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.75)
                  : Colors.transparent,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ScanCorners extends StatelessWidget {
  const _ScanCorners();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: CustomPaint(
        painter: _ScanCornerPainter(color: AppColors.categoryNutrition),
      ),
    );
  }
}

class _ScanCornerPainter extends CustomPainter {
  const _ScanCornerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 22.0;

    canvas.drawPath(
      Path()..moveTo(0, len)..lineTo(0, 0)..lineTo(len, 0),
      paint,
    );
    canvas.drawPath(
      Path()..moveTo(size.width - len, 0)..lineTo(size.width, 0)..lineTo(size.width, len),
      paint,
    );
    canvas.drawPath(
      Path()..moveTo(0, size.height - len)..lineTo(0, size.height)..lineTo(len, size.height),
      paint,
    );
    canvas.drawPath(
      Path()..moveTo(size.width - len, size.height)..lineTo(size.width, size.height)..lineTo(size.width, size.height - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ScanCornerPainter old) => old.color != color;
}

// ── NutrientsScreen4 ─────────────────────────────────────────────────────────

class NutrientsScreen4 extends StatelessWidget {
  const NutrientsScreen4({
    super.key,
    required this.progress,
    required this.onNext,
  });

  final double progress;
  final VoidCallback onNext;

  static const _bars = [0.95, 0.80, 1.0, 1.05, 0.72, 0.90, 1.0];
  static const _hit  = [true, false, true, true, false, true, true];
  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return TourScreen(
      topo: true,
      topoColor: AppColors.categoryNutrition,
      topoSeed: 'nut-4',
      topoOpacity: 0.10,
      child: Stack(
        children: [
          TourProgressBar(
            progress: progress,
            color: AppColors.categoryNutrition,
          ),
          TourAppHeader(title: 'This week'),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 116),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 80),
                    child: Text(
                      'PROTEIN. LAST 7 DAYS',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                        color: AppColors.categoryNutrition,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 200),
                    child: const Text(
                      'You hit your protein goal\n5 of 7 days.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.9,
                        height: 1.15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 380),
                    child: TourStatCard(
                      color: AppColors.categoryNutrition,
                      child: _ProteinBarChart(
                        bars: _bars,
                        hit: _hit,
                        labels: _labels,
                      ),
                    ),
                  ),
                  const Spacer(),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 900),
                    child: TourPrimaryButton(
                      label: 'Continue',
                      onTap: onNext,
                      color: AppColors.categoryNutrition,
                      textColor: AppColors.canvas,
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProteinBarChart extends StatefulWidget {
  const _ProteinBarChart({
    required this.bars,
    required this.hit,
    required this.labels,
  });

  final List<double> bars;
  final List<bool> hit;
  final List<String> labels;

  @override
  State<_ProteinBarChart> createState() => _ProteinBarChartState();
}

class _ProteinBarChartState extends State<_ProteinBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const chartH = 130.0;
    const goalRatio = 1.0;
    const maxBar = 1.1;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) {
        final prog = CurvedAnimation(
          parent: _ctrl,
          curve: const Cubic(0.22, 1, 0.36, 1),
        ).value;

        return SizedBox(
          height: chartH + 40,
          child: Stack(
            children: [
              Positioned(
                top: chartH * (1 - goalRatio / maxBar) - 1,
                left: 0,
                right: 0,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: AppColors.categoryNutrition.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '150g goal',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10,
                        color: AppColors.categoryNutrition.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 20,
                top: 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: widget.bars.asMap().entries.map((entry) {
                    final i = entry.key;
                    final barVal = entry.value;
                    final barH = (barVal / maxBar) * chartH * prog;
                    final isHit = widget.hit[i];
                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 500 + i * 60),
                              curve: const Cubic(0.22, 1, 0.36, 1),
                              height: barH.clamp(0.0, chartH),
                              decoration: BoxDecoration(
                                color: isHit
                                    ? AppColors.categoryNutrition
                                    : Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Row(
                  children: widget.labels.map((l) => Expanded(
                    child: Center(
                      child: Text(
                        l,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
