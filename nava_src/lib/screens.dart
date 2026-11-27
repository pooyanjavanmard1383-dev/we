import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_audio/just_audio.dart';
import 'store.dart';
import 'themes.dart';

String fmt(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

void showSheet(BuildContext c, WidgetBuilder b) {
  showModalBottomSheet(
    context: c,
    backgroundColor: const Color(0xFF14141C),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: b,
  );
}

Widget sheetTitle(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    );

class NavaRoot extends StatefulWidget {
  const NavaRoot({super.key});
  @override
  State<NavaRoot> createState() => _NavaRootState();
}

class _NavaRootState extends State<NavaRoot> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) {
      final dt = (d - _last).inMicroseconds / 1e6;
      _last = d;
      store.spin += dt * 2.0 * store.playAnim * store.speed;
      store.playAnim += ((store.playing ? 1.0 : 0.0) - store.playAnim) * cl(dt * 6);
      store.clock.value = d.inMicroseconds / 1e6;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final th = themeById(store.activeThemeId);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'نوا',
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(seedColor: th.a, brightness: Brightness.dark),
            scaffoldBackgroundColor: th.bg.last,
          ),
          builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
          home: const HomePage(),
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final m = store.takeMessage();
        if (m != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
          });
        }
        final th = themeById(store.activeThemeId);
        return Container(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: th.bg)),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: IndexedStack(
                      index: tab,
                      children: const [LibraryTab(fav: false), LibraryTab(fav: true), ThemesTab(), SettingsTab()],
                    ),
                  ),
                  if (store.current != null) const MiniPlayer(),
                ],
              ),
            ),
            bottomNavigationBar: NavigationBar(
              backgroundColor: Colors.black.withOpacity(0.35),
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music), label: 'آهنگ‌ها'),
                NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'مورد علاقه'),
                NavigationDestination(icon: Icon(Icons.palette_outlined), selectedIcon: Icon(Icons.palette), label: 'تم‌ها'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'تنظیمات'),
              ],
            ),
          ),
        );
      },
    );
  }
}

