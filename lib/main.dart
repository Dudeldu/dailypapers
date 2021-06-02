import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:xml_parser/xml_parser.dart';
import 'package:url_launcher/url_launcher.dart';

import 'utils.dart';
import 'shelf.dart';
import 'preferences.dart';
import 'preferenceSettings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(APaperADay());
}

class APaperADay extends StatelessWidget {
  APaperADay({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A Paper a Day',
      theme: ThemeData(
        primarySwatch: MaterialColor(0xFFb31b1b, color),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: PaperOverviewState(),
    );
  }
}

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
      "http://export.arxiv.org/api/query?search_query=cat:cs.*&sortBy=submittedDate&sortOrder=descending&max_results=200";
  static final String papersStorageKey = "PAPERS";

  static Future<void> updatePapers({bool force = false}) async {
    var prefs = await SharedPreferences.getInstance();
    var lastDate = prefs.getString("lastUpdate") ?? '';
    if (!force && lastDate != '' &&
        DateTime.now().difference(DateTime.parse(lastDate)) <
            Duration(hours: 12)) {
      return;
    }

    Map<String, int> relevanceMap = PreferenceManager(prefs).loadRelevanceMap();

    var response = await http.get(arxivRequestUrl);
    var arxivResponse = XmlDocument.fromString(response.body);
    var papers = new List<Paper>();
    var latestDate = DateTime.parse(arxivResponse.firstChild
        .getChildren("entry")[0]
        .getChild("published")
        .text);
    arxivResponse.firstChild.getChildren("entry").forEach((e) {
      if (latestDate.difference(DateTime.parse(e.getChild("published").text)) >
          Duration(hours: 24)) return;
      var authors = new List<String>();
      e.getChildren("author").forEach((a) {
        authors.add(a.getChild("name").text);
      });
      var relevance = 0;
      var categories = new List<String>();
      categories.add(e.getChild("arxiv:primary_category").getAttribute("term"));
      relevance += relevanceMap[categories[0]] ?? 0;
      e.getChildren("category").forEach((c) {
        categories.add(c.getAttribute("term"));
        relevance += relevanceMap[c.getAttribute("term")] ?? 0;
      });
      papers.add(Paper(
          e.getChild("title").text,
          e.getChild("summary").text,
          DateTime.parse(e.getChild("updated").text),
          DateTime.parse(e.getChild("published").text),
          e.getChild("id").text,
          authors,
          categories,
          relevance));
    });
    papers.sort((b, a) => a.relevance.compareTo(b.relevance));
    papers = papers.sublist(0, min(papers.length, 10));
    prefs.setStringList(papersStorageKey,
        papers.map((paper) => paper.serializeToJson()).toList());
    prefs.setString("lastUpdate", DateTime.now().toIso8601String());
    return papers;
  }

