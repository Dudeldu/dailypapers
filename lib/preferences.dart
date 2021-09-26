import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:select_dialog/select_dialog.dart';

import 'utils.dart';

const int MAX_PREFERENCE = 20;

class Preferences {
  Map<String, int> preferences;

  Preferences(this.preferences);

  int getPreference(String category) {
    return preferences[category] ?? 0;
  }

  Iterable<String> preferredKeys() {
    return preferences.keys.where((category) => getPreference(category) > 0);
  }

  Iterable<String> keys() {
    return preferences.keys;
  }

  int increase(String category) {
    var current = getPreference(category);
    if (current < MAX_PREFERENCE) {
      preferences[category] = current + 1;
    }
    return getPreference(category);
  }

  int decrease(String category) {
    var current = getPreference(category);
    if (current > -1) {
      preferences[category] = current - 1;
    }
    return getPreference(category);
  }
}

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

  Future<Preferences> loadRelevanceMap({context}) async {
    var relevanceMap = new Map<String, int>();
    for (var key in sharedPrefs.getKeys()) {
      if (key.startsWith("RELEVANCE") && key.trim() != "RELEVANCE") {
        relevanceMap[key.replaceAll("RELEVANCE", "")] = sharedPrefs.getInt(key);
      }
    }
    /* if relevance Map has still no keys it is a new installation
     * without any preferences
     * -> to simplify the start it lets you chose from the main topics
     */
    if (relevanceMap.isEmpty && context != null) {
      var mainTopic = "";
      await SelectDialog.showModal<String>(context,
          label: "Choose main direction",
          items: Directions.names,
          onChange: (String selected) {
        mainTopic = selected;
      });
      if (mainTopic != "") {
        var mainTopicAbbr = Directions.nameToId(mainTopic) + ".";
        for (var key in CATEGORY_DESCRIPTIONS.keys) {
          if (key.startsWith(mainTopicAbbr)) {
            setPreference(key, 1);
            relevanceMap[key] = 1;
          }
        }
      }
    }
    for (var key in CATEGORY_DESCRIPTIONS.keys) {
      if (!relevanceMap.containsKey(key)) {
        relevanceMap[key] = 0;
      }
    }
    return Preferences(relevanceMap);
  }

  void setPreference(String category, int value) {
    sharedPrefs.setInt("RELEVANCE" + category, value);
  }

  int getPreference(String category) {
    return sharedPrefs.getInt("RELEVANCE" + category) ?? 0;
  }

  void increasePreferenceOnShelving(List<String> categories) {
    for (var category in categories) {
      setPreference(category, min(getPreference(category) + 2, MAX_PREFERENCE));
    }
  }
}
