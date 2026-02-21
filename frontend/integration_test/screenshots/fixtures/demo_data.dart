/// Curated demo data for App Store / Play Store screenshots (Staff app).
///
/// All dates are relative to "now" so screenshots always look current.
library;

class StaffDemoData {
  StaffDemoData._();

  /// A demo user key (staff member ID) used in screenshots.
  static const String demoUserKey = 'staff_demo_001';
  static const String demoUserName = 'Maria Garcia';

  // ── Events (shifts available/accepted) ─────────────────────────────
  static List<Map<String, dynamic>> get events {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final nextWeek = now.add(const Duration(days: 7));

    return [
      {
        '_id': 'evt_001',
        'title': 'Annual Gala Dinner',
        'venueName': 'The Ritz-Carlton Ballroom',
        'venueAddress': '1150 22nd St NW, Washington, DC 20037',
        'lat': 38.9048,
        'lng': -77.0487,
        'date': tomorrow.toIso8601String(),
        'callTime': '${tomorrow.year}-${_pad(tomorrow.month)}-${_pad(tomorrow.day)}T16:00:00.000Z',
        'endTime': '${tomorrow.year}-${_pad(tomorrow.month)}-${_pad(tomorrow.day)}T23:30:00.000Z',
        'status': 'posted',
        'roles': [
          {'role': 'Bartender', 'count': 4, 'filled': 2},
          {'role': 'Server', 'count': 6, 'filled': 4},
          {'role': 'Event Coordinator', 'count': 2, 'filled': 1},
        ],
        'acceptedStaff': [
          {'_id': demoUserKey, 'name': demoUserName, 'role': 'Bartender', 'status': 'accepted'},
          {'_id': 'staff_002', 'name': 'James Thompson', 'role': 'Server', 'status': 'accepted'},
          {'_id': 'staff_003', 'name': 'Sofia Rodriguez', 'role': 'Event Coordinator', 'status': 'accepted'},
        ],
        'compensation': {'type': 'hourly', 'rate': 28.00},
        'notes': 'Black-tie event. All staff must arrive in formal attire.',
        'client': 'Grand Ballroom Events',
      },
      {
        '_id': 'evt_002',
        'title': 'Tech Conference Reception',
        'venueName': 'Marriott Grand Salon',
        'venueAddress': '901 Massachusetts Ave NW, Washington, DC 20001',
        'lat': 38.9018,
        'lng': -77.0234,
        'date': nextWeek.toIso8601String(),
        'callTime': '${nextWeek.year}-${_pad(nextWeek.month)}-${_pad(nextWeek.day)}T10:00:00.000Z',
        'endTime': '${nextWeek.year}-${_pad(nextWeek.month)}-${_pad(nextWeek.day)}T18:00:00.000Z',
        'status': 'posted',
        'roles': [
          {'role': 'Server', 'count': 4, 'filled': 1},
          {'role': 'Bartender', 'count': 2, 'filled': 0},
          {'role': 'Runner', 'count': 2, 'filled': 1},
        ],
        'acceptedStaff': [],
        'compensation': {'type': 'hourly', 'rate': 25.00},
        'notes': 'Tech conference with 500+ attendees. Cocktail service.',
        'client': 'Marriott Downtown',
      },
      {
        '_id': 'evt_003',
        'title': 'Wedding: Johnson & Lee',
        'venueName': 'Dumbarton House Gardens',
        'venueAddress': '2715 Q St NW, Washington, DC 20007',
        'lat': 38.9115,
        'lng': -77.0632,
        'date': now.add(const Duration(days: 3)).toIso8601String(),
        'callTime': now.add(const Duration(days: 3)).toIso8601String(),
        'endTime': now.add(const Duration(days: 3, hours: 8)).toIso8601String(),
        'status': 'posted',
        'roles': [
          {'role': 'Server', 'count': 8, 'filled': 3},
          {'role': 'Bartender', 'count': 3, 'filled': 1},
        ],
        'acceptedStaff': [
          {'_id': demoUserKey, 'name': demoUserName, 'role': 'Server', 'status': 'accepted'},
        ],
        'compensation': {'type': 'hourly', 'rate': 30.00},
        'notes': 'Outdoor wedding ceremony + indoor reception.',
        'client': 'Elegant Affairs Co',
      },
      {
        '_id': 'evt_004',
        'title': 'Corporate Luncheon',
        'venueName': 'Four Seasons Terrace',
        'venueAddress': '2800 Pennsylvania Ave NW, Washington, DC 20007',
        'lat': 38.9068,
        'lng': -77.0576,
        'date': now.add(const Duration(days: 5)).toIso8601String(),
        'callTime': now.add(const Duration(days: 5)).toIso8601String(),
        'endTime': now.add(const Duration(days: 5, hours: 4)).toIso8601String(),
        'status': 'posted',
        'roles': [
          {'role': 'Server', 'count': 4, 'filled': 4},
          {'role': 'Bartender', 'count': 2, 'filled': 2},
        ],
        'acceptedStaff': [],
        'compensation': {'type': 'hourly', 'rate': 22.00},
        'client': 'Capital Catering Group',
      },
      {
        '_id': 'evt_005',
        'title': 'Charity Fundraiser Gala',
        'venueName': 'National Building Museum',
        'venueAddress': '401 F St NW, Washington, DC 20001',
        'lat': 38.8983,
        'lng': -77.0161,
        'date': now.add(const Duration(days: 10)).toIso8601String(),
        'callTime': now.add(const Duration(days: 10)).toIso8601String(),
        'endTime': now.add(const Duration(days: 10, hours: 6)).toIso8601String(),
        'status': 'posted',
        'roles': [
          {'role': 'Server', 'count': 10, 'filled': 5},
          {'role': 'Bartender', 'count': 5, 'filled': 2},
          {'role': 'Event Coordinator', 'count': 3, 'filled': 1},
        ],
        'acceptedStaff': [],
        'compensation': {'type': 'hourly', 'rate': 32.00},
        'client': 'National Arts Foundation',
      },
    ];
  }

