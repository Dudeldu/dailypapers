import 'dart:convert';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:xml_parser/xml_parser.dart';

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

  static const int NO_CATEGORIES = -2;
  static const int NO_UPDATE = -1;
  static const int OK = 0;

  static const String ARXIV_BASE_URL = "http://export.arxiv.org/api/query";
  static const String SORTING_URL_PATTERN =
      "sortBy=submittedDate&sortOrder=descending";
  static const String RESULT_URL_PATTERN = "max_results=200";

  static const String PAPERS_STORAGE_KEY = "PAPERS";
  static const int NR_PAPERS = 10;

  static String generateArxivRequestUrlFromPreferences(
      Preferences preferences) {
    var categoryQuery = preferences.preferredKeys().join("+OR+");
    if (categoryQuery.length == 0) {
      return "";
    }
    return "$ARXIV_BASE_URL?search_query=$categoryQuery&$SORTING_URL_PATTERN&$RESULT_URL_PATTERN";
  }

  static Future<int> updatePapers(BuildContext context, {force = false}) async {
    var prefs = await SharedPreferences.getInstance();
    var lastDate = prefs.getString("lastUpdate") ?? '';
    if (!force &&
        lastDate != '' &&
        DateTime.now().difference(DateTime.parse(lastDate)) <
            Duration(hours: 12)) {
      // Skip update if it is not forced and less than 12h
      // passed since the last one
      return NO_UPDATE;
    }

    Preferences preferences =
        await PreferenceManager(prefs).loadRelevanceMap(context: context);
    var requestUrl = generateArxivRequestUrlFromPreferences(preferences);
    if (requestUrl.length == 0) {
      return NO_CATEGORIES;
    }
    var response = await http.get(requestUrl);
    var arxivResponse = XmlDocument.fromString(response.body);
    var latestDate = DateTime.parse(arxivResponse.firstChild
        .getChildren("entry")[0]
        .getChild("published")
        .text);
    var papers = arxivResponse.firstChild
        .getChildren("entry")
        .map((paper) {
          var publishedDate = DateTime.parse(paper.getChild("published").text);
          if (publishedDate.year != latestDate.year ||
              publishedDate.month != latestDate.month ||
              publishedDate.day != latestDate.day)
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
              .map((category) => preferences.getPreference(category))
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
        })
        .where((element) => element != null)
        .toList();
    papers.sort((b, a) => a.relevance == b.relevance
        ? (a.published.compareTo(b.published) == 0
            ? b.title.compareTo(a.title)
            : a.published.compareTo(b.published))
        : a.relevance.compareTo(b.relevance));
    papers = papers.sublist(0, min(papers.length, NR_PAPERS));
    prefs.setStringList(PAPERS_STORAGE_KEY,
        papers.map((paper) => paper.serializeToJson()).toList());
    prefs.setString("lastUpdate", DateTime.now().toIso8601String());
    return OK;
  }

  static Future<List<Paper>> loadPapers() async {
    var prefs = await SharedPreferences.getInstance();
    var papersJsonRepresentation = prefs.getStringList(PAPERS_STORAGE_KEY);
    return papersJsonRepresentation
        .map((paper) => Paper.serializeFromJson(paper))
        .where((element) => element != null)
        .toList();
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
    /* Implements the same as the following but preserves the
     * order of categories
     * ```dart
     * return categories
     *    .map((e) => CATEGORY_DESCRIPTIONS[e])
     *    .where((element) => element != null)
     *    .toSet()
     *    .join(", ");
     * ```
     */
    var set = new Set();
    return categories
        .map((e) => CATEGORY_DESCRIPTIONS[e])
        .where((element) => element != null)
        .where((e) => set.add(e))
        .join(", ");
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
