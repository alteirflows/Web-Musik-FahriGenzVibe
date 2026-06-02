import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FahriGenzVibe',
      theme: ThemeData.dark(),
      home: const SearchPage(),
    );
  }
}

class Song {
  final String title;
  final String artist;
  final String previewUrl;
  final String artwork;

  Song({required this.title, required this.artist, required this.previewUrl, required this.artwork});

  factory Song.fromItunes(Map<String, dynamic> j) {
    return Song(
      title: j['trackName'] ?? 'Unknown',
      artist: j['artistName'] ?? 'Unknown',
      previewUrl: j['previewUrl'] ?? '',
      artwork: j['artworkUrl100'] ?? '',
    );
  }

  factory Song.fromJamendo(Map<String, dynamic> j) {
    return Song(
      title: j['name'] ?? j['title'] ?? 'Unknown',
      artist: j['artist_name'] ?? j['artist'] ?? 'Unknown',
      previewUrl: j['audio'] ?? j['audioUrl'] ?? '',
      artwork: j['image'] ?? j['cover_url'] ?? '',
    );
  }

  String get artworkOrPlaceholder {
    if (artwork.isNotEmpty) return artwork;
    return _svgDataUriPlaceholder(title, artist, size: 200);
  }
}

String _svgDataUriPlaceholder(String title, String artist, {int size = 100}) {
  final bg = '#121212';
  final fg = '#24ff8a';
  final shortTitle = title.length > 24 ? title.substring(0, 22) + '…' : title;
  final shortArtist = artist.length > 24 ? artist.substring(0, 22) + '…' : artist;
  final svg = '''<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="$size"><rect width="100%" height="100%" fill="$bg"/><text x="50%" y="45%" font-family="Arial, Helvetica, sans-serif" font-size="18" fill="$fg" text-anchor="middle" dominant-baseline="middle">${_escapeXml(shortTitle)}</text><text x="50%" y="75%" font-family="Arial, Helvetica, sans-serif" font-size="12" fill="#bfc9d8" text-anchor="middle" dominant-baseline="middle">${_escapeXml(shortArtist)}</text></svg>''';
  return 'data:image/svg+xml;utf8,' + Uri.encodeComponent(svg);
}

