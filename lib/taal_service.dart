  import 'dart:convert';
  import 'package:flutter/services.dart';

  class Taal {
    final String name;
    final List<String> matras;
    final int columns;
    final List<int> guuns;

    Taal({required this.name, required this.matras, required this.columns, required this.guuns});

    factory Taal.fromJson(Map<String, dynamic> json) {
      return Taal(
        name: json['name'],
        matras: List<String>.from(json['matras']),
        columns: json['columns'],
        guuns: List<int>.from(json['guuns']),
      );
    }
  }

  class TaalService {
    static Future<List<Taal>> loadTaals() async {
      String jsonString = await rootBundle.loadString('assets/json/taals.json');
      final Map<String, dynamic> data = json.decode(jsonString);
      return (data['taals'] as List).map((json) => Taal.fromJson(json)).toList();
    }
  }
