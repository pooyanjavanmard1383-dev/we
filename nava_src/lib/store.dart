import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'themes.dart';

class Song {
  final String path;
  final String title;
  final String artist;
  final int added;
  Song(this.path, this.title, this.artist, this.added);

  factory Song.fromPath(String path) {
    final name = p.basenameWithoutExtension(path).replaceAll('_', ' ').trim();
    String artist = 'ناشناس';
    String title = name;
    final i = name.indexOf(' - ');
    if (i > 0) {
      artist = name.substring(0, i).trim();
      title = name.substring(i + 3).trim();
    }
    int added = 0;
    try {
      added = File(path).lastModifiedSync().millisecondsSinceEpoch;
    } catch (_) {}
    return Song(path, title.isEmpty ? name : title, artist, added);
  }
}

class LyricLine {
  final Duration t;
  final String text;
  LyricLine(this.t, this.text);
}

Future<List<LyricLine>> loadLrc(String audioPath) async {
  try {
    final f = File(p.setExtension(audioPath, '.lrc'));
    if (!await f.exists()) return [];
    final out = <LyricLine>[];
    final re = RegExp(r'\[(\d+):(\d+(?:\.\d+)?)\]');
    for (final line in await f.readAsLines()) {
      final ms = re.allMatches(line).toList();
      if (ms.isEmpty) continue;
      final text = line.replaceAll(re, '').trim();
      for (final m in ms) {
        final mm = int.parse(m.group(1)!);
        final ss = double.parse(m.group(2)!);
        out.add(LyricLine(Duration(milliseconds: (mm * 60000 + ss * 1000).round()), text));
      }
    }
    out.sort((a, b) => a.t.compareTo(b.t));
    return out;
  } catch (_) {
    return [];
  }
}

const Map<String, List<double>> eqPresets = {
  'عادی': [0, 0, 0, 0, 0],
  'بیس': [6, 4, 0, -1, -1],
  'ووکال': [-2, 0, 3, 3, 0],
  'تیز': [-1, 0, 1, 4, 6],
  'راک': [4, 2, -1, 2, 4],
  'پاپ': [-1, 2, 4, 2, -1],
};

class PlayerStore extends ChangeNotifier {
  late final AndroidEqualizer eq;
  late final AndroidLoudnessEnhancer loud;
  late final AudioPlayer player;
  SharedPreferences? prefs;

  final ValueNotifier<double> clock = ValueNotifier<double>(0);
  double spin = 0;
  double playAnim = 0;
  double progress = 0;

  List<Song> library = [];
  final Set<String> _paths = {};
  List<Song> queue = [];
  int index = 0;
  Set<String> favs = {};

  String themeId = 'neon';
  bool autoTheme = false;
  bool vizOn = true;
  bool lite = false;
  bool haptics = true;
  bool fadeSleep = true;
  bool showLyrics = true;
  String sort = 'name';

  bool shuffle = false;
  LoopMode loop = LoopMode.off;
  double speed = 1.0;
  Duration? abA;
  Duration? abB;
  int? sleepLeft;
  Timer? _sleepTimer;
  bool eqOn = true;
  double loudGain = 0;
  List<LyricLine> lyrics = [];
  bool playing = false;
  bool ready = false;
  bool scanning = false;
  String? message;

  Song? get current => (index >= 0 && index < queue.length) ? queue[index] : null;

  String get activeThemeId {
    final c = current;
    if (autoTheme && c != null) return themes[hashStr(c.title) % themes.length].id;
    return themeId;
  }

  Scene scene() {
    final th = themeById(activeThemeId);
    final c = current;
    final seed = c == null ? 7 : hashStr(c.title);
    final e = vizOn ? fakeEnergy(clock.value, playing, seed) : 0.1;
    return Scene(
      id: th.id,
      t: clock.value,
      energy: e,
      progress: progress,
      pa: playAnim,
      spin: spin,
      seed: seed,
      a: th.a,
      b: th.b,
      bg: th.bg,
      lite: lite,
    );
  }

  Future<void> init() async {
    eq = AndroidEqualizer();
    loud = AndroidLoudnessEnhancer();
    player = AudioPlayer(audioPipeline: AudioPipeline(androidAudioEffects: [loud, eq]));
    prefs = await SharedPreferences.getInstance();
    _load();
    player.playerStateStream.listen((s) {
      playing = s.playing;
      notifyListeners();
    });
    player.currentIndexStream.listen((i) {
      if (i != null) index = i;
      _onSongChanged();
    });
    player.positionStream.listen(_onPos);
    ready = true;
    notifyListeners();
  }

