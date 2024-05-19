import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:helloworld/data/tour.dart';
import 'package:helloworld/services/app_logic_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsDialog extends StatelessWidget {
  late AppLogicService appLogic;

  SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    appLogic = context.watch<AppLogicService>();

    return AlertDialog(
      title: const Text("Settings"),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => onExport(),
            icon: const Icon(Icons.ios_share),
            label: const Text("Export"),
          ),
          const SizedBox(height: 8),
          const Text('All your saved Tours'),
          Column(
            children: appLogic.currentState.allTourNames
                .map((tourName) => Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              labelText: tourName,
                            ),
                            onSubmitted: (value) =>
                                onChangeTourName(tourName, value),
                          ),
                        ),
                        if (tourName != appLogic.currentState.currentTourName)
                          IconButton(
                            onPressed: () => onSelectTour(tourName),
                            icon: const Icon(Icons.view_carousel),
                          ),
                        if (tourName != appLogic.currentState.currentTourName)
                          IconButton(
                            onPressed: () => onDeleteTour(tourName),
                            icon: const Icon(Icons.delete),
                          ),
                        if (tourName == appLogic.currentState.currentTourName)
                          const Icon(Icons.stay_current_portrait)
                      ],
                    ))
                .toList(),
          ),
          TextButton.icon(
            onPressed: () => onNewTour(),
            icon: const Icon(Icons.add),
            label: const Text('Create a new Tour'),
          )
        ],
      ),
    );
  }

  Future<void> onExport() async {
    final allData = appLogic.currentTour.toMap();
    final jsonData = jsonEncode(allData);

    await Clipboard.setData(ClipboardData(text: jsonData));
  }

  String _getSaveName() {
    if (!appLogic.currentState.allTourNames.contains(Tour.DEFAULT_SAVE_NAME)) {
      return Tour.DEFAULT_SAVE_NAME;
    }

    for (int i = 1; i < 1000; i++) {
      if (!appLogic.currentState.allTourNames
          .contains(Tour.DEFAULT_SAVE_NAME + i.toString())) {
        return Tour.DEFAULT_SAVE_NAME + i.toString();
      }
    }

    return 'Error: You are crazy.. Stop creating so many Tours..';
  }

  Future<void> onNewTour() async {
    await appLogic.saveData();
    final newName = _getSaveName();
    appLogic.currentTour = Tour.empty(name: newName);
    appLogic.currentState.allTourNames.add(newName);
    appLogic.currentState.currentTourName = newName;
    await appLogic.saveData();
    await appLogic.loadData();
  }

  Future<void> onSelectTour(String tourName) async {
    appLogic.currentState.currentTourName = tourName;
    await appLogic.saveData();
    await appLogic.loadData();
  }

  Future<void> onChangeTourName(String oldName, String newName) async {
    // rename in currentState.allTourNames
    int index = appLogic.currentState.allTourNames.indexOf(oldName);
    appLogic.currentState.allTourNames[index] = newName;

    // rename currentTourName if applicable
    if (oldName == appLogic.currentState.currentTourName) {
      appLogic.currentState.currentTourName = newName;
    }

    // load the tour, rename it and save it under its new name
    final tour = await Tour.load(oldName);
    tour.name = newName;
    await tour.save();

    // delete the old tour json data
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(oldName, '');

    // update app logic with new state and tour
    await appLogic.saveData();
    await appLogic.loadData();
  }

  Future<void> onDeleteTour(String tourName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tourName, ''); // delete the tour json data
    appLogic.currentState.allTourNames.remove(tourName);
    await appLogic.saveData();
    await appLogic.loadData();
  }
}
