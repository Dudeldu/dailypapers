import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:xml_parser/xml_parser.dart';
import 'package:url_launcher/url_launcher.dart';

import 'preferences.dart';
import 'utils.dart';

class Paper {
  Paper(this.title, this.summary, this.updated, this.published, this.id,
      this.author, this.categories, this.relevance);

  bool isExpanded = false;

  final String title;
  final String summary;
  final DateTime updated;
  final DateTime published;
  final String id;
  final List<String> author;
  final List<String> categories;
  final int relevance;

  static final String arxivRequestUrl =
      "http://export.arxiv.org/api/query?search_query=cat:cs.*&"
      "sortBy=submittedDate&sortOrder=descending&max_results=200";
  static final String papersStorageKey = "PAPERS";

  static Future<int> updatePapers({bool force = false}) async {
    var prefs = await SharedPreferences.getInstance();
    var lastDate = prefs.getString("lastUpdate") ?? '';
    if (!force &&
        lastDate != '' &&
        DateTime.now().difference(DateTime.parse(lastDate)) <
            Duration(hours: 12)) {
      // Skip update if it is not forced and less than 12h
      // passed since the last one
      return -1;
    }

    Map<String, int> relevanceMap = PreferenceManager(prefs).loadRelevanceMap();

    var response = await http.get(arxivRequestUrl);
    var arxivResponse = XmlDocument.fromString(response.body);
    var latestDate = DateTime.parse(arxivResponse.firstChild
        .getChildren("entry")[0]
        .getChild("published")
        .text);
    var papers = arxivResponse.firstChild.getChildren("entry").map((paper) {
      var publishedDate = DateTime.parse(paper.getChild("published").text);
      if (latestDate.difference(publishedDate) > Duration(hours: 24))
        /* if there are more than 24 hours difference compared to the newest
         * paper in the retrieved batch then this paper is already old and
         * shouldn't be processed
         */
        return null;
      var authors = paper
          .getChildren("author")
          .map((author) => author.getChild("name").text)
          .toList();
      var primaryCategory = paper
          .getChild("arxiv:primary_category")
          .getAttribute("term")
          .toString();
      var categories = [primaryCategory] +
          paper
              .getChildren("category")
              .map((category) => category.getAttribute("term").toString())
              .toList();

      var relevance = categories
          .map((category) => relevanceMap[category] ?? 0)
          .reduce((value, element) => value + element);

      return Paper(
          paper.getChild("title").text,
          paper.getChild("summary").text,
          DateTime.parse(paper.getChild("updated").text),
          DateTime.parse(paper.getChild("published").text),
          paper.getChild("id").text,
          authors,
          categories,
          relevance);
    }).toList();
    papers.removeWhere((element) => element == null);
    papers.sort((b, a) => a.relevance.compareTo(b.relevance));
    papers = papers.sublist(0, min(papers.length, 10));
    prefs.setStringList(papersStorageKey,
        papers.map((paper) => paper.serializeToJson()).toList());
    prefs.setString("lastUpdate", DateTime.now().toIso8601String());
    return 0;
  }

  static Future<List<Paper>> loadPapers() async {
    var prefs = await SharedPreferences.getInstance();
    var papersJsonRepresentation = prefs.getStringList(papersStorageKey);
    return papersJsonRepresentation
        .map((paper) => Paper.serializeFromJson(paper))
        .toList();
  }

  launchWeb() async {
    if (await canLaunch(id)) {
      await launch(id);
    } else {
      throw 'Could not launch $id';
    }
  }

  String formatUpdated() {
    var localTime = updated.toLocal();
    var monthString = (localTime.month >= 10)
        ? localTime.month.toString()
        : ("0" + localTime.month.toString());
    var dayString = (localTime.day >= 10)
        ? localTime.day.toString()
        : ("0" + localTime.day.toString());
    return localTime.year.toString() + "-" + monthString + "-" + dayString;
  }

  String getCategoriesDescription() {
    var descList = new List<String>();
    categories.forEach((e) {
      var desc = CATEGORY_DESCRIPTIONS[e];
      if (desc != null && !descList.contains(desc)) {
        descList.add(desc);
      }
    });
    return descList.join(", ");
  }

  String serializeToJson() {
    return JsonEncoder().convert(this.toMap());
  }

  static Paper serializeFromJson(String json) {
    Map<String, dynamic> attributeMap;
    try {
      attributeMap = JsonDecoder().convert(json);
    } catch (e) {
      return null;
    }

    return Paper(
        attributeMap["title"],
        attributeMap["summary"],
        DateTime.parse(attributeMap["updated"]),
        DateTime.parse(attributeMap["published"]),
        attributeMap["id"],
        attributeMap["author"].cast<String>(),
        attributeMap["categories"].cast<String>(),
        attributeMap["relevance"]);
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = new Map();
    map["title"] = title;
    map["summary"] = summary;
    map["updated"] = updated.toIso8601String();
    map["published"] = published.toIso8601String();
    map["id"] = id;
    map["author"] = author;
    map["categories"] = categories;
    map["relevance"] = relevance;
    return map;
  }
}