  void _load() {
    final pr = prefs!;
    themeId = pr.getString('theme') ?? 'neon';
    autoTheme = pr.getBool('auto') ?? false;
    vizOn = pr.getBool('viz') ?? true;
    lite = pr.getBool('lite') ?? false;
    haptics = pr.getBool('hap') ?? true;
    fadeSleep = pr.getBool('fade') ?? true;
    showLyrics = pr.getBool('lyr') ?? true;
    sort = pr.getString('sort') ?? 'name';
    favs = (pr.getStringList('favs') ?? <String>[]).toSet();
    for (final x in pr.getStringList('lib') ?? <String>[]) {
      if (File(x).existsSync()) _addSong(x);
    }
  }

  void _save() {
    final pr = prefs;
    if (pr == null) return;
    pr.setString('theme', themeId);
    pr.setBool('auto', autoTheme);
    pr.setBool('viz', vizOn);
    pr.setBool('lite', lite);
    pr.setBool('hap', haptics);
    pr.setBool('fade', fadeSleep);
    pr.setBool('lyr', showLyrics);
    pr.setString('sort', sort);
    pr.setStringList('favs', favs.toList());
  }

  void _saveLib() {
    prefs?.setStringList('lib', library.map((s) => s.path).toList());
  }

  void upd(void Function() f) {
    f();
    _save();
    notifyListeners();
  }

  void tap() {
    if (haptics) HapticFeedback.selectionClick();
  }

  void _onPos(Duration pos) {
    final d = player.duration;
    if (d != null && d.inMilliseconds > 0) {
      progress = cl(pos.inMilliseconds / d.inMilliseconds);
    } else {
      progress = 0;
    }
    final b = abB;
    if (b != null && pos >= b) {
      player.seek(abA ?? Duration.zero);
    }
  }

  Future<void> _onSongChanged() async {
    final c = current;
    if (c == null) {
      lyrics = [];
    } else {
      lyrics = await loadLrc(c.path);
    }
    abA = null;
    abB = null;
    notifyListeners();
  }

  bool _isAudio(String path) {
    const ex = {'.mp3', '.m4a', '.aac', '.flac', '.wav', '.ogg', '.opus'};
    return ex.contains(p.extension(path).toLowerCase());
  }

  bool _addSong(String path) {
    if (_paths.contains(path)) return false;
    _paths.add(path);
    library.add(Song.fromPath(path));
    return true;
  }

  Future<bool> _perm() async {
    final a = await Permission.audio.request();
    if (a.isGranted) return true;
    final s = await Permission.storage.request();
    return s.isGranted;
  }

  Future<int> _scanDir(String dir) async {
    int n = 0;
    try {
      final d = Directory(dir);
      if (!await d.exists()) return 0;
      await for (final e in d.list(recursive: true, followLinks: false)) {
        if (e is File && _isAudio(e.path)) {
          int len = 0;
          try {
            len = await e.length();
          } catch (_) {}
          if (len >= 200 * 1024 && _addSong(e.path)) n++;
        }
      }
    } catch (_) {}
    return n;
  }

  Future<int> scanDefault() async {
    scanning = true;
    notifyListeners();
    int n = 0;
    if (await _perm()) {
      for (final d in ['/storage/emulated/0/Music', '/storage/emulated/0/Download', '/storage/emulated/0/Telegram', '/storage/emulated/0/Audiobooks']) {
        n += await _scanDir(d);
      }
      _saveLib();
      message = n > 0 ? '$n آهنگ جدید پیدا شد' : 'آهنگ جدیدی پیدا نشد';
    } else {
      message = 'دسترسی به موزیک‌ها داده نشد';
    }
    scanning = false;
    notifyListeners();
    return n;
  }

  Future<void> addFolder() async {
    if (!await _perm()) {
      message = 'دسترسی به موزیک‌ها داده نشد';
      notifyListeners();
      return;
    }
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;
    scanning = true;
    notifyListeners();
    final n = await _scanDir(dir);
    _saveLib();
    message = n > 0 ? '$n آهنگ اضافه شد' : 'آهنگی در این پوشه پیدا نشد';
    scanning = false;
    notifyListeners();
  }

  Future<void> addFiles() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
    if (r == null) return;
    int n = 0;
    for (final f in r.files) {
      final path = f.path;
      if (path != null && _addSong(path)) n++;
    }
    _saveLib();
    message = '$n آهنگ اضافه شد';
    notifyListeners();
  }

  void clearLibrary() {
    library.clear();
    _paths.clear();
    _saveLib();
    notifyListeners();
  }

  List<Song> view(String q) {
    var l = library.where((s) {
      if (q.isEmpty) return true;
      final x = q.toLowerCase();
      return s.title.toLowerCase().contains(x) || s.artist.toLowerCase().contains(x);
    }).toList();
    if (sort == 'artist') {
      l.sort((a, b) => a.artist.compareTo(b.artist));
    } else if (sort == 'new') {
      l.sort((a, b) => b.added.compareTo(a.added));
    } else {
      l.sort((a, b) => a.title.compareTo(b.title));
    }
    return l;
  }

  AudioSource _src(Song s) {
    return AudioSource.uri(Uri.file(s.path), tag: MediaItem(id: s.path, title: s.title, artist: s.artist));
  }

  Future<void> playList(List<Song> list, int start, {bool shuf = false}) async {
    if (list.isEmpty) return;
    tap();
    Permission.notification.request();
    queue = List<Song>.of(list);
    index = start;
    try {
      await player.setAudioSource(
        ConcatenatingAudioSource(children: queue.map(_src).toList()),
        initialIndex: start,
        initialPosition: Duration.zero,
      );
      if (shuf) {
        shuffle = true;
        await player.setShuffleModeEnabled(true);
        await player.shuffle();
      } else {
        await player.setShuffleModeEnabled(shuffle);
      }
      player.play();
    } catch (e) {
      message = 'خطا در پخش آهنگ';
    }
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    tap();
    shuffle = !shuffle;
    await player.setShuffleModeEnabled(shuffle);
    if (shuffle) await player.shuffle();
    notifyListeners();
  }

  Future<void> cycleLoop() async {
    tap();
    if (loop == LoopMode.off) {
      loop = LoopMode.all;
    } else if (loop == LoopMode.all) {
      loop = LoopMode.one;
    } else {
      loop = LoopMode.off;
    }
    await player.setLoopMode(loop);
    notifyListeners();
  }

  void togglePlay() {
    tap();
    if (player.playing) {
      player.pause();
    } else {
      player.play();
    }
  }

  void next() {
    tap();
    player.seekToNext();
  }

  void prev() {
    tap();
    if (player.position.inSeconds > 3) {
      player.seek(Duration.zero);
    } else {
      player.seekToPrevious();
    }
  }

  void seekTo(int i) {
    tap();
    player.seek(Duration.zero, index: i);
    player.play();
  }

  bool isFav(Song s) => favs.contains(s.path);

  void toggleFav(Song s) {
    tap();
    if (!favs.remove(s.path)) favs.add(s.path);
    _save();
    notifyListeners();
  }

  Future<void> setSpeed(double v) async {
    speed = v;
    await player.setSpeed(v);
    notifyListeners();
  }

  void cycleAB() {
    tap();
    if (abA == null) {
      abA = player.position;
    } else if (abB == null) {
      if (player.position > abA!) abB = player.position;
    } else {
      abA = null;
      abB = null;
    }
    notifyListeners();
  }

  void setSleep(int? minutes) {
    _sleepTimer?.cancel();
    player.setVolume(1);
    if (minutes == null) {
      sleepLeft = null;
      notifyListeners();
      return;
    }
    sleepLeft = minutes * 60;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = (sleepLeft ?? 0) - 1;
      sleepLeft = left;
      if (fadeSleep && left <= 20 && left > 0) player.setVolume(left / 20);
      if (left <= 0) {
        t.cancel();
        player.pause();
        player.setVolume(1);
        sleepLeft = null;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> setEq(bool v) async {
    eqOn = v;
    try {
      await eq.setEnabled(v);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setLoud(double v) async {
    loudGain = v;
    try {
      await loud.setEnabled(v > 0);
      await loud.setTargetGain(v);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> applyPreset(AndroidEqualizerParameters params, String name) async {
    final g = eqPresets[name] ?? eqPresets['عادی']!;
    final n = params.bands.length;
    for (int i = 0; i < n; i++) {
      final idx = n == 1 ? 0 : (i * (g.length - 1) / (n - 1)).round();
      final v = cl(g[idx], params.minDecibels, params.maxDecibels);
      await params.bands[i].setGain(v);
    }
    notifyListeners();
  }

  String? takeMessage() {
    final m = message;
    message = null;
    return m;
  }
}

final PlayerStore store = PlayerStore();
