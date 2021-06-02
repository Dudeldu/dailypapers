import 'package:DailyPaper/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preferences.dart';

class Shelf {

  static const String IDS_KEY = "SAVED_IDS";
  static const String TITLES_KEY = "SAVED_TITLES";

  static Future<List<List<String>>> load() async {
    var prefs = await SharedPreferences.getInstance();
    var ids = prefs.getStringList(IDS_KEY) ?? new List<String>();
    var titles = prefs.getStringList(TITLES_KEY) ?? new List<String>();
    return [titles, ids];
  }

  static Future<List<List<String>>> deleteEntry(String id) async {
    var prefs = await SharedPreferences.getInstance();
    var ids = prefs.getStringList(IDS_KEY) ?? new List<String>();
    var titles = prefs.getStringList(TITLES_KEY) ?? new List<String>();
    var idx = ids.indexOf(id);
    ids.removeAt(idx);
    titles.removeAt(idx);
    prefs.setStringList(IDS_KEY, ids);
    prefs.setStringList(TITLES_KEY, titles);
    return [titles, ids];
  }

  static Future<List<List<String>>> moveToShelf(Paper paper) async {
    var prefs = await SharedPreferences.getInstance();
    var ids = prefs.getStringList(Shelf.IDS_KEY) ?? new List<String>();
    var titles = prefs.getStringList(Shelf.TITLES_KEY) ?? new List<String>();
    if (!ids.contains(paper.id)) {
      ids.add(paper.id);
      titles.add(paper.title);
    }
    prefs.setStringList(Shelf.IDS_KEY, ids);
    prefs.setStringList(Shelf.TITLES_KEY, titles);
    PreferenceManager(prefs).increasePreferenceOnShelving(paper.categories);
    return [titles, ids];
  }
}
