/// Help Center Screen.
///
/// Searchable, categorized FAQs plus a Contact Support CTA. Opens
/// from Settings → About → Help Center.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/settings/presentation/widgets/settings_section_label.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── HelpCenterScreen ──────────────────────────────────────────────────────────

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final next = _searchController.text.trim().toLowerCase();
      if (next != _query) setState(() => _query = next);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final categories = _allCategories().map((c) => c.filter(_query)).toList()
      ..removeWhere((c) => c.items.isEmpty);

    return ZuralogScaffold(
      appBar: const ZuralogAppBar(title: 'Help Center', showProfileAvatar: false),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppDimens.spaceXl),
        children: [
          const SizedBox(height: AppDimens.spaceLg),
          _HelpHero(),
          const SizedBox(height: AppDimens.spaceLg),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: ZSearchBar(
              controller: _searchController,
              placeholder: 'Search help articles',
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),

          if (categories.isEmpty)
            _EmptyResults(query: _query)
          else
            for (final category in categories) ...[
              SettingsSectionLabel(category.name.toUpperCase()),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: ZAccordion(
                  items: category.items
                      .map(
                        (f) => ZAccordionItem(
                          title: f.question,
                          content: _FaqAnswer(answer: f.answer),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
            ],

          const SizedBox(height: AppDimens.spaceSm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: _StillNeedHelp(primaryColor: colors.primary),
          ),
        ],
      ),
    );
  }
}

// ── Content model ─────────────────────────────────────────────────────────────

class _HelpCategory {
  const _HelpCategory({required this.name, required this.items});

  final String name;
  final List<_FaqEntry> items;

  _HelpCategory filter(String query) {
    if (query.isEmpty) return this;
    return _HelpCategory(
      name: name,
      items: items
          .where((f) =>
              f.question.toLowerCase().contains(query) ||
              f.answer.toLowerCase().contains(query))
          .toList(),
    );
  }
}

class _FaqEntry {
  const _FaqEntry({required this.question, required this.answer});
  final String question;
  final String answer;
}

