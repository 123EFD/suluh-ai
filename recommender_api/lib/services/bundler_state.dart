import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import '../models/resource_item.dart'; // We will create this model next

class BundlerState extends ChangeNotifier {
  List<ResourceItem> currentBundle = [];
  bool isLoading = false;
  String errorMessage = "";

//when user click "build bundle" this func. will be called
  Future<void> fetchBundle(int minutes, String topic) async {
    isLoading = true;
    errorMessage = "";
    notifyListeners(); // Tells the UI to show the loading spinner

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/bundler/create"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"minutes_available": minutes, "topic": topic}),
      );

      if (response.statusCode ==200 ) {
        final List<dynamic> data = jsonDecode(response.body);
        currentBundle =  data.map((json) => ResourceItem.fromJson(json)).toList();
      } else {
        errorMessage = "Error: Failed to fetch bundle.";
      }
    } catch (e) {
      errorMessage = "Error: ${e.toString()}";
    }

    isLoading = false;
    notifyListeners(); // Tells the UI to hide the spinner and show the new cards
  }

  void addDirectFlashcards(List<ResourceItem> flashcards) {
    currentBundle = [...flashcards, ...currentBundle];
    errorMessage = "";
    notifyListeners();
  }

  void setDirectBundle(List<ResourceItem> items) {
    currentBundle = List.from(items);
    errorMessage = "";
    notifyListeners();
  }
}