  // ── Availability ───────────────────────────────────────────────────
  static List<Map<String, dynamic>> get availability {
    final now = DateTime.now();
    return List.generate(14, (i) {
      final date = now.add(Duration(days: i));
      return {
        'date': date.toIso8601String().split('T')[0],
        'available': i % 3 != 0, // available most days
        'note': i == 2 ? 'Doctor appointment in morning' : null,
      };
    });
  }

  // ── Conversations ──────────────────────────────────────────────────
  static List<Map<String, dynamic>> get conversations => [
        {
          '_id': 'conv_001',
          'name': 'Annual Gala Team',
          'eventId': 'evt_001',
          'lastMessage': 'Uniform update: black vest required',
          'lastMessageTime': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
          'unreadCount': 2,
          'participants': 8,
        },
        {
          '_id': 'conv_002',
          'name': 'Wedding Staff Chat',
          'eventId': 'evt_003',
          'lastMessage': 'Menu finalized — see attached PDF',
          'lastMessageTime': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          'unreadCount': 0,
          'participants': 12,
        },
        {
          '_id': 'conv_003',
          'name': 'All Staff Announcements',
          'lastMessage': 'Holiday schedule posted for December',
          'lastMessageTime': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          'unreadCount': 0,
          'participants': 45,
        },
      ];

  // ── AI Chat Messages (Valerio) ─────────────────────────────────────
  static List<Map<String, dynamic>> get aiChatMessages => [
        {
          'role': 'user',
          'content': 'What shifts do I have coming up this week?',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        },
        {
          'role': 'assistant',
          'content':
              'You have **2 upcoming shifts** this week:\n\n'
              '1. **Annual Gala Dinner** — tomorrow at The Ritz-Carlton, 4 PM - 11:30 PM (Bartender, \$28/hr)\n'
              '2. **Wedding: Johnson & Lee** — in 3 days at Dumbarton House, all day (Server, \$30/hr)\n\n'
              'Your estimated earnings for the week: **\$434**. Would you like to see available shifts to pick up more hours?',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 4)).toIso8601String(),
        },
        {
          'role': 'user',
          'content': 'Yes, show me open bartender shifts.',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 3)).toIso8601String(),
        },
        {
          'role': 'assistant',
          'content':
              'Here are **3 open bartender positions** this week:\n\n'
              '1. **Tech Conference** — next week, Marriott Grand Salon (2 spots, \$25/hr)\n'
              '2. **Charity Fundraiser Gala** — in 10 days, National Building Museum (5 spots, \$32/hr)\n\n'
              'Would you like me to request to join any of these?',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String(),
        },
      ];

  // ── Earnings Data ──────────────────────────────────────────────────
  static Map<String, dynamic> get earningsData => {
        'thisWeek': 434.00,
        'lastWeek': 612.00,
        'thisMonth': 2847.50,
        'lastMonth': 3156.00,
        'ytd': 28450.00,
        'pendingPayments': 434.00,
      };

  // ── Helpers ─────────────────────────────────────────────────────────
  static String _pad(int n) => n.toString().padLeft(2, '0');
}
