import 'package:flutter/material.dart';

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
  int retrievalStatus = Paper.OK;

  Future<List<ShelfEntry>> shelfEntries;
  Future<List<Paper>> papers;

  static const Widget NO_CATEGORIES_WIDGET = Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Text(
        "\n\n\nIndicate your personal preferences for at least one "
        "category by increasing its value!\n\n\n",
        textAlign: TextAlign.justify,
        softWrap: true,
        style: TextStyle(fontSize: 20),
      ));
  static const Widget DRAWER_HEADER = DrawerHeader(
    decoration: BoxDecoration(
        color: Color.fromRGBO(179, 27, 27, .8),
        image: DecorationImage(image: AssetImage('assets/books.jpg'))),
    child: Text(
      'Shelf',
      style: TextStyle(
        color: Colors.white,
        fontSize: 24,
      ),
    ),
  );

  @override
  void initState() {
    super.initState();
    shelfEntries = Shelf.load();
    refreshPapers();
  }

  void refreshPapers({force = false}) async {
    retrievalStatus = Paper.OK;
    retrievalStatus = await Paper.updatePapers(context, force: force);
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
                    child: retrievalStatus == Paper.NO_CATEGORIES
                        ? NO_CATEGORIES_WIDGET
                        : Container(
                            child: ExpansionPanelList(
                            expansionCallback: (int index, bool isExpanded) {
                              setState(() {
                                snapshot.data[index].isExpanded = !isExpanded;
                              });
                            },
                            children:
                                snapshot.data.map(buildPanelForPaper).toList(),
                          ))));
          } else {
            return CircularProgressIndicator();
          }
        },
      )),
      drawer: buildSideDrawer(),
    );
  }

  FutureBuilder buildSideDrawer() {
    return FutureBuilder<Iterable<ShelfEntry>>(
        future: shelfEntries,
        builder: (BuildContext context,
            AsyncSnapshot<Iterable<ShelfEntry>> snapshot) {
          if (snapshot.hasData)
            return fillDrawerWithShelfOrLoadingIndicator(snapshot.data
                .map((entry) => ListTile(
                      title: Text(entry.title),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => setState(() {
                          shelfEntries = Shelf.deleteEntry(entry.id);
                        }),
                      ),
                      onTap: () => launchWeb(entry.id),
                    ))
                .toList());
          else
            return fillDrawerWithShelfOrLoadingIndicator(
                [CircularProgressIndicator()]);
        });
  }

  Drawer fillDrawerWithShelfOrLoadingIndicator(List<Widget> widgets) {
    return Drawer(
        child: ListView(
            padding: EdgeInsets.zero, children: [DRAWER_HEADER] + widgets));
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
                  onPressed: () => launchWeb(paper.id),
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
                  onPressed: () => setState(() {
                        shelfEntries = Shelf.moveToShelf(paper);
                      }),
                  color: Colors.black,
                  alignment: Alignment.centerRight)
            ])
          ]),
          padding: EdgeInsets.all(15),
        ),
        isExpanded: paper.isExpanded);
  }
}
