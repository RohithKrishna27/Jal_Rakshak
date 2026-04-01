import 'package:flutter/material.dart';

/// Shared demo content for monitor / campaigns (single source of truth).
abstract final class WaterBodiesDemoData {
  static final List<Map<String, dynamic>> monitorSegments = [
    {
      'name': 'Ganga - Varanasi',
      'status': 'High Risk',
      'bod': 5.8,
      'trend': '+9% this month',
      'color': const Color(0xFFDC2626),
    },
    {
      'name': 'Yamuna - Delhi Stretch',
      'status': 'Critical',
      'bod': 8.2,
      'trend': '+14% this month',
      'color': const Color(0xFFB91C1C),
    },
    {
      'name': 'Narmada - Central Belt',
      'status': 'Stable',
      'bod': 2.4,
      'trend': '-3% this month',
      'color': const Color(0xFF15803D),
    },
    {
      'name': 'Godavari - Urban Segment',
      'status': 'Moderate',
      'bod': 3.1,
      'trend': '+4% this month',
      'color': const Color(0xFFD97706),
    },
  ];

  static final List<Map<String, dynamic>> campaigns = [
    {
      'id': 'cmp-01',
      'title': 'Weekend Lake Cleanup Drive',
      'place': 'Assi Ghat, Varanasi',
      'time': 'Sunday, 7:00 AM',
      'volunteers': 142,
    },
    {
      'id': 'cmp-02',
      'title': 'Canal Watch Volunteer Program',
      'place': 'Prayagraj Urban Canal',
      'time': 'Saturday, 8:30 AM',
      'volunteers': 89,
    },
    {
      'id': 'cmp-03',
      'title': 'Community Water Testing Camp',
      'place': 'Patna Riverfront',
      'time': 'Saturday, 10:00 AM',
      'volunteers': 56,
    },
  ];
}
