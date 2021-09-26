import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'utils.dart';
import 'shelf.dart';
import 'preferenceSettings.dart';
import 'papers.dart';

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

class PaperOverviewState extends StatefulWidget {
  PaperOverviewState({Key key}) : super(key: key);

  @override
  PaperOverview createState() => PaperOverview();
}

class PaperOverview extends State<PaperOverviewState> {
  Iterable<ShelfEntry> shelfEntries;
  Future<List<Paper>> papers;
  int retrievalStatus;

  static final Widget noCategoriesTextWidget = Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Text(
        "\n\n\nIndicate your personal preferences for at least one "
        "category by increasing its value!\n\n\n",
        textAlign: TextAlign.justify,
        softWrap: true,
        style: TextStyle(fontSize: 20),
      ));

  @override
  void initState() {
    super.initState();
    shelfEntries = [];
    Shelf.load().then((value) {
      shelfEntries = value;
      setState(() {});
    });
    refreshPapers();
  }

  void refreshPapers({force = false}) async {
    retrievalStatus = Paper.OK;
    retrievalStatus = await Paper.updatePapers(context: context, force: force);
    if (retrievalStatus == Paper.NO_CATEGORIES) {
      setState(() {
        papers = Future(() {
          return [];
        });
      });
      return;
    }
    setState(() {
      papers = Paper.loadPapers();
    });
  }

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
          if (snapshot.hasData) {
            return RefreshIndicator(
                onRefresh: () async {
                  return refreshPapers(force: true);
                },
                child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: !(snapshot.data.length == 0 &&
                            retrievalStatus == Paper.NO_CATEGORIES)
                        ? Container(
                            child: ExpansionPanelList(
                            expansionCallback: (int index, bool isExpanded) {
                              setState(() {
                                snapshot.data[index].isExpanded = !isExpanded;
                              });
                            },
                            children:
                                snapshot.data.map(buildPanelForPaper).toList(),
                          ))
                        : noCategoriesTextWidget));
          } else {
            return CircularProgressIndicator();
          }
        },
      )),
      drawer: buildSideDrawer(),
    );
  }

  Drawer buildSideDrawer() {
    return Drawer(
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
          generateShelf(),
    ));
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
                    shelfEntries = await Shelf.moveToShelf(paper);
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

  List<Widget> generateShelf() {
    return shelfEntries.map((entry) {
      return ListTile(
        title: Text(entry.title),
        trailing: IconButton(
          icon: Icon(Icons.delete),
          onPressed: () async {
            shelfEntries = await Shelf.deleteEntry(entry.id);
            setState(() {});
          },
        ),
        onTap: () async {
          final url = entry.id;
          if (await canLaunch(url)) {
            await launch(url);
          } else {
            throw 'Could not launch $url';
          }
        },
      );
    }).toList();
  }
}
