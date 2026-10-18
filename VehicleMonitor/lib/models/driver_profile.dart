import 'package:flutter/material.dart';

class DriverProfile {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final String vehicleNumber;
  final String vehicleModel;
  final String assignedCorridor;
  final bool isDemo;

  const DriverProfile({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    required this.vehicleNumber,
    required this.vehicleModel,
    required this.assignedCorridor,
    this.isDemo = false,
  });

  static const DriverProfile demo = DriverProfile(
    id: 'drv-ceylon-049',
    name: 'Kamal Perera',
    email: 'kamal.tourmate@gmail.com',
    photoUrl: null,
    vehicleNumber: 'WP NC-4921',
    vehicleModel: 'Toyota HiAce KDH Luxury Van',
    assignedCorridor: 'Southern Coastal Tourist Corridor (E01 / Galle Rd)',
    isDemo: true,
  );
}

enum AlertSeverity {
  info,
  warning,
  critical,
}

class AlertItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final AlertSeverity severity;
  final IconData icon;
  bool isRead;

  AlertItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.severity,
    required this.icon,
    this.isRead = false,
  });
}
