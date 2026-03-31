/// Coach Tab — Thinking Layer (Layer 0 of AI response anatomy).
///
/// Shown while the AI is generating but no response tokens have arrived yet
/// (or a tool is running). Displays an inline blob + rotating status word,
/// styled like the "AI can make mistakes" footer row. Tappable to expand
/// full thinking content when reasoning tokens are available.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_blob.dart';
import 'package:zuralog/shared/widgets/widgets.dart'
    show ZPatternText, ZPatternVariant;

// 187-word list sourced from the Claude Code binary (hardcoded, random pick
// every second — same mechanism as Claude Code's own spinner).
const _kThinkingWords = [
  'Accomplishing', 'Actioning', 'Actualizing', 'Architecting', 'Baking',
  'Beaming', "Beboppin'", 'Befuddling', 'Billowing', 'Blanching',
  'Bloviating', 'Boogieing', 'Boondoggling', 'Booping', 'Bootstrapping',
  'Brewing', 'Bunning', 'Burrowing', 'Calculating', 'Canoodling',
  'Caramelizing', 'Cascading', 'Catapulting', 'Cerebrating', 'Channeling',
  'Channelling', 'Choreographing', 'Churning', 'Clauding', 'Coalescing',
  'Cogitating', 'Combobulating', 'Composing', 'Computing', 'Concocting',
  'Considering', 'Contemplating', 'Cooking', 'Crafting', 'Creating',
  'Crunching', 'Crystallizing', 'Cultivating', 'Deciphering', 'Deliberating',
  'Determining', 'Dilly-dallying', 'Discombobulating', 'Doing', 'Doodling',
  'Drizzling', 'Ebbing', 'Effecting', 'Elucidating', 'Embellishing',
  'Enchanting', 'Envisioning', 'Evaporating', 'Fermenting', 'Fiddle-faddling',
  'Finagling', 'Flambéing', 'Flibbertigibbeting', 'Flowing', 'Flummoxing',
  'Fluttering', 'Forging', 'Forming', 'Frolicking', 'Frosting',
  'Gallivanting', 'Galloping', 'Garnishing', 'Generating', 'Germinating',
  'Gesticulating', 'Gitifying', 'Grooving', 'Gusting', 'Harmonizing',
  'Hashing', 'Hatching', 'Herding', 'Honking', 'Hullaballooing',
  'Hyperspacing', 'Ideating', 'Imagining', 'Improvising', 'Incubating',
  'Inferring', 'Infusing', 'Ionizing', 'Jitterbugging', 'Julienning',
  'Kneading', 'Leavening', 'Levitating', 'Lollygagging', 'Manifesting',
  'Marinating', 'Meandering', 'Metamorphosing', 'Misting', 'Moonwalking',
  'Moseying', 'Mulling', 'Musing', 'Mustering', 'Nebulizing',
  'Nesting', 'Newspapering', 'Noodling', 'Nucleating', 'Orbiting',
  'Orchestrating', 'Osmosing', 'Perambulating', 'Percolating', 'Perusing',
  'Philosophising', 'Photosynthesizing', 'Pollinating', 'Pondering', 'Pontificating',
  'Pouncing', 'Precipitating', 'Prestidigitating', 'Processing', 'Proofing',
  'Propagating', 'Puttering', 'Puzzling', 'Quantumizing', 'Razzle-dazzling',
  'Razzmatazzing', 'Recombobulating', 'Reticulating', 'Roosting', 'Ruminating',
  'Sautéing', 'Scampering', 'Schlepping', 'Scurrying', 'Seasoning',
  'Shenaniganing', 'Shimmying', 'Simmering', 'Skedaddling', 'Sketching',
  'Slithering', 'Smooshing', 'Sock-hopping', 'Spelunking', 'Spinning',
  'Sprouting', 'Stewing', 'Sublimating', 'Swirling', 'Swooping',
  'Symbioting', 'Synthesizing', 'Tempering', 'Thinking', 'Thundering',
  'Tinkering', 'Tomfoolering', 'Topsy-turvying', 'Transfiguring', 'Transmuting',
  'Twisting', 'Undulating', 'Unfurling', 'Unravelling', 'Vibing',
  'Waddling', 'Wandering', 'Warping', 'Whatchamacalliting', 'Whirlpooling',
  'Whirring', 'Whisking', 'Wibbling', 'Working', 'Wrangling',
  'Zesting', 'Zigzagging',
];

