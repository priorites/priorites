import 'package:flutter/material.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/wasm.dart';

void main() {
  runApp(const DomainSqliteTestApp());
}

class DomainSqliteTestApp extends StatelessWidget {
  const DomainSqliteTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Domain SQLite Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff2563eb)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class SavedEntry {
  const SavedEntry({
    required this.id,
    required this.text,
    required this.createdAt,
  });

  final int id;
  final String text;
  final DateTime createdAt;
}

class LocalDatabase {
  LocalDatabase._(this._db);

  final CommonDatabase _db;

  static Future<LocalDatabase> open() async {
    final sqlite = await WasmSqlite3.loadFromUrlString('sqlite3.wasm');
    final fileSystem = await IndexedDbFileSystem.open(
      dbName: 'domain_sqlite_test_storage',
    );

    sqlite.registerVirtualFileSystem(fileSystem, makeDefault: true);
    final db = sqlite.open('/domain_sqlite_test.sqlite');

    db.execute('''
      CREATE TABLE IF NOT EXISTS entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');

    return LocalDatabase._(db);
  }

  void insertEntry(String text) {
    final statement = _db.prepare(
      'INSERT INTO entries (text, created_at) VALUES (?, ?)',
    );

    try {
      statement.execute([text, DateTime.now().toIso8601String()]);
    } finally {
      statement.dispose();
    }
  }

  List<SavedEntry> readEntries() {
    final rows = _db.select(
      'SELECT id, text, created_at FROM entries ORDER BY id DESC',
    );

    return [
      for (final row in rows)
        SavedEntry(
          id: row['id'] as int,
          text: row['text'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
    ];
  }

  void clearEntries() {
    _db.execute('DELETE FROM entries');
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  late final Future<LocalDatabase> _databaseFuture;
  LocalDatabase? _database;
  List<SavedEntry> _entries = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _databaseFuture = _loadDatabase();
  }

  Future<LocalDatabase> _loadDatabase() async {
    try {
      final database = await LocalDatabase.open();
      _database = database;
      _entries = database.readEntries();
      return database;
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _saveEntry() {
    final value = _controller.text.trim();
    final database = _database;

    if (value.isEmpty || database == null) {
      return;
    }

    database.insertEntry(value);
    setState(() {
      _entries = database.readEntries();
      _controller.clear();
    });
  }

  void _clearEntries() {
    final database = _database;

    if (database == null) {
      return;
    }

    database.clearEntries();
    setState(() {
      _entries = [];
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f5ef),
      appBar: AppBar(
        title: const Text('Domain SQLite Test'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Clear saved rows',
            onPressed: _entries.isEmpty ? null : _clearEntries,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: FutureBuilder<LocalDatabase>(
              future: _databaseFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _ErrorView(message: _error ?? '${snapshot.error}');
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Saved rows: ${_entries.length}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Save anything, reload the page, and the rows should still be here.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Test value',
                            ),
                            onSubmitted: (_) => _saveEntry(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _saveEntry,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: _entries.isEmpty
                          ? const _EmptyState()
                          : ListView.separated(
                              itemCount: _entries.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final entry = _entries[index];

                                return ListTile(
                                  tileColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  title: Text(entry.text),
                                  subtitle: Text(
                                    entry.createdAt.toLocal().toString(),
                                  ),
                                  leading: CircleAvatar(
                                    child: Text('${entry.id}'),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No saved rows yet.'),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SelectableText(
        'SQLite failed to open:\n$message',
        textAlign: TextAlign.center,
      ),
    );
  }
}
