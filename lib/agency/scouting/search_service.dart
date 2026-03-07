import 'package:flutter/foundation.dart';

class SearchService {
  static final ValueNotifier<String> query = ValueNotifier<String>('');

  static void setQuery(String q) => query.value = q;
}