final _random = Random();

/// Inline thinking indicator styled like the "AI can make mistakes" footer row.
///
/// Shows a blob (size 28, BlobState.thinking) + a status label. The label
/// cycles through [_kThinkingWords] at random every second while idle.
/// When [activeToolName] is set it shows a "Checking …" label instead.
/// When [thinkingContent] is populated a chevron appears and tapping expands
/// the full accumulated reasoning text below the row.
class CoachThinkingLayer extends StatefulWidget {
  const CoachThinkingLayer({
    super.key,
    this.thinkingContent,
    this.activeToolName,
  });

  /// Accumulated reasoning text from the AI, or null if none has arrived yet.
  final String? thinkingContent;

  /// Raw tool name currently executing (e.g. "apple_health_read_metrics"), or null.
  final String? activeToolName;

  @override
  State<CoachThinkingLayer> createState() => _CoachThinkingLayerState();
}

class _CoachThinkingLayerState extends State<CoachThinkingLayer> {
  late String _word;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // Pick one word for the lifetime of this thinking session — no cycling.
    // This matches Claude Code's behaviour: one word per response, not per second.
    _word = _kThinkingWords[_random.nextInt(_kThinkingWords.length)];
  }

  @override
  void didUpdateWidget(CoachThinkingLayer old) {
    super.didUpdateWidget(old);
    // Collapse the panel when a tool starts so stale reasoning text
    // doesn't stay visible while a different operation is running.
    if (widget.activeToolName != null && old.activeToolName == null) {
      _expanded = false;
    }
  }

  static String _friendlyToolName(String raw) {
    const prefixes = {
      'apple_health_': 'Apple Health',
      'health_connect_': 'Health Connect',
      'fitbit_': 'Fitbit',
      'strava_': 'Strava',
      'garmin_': 'Garmin',
      'oura_': 'Oura',
      'whoop_': 'Whoop',
    };
    for (final entry in prefixes.entries) {
      if (raw.startsWith(entry.key)) return entry.value;
    }
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final hasContent = widget.thinkingContent != null &&
        widget.thinkingContent!.isNotEmpty;

    // Status label: tool name > thinking snippet > rotating word.
    final String label;
    if (widget.activeToolName != null) {
      label = 'Checking ${_friendlyToolName(widget.activeToolName!)}…';
    } else if (hasContent) {
      final t = widget.thinkingContent!;
      label = t.length > 120 ? t.substring(t.length - 120) : t;
    } else {
      label = '$_word…';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Inline row — same structure as the Layer 3 footer ────────────
        GestureDetector(
          onTap: hasContent
              ? () => setState(() => _expanded = !_expanded)
              : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CoachBlob(state: BlobState.thinking, size: 28),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: ZPatternText(
                  text: label,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontStyle: hasContent
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                  variant: ZPatternVariant.sage,
                  animate: true,
                ),
              ),
              if (hasContent) ...[
                const SizedBox(width: AppDimens.spaceXs),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: AppDimens.iconSm,
                  color: colors.textSecondary,
                ),
              ],
            ],
          ),
        ),

        // ── Expanded reasoning panel ─────────────────────────────────────
        if (_expanded && hasContent)
          Padding(
            padding: const EdgeInsets.only(
              top: AppDimens.spaceXs,
              left: 28 + AppDimens.spaceSm, // align with text, past the blob
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Text(
                  widget.thinkingContent!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
