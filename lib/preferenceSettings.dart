import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preferences.dart';
import 'utils.dart';

class PreferenceSettingsState extends StatefulWidget {
  PreferenceSettingsState({Key key}) : super(key: key);

  @override
  PreferenceSettingsView createState() => PreferenceSettingsView();
}

class PreferenceSettingsView extends State<PreferenceSettingsState> {
  Future<int> status;
  Map<String, int> relevanceMap;
  Map<String, String> categoryDescSorted;
  List<String> relevanceKeyList;
  List<String> categoryKeyList;
  Future<PreferenceManager> preferenceManager;

  PreferenceSettingsView(){
    preferenceManager = SharedPreferences.getInstance()
        .then((value) => PreferenceManager(value));
  }

  @override
  void initState() {
    super.initState();
    status = preferenceManager.then((preferenceManager) {
      var temp = preferenceManager.loadRelevanceMap();
      List<String> sortedKeys = temp.keys.toList(growable: true);
      sortedKeys.sort((k1, k2) => temp[k2].compareTo(temp[k1]));
      sortedKeys.removeWhere((k) => !CATEGORY_DESCRIPTIONS.containsKey(k));
      relevanceMap = new LinkedHashMap<String, int>.fromIterable(sortedKeys,
          key: (k) => k, value: (k) => temp[k]);
      categoryDescSorted = new LinkedHashMap<String, String>.fromIterable(
          sortedKeys,
          key: (k) => k,
          value: (k) => CATEGORY_DESCRIPTIONS[k]);
      relevanceKeyList = relevanceMap.keys.toList();
      categoryKeyList = categoryDescSorted.keys.toList();
      return 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Preferences"),
        ),
        body: FutureBuilder<int>(
            future: status,
            builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
              return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: CATEGORY_DESCRIPTIONS.length,
                  itemBuilder: (BuildContext context, int index) {
                    return buildPreferenceListItem(index);
                  },
                  separatorBuilder: (BuildContext context, int index) =>
                      const Divider());
            }));
  }

  Container buildPreferenceListItem(int index) {
    return Container(
        height: 50,
        child: Row(children: [
          Expanded(child: Text(categoryDescSorted.values.toList()[index])),
          IconButton(
            icon: Icon(Icons.remove),
            onPressed: () async {
              var relevanceKey = relevanceKeyList[index];
              if (relevanceMap[relevanceKey] > -1) {
                relevanceMap[relevanceKey]--;
                (await preferenceManager).setPreference(
                    relevanceKey,
                    relevanceMap[relevanceKey]
                );
                setState(() {});
              }
            },
          ),
          Text(
            relevanceMap[categoryKeyList[index]].toString(),
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () async {
              var relevanceKey = relevanceKeyList[index];
              if (relevanceMap[relevanceKey] < 10) {
                relevanceMap[relevanceKey]++;
                (await preferenceManager).setPreference(
                    relevanceKey,
                    relevanceMap[relevanceKey]
                );
                setState(() {});
              }
            },
          )
        ]));
  }
}
