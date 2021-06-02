import 'package:shared_preferences/shared_preferences.dart';

import 'utils.dart';

class PreferenceManager {
  SharedPreferences sharedPrefs;

  PreferenceManager(this.sharedPrefs);

  resetPreferences() async {
    for (var key in sharedPrefs.getKeys()) {
      if (key.startsWith("RELEVANCE")) {
        sharedPrefs.remove(key);
      }
    }
  }

  Map<String, int> loadRelevanceMap() {
    var relevanceMap = new Map<String, int>();
    for (var key in sharedPrefs.getKeys()) {
      if (key.startsWith("RELEVANCE") && key.trim() != "RELEVANCE") {
        relevanceMap[key.replaceAll("RELEVANCE", "")] = sharedPrefs.getInt(key);
      }
    }
    for (var key in CATEGORY_DESCRIPTIONS.keys) {
      if (!relevanceMap.containsKey(key)) {
        relevanceMap[key] = 0;
      }
    }
    return relevanceMap;
  }

  void setPreference(String category, int value) {
    sharedPrefs.setInt("RELEVANCE" + category, value);
  }

  void increasePreferenceOnShelving(List<String> categories) {
    for (var category in categories) {
      sharedPrefs.setInt("RELEVANCE" + category,
          (sharedPrefs.getInt("RELEVANCE" + category) ?? 0) + 2);
    }
  }
}