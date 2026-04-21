/// Maps a free-text food name to a FontAwesome icon.
///
/// Used on parsed-food rows in the nutrition flow (meal review, meal detail)
/// to give each food a visual identity. Rule-order matters: specific keywords
/// (pizza, burger) come before generic ones (bread, cheese) so composite names
/// resolve to the most useful icon.
library;

import 'package:flutter/widgets.dart' show IconData;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Ordered keyword rules. Each tuple is `(keywords, icon)`. The first tuple
/// whose keyword list has any term appearing in the normalized food name wins.
const List<(List<String>, IconData)> _foodIconRules = [
  (['pizza'], FontAwesomeIcons.pizzaSlice),
  (['burger', 'sandwich', 'wrap', 'taco', 'burrito', 'hot dog'],
      FontAwesomeIcons.burger),
  (['egg', 'omelette', 'omelet', 'scrambled', 'frittata'],
      FontAwesomeIcons.egg),
  (['bread', 'toast', 'bagel', 'croissant', 'muffin', 'pancake', 'waffle'],
      FontAwesomeIcons.breadSlice),
  (['rice', 'pasta', 'noodle', 'ramen', 'spaghetti', 'risotto', 'lasagna'],
      FontAwesomeIcons.bowlRice),
  (['chicken', 'turkey', 'duck'], FontAwesomeIcons.drumstickBite),
  (['fish', 'salmon', 'tuna', 'sushi', 'shrimp', 'prawn', 'cod', 'trout'],
      FontAwesomeIcons.fish),
  (['beef', 'steak', 'pork', 'bacon', 'ham', 'sausage', 'meatball'],
      FontAwesomeIcons.bacon),
  (['nut', 'almond', 'peanut', 'chip', 'pretzel', 'cracker'],
      FontAwesomeIcons.seedling),
  (['cheese', 'yogurt', 'yoghurt', 'milk', 'cream', 'butter'],
      FontAwesomeIcons.cheese),
  (
    [
      'apple',
      'banana',
      'berry',
      'grape',
      'orange',
      'melon',
      'pear',
      'mango',
      'peach',
      'pineapple',
    ],
    FontAwesomeIcons.appleWhole,
  ),
  (
    [
      'salad',
      'carrot',
      'lettuce',
      'broccoli',
      'tomato',
      'cucumber',
      'spinach',
      'kale',
      'veg',
    ],
    FontAwesomeIcons.carrot,
  ),
  (['soup', 'stew', 'chili', 'broth'], FontAwesomeIcons.bowlFood),
  (
    [
      'cake',
      'cookie',
      'brownie',
      'chocolate',
      'ice cream',
      'candy',
      'donut',
      'pastry'
    ],
    FontAwesomeIcons.cookie,
  ),
  (['coffee', 'tea', 'latte', 'espresso', 'cappuccino', 'matcha'],
      FontAwesomeIcons.mugHot),
  (['water', 'juice', 'smoothie', 'soda', 'cola', 'kombucha'],
      FontAwesomeIcons.wineBottle),
];

/// Returns the icon that best matches [foodName].
///
/// Normalizes by trimming and lowercasing, then returns the first rule's
/// icon whose keyword list contains a term present in the normalized name.
/// Returns [FontAwesomeIcons.utensils] on no match or empty input.
IconData iconForFood(String foodName) {
  final normalized = foodName.trim().toLowerCase();
  if (normalized.isEmpty) return FontAwesomeIcons.utensils;
  for (final (keywords, icon) in _foodIconRules) {
    for (final kw in keywords) {
      if (normalized.contains(kw)) return icon;
    }
  }
  return FontAwesomeIcons.utensils;
}
