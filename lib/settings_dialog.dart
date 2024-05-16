import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:helloworld/data/app_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

class SettingsDialog extends StatelessWidget {
  final Future Function() loadFromPrefs;
  final Future Function() saveToPrefs;
  final AppData appData;

  const SettingsDialog({
    super.key,
    required this.loadFromPrefs,
    required this.saveToPrefs,
    required this.appData,
  });

  @override
  Widget build(BuildContext context) {
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
      await AppData.fromMap(allData).save();
      await loadFromPrefs();
    }
  }

  Future<void> onExport() async {
    final allData = appData.toMap();
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
    final prefs = await SharedPreferences.getInstance();

    await prefs.clear();
    await loadFromPrefs();
  }
}