  static Future<List<Paper>> loadPapers() async {
    var prefs = await SharedPreferences.getInstance();
    var papersJsonRepresentation = prefs.getStringList(papersStorageKey);
    return papersJsonRepresentation
        .map((e) => Paper.serializeFromJson(e))
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
    Map<String, dynamic> attribMap;
    try {
      attribMap = JsonDecoder().convert(json);
    } catch (e) {
      return null;
    }

    var authors = new List<String>();
    if (attribMap["author"] != null)
      for (var i = 0; i < attribMap["author"].length; i++) {
        authors.add(attribMap["author"][i] as String);
      }
    var categories = new List<String>();
    if (attribMap["categories"] != null)
      for (var i = 0; i < attribMap["categories"].length; i++) {
        categories.add(attribMap["categories"][i] as String);
      }
    return Paper(
        attribMap["title"],
        attribMap["summary"],
        DateTime.parse(attribMap["updated"]),
        DateTime.parse(attribMap["published"]),
        attribMap["id"],
        authors,
        categories,
        attribMap["relevance"]);
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

class PaperOverviewState extends StatefulWidget {
  PaperOverviewState({Key key}) : super(key: key);

  @override
  PaperOverview createState() => PaperOverview();
}

class PaperOverview extends State<PaperOverviewState> {
  @override
  void initState() {
    super.initState();
    shelf = [new List(), new List()];
    Shelf.load().then((value) {
      shelf = value;
      setState(() {});
    });
    papers = Paper.updatePapers().then((_) {
      return Paper.loadPapers();
    });
  }

  List<List<String>> shelf;
  Future<List<Paper>> papers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("A Paper a Day"),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => PreferenceSettingsState()));
            },
            icon: Icon(Icons.low_priority),
          )
        ],
      ),
      body: Center(
          child: FutureBuilder<List<Paper>>(
        future: papers,
        builder: (BuildContext context, AsyncSnapshot<List<Paper>> snapshot) {
          if (snapshot.hasData)
            return RefreshIndicator(
                onRefresh: () {
                  papers = Paper.updatePapers(force: true).then((_) => Paper.loadPapers());
                  return papers;
                },
                child: SingleChildScrollView(
                    child: Container(
                        child: ExpansionPanelList(
                  expansionCallback: (int index, bool isExpanded) {
                    setState(() {
                      snapshot.data[index].isExpanded = !isExpanded;
                    });
                  },
                  children: snapshot.data.map(buildPanelForPaper).toList(),
                ))));
          else
            return CircularProgressIndicator();
        },
      )),
      drawer: Drawer(
          child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
              DrawerHeader(
                decoration: BoxDecoration(
                    color: Color.fromRGBO(179, 27, 27, .8),
                    image:
                        DecorationImage(image: AssetImage('assets/books.jpg'))),
                child: Text(
                  'Shelf',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              )
            ] +
            generateShelf(shelf),
      )),
    );
  }

  ExpansionPanel buildPanelForPaper(Paper paper) {
    return ExpansionPanel(
        headerBuilder: (BuildContext context, bool isExpanded) {
          return Column(children: [
            ListTile(
                onTap: () {
                  setState(() {
                    paper.isExpanded = !paper.isExpanded;
                  });
                },
                title: Padding(
                    child: Text(paper.title, textScaleFactor: 1.0),
                    padding: EdgeInsets.fromLTRB(0, 5, 0, 5)),
                subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(paper.formatUpdated()),
                      Divider(),
                      Padding(
                        child: Text(
                          paper.getCategoriesDescription(),
                          textScaleFactor: 1.0,
                          style: TextStyle(color: Colors.black),
                        ),
                        padding: EdgeInsets.fromLTRB(0, 0, 0, 5),
                      )
                    ]),
                leading: IconButton(
                  icon: Icon(Icons.picture_as_pdf),
                  onPressed: paper.launchWeb,
                )),
          ]);
        },
        body: Padding(
          child: Column(children: [
            Text(
              paper.summary,
              softWrap: true,
              textAlign: TextAlign.justify,
            ),
            Divider(),
            Row(children: [
              Expanded(
                  child: Text(
                paper.author.join(', '),
                textAlign: TextAlign.left,
                softWrap: true,
              )),
              IconButton(
                  icon: Icon(Icons.save),
                  onPressed: () async {
                    shelf = await Shelf.moveToShelf(paper);
                    setState(() {});
                  },
                  color: Colors.black,
                  alignment: Alignment.centerRight)
            ])
          ]),
          padding: EdgeInsets.all(15),
        ),
        isExpanded: paper.isExpanded);
  }

  List<Widget> generateShelf(List<List<String>> shelfData) {
    List<Widget> shelfWidgets = new List<Widget>();
    if (shelfData.length != 2 || shelfData[0].length != shelfData[1].length)
      return [];
    for (var i = 0; i < shelfData[0].length; i++) {
      shelfWidgets.add(ListTile(
        title: Text(shelfData[0][i]),
        trailing: IconButton(
          icon: Icon(Icons.delete),
          onPressed: () async {
            shelf = await Shelf.deleteEntry(shelfData[1][i]);
            setState(() {});
          },
        ),
        onTap: () async {
          final url = shelfData[1][i];
          if (await canLaunch(url)) {
            await launch(url);
          } else {
            throw 'Could not launch $url';
          }
        },
      ));
    }
    return shelfWidgets;
  }
}
