import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexa Staff iOS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const EventsPage(),
    );
  }
}

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _events = [];

  Future<void> _loadEvents() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:4000';
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await http.get(Uri.parse('$baseUrl/events'));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as List<dynamic>;
        setState(() {
          _events = data.cast<Map<String, dynamic>>();
        });
      } else {
        setState(() {
          _error = 'HTTP ${resp.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton(
                  onPressed: _loading ? null : _loadEvents,
                  child: Text(_loading ? 'Loading...' : 'Load Events'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _error != null
                      ? Text(_error!, style: const TextStyle(color: Colors.red))
                      : Text('Loaded: ${_events.length}'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: _events.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final e = _events[index];
                  return ListTile(
                    title: Text(e['event_name']?.toString() ?? '(no name)'),
                    subtitle: Text(
                      [
                        e['client_name'],
                        e['city'],
                        e['state'],
                      ].whereType<String>().join(' • '),
                    ),
                    trailing: Text(e['headcount_total']?.toString() ?? ''),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
