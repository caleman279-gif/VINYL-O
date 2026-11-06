
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const VinylO());
}

class VinylO extends StatelessWidget {
  const VinylO({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VINYL-O',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF101010),
        colorScheme: const ColorScheme.dark(
          primary: Colors.redAccent,
        ),
      ),
      home: const CollectionPage(),
    );
  }
}

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  final String username = 'Charlie_LP';
  List<Map<String, dynamic>> records = [];
  bool loading = false;
  String message = 'Tus vinilos aparecerán aquí.';
  int imported = 0;

  @override
  void initState() {
    super.initState();
    loadSavedRecords();
  }

  Future<void> loadSavedRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('vinyl_collection');
    if (saved != null) {
      final decoded = jsonDecode(saved) as List;
      setState(() {
        records = decoded
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    }
  }

  Future<void> saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vinyl_collection', jsonEncode(records));
  }

  Future<void> importDiscogs() async {
    if (loading) return;

    setState(() {
      loading = true;
      imported = 0;
      message = 'Conectando con Discogs...';
    });

    try {
      final List<Map<String, dynamic>> newRecords = [];
      int page = 1;
      int totalPages = 1;

      do {
        final uri = Uri.https(
          'api.discogs.com',
          '/users/$username/collection/folders/0/releases',
          {
            'page': '$page',
            'per_page': '100',
            'sort': 'year',
            'sort_order': 'asc',
          },
        );

        final response = await http.get(
          uri,
          headers: {
            'User-Agent': 'VINYL-O/0.1 (vinyl collection app)',
            'Accept': 'application/vnd.discogs.v2.discogs+json',
          },
        );

        if (response.statusCode != 200) {
          throw Exception(
            'Discogs respondió con el código ${response.statusCode}. '
            'Comprueba que tu colección sea pública.',
          );
        }

        final data = jsonDecode(response.body);
        final pagination = data['pagination'];
        totalPages = pagination['pages'] ?? 1;
        final releases = data['releases'] as List? ?? [];

        for (final item in releases) {
          final basic = item['basic_information'] ?? {};
          final artists = basic['artists'] as List? ?? [];
          final labels = basic['labels'] as List? ?? [];

          newRecords.add({
            'instanceId': item['id']?.toString() ?? '',
            'releaseId': basic['id']?.toString() ?? '',
            'title': basic['title'] ?? 'Título desconocido',
            'artist': artists
                .map((a) => a['name'] ?? '')
                .join(', '),
            'year': basic['year']?.toString() ?? '',
            'label': labels.isNotEmpty
                ? labels.first['name'] ?? ''
                : '',
            'cover': basic['cover_image'] ??
                basic['thumb'] ??
                '',
          });
        }

        setState(() {
          imported = newRecords.length;
          message = 'Importando página $page de $totalPages...';
        });

        page++;
      } while (page <= totalPages);

      records = newRecords;
      await saveRecords();

      setState(() {
        message = 'Importación terminada: ${records.length} vinilos.';
      });
    } catch (e) {
      setState(() {
        message = 'No se pudo importar: $e';
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'VINYL-O',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            'MI COLECCIÓN',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text('Discogs: $username'),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: loading ? null : importDiscogs,
                icon: const Icon(Icons.sync),
                label: Text(
                  loading ? 'IMPORTANDO...' : 'IMPORTAR DESDE DISCOGS',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(15),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              message,
              textAlign: TextAlign.center,
            ),
          ),
          if (loading)
            Padding(
              padding: const EdgeInsets.all(12),
              child: LinearProgressIndicator(
                value: null,
                color: Colors.redAccent,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '${records.length} VINILOS GUARDADOS',
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: records.isEmpty
                ? const Center(
                    child: Text('Todavía no hay vinilos importados.'),
                  )
                : ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final record = records[index];
                      final cover = record['cover']?.toString() ?? '';

                      return Card(
                        color: const Color(0xFF202020),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: SizedBox(
                            width: 55,
                            height: 55,
                            child: cover.isEmpty
                                ? const Icon(Icons.album, size: 40)
                                : Image.network(
                                    cover,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.album, size: 40),
                                  ),
                          ),
                          title: Text(
                            record['title'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${record['artist'] ?? ''} · '
                            '${record['year'] ?? ''}',
                          ),
                          trailing: const Icon(
                            Icons.album,
                            color: Colors.redAccent,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
