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

  Iterable<ShelfEntry> entries;

  static Iterable<ShelfEntry> buildEntries(List<String> titles, List<String> ids) {
    if (titles.length != ids.length) {
      return new List();
    } else {

      return List<ShelfEntry>.generate(
          titles.length, (i) => ShelfEntry(titles[i], ids[i]));
    }
  }

  static Future<Iterable<ShelfEntry>> load() async {
    var prefs = await SharedPreferences.getInstance();
    var ids = prefs.getStringList(IDS_KEY) ?? new List<String>();
    var titles = prefs.getStringList(TITLES_KEY) ?? new List<String>();
    return buildEntries(titles, ids);
  }

  static Future<Iterable<ShelfEntry>> deleteEntry(String id) async {
    var prefs = await SharedPreferences.getInstance();
    var ids = prefs.getStringList(IDS_KEY) ?? new List<String>();
    var titles = prefs.getStringList(TITLES_KEY) ?? new List<String>();
    var idx = ids.indexOf(id);
    ids.removeAt(idx);
    titles.removeAt(idx);
    prefs.setStringList(IDS_KEY, ids);
    prefs.setStringList(TITLES_KEY, titles);
    return buildEntries(titles, ids);
  }

  static Future<Iterable<ShelfEntry>> moveToShelf(Paper paper) async {
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
    return buildEntries(titles, ids);
  }
}
