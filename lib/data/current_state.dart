import 'dart:convert';

import 'package:helloworld/data/tour.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrentState {
  List<String> allTourNames;
  String currentTourName;

  CurrentState(this.allTourNames, this.currentTourName);
  static CurrentState empty() =>
      CurrentState([Tour.DEFAULT_SAVE_NAME], Tour.DEFAULT_SAVE_NAME);

  Map<String, dynamic> toMap() => {
        'allTourNames': allTourNames,
        'currentTourName': currentTourName,
      };

  static CurrentState fromMap(Map<String, dynamic> data) => CurrentState(
        List<String>.from(data['allTourNames']),
        data['currentTourName'],
      );

  static Future<CurrentState> load() async {
    final prefs = await SharedPreferences.getInstance();

    final allData = prefs.getString('currentState');
    if (allData == null) {
      return CurrentState.empty();
    } else {
      return CurrentState.fromMap(jsonDecode(allData));
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('currentState', jsonEncode(toMap()));
  }
}