List<_HelpCategory> _allCategories() => const [
      _HelpCategory(
        name: 'Getting started',
        items: [
          _FaqEntry(
            question: 'What is ZuraLog?',
            answer:
                "ZuraLog is your pocket health coach. It brings every "
                "piece of your health data — activity, sleep, nutrition, "
                "heart — into one place, and pairs it with an AI coach "
                "(Zura) who reads it with you and helps you act on it.",
          ),
          _FaqEntry(
            question: 'How do I connect Apple Health or Google Health Connect?',
            answer:
                "Go to Settings → Integrations. Tap Apple Health (iOS) or "
                "Health Connect (Android) and grant permission to the "
                "categories you want synced. You can change what's shared "
                "any time from the same screen.",
          ),
          _FaqEntry(
            question: 'Where should I start?',
            answer:
                "Finish onboarding so Zura has a baseline, connect at least "
                "one health data source, and open the coach tab. Ask it "
                "anything — \"how did I sleep last night?\" or \"what "
                "should I focus on today?\" — and it'll pull your real "
                "numbers into the reply.",
          ),
        ],
      ),
      _HelpCategory(
        name: 'AI coach',
        items: [
          _FaqEntry(
            question: 'What can Zura do?',
            answer:
                "Zura can read your health data, answer questions about "
                "it, log meals and workouts when you ask, create and "
                "update goals, and spot patterns over time. It's a coach, "
                "not a doctor — it won't diagnose anything and will tell "
                "you when to see a professional.",
          ),
          _FaqEntry(
            question: "How do I change Zura's tone?",
            answer:
                "Settings → About you → Tone. Pick direct, warm, minimal, "
                "or thorough — the next reply uses the new tone.",
          ),
          _FaqEntry(
            question: 'Can I send Zura a photo?',
            answer:
                "Yes. Tap the plus icon in the chat, pick a photo from "
                "your camera or library, and send it with your question. "
                "Zura can describe what it sees and use it as context.",
          ),
          _FaqEntry(
            question: "Why did Zura say it can't help with something?",
            answer:
                "Zura only answers health, fitness, nutrition, sleep, "
                "recovery, and app-navigation questions. Ask it something "
                "outside that range and it'll politely redirect you.",
          ),
        ],
      ),
      _HelpCategory(
        name: 'Nutrition',
        items: [
          _FaqEntry(
            question: 'How do I log a meal?',
            answer:
                "Tap the plus icon on the Today tab, pick Nutrition, then "
                "either type the food, pick from your meal templates, or "
                "snap a photo. Zura estimates calories and macros and "
                "lets you adjust before saving.",
          ),
          _FaqEntry(
            question: 'Can Zura estimate calories from a photo?',
            answer:
                "Yes — send Zura a photo of the meal and ask for an "
                "estimate. It'll return calories and macros with a "
                "confidence note. You can refine the numbers before "
                "logging if you want.",
          ),
        ],
      ),
      _HelpCategory(
        name: 'Workouts & activity',
        items: [
          _FaqEntry(
            question: 'How do streaks work?',
            answer:
                "You keep a streak by hitting at least one logged "
                "activity, workout, or wellness check-in on a given day. "
                "Miss a day and the streak resets — unless you have a "
                "freeze token saved, which skips a single day for you.",
          ),
          _FaqEntry(
            question: 'Do I need a wearable to use ZuraLog?',
            answer:
                "No. ZuraLog works with manual logs, phone-tracked "
                "activity, and any data already in Apple Health or "
                "Health Connect. A wearable makes things richer, but "
                "it's never required.",
          ),
        ],
      ),
      _HelpCategory(
        name: 'Privacy & data',
        items: [
          _FaqEntry(
            question: 'Who can see my data?',
            answer:
                "Only you. Your health data is tied to your account and "
                "never shared with other users. Zura reads your data to "
                "answer your questions, but the contents of your "
                "conversations stay private to you.",
          ),
          _FaqEntry(
            question: 'How do I export my data?',
            answer:
                "Settings → Privacy & Data → Export my data. You'll get "
                "a JSON file with your profile, activity, sleep, "
                "nutrition, weight, and goals.",
          ),
          _FaqEntry(
            question: 'How do I delete my account?',
            answer:
                "Settings → Account → Delete account. This removes your "
                "profile and every health record we have for you. The "
                "action is final — export your data first if you want a "
                "copy.",
          ),
        ],
      ),
      _HelpCategory(
        name: 'Subscription',
        items: [
          _FaqEntry(
            question: "What's free and what's premium?",
            answer:
                "The core experience — logging, the coach, health "
                "integrations, streaks — is free. Premium unlocks the "
                "larger Zura model for deeper questions, higher daily "
                "message limits, richer trend charts, and the full "
                "Progress tab.",
          ),
          _FaqEntry(
            question: 'How do I cancel?',
            answer:
                "Cancel in the App Store (iOS) or Play Store (Android) "
                "under your subscriptions. Your premium features stay "
                "active until the end of the billing period, then the "
                "account drops back to free.",
          ),
        ],
      ),
    ];

// ── Widgets ───────────────────────────────────────────────────────────────────

class _HelpHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.shapeSm),
                ),
                child: Icon(
                  Icons.help_rounded,
                  color: colors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "We're here to help",
                      style: AppTextStyles.titleLarge.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Browse answers, or search for what you need.",
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FaqAnswer extends StatelessWidget {
  const _FaqAnswer({required this.answer});

  final String answer;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: AppDimens.spaceLg,
        right: AppDimens.spaceLg,
        bottom: AppDimens.spaceMd,
      ),
      child: Text(
        answer,
        style: AppTextStyles.bodyMedium.copyWith(
          color: colors.textSecondary,
          height: 1.45,
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceXl,
        AppDimens.spaceLg,
        AppDimens.spaceXl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No answers matched "$query"',
            style: AppTextStyles.titleMedium.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            "Try a different keyword, or send us a note — we'll get back to you.",
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StillNeedHelp extends StatelessWidget {
  const _StillNeedHelp({required this.primaryColor});
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.shapeLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Still need help?',
              style: AppTextStyles.titleMedium.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              "Email us — we read every message and usually reply within a day.",
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            PrimaryButton(
              label: 'Contact Support',
              onPressed: () => launchUrl(
                Uri.parse('mailto:support@zuralog.com'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
