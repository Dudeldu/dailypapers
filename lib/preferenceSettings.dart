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
  Future<PreferenceManager> preferenceManager;
  Future<int> status;

  // Only filled with data, once status was awaited
  Preferences preferences;
  List<String> keysSorted;
  List<String> categoriesSorted;

  PreferenceSettingsView() {
    preferenceManager = SharedPreferences.getInstance()
        .then((value) => PreferenceManager(value));
  }

  @override
  void initState() {
    super.initState();
    status = preferenceManager.then((preferenceManager) async {
      preferences = await preferenceManager.loadRelevanceMap();

      keysSorted = preferences.keys().toList();
      keysSorted.sort((k1, k2) => preferences
          .getPreference(k2)
          .compareTo(preferences.getPreference(k1)));
      keysSorted.removeWhere((k) => !CATEGORY_DESCRIPTIONS.containsKey(k));

      categoriesSorted =
          keysSorted.map<String>((k) => CATEGORY_DESCRIPTIONS[k]).toList();
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
              if (!snapshot.hasData)
                return Center(child: CircularProgressIndicator());
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
    var key = keysSorted[index];
    var category = categoriesSorted[index];
    return Container(
        height: 50,
        child: Row(children: [
          Expanded(child: Text(category)),
          IconButton(
            icon: Icon(Icons.remove),
            onPressed: () async {
              (await preferenceManager)
                  .setPreference(key, preferences.decrease(key));
              setState(() {});
            },
          ),
          Text(
            preferences.getPreference(key).toString(),
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () async {
              (await preferenceManager)
                  .setPreference(key, preferences.increase(key));
              setState(() {});
            },
          )
        ]));
  }
}
