import 'package:flutter/foundation.dart';

Map<String, dynamic>? currentUser;

// Robust navigation system: Use ValueNotifier instead of GlobalKey to avoid collisions during transitions
final ValueNotifier<int> homeTabNotifier = ValueNotifier<int>(0);
final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);

final List<String> shopCategories = [
  'All',
  'Furniture',
  'Electronics',
  'Fashion',
  'Beauty',
  'Groceries',
  'Others'
];
