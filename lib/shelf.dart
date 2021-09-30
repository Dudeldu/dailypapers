import 'package:shared_preferences/shared_preferences.dart';

import 'preferences.dart';
import 'papers.dart';

class ShelfEntry {
  String title;
  String id;

  ShelfEntry(this.title, this.id);
}

class Shelf {
  static const String IDS_KEY = "SAVED_IDS";
  static const String TITLES_KEY = "SAVED_TITLES";

  static List<ShelfEntry> buildEntries(List<String> titles, List<String> ids) {
    if (titles.length != ids.length) {
      return [];
    } else {
      return List<ShelfEntry>.generate(
          titles.length, (i) => ShelfEntry(titles[i], ids[i]));
    }
  }

  static Future<List<ShelfEntry>> load() async {
    var prefs = await SharedPreferences.getInstance();
    var ids = prefs.getStringList(IDS_KEY) ?? [];
    var titles = prefs.getStringList(TITLES_KEY) ?? [];
    return buildEntries(titles, ids);
  }

  static Future<List<ShelfEntry>> deleteEntry(String id) async {
    var prefs = await SharedPreferences.getInstance();
    var ids = prefs.getStringList(IDS_KEY) ?? [];
    var titles = prefs.getStringList(TITLES_KEY) ?? [];
    var idx = ids.indexOf(id);
    ids.removeAt(idx);
    titles.removeAt(idx);
    prefs.setStringList(IDS_KEY, ids);
    prefs.setStringList(TITLES_KEY, titles);
    return buildEntries(titles, ids);
  }

  static Future<List<ShelfEntry>> moveToShelf(Paper paper) async {
    var prefs = await SharedPreferences.getInstance();
    var ids = prefs.getStringList(Shelf.IDS_KEY) ?? [];
    var titles = prefs.getStringList(Shelf.TITLES_KEY) ?? [];
    if (!ids.contains(paper.id)) {
      ids.add(paper.id);
      titles.add(paper.title);
      PreferenceManager(prefs)
          .increasePreferenceOnShelving(paper.getCategories());
    }
    prefs.setStringList(Shelf.IDS_KEY, ids);
    prefs.setStringList(Shelf.TITLES_KEY, titles);
    return buildEntries(titles, ids);
  }
}
