import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:zuralog/features/nutrition/domain/food_icon.dart';

void main() {
  group('iconForFood', () {
    test('exact match: egg → egg icon', () {
      expect(iconForFood('egg'), FontAwesomeIcons.egg);
    });

    test('partial match: scrambled eggs with spinach → egg (rule order)',
        () {
      expect(iconForFood('scrambled eggs with spinach'), FontAwesomeIcons.egg);
    });

    test('case insensitive: TOAST and Toast → breadSlice', () {
      expect(iconForFood('TOAST'), FontAwesomeIcons.breadSlice);
      expect(iconForFood('Toast'), FontAwesomeIcons.breadSlice);
    });

    test('whitespace trimmed: "  rice  " → bowlRice', () {
      expect(iconForFood('  rice  '), FontAwesomeIcons.bowlRice);
    });

    test('pizza wins over bread: pepperoni pizza → pizzaSlice', () {
      expect(iconForFood('pepperoni pizza'), FontAwesomeIcons.pizzaSlice);
    });

    test('burger wins over bread/cheese: cheeseburger → burger', () {
      expect(iconForFood('cheeseburger'), FontAwesomeIcons.burger);
    });

    test('nut rule fires on "peanut butter" before cheese: → seedling', () {
      expect(iconForFood('peanut butter'), FontAwesomeIcons.seedling);
    });

    test('empty and unknown fall back to utensils', () {
      expect(iconForFood(''), FontAwesomeIcons.utensils);
      expect(iconForFood('xyzzy'), FontAwesomeIcons.utensils);
    });
  });
}
