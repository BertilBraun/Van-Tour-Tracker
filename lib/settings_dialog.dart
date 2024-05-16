import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:helloworld/data/tour.dart';
import 'package:helloworld/services/app_logic_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

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
            onPressed: () => onImport(),
            icon: const Icon(Icons.publish),
            label: const Text("Import"),
          ),
          TextButton.icon(
            onPressed: () => onExport(),
            icon: const Icon(Icons.ios_share),
            label: const Text("Export"),
          ),
          TextButton.icon(
            onPressed: () => onDeleteAll(),
            icon: const Icon(Icons.delete),
            label: const Text("Delete all Entries"),
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
                            onChanged: (value) =>
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

  Future<void> onImport() async {
    final files = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select the Save File',
      allowedExtensions: ['json'],
    );

    if (files != null && files.count > 0) {
      final jsonData = await File(files.paths[0]!).readAsString();
      final allData = jsonDecode(jsonData);
      await Tour.fromMap(allData).save();
      await appLogic.loadData();
    }
  }

  Future<void> onExport() async {
    final allData = appLogic.currentTour.toMap();
    final jsonData = jsonEncode(allData);

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Your File to desired location',
      fileName: 'export.json',
    );

    if (outputFile != null) {
      await File(outputFile).writeAsString(jsonData);
    }
  }

  Future<void> onDeleteAll() async {
    appLogic.currentTour = Tour.empty();
    await appLogic.saveData();
    await appLogic.loadData();
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
    int index = appLogic.currentState.allTourNames.indexOf(oldName);
    appLogic.currentState.allTourNames[index] = newName;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(newName, prefs.getString(oldName)!);
    await prefs.setString(oldName, ''); // delete the old tour json data

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
