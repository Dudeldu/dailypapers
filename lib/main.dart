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
  @override
  void initState() {
    super.initState();
    shelfEntries = new List();
    Shelf.load().then((value) {
      shelfEntries = value;
      setState(() {});
    });
    papers = Paper.updatePapers().then((_) {
      return Paper.loadPapers();
    });
  }

  Iterable<ShelfEntry> shelfEntries;
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
                  papers = Paper.updatePapers(force: true)
                      .then((_) => Paper.loadPapers());
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