String _escapeXml(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#039;');

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _ctrl = TextEditingController();
  List<Song> results = [];
  bool loading = false;
  final AudioPlayer _player = AudioPlayer();
  String? playingUrl;
  int _currentIndex = 0; // 0 = search, 1 = favorites
  List<Song> favorites = [];
  List<Map<String, dynamic>> playlists = [];
  final String serverBase = 'http://10.0.2.2:8000'; // emulator local host
  String username = 'default';

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadUsername().then((_) => fetchPlaylists());
  }

  void _showUsernameDialog() async {
    final ctrl = TextEditingController(text: username == 'default' ? '' : username);
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Masukkan username'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Username')), 
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')), TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Simpan'))],
    ));
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await _saveUsername(ctrl.text.trim());
      await fetchPlaylists();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username disimpan')));
    }
  }

  Future<void> _loadUsername() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      username = sp.getString('username_v1') ?? 'default';
    });
  }

  Future<void> _saveUsername(String u) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('username_v1', u);
    setState(() => username = u);
  }

  Future<void> _loadFavorites() async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList('favorites_v1') ?? [];
    setState(() {
      favorites = list.map((s) {
        final m = json.decode(s) as Map<String, dynamic>;
        return Song(title: m['title'] ?? '', artist: m['artist'] ?? '', previewUrl: m['previewUrl'] ?? '', artwork: m['artwork'] ?? '');
      }).toList();
    });
  }

  Future<void> _saveFavorites() async {
    final sp = await SharedPreferences.getInstance();
    final list = favorites.map((s) => json.encode({'title': s.title, 'artist': s.artist, 'previewUrl': s.previewUrl, 'artwork': s.artworkOrPlaceholder})).toList();
    await sp.setStringList('favorites_v1', list);
  }

  Future<void> fetchPlaylists() async {
    try {
      final uri = Uri.parse('$serverBase/api/playlists?user=${Uri.encodeComponent(username)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      final j = json.decode(res.body) as Map<String, dynamic>;
      setState(() {
        playlists = (j['playlists'] as List? ?? []).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      // ignore
    }
  }

  Future<void> createPlaylist(String name) async {
    final uri = Uri.parse('$serverBase/api/playlists?user=${Uri.encodeComponent(username)}');
    final body = json.encode({'name': name, 'tracks': []});
    try {
      await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body).timeout(const Duration(seconds: 8));
      await fetchPlaylists();
    } catch (e) {}
  }

  Future<void> addTrackToPlaylist(String playlistId, Song s) async {
    try {
      // fetch playlists, find target
      final uriGet = Uri.parse('$serverBase/api/playlists?user=${Uri.encodeComponent(username)}');
      final res = await http.get(uriGet).timeout(const Duration(seconds: 8));
      final j = json.decode(res.body) as Map<String, dynamic>;
      final pls = (j['playlists'] as List? ?? []).cast<Map<String, dynamic>>();
      for (var p in pls) {
        if (p['id'] == playlistId) {
          final tracks = (p['tracks'] as List? ?? []);
          tracks.add({'title': s.title, 'artist': s.artist, 'previewUrl': s.previewUrl, 'artwork': s.artworkOrPlaceholder});
          final uriPost = Uri.parse('$serverBase/api/playlists?user=${Uri.encodeComponent(username)}');
          await http.post(uriPost, headers: {'Content-Type': 'application/json'}, body: json.encode({'id': p['id'], 'name': p['name'], 'tracks': tracks})).timeout(const Duration(seconds: 8));
          await fetchPlaylists();
          return;
        }
      }
    } catch (e) {}
  }

  Future<void> deletePlaylist(String id) async {
    try {
      final uri = Uri.parse('$serverBase/api/playlists/$id?user=${Uri.encodeComponent(username)}');
      await http.delete(uri).timeout(const Duration(seconds: 8));
      await fetchPlaylists();
    } catch (e) {}
  }

  @override
  void dispose() {
    _player.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() {
      loading = true;
      results = [];
    });
    try {
      // Jamendo API - menyediakan musik gratis dengan audio URL penuh
      const jamendoClientId = 'd945bbd0';
      final uri = Uri.https('api.jamendo.com', '/v3.0/tracks/search', {
        'format': 'json',
        'limit': '50',
        'order': 'popularity_week',
        'client_id': jamendoClientId,
        'name': q
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final jsonBody = json.decode(res.body) as Map<String, dynamic>;
      final list = (jsonBody['results'] as List).map((e) => Song.fromJamendo(e)).where((s) => s.previewUrl.isNotEmpty).toList();
      setState(() {
        results = list.cast<Song>();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mencari: $e')));
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> playOrPause(Song s) async {
    if (playingUrl == s.previewUrl) {
      final playerState = await _player.state;
      if (playerState == PlayerState.playing) {
        await _player.pause();
      } else {
        await _player.resume();
      }
    } else {
      await _player.stop();
      await _player.play(UrlSource(s.previewUrl));
      setState(() => playingUrl = s.previewUrl);
    }
    setState(() {});
  }

  void toggleFavorite(Song s) {
    final exists = favorites.any((f) => f.previewUrl == s.previewUrl);
    setState(() {
      if (exists) favorites.removeWhere((f) => f.previewUrl == s.previewUrl);
      else favorites.insert(0, s);
    });
    _saveFavorites();
  }

  Widget _tile(Song s) {
    final isPlaying = playingUrl == s.previewUrl;
    final isFav = favorites.any((f) => f.previewUrl == s.previewUrl);
    return ListTile(
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey[900]),
        clipBehavior: Clip.hardEdge,
          child: Image.network(
          s.artworkOrPlaceholder,
          fit: BoxFit.cover,
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return Container(color: Colors.grey[800]);
          },
          errorBuilder: (_, __, ___) => const Icon(Icons.music_note, size: 32, color: Colors.white24),
        ),
      ),
      title: Text(s.title),
      subtitle: Text(s.artist),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.pink : null),
            onPressed: () => toggleFavorite(s),
          ),
          IconButton(
            icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
            onPressed: () => playOrPause(s),
          ),
        ],
      ),
      onTap: () => playOrPause(s),
      onLongPress: () => _showAddToPlaylistDialog(s),
    );
  }

  void _showAddToPlaylistDialog(Song s) {
    showDialog<void>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Tambah ke Playlist'),
        content: SizedBox(
          width: double.maxFinite,
          child: playlists.isEmpty
            ? const Text('Belum ada playlist. Buat playlist dulu.')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (_, i) {
                  final p = playlists[i];
                  return ListTile(
                    title: Text(p['name'] ?? 'Playlist'),
                    onTap: () async {
                      await addTrackToPlaylist(p['id'], s);
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ditambahkan ke playlist')));
                    },
                  );
                },
              ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
          TextButton(onPressed: () async {
            Navigator.of(ctx).pop();
            final nameCtrl = TextEditingController();
            final ok = await showDialog<bool>(context: context, builder: (c2) => AlertDialog(
              title: const Text('Buat Playlist Baru'),
              content: TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Nama playlist')),
              actions: [TextButton(onPressed: () => Navigator.of(c2).pop(false), child: const Text('Batal')), TextButton(onPressed: () => Navigator.of(c2).pop(true), child: const Text('Buat'))],
            ));
            if (ok == true && nameCtrl.text.trim().isNotEmpty) {
              await createPlaylist(nameCtrl.text.trim());
              await addTrackToPlaylist(playlists.isNotEmpty ? playlists.first['id'] : '', s);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Playlist dibuat dan lagu ditambahkan')));
            }
          }, child: const Text('Buat Baru')),
        ],
      );
    });
  }

  Widget _buildPlaylists() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text('Daftar Playlist', style: Theme.of(context).textTheme.titleLarge)),
            IconButton(icon: const Icon(Icons.refresh), onPressed: fetchPlaylists),
            IconButton(icon: const Icon(Icons.add), onPressed: () async {
              final nameCtrl = TextEditingController();
              final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                title: const Text('Buat Playlist'),
                content: TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Nama playlist')),
                actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')), TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Buat'))],
              ));
              if (ok == true && nameCtrl.text.trim().isNotEmpty) {
                await createPlaylist(nameCtrl.text.trim());
                await fetchPlaylists();
              }
            }),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: playlists.isEmpty ? const Center(child: Text('Belum ada playlist.')) : ListView.separated(
            itemCount: playlists.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = playlists[i];
              return ListTile(
                title: Text(p['name'] ?? 'Playlist'),
                subtitle: Text('${(p['tracks'] as List? ?? []).length} lagu'),
                onTap: () async {
                  // show playlist detail
                  await showDialog(context: context, builder: (ctx) {
                    final tracks = (p['tracks'] as List? ?? []);
                    return AlertDialog(
                      title: Text(p['name'] ?? 'Playlist'),
                      content: SizedBox(width: double.maxFinite, child: tracks.isEmpty ? const Text('Kosong') : ListView.builder(
                        shrinkWrap: true,
                        itemCount: tracks.length,
                        itemBuilder: (_, j) {
                          final t = tracks[j] as Map<String, dynamic>;
                          final song = Song(title: t['title'] ?? '', artist: t['artist'] ?? '', previewUrl: t['previewUrl'] ?? '', artwork: t['artwork'] ?? '');
                          return ListTile(
                            leading: Image.network(song.artworkOrPlaceholder, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note)),
                            title: Text(song.title),
                            subtitle: Text(song.artist),
                            trailing: IconButton(icon: const Icon(Icons.play_arrow), onPressed: () { playOrPause(song); Navigator.of(ctx).pop(); }),
                          );
                        },
                      )),
                      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Tutup')), TextButton(onPressed: () async { Navigator.of(ctx).pop(); await deletePlaylist(p['id']); }, child: const Text('Hapus', style: TextStyle(color: Colors.red)))],
                    );
                  });
                  await fetchPlaylists();
                },
              );
            },
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FahriGenzVibe'), actions: [
        Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal:8.0), child: Text(username, style: const TextStyle(fontSize: 14)))),
        IconButton(icon: const Icon(Icons.person), onPressed: _showUsernameDialog),
      ]),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _currentIndex == 0
            ? Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          decoration: const InputDecoration(hintText: 'Cari lagu, contoh: nina'),
                          onSubmitted: search,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => search(_ctrl.text),
                        child: const Text('Cari'),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (loading)
                    SizedBox(
                      height: 240,
                      child: ListView.separated(
                        itemCount: 6,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, __) => Container(
                          height: 72,
                          decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [Container(width:56, height:56, color: Colors.grey[800]), const SizedBox(width:12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Container(height:14,color:Colors.grey[800]), const SizedBox(height:8), Container(height:12,color:Colors.grey[800])]))]),
                        ),
                      ),
                    ),
                  Expanded(
                    child: results.isEmpty
                        ? const Center(child: Text('Tidak ada hasil.'))
                        : ListView.separated(
                            itemCount: results.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) => _tile(results[i]),
                          ),
                  )
                ],
              )
            : _currentIndex == 1
                ? (favorites.isEmpty
                    ? const Center(child: Text('Belum ada favorit.'))
                    : ListView.separated(
                        itemCount: favorites.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) => _tile(favorites[i]),
                      ))
                : _buildPlaylists(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Cari'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorit'),
          BottomNavigationBarItem(icon: Icon(Icons.playlist_play), label: 'Playlist'),
        ],
      ),
    );
  }
}
