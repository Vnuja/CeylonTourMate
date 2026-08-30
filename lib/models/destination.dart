import 'package:flutter/material.dart';

class Destination {
  final String name;
  final String description;
  final String category;
  final List<String> tags;
  final IconData icon;

  const Destination({
    required this.name,
    required this.description,
    required this.category,
    required this.tags,
    required this.icon,
  });
}