void openNowPlaying(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => const NowPlayingPage(),
      transitionsBuilder: (_, a, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}

class LibraryTab extends StatefulWidget {
  final bool fav;
  const LibraryTab({super.key, required this.fav});
  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        var list = store.view(q);
        if (widget.fav) list = list.where((s) => store.isFav(s)).toList();
        final cur = store.current;
        final th = themeById(store.activeThemeId);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(child: Text(widget.fav ? 'مورد علاقه' : 'کتابخانه', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
                  if (list.isNotEmpty)
                    IconButton(
                      tooltip: 'پخش تصادفی',
                      onPressed: () => store.playList(list, Random().nextInt(list.length), shuf: true),
                      icon: Icon(Icons.shuffle, color: th.a),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.sort),
                    onSelected: (v) => store.upd(() => store.sort = v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'name', child: Text('نام آهنگ')),
                      PopupMenuItem(value: 'artist', child: Text('خواننده')),
                      PopupMenuItem(value: 'new', child: Text('تازه‌ترین')),
                    ],
                  ),
                  if (!widget.fav)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.add_circle_outline),
                      onSelected: (v) {
                        if (v == 'scan') {
                          store.scanDefault();
                        } else if (v == 'files') {
                          store.addFiles();
                        } else {
                          store.addFolder();
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'scan', child: Text('اسکن موزیک گوشی')),
                        PopupMenuItem(value: 'folder', child: Text('افزودن پوشه')),
                        PopupMenuItem(value: 'files', child: Text('افزودن فایل')),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => q = v),
                decoration: InputDecoration(
                  hintText: 'جستجوی آهنگ یا خواننده',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.07),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ),
            if (store.scanning) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: list.isEmpty
                  ? _empty(context)
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (c, i) {
                        final s = list[i];
                        final on = cur != null && cur.path == s.path;
                        return ListTile(
                          selected: on,
                          selectedColor: th.a,
                          leading: Cover(seed: hashStr(s.title), size: 46, active: on && store.playing),
                          title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: Icon(store.isFav(s) ? Icons.favorite : Icons.favorite_border, color: store.isFav(s) ? th.b : null),
                            onPressed: () => store.toggleFav(s),
                          ),
                          onTap: () {
                            if (on) {
                              openNowPlaying(context);
                            } else {
                              store.playList(list, i);
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _empty(BuildContext context) {
    if (widget.fav) {
      return const Center(child: Text('هنوز آهنگی را دوست نداشته‌ای.\nروی قلب بزن یا در صفحه‌ی پخش دو بار روی تصویر بزن.', textAlign: TextAlign.center));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.library_music, size: 64),
            const SizedBox(height: 12),
            const Text('کتابخانه خالی است', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: store.scanDefault, icon: const Icon(Icons.search), label: const Text('اسکن موزیک گوشی')),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: store.addFolder, icon: const Icon(Icons.folder_open), label: const Text('افزودن پوشه')),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: store.addFiles, icon: const Icon(Icons.audio_file), label: const Text('افزودن فایل')),
          ],
        ),
      ),
    );
  }
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.current;
        if (s == null) return const SizedBox.shrink();
        final th = themeById(store.activeThemeId);
        return GestureDetector(
          onTap: () => openNowPlaying(context),
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: th.a.withOpacity(0.35)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 6, 4),
                  child: Row(
                    children: [
                      Cover(seed: hashStr(s.title), size: 42, active: store.playing),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white60)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: store.togglePlay, icon: Icon(store.playing ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 38, color: th.a)),
                      IconButton(onPressed: store.next, icon: const Icon(Icons.skip_next)),
                    ],
                  ),
                ),
                StreamBuilder<Duration>(
                  stream: store.player.positionStream,
                  builder: (c, snap) {
                    final d = store.player.duration;
                    final pos = snap.data ?? Duration.zero;
                    final v = (d == null || d.inMilliseconds == 0) ? 0.0 : cl(pos.inMilliseconds / d.inMilliseconds);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                      child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: v, minHeight: 3, color: th.a, backgroundColor: Colors.white12)),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final song = store.current;
        if (song == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          });
          return const Scaffold();
        }
        final th = themeById(store.activeThemeId);
        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: ValueListenableBuilder<double>(
                  valueListenable: store.clock,
                  builder: (c, _, __) => CustomPaint(painter: BackdropPainter(store.scene())),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.25), Colors.transparent, Colors.black.withOpacity(0.6)],
                      stops: const [0.0, 0.35, 1.0],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        children: [
                          IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.keyboard_arrow_down, size: 32)),
                          Expanded(
                            child: Column(
                              children: [
                                const Text('در حال پخش', style: TextStyle(fontWeight: FontWeight.w700)),
                                Text(th.name, style: TextStyle(fontSize: 12, color: th.a)),
                              ],
                            ),
                          ),
                          IconButton(onPressed: () => showSheet(context, (c) => const QueueSheet()), icon: const Icon(Icons.queue_music)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragEnd: (d) {
                          final v = d.primaryVelocity ?? 0;
                          if (v < -200) {
                            store.next();
                          } else if (v > 200) {
                            store.prev();
                          }
                        },
                        onDoubleTap: () => store.toggleFav(song),
                        child: Center(
                          child: LayoutBuilder(
                            builder: (c, box) {
                              final sz = min(box.maxWidth, box.maxHeight);
                              return SizedBox(
                                width: sz,
                                height: sz,
                                child: ValueListenableBuilder<double>(
                                  valueListenable: store.clock,
                                  builder: (c, _, __) => CustomPaint(painter: ArtPainter(store.scene())),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const LyricsView(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 4, 12, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                                Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: Colors.white70)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => store.toggleFav(song),
                            icon: Icon(store.isFav(song) ? Icons.favorite : Icons.favorite_border, color: store.isFav(song) ? th.b : Colors.white70, size: 28),
                          ),
                        ],
                      ),
                    ),
                    const SeekBar(),
                    const Controls(),
                    const ExtrasRow(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class LyricsView extends StatelessWidget {
  const LyricsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (!store.showLyrics || store.lyrics.isEmpty) return const SizedBox(height: 8);
        final th = themeById(store.activeThemeId);
        return StreamBuilder<Duration>(
          stream: store.player.positionStream,
          builder: (c, snap) {
            final pos = snap.data ?? Duration.zero;
            int cur = -1;
            for (int i = 0; i < store.lyrics.length; i++) {
              if (store.lyrics[i].t <= pos) {
                cur = i;
              } else {
                break;
              }
            }
            String line(int i) => (i >= 0 && i < store.lyrics.length) ? store.lyrics[i].text : '';
            const dim = TextStyle(fontSize: 13, color: Colors.white54);
            return SizedBox(
              height: 78,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(line(cur - 1), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: dim),
                  const SizedBox(height: 4),
                  Text(line(cur), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: th.a)),
                  const SizedBox(height: 4),
                  Text(line(cur + 1), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: dim),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class SeekBar extends StatefulWidget {
  const SeekBar({super.key});
  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? drag;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final th = themeById(store.activeThemeId);
        return StreamBuilder<Duration?>(
          stream: store.player.durationStream,
          builder: (c, ds) {
            final dur = ds.data ?? store.player.duration ?? Duration.zero;
            return StreamBuilder<Duration>(
              stream: store.player.positionStream,
              builder: (c, ps) {
                final pos = ps.data ?? Duration.zero;
                final mx = dur.inMilliseconds.toDouble();
                final raw = drag ?? pos.inMilliseconds.toDouble();
                final v = mx <= 0 ? 0.0 : cl(raw, 0.0, mx);
                final a = store.abA;
                final b = store.abB;
                return Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        activeTrackColor: th.a,
                        thumbColor: th.a,
                        inactiveTrackColor: Colors.white24,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: v,
                        min: 0,
                        max: mx <= 0 ? 1.0 : mx,
                        onChanged: mx <= 0 ? null : (x) => setState(() => drag = x),
                        onChangeEnd: (x) {
                          store.player.seek(Duration(milliseconds: x.round()));
                          setState(() => drag = null);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(fmt(Duration(milliseconds: raw.round())), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                          if (a != null)
                            Text('A ${fmt(a)}${b != null ? '  ←  B ${fmt(b)}' : ''}', style: TextStyle(fontSize: 12, color: th.b, fontWeight: FontWeight.w700)),
                          Text(fmt(dur), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class Controls extends StatelessWidget {
  const Controls({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final th = themeById(store.activeThemeId);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(onPressed: store.toggleShuffle, icon: Icon(Icons.shuffle, color: store.shuffle ? th.a : Colors.white60)),
              IconButton(onPressed: store.prev, iconSize: 38, icon: const Icon(Icons.skip_previous)),
              GestureDetector(
                onTap: store.togglePlay,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [th.a, th.b]),
                    boxShadow: [BoxShadow(color: th.a.withOpacity(0.5), blurRadius: 20)],
                  ),
                  child: Icon(store.playing ? Icons.pause : Icons.play_arrow, size: 42, color: Colors.white),
                ),
              ),
              IconButton(onPressed: store.next, iconSize: 38, icon: const Icon(Icons.skip_next)),
              IconButton(
                onPressed: store.cycleLoop,
                icon: Icon(store.loop == LoopMode.one ? Icons.repeat_one : Icons.repeat, color: store.loop == LoopMode.off ? Colors.white60 : th.a),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ExtrasRow extends StatelessWidget {
  const ExtrasRow({super.key});

  Widget _ex(IconData icon, String label, VoidCallback onTap, {bool active = false, Color? color}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: active ? color : Colors.white70),
              const SizedBox(height: 2),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: active ? color : Colors.white60)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final th = themeById(store.activeThemeId);
        final sl = store.sleepLeft;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              _ex(Icons.speed, '${store.speed}x', () => showSheet(context, (c) => const SpeedSheet()), active: store.speed != 1.0, color: th.a),
              _ex(Icons.bedtime, sl == null ? 'خواب' : '${(sl / 60).ceil()} دقیقه', () => showSheet(context, (c) => const SleepSheet()), active: sl != null, color: th.a),
              _ex(Icons.compare_arrows, 'تکرار A-B', store.cycleAB, active: store.abA != null, color: th.a),
              _ex(Icons.equalizer, 'اکولایزر', () => showSheet(context, (c) => const EqSheet()), color: th.a),
              _ex(Icons.lyrics, 'متن', () => store.upd(() => store.showLyrics = !store.showLyrics), active: store.showLyrics, color: th.a),
              _ex(Icons.palette, 'تم', () => showSheet(context, (c) => const ThemeSheet()), color: th.a),
              _ex(Icons.directions_car, 'ماشین', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CarPage())), color: th.a),
            ],
          ),
        );
      },
    );
  }
}

class SpeedSheet extends StatelessWidget {
  const SpeedSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sheetTitle('سرعت پخش'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
                  .map((v) => ChoiceChip(label: Text('${v}x'), selected: store.speed == v, onSelected: (_) => store.setSpeed(v)))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class SleepSheet extends StatelessWidget {
  const SleepSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final sl = store.sleepLeft;
        return Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sheetTitle('تایمر خواب'),
              if (sl != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('${fmt(Duration(seconds: sl))} تا توقف پخش')),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [5, 10, 15, 30, 45, 60, 90]
                    .map((m) => ActionChip(
                          label: Text('$m دقیقه'),
                          onPressed: () {
                            store.setSleep(m);
                            Navigator.of(context).pop();
                          },
                        ))
                    .toList(),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('کم شدن آرام صدا در ۲۰ ثانیه‌ی آخر'),
                value: store.fadeSleep,
                onChanged: (v) => store.upd(() => store.fadeSleep = v),
              ),
              if (sl != null)
                TextButton.icon(
                  onPressed: () {
                    store.setSleep(null);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('لغو تایمر'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class QueueSheet extends StatelessWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final th = themeById(store.activeThemeId);
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(22, 20, 22, 6), child: Align(alignment: Alignment.centerRight, child: sheetTitle('صف پخش (${store.queue.length})'))),
              Expanded(
                child: ListView.builder(
                  itemCount: store.queue.length,
                  itemBuilder: (c, i) {
                    final s = store.queue[i];
                    final on = i == store.index;
                    return ListTile(
                      selected: on,
                      selectedColor: th.a,
                      leading: Cover(seed: hashStr(s.title), size: 40, active: on && store.playing),
                      title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => store.seekTo(i),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class EqSheet extends StatefulWidget {
  const EqSheet({super.key});
  @override
  State<EqSheet> createState() => _EqSheetState();
}

class _EqSheetState extends State<EqSheet> {
  late final Future<AndroidEqualizerParameters> f = store.eq.parameters;

  @override
  Widget build(BuildContext context) {
    final th = themeById(store.activeThemeId);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
        child: FutureBuilder<AndroidEqualizerParameters>(
          future: f,
          builder: (c, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final params = snap.data!;
            return ListView(
              children: [
                Row(
                  children: [
                    Expanded(child: sheetTitle('اکولایزر')),
                    Switch(value: store.eqOn, onChanged: (v) async {
                      await store.setEq(v);
                      setState(() {});
                    }),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: eqPresets.keys
                      .map((n) => ActionChip(
                            label: Text(n),
                            onPressed: () async {
                              await store.applyPreset(params, n);
                              setState(() {});
                            },
                          ))
                      .toList(),
                ),
                const SizedBox(height: 10),
                for (final band in params.bands)
                  Row(
                    children: [
                      SizedBox(width: 64, child: Text('${band.centerFrequency.round()} Hz', style: const TextStyle(fontSize: 12, color: Colors.white70))),
                      Expanded(
                        child: Slider(
                          value: cl(band.gain, params.minDecibels, params.maxDecibels),
                          min: params.minDecibels,
                          max: params.maxDecibels,
                          activeColor: th.a,
                          onChanged: (v) {
                            band.setGain(v);
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                const Divider(),
                Text('تقویت حجم صدا: ${store.loudGain.toStringAsFixed(1)} dB', style: const TextStyle(fontWeight: FontWeight.w700)),
                Slider(
                  value: store.loudGain,
                  min: 0,
                  max: 12,
                  activeColor: th.b,
                  onChanged: (v) async {
                    await store.setLoud(v);
                    setState(() {});
                  },
                ),
                const Text('اکولایزر و تقویت صدا فقط روی اندروید کار می‌کنند.', style: TextStyle(fontSize: 11, color: Colors.white54)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ThemeSheet extends StatelessWidget {
  const ThemeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(22, 20, 22, 0), child: Align(alignment: Alignment.centerRight, child: sheetTitle('انتخاب تم'))),
            Expanded(child: ThemeGrid(onPick: () => Navigator.of(context).pop())),
          ],
        ),
      ),
    );
  }
}

class ThemeGrid extends StatelessWidget {
  final VoidCallback? onPick;
  const ThemeGrid({super.key, this.onPick});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.82, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: themes.length,
      itemBuilder: (c, i) {
        final th = themes[i];
        return ThemeCard(
          th: th,
          selected: !store.autoTheme && store.themeId == th.id,
          onTap: () {
            store.upd(() {
              store.themeId = th.id;
              store.autoTheme = false;
            });
            store.tap();
            if (onPick != null) onPick!();
          },
        );
      },
    );
  }
}

class ThemeCard extends StatelessWidget {
  final NavaTheme th;
  final bool selected;
  final VoidCallback onTap;
  const ThemeCard({super.key, required this.th, required this.selected, required this.onTap});

  Scene _sc() => Scene(id: th.id, t: 3.0, energy: 0.55, progress: 0.4, pa: 1.0, spin: 0.8, seed: hashStr(th.name), a: th.a, b: th.b, bg: th.bg, lite: true);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? th.a : Colors.white12, width: selected ? 2.5 : 1),
          boxShadow: selected ? [BoxShadow(color: th.a.withOpacity(0.45), blurRadius: 16)] : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: BackdropPainter(_sc())),
              Center(
                child: FractionallySizedBox(
                  widthFactor: 0.66,
                  child: AspectRatio(aspectRatio: 1, child: CustomPaint(painter: ArtPainter(_sc()))),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.8)])),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(th.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(th.tag, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
              if (selected) Positioned(top: 8, right: 8, child: Icon(Icons.check_circle, color: th.a)),
            ],
          ),
        ),
      ),
    );
  }
}

class ThemesTab extends StatelessWidget {
  const ThemesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Column(
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: Align(alignment: Alignment.centerRight, child: Text('تم‌ها', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)))),
          SwitchListTile(
            title: const Text('تم خودکار'),
            subtitle: const Text('برای هر آهنگ یک تم متفاوت انتخاب می‌شود'),
            value: store.autoTheme,
            onChanged: (v) => store.upd(() => store.autoTheme = v),
          ),
          const Expanded(child: ThemeGrid()),
        ],
      ),
    );
  }
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return ListView(
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 8), child: Text('تنظیمات', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
            SwitchListTile(title: const Text('ویژوالایزر زنده'), subtitle: const Text('حرکت و ضرباهنگ تصویر هنگام پخش'), value: store.vizOn, onChanged: (v) => store.upd(() => store.vizOn = v)),
            SwitchListTile(title: const Text('حالت سبک'), subtitle: const Text('بدون محوشدگی و جلوه‌ی سنگین؛ برای گوشی‌های ضعیف'), value: store.lite, onChanged: (v) => store.upd(() => store.lite = v)),
            SwitchListTile(title: const Text('لرزش هنگام لمس'), value: store.haptics, onChanged: (v) => store.upd(() => store.haptics = v)),
            SwitchListTile(title: const Text('نمایش متن آهنگ همگام'), subtitle: const Text('فایل .lrc با همان نام آهنگ کنار آن بگذار'), value: store.showLyrics, onChanged: (v) => store.upd(() => store.showLyrics = v)),
            SwitchListTile(title: const Text('کم شدن آرام صدا در تایمر خواب'), value: store.fadeSleep, onChanged: (v) => store.upd(() => store.fadeSleep = v)),
            SwitchListTile(title: const Text('تم خودکار برای هر آهنگ'), value: store.autoTheme, onChanged: (v) => store.upd(() => store.autoTheme = v)),
            const Divider(),
            ListTile(leading: const Icon(Icons.search), title: const Text('اسکن موزیک گوشی'), subtitle: Text('${store.library.length} آهنگ در کتابخانه'), onTap: store.scanDefault),
            ListTile(leading: const Icon(Icons.folder_open), title: const Text('افزودن پوشه'), onTap: store.addFolder),
            ListTile(leading: const Icon(Icons.audio_file), title: const Text('افزودن فایل'), onTap: store.addFiles),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('پاک کردن کتابخانه'),
              subtitle: const Text('فایل‌های آهنگ پاک نمی‌شوند'),
              onTap: () => showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('پاک کردن کتابخانه؟'),
                  content: const Text('فقط فهرست آهنگ‌ها در نوا پاک می‌شود، نه خود فایل‌ها.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('انصراف')),
                    FilledButton(
                      onPressed: () {
                        store.clearLibrary();
                        Navigator.of(c).pop();
                      },
                      child: const Text('پاک کن'),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('درباره‌ی نوا'),
              subtitle: const Text('نسخه‌ی ۱٫۰'),
              onTap: () => showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('نوا'),
                  content: const Text('پخش‌کننده‌ی موزیک با تم‌های زنده.\n\nتوجه: حرکت ویژوالایزر نمایشی است و از روی طیف واقعی صدا ساخته نمی‌شود. اکولایزر و تقویت صدا واقعی‌اند.'),
                  actions: [TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('باشه'))],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

class CarPage extends StatelessWidget {
  const CarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.current;
        final th = themeById(store.activeThemeId);
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                Align(alignment: Alignment.topRight, child: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, size: 30))),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s?.title ?? '—', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text(s?.artist ?? '', style: const TextStyle(fontSize: 18, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  child: Row(
                    children: [
                      Expanded(child: _big(Icons.skip_previous, store.prev, th.b)),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: _big(store.playing ? Icons.pause : Icons.play_arrow, store.togglePlay, th.a)),
                      const SizedBox(width: 12),
                      Expanded(child: _big(Icons.skip_next, store.next, th.b)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _big(IconData i, VoidCallback f, Color c) {
    return GestureDetector(
      onTap: f,
      child: Container(
        height: 130,
        decoration: BoxDecoration(color: c.withOpacity(0.22), borderRadius: BorderRadius.circular(28), border: Border.all(color: c, width: 2)),
        child: Icon(i, size: 64, color: c),
      ),
    );
  }
}
