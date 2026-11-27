import 'dart:math';
import 'package:flutter/material.dart';

int hashStr(String s) {
  int h = 7;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

double cl(double v, [double a = 0.0, double b = 1.0]) => v < a ? a : (v > b ? b : v);

Color hueColor(double h, {double s = 0.75, double l = 0.55, double a = 1.0}) {
  return HSLColor.fromAHSL(a, ((h % 360) + 360) % 360, s, l).toColor();
}

double fakeEnergy(double t, bool playing, int seed) {
  if (!playing) return 0.08;
  final s = (seed % 97) * 0.1;
  final a = sin(t * 5.3 + s) * 0.5 + 0.5;
  final b = sin(t * 2.1 + s * 2) * 0.5 + 0.5;
  final c = sin(t * 11.7 + s * 3) * 0.5 + 0.5;
  return cl(0.25 + 0.45 * a * b + 0.3 * c * a);
}

class NavaTheme {
  final String id;
  final String name;
  final String tag;
  final Color a;
  final Color b;
  final List<Color> bg;
  const NavaTheme(this.id, this.name, this.tag, this.a, this.b, this.bg);
}

const List<NavaTheme> themes = [
  NavaTheme('neon', 'نئون تهران', 'برج میلاد و شب نئونی', Color(0xFFFF2E93), Color(0xFF00E5FF), [Color(0xFF1B0833), Color(0xFF05020C)]),
  NavaTheme('vinyl', 'گرامافون', 'صفحه‌ی چرخان و بازوی سوزن', Color(0xFFFFB454), Color(0xFFC4572B), [Color(0xFF2A140B), Color(0xFF0E0604)]),
  NavaTheme('cassette', 'کاست', 'نوار کاست قدیمی', Color(0xFFFF8A3D), Color(0xFFFFD37A), [Color(0xFF3A2A20), Color(0xFF18110D)]),
  NavaTheme('aurora', 'شفق', 'روبان‌های نور شمالگان', Color(0xFF3DFFB0), Color(0xFF9B6BFF), [Color(0xFF04141F), Color(0xFF020509)]),
  NavaTheme('synth', 'سین‌ویو', 'خورشید و شبکه‌ی دهه‌ی هشتاد', Color(0xFF7B2FF7), Color(0xFFFF2D95), [Color(0xFF0B0020), Color(0xFF2A0A4A)]),
  NavaTheme('galaxy', 'کهکشان', 'ستاره، سحابی و سیاره‌ی حلقه‌دار', Color(0xFF7C9CFF), Color(0xFFFF7AD9), [Color(0xFF0A0F2E), Color(0xFF010208)]),
  NavaTheme('liquid', 'مایع', 'حباب‌های زنده و شناور', Color(0xFF00D4FF), Color(0xFFFF4D8D), [Color(0xFF0D1030), Color(0xFF1B0B2E)]),
  NavaTheme('bars', 'ویژوالایزر', 'نوارهای دایره‌ای رقصان', Color(0xFF00FFA3), Color(0xFF3A7BFF), [Color(0xFF07122B), Color(0xFF02040C)]),
];

NavaTheme themeById(String id) {
  for (final t in themes) {
    if (t.id == id) return t;
  }
  return themes.first;
}

class Scene {
  final String id;
  final double t;
  final double energy;
  final double progress;
  final double pa;
  final double spin;
  final int seed;
  final Color a;
  final Color b;
  final List<Color> bg;
  final bool lite;
  const Scene({
    required this.id,
    required this.t,
    required this.energy,
    required this.progress,
    required this.pa,
    required this.spin,
    required this.seed,
    required this.a,
    required this.b,
    required this.bg,
    required this.lite,
  });
}

Paint glowPaint(Color col, double blur, bool lite) {
  final p = Paint()..color = col;
  if (!lite) p.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
  return p;
}

Paint strokePaint(Color col, double w) {
  return Paint()
    ..color = col
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;
}

class BackdropPainter extends CustomPainter {
  final Scene s;
  BackdropPainter(this.s);

  @override
  void paint(Canvas c, Size z) {
    final w = z.width;
    final h = z.height;
    final rect = Offset.zero & z;
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: s.bg).createShader(rect),
    );
    switch (s.id) {
      case 'vinyl':
        _vinyl(c, w, h);
        break;
      case 'neon':
        _neon(c, w, h);
        break;
      case 'cassette':
        _cassette(c, w, h);
        break;
      case 'aurora':
        _aurora(c, w, h);
        break;
      case 'synth':
        _synth(c, w, h);
        break;
      case 'galaxy':
        _galaxy(c, w, h);
        break;
      case 'liquid':
        _liquid(c, w, h);
        break;
      default:
        _bars(c, w, h);
    }
  }

  void _vinyl(Canvas c, double w, double h) {
    final ctr = Offset(w / 2, h * 0.34);
    c.drawCircle(
      ctr,
      w * (0.7 + 0.05 * s.energy),
      Paint()
        ..shader = RadialGradient(colors: [s.a.withOpacity(0.28), Colors.transparent])
            .createShader(Rect.fromCircle(center: ctr, radius: w * 0.75)),
    );
    final r = Random(11);
    for (int i = 0; i < 26; i++) {
      final x = r.nextDouble() * w;
      final y0 = r.nextDouble() * h;
      final sp = 6 + r.nextDouble() * 14;
      final y = (y0 - s.t * sp) % h;
      c.drawCircle(Offset(x, y), 1 + r.nextDouble() * 1.6, Paint()..color = Colors.white.withOpacity(0.08 + 0.08 * r.nextDouble()));
    }
  }

  void _neon(Canvas c, double w, double h) {
    final base = h * 0.64;
    final mc = Offset(w * 0.28, h * 0.22);
    c.drawCircle(mc, w * 0.12, glowPaint(s.b.withOpacity(0.55), 40, s.lite));
    c.drawCircle(mc, w * 0.1, Paint()..color = s.b.withOpacity(0.9));
    c.drawRect(Rect.fromLTWH(0, base, w, h - base), Paint()..color = const Color(0xFF07030F));
    final r = Random(7);
    double x = -10;
    while (x < w) {
      final bw = 22 + r.nextDouble() * 34;
      final bh = h * (0.05 + r.nextDouble() * 0.17);
      c.drawRect(Rect.fromLTWH(x, base - bh, bw, bh + 4), Paint()..color = const Color(0xFF0A0516));
      final cols = (bw / 9).floor();
      final rows = (bh / 12).floor();
      for (int i = 0; i < cols; i++) {
        for (int j = 0; j < rows; j++) {
          final hh = (i * 7 + j * 13 + x.toInt().abs()) % 11;
          if (hh < 4) {
            final fl = 0.5 + 0.5 * sin(s.t * (1 + hh) + i + j);
            c.drawRect(
              Rect.fromLTWH(x + 4 + i * 9, base - bh + 5 + j * 12, 4, 6),
              Paint()..color = (hh % 2 == 0 ? s.a : s.b).withOpacity(0.25 + 0.5 * fl * (0.4 + s.energy)),
            );
          }
        }
      }
      x += bw + 2 + r.nextDouble() * 6;
    }
    final tx = w * 0.74;
    final tower = Path()
      ..moveTo(tx - 9, base)
      ..lineTo(tx - 3, base - h * 0.30)
      ..lineTo(tx + 3, base - h * 0.30)
      ..lineTo(tx + 9, base)
      ..close();
    c.drawPath(tower, Paint()..color = const Color(0xFF120824));
    final tg = glowPaint(s.b.withOpacity(0.8), 12, s.lite)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    c.drawPath(tower, tg);
    final pod = Rect.fromCenter(center: Offset(tx, base - h * 0.33), width: 34, height: 22);
    c.drawOval(pod, Paint()..color = const Color(0xFF120824));
    final pg = glowPaint(s.a, 10, s.lite)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    c.drawOval(pod, pg);
    c.drawLine(Offset(tx, base - h * 0.345), Offset(tx, base - h * 0.43), Paint()..color = s.a..strokeWidth = 2);
    final blink = sin(s.t * 3) > 0.4;
    c.drawCircle(Offset(tx, base - h * 0.43), 3.2, Paint()..color = blink ? Colors.redAccent : Colors.red.withOpacity(0.3));
  }

  void _cassette(Canvas c, double w, double h) {
    final lp = Paint()
      ..color = Colors.white.withOpacity(0.035)
      ..strokeWidth = 1.2;
    for (double i = -h; i < w; i += 28) {
      c.drawLine(Offset(i, 0), Offset(i + h, h), lp);
    }
    final ctr = Offset(w / 2, h * 0.34);
    c.drawCircle(
      ctr,
      w * 0.8,
      Paint()
        ..shader = RadialGradient(colors: [s.a.withOpacity(0.18 + 0.1 * s.energy), Colors.transparent])
            .createShader(Rect.fromCircle(center: ctr, radius: w * 0.8)),
    );
  }

  void _aurora(Canvas c, double w, double h) {
    for (int k = 0; k < 4; k++) {
      final p = Path();
      final amp = h * 0.045 * (1 + s.energy * 1.2);
      final yb = h * (0.18 + 0.09 * k);
      for (double x = 0; x <= w; x += 8) {
        final y = yb + sin(x / w * 2 * pi * (1 + k * 0.35) + s.t * (0.45 + 0.18 * k) + k) * amp;
        if (x == 0) {
          p.moveTo(x, y);
        } else {
          p.lineTo(x, y);
        }
      }
      final pt = strokePaint((k.isEven ? s.a : s.b).withOpacity(0.22), 46.0 + k * 14.0);
      if (!s.lite) pt.maskFilter = MaskFilter.blur(BlurStyle.normal, 26);
      c.drawPath(p, pt);
    }
  }

  void _synth(Canvas c, double w, double h) {
    final hy = h * 0.5;
    final sc = Offset(w / 2, hy - w * 0.02);
    final sr = w * 0.3;
    final srect = Rect.fromCircle(center: sc, radius: sr);
    c.save();
    c.clipPath(Path()..addOval(srect));
    c.drawRect(
      srect,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFFFFE066), s.b, s.a]).createShader(srect),
    );
    final mid = Color.lerp(s.bg.first, s.bg.last, 0.5)!;
    for (int i = 0; i < 7; i++) {
      final yy = sc.dy + sr * (0.05 + i * 0.14);
      c.drawRect(Rect.fromLTWH(sc.dx - sr, yy, sr * 2, 2 + i * 1.6), Paint()..color = mid);
    }
    c.restore();
    final m = Path()..moveTo(0, hy);
    for (double x = 0; x <= w; x += 12) {
      m.lineTo(x, hy - (sin(x * 0.02) + sin(x * 0.047 + 2)).abs() * h * 0.03);
    }
    m.lineTo(w, hy);
    m.close();
    c.drawPath(m, Paint()..color = const Color(0xFF12002B));
    c.drawRect(Rect.fromLTWH(0, hy, w, h - hy), Paint()..color = const Color(0xFF12002B));
    final gp = Paint()
      ..color = const Color(0xFF00F0FF).withOpacity(0.45)
      ..strokeWidth = 1.2;
    for (int i = 0; i < 14; i++) {
      final f = ((i + s.t * 0.6 * (0.4 + s.energy)) % 14) / 14;
      final y = hy + (h - hy) * f * f;
      c.drawLine(Offset(0, y), Offset(w, y), gp);
    }
    for (int i = -10; i <= 10; i++) {
      c.drawLine(Offset(w / 2 + i * 8, hy), Offset(w / 2 + i * w * 0.16, h), gp);
    }
  }

  void _galaxy(Canvas c, double w, double h) {
    c.drawCircle(Offset(w * 0.2, h * 0.25), w * 0.5, glowPaint(s.a.withOpacity(0.16), 60, s.lite));
    c.drawCircle(Offset(w * 0.85, h * 0.55), w * 0.45, glowPaint(s.b.withOpacity(0.12), 60, s.lite));
    final r = Random(3);
    for (int i = 0; i < 150; i++) {
      final layer = 0.3 + r.nextDouble() * 1.2;
      final x = (r.nextDouble() * w + s.t * layer * 5) % w;
      final y = r.nextDouble() * h;
      final ph = r.nextDouble() * 6;
      final tw = 0.5 + 0.5 * sin(s.t * (1 + layer) + ph);
      c.drawCircle(Offset(x, y), 0.6 + layer * 0.7, Paint()..color = Colors.white.withOpacity(cl(0.2 + 0.6 * tw * (0.5 + layer / 3))));
    }
  }

  void _liquid(Canvas c, double w, double h) {
    for (int k = 0; k < 5; k++) {
      final cx = w * (0.5 + 0.38 * sin(s.t * (0.25 + 0.07 * k) + k * 1.7));
      final cy = h * (0.3 + 0.22 * cos(s.t * (0.2 + 0.05 * k) + k));
      final rad = w * (0.32 + 0.05 * k * 0.3 + 0.12 * s.energy);
      final col = (k.isEven ? s.a : s.b);
      c.drawCircle(
        Offset(cx, cy),
        rad,
        Paint()
          ..shader = RadialGradient(colors: [col.withOpacity(0.5), Colors.transparent])
              .createShader(Rect.fromCircle(center: Offset(cx, cy), radius: rad)),
      );
    }
  }

  void _bars(Canvas c, double w, double h) {
    final base = h * 0.64;
    const n = 28;
    final bw = w / n;
    for (int i = 0; i < n; i++) {
      final v = (sin(s.t * 3.2 + i * 0.55 + s.seed % 13) * 0.5 + 0.5) * (0.25 + 0.75 * s.energy);
      final bh = h * 0.015 + h * 0.12 * v;
      final col = Color.lerp(s.a, s.b, i / n)!;
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(i * bw + bw * 0.2, base - bh, bw * 0.6, bh), const Radius.circular(3)),
        Paint()..color = col.withOpacity(0.55),
      );
    }
    c.drawRect(Rect.fromLTWH(0, base, w, h - base), Paint()..color = Colors.black.withOpacity(0.35));
  }

  @override
  bool shouldRepaint(BackdropPainter old) => true;
}

class ArtPainter extends CustomPainter {
  final Scene s;
  ArtPainter(this.s);

  @override
  void paint(Canvas c, Size z) {
    final sz = min(z.width, z.height);
    final ctr = Offset(z.width / 2, z.height / 2);
    final hue = (s.seed % 360).toDouble();
    switch (s.id) {
      case 'vinyl':
        _vinyl(c, sz, ctr, hue);
        break;
      case 'neon':
        _neon(c, sz, ctr, hue);
        break;
      case 'cassette':
        _cassette(c, sz, ctr, hue);
        break;
      case 'aurora':
        _aurora(c, sz, ctr, hue);
        break;
      case 'synth':
        _synth(c, sz, ctr, hue);
        break;
      case 'galaxy':
        _galaxy(c, sz, ctr, hue);
        break;
      case 'liquid':
        _liquid(c, sz, ctr, hue);
        break;
      default:
        _bars(c, sz, ctr, hue);
    }
  }

  void _vinyl(Canvas c, double sz, Offset ctr, double hue) {
    final r = sz * 0.46;
    final disc = Rect.fromCircle(center: ctr, radius: r);
    c.drawCircle(ctr.translate(0, 6), r, Paint()..color = Colors.black.withOpacity(0.5)..maskFilter = MaskFilter.blur(BlurStyle.normal, 14));
    c.save();
    c.translate(ctr.dx, ctr.dy);
    c.rotate(s.spin);
    final dr = Rect.fromCircle(center: Offset.zero, radius: r);
    c.drawCircle(Offset.zero, r, Paint()..shader = const RadialGradient(colors: [Color(0xFF1B1B1F), Color(0xFF050507)]).createShader(dr));
    final gp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = Colors.white.withOpacity(0.06);
    for (double rr = r * 0.36; rr < r * 0.98; rr += r * 0.035) {
      c.drawCircle(Offset.zero, rr, gp);
    }
    final lr = Rect.fromCircle(center: Offset.zero, radius: r * 0.33);
    c.drawCircle(Offset.zero, r * 0.33, Paint()..shader = RadialGradient(colors: [hueColor(hue, l: 0.62), hueColor(hue + 40, l: 0.4)]).createShader(lr));
    c.drawCircle(Offset(r * 0.18, 0), r * 0.025, Paint()..color = Colors.white.withOpacity(0.5));
    c.drawCircle(Offset.zero, r * 0.04, Paint()..color = const Color(0xFF0B0B0B));
    c.restore();
    c.drawCircle(
      ctr,
      r,
      Paint()
        ..shader = SweepGradient(
          colors: [Colors.transparent, Colors.white.withOpacity(0.10), Colors.transparent, Colors.white.withOpacity(0.07), Colors.transparent],
          stops: const [0.0, 0.12, 0.5, 0.62, 1.0],
        ).createShader(disc),
    );
    final pivot = Offset(ctr.dx + r * 1.02, ctr.dy - r * 0.98);
    final tipPlay = Offset.lerp(ctr + Offset(r * 0.80, -r * 0.58), ctr + Offset(r * 0.36, -r * 0.20), cl(s.progress))!;
    final tipRest = ctr + Offset(r * 1.08, -r * 0.30);
    final tip = Offset.lerp(tipRest, tipPlay, cl(s.pa))!;
    c.drawLine(pivot, tip, Paint()..color = const Color(0xFFD9D9DE)..strokeWidth = 5..strokeCap = StrokeCap.round);
    c.drawCircle(pivot, r * 0.1, Paint()..color = const Color(0xFF3A3A40));
    c.drawCircle(tip, 6, Paint()..color = s.a);
  }

  void _neon(Canvas c, double sz, Offset ctr, double hue) {
    final e = s.energy;
    final r = sz * 0.34;
    c.drawCircle(ctr, r + sz * 0.06 * e, strokePaint(s.b.withOpacity(0.7), 5)..maskFilter = s.lite ? null : MaskFilter.blur(BlurStyle.normal, 10));
    c.drawCircle(ctr, r + sz * 0.06 * e, strokePaint(s.b, 1.8));
    c.drawCircle(ctr, r * 1.22 + sz * 0.03 * e, strokePaint(s.a.withOpacity(0.55), 1.4));
    final ir = Rect.fromCircle(center: ctr, radius: r * 0.92);
    c.drawCircle(ctr, r * 0.92, Paint()..shader = RadialGradient(colors: [hueColor(hue, l: 0.62), hueColor(hue + 60, l: 0.28)]).createShader(ir));
    for (int i = 0; i < 3; i++) {
      final a = s.spin * (1 + i * 0.4) + i * 2.1;
      final rr = r * (1.22 + 0.1 * i) + sz * 0.03 * e;
      c.drawCircle(ctr + Offset(cos(a) * rr, sin(a) * rr), 4.5, Paint()..color = i.isEven ? s.a : s.b);
    }
  }

  void _cassette(Canvas c, double sz, Offset ctr, double hue) {
    final bw = sz * 0.98;
    final bh = sz * 0.64;
    final body = RRect.fromRectAndRadius(Rect.fromCenter(center: ctr, width: bw, height: bh), Radius.circular(sz * 0.04));
    c.drawRRect(body.shift(const Offset(0, 6)), Paint()..color = Colors.black.withOpacity(0.4)..maskFilter = MaskFilter.blur(BlurStyle.normal, 12));
    c.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [hueColor(hue, s: 0.35, l: 0.35), hueColor(hue + 30, s: 0.35, l: 0.2)]).createShader(body.outerRect),
    );
    final lab = RRect.fromRectAndRadius(Rect.fromLTWH(ctr.dx - bw * 0.44, ctr.dy - bh * 0.44, bw * 0.88, bh * 0.34), const Radius.circular(6));
    c.drawRRect(lab, Paint()..color = const Color(0xFFF1E6CF));
    for (int i = 0; i < 3; i++) {
      c.drawLine(
        Offset(lab.left + 14, lab.top + 10 + i * 9),
        Offset(lab.right - 14 - (i == 2 ? 60 : 0), lab.top + 10 + i * 9),
        Paint()..color = hueColor(hue, l: 0.4).withOpacity(0.7)..strokeWidth = 2,
      );
    }
    final wc = Offset(ctr.dx, ctr.dy + bh * 0.14);
    final win = RRect.fromRectAndRadius(Rect.fromCenter(center: wc, width: bw * 0.62, height: bh * 0.3), Radius.circular(bh * 0.15));
    c.drawRRect(win, Paint()..color = const Color(0xFF14110E));
    c.save();
    c.clipRRect(win);
    for (int side = 0; side < 2; side++) {
      final rc = Offset(wc.dx + (side == 0 ? -bw * 0.17 : bw * 0.17), wc.dy);
      final tr = bh * 0.12 + bh * 0.07 * (side == 0 ? 1 - cl(s.progress) : cl(s.progress));
      c.drawCircle(rc, tr, Paint()..color = const Color(0xFF3B2A1E));
      c.drawCircle(rc, bh * 0.095, Paint()..color = const Color(0xFFEDEDED));
      for (int k = 0; k < 6; k++) {
        final a = s.spin + k * pi / 3;
        c.drawLine(rc, rc + Offset(cos(a), sin(a)) * (bh * 0.085), Paint()..color = const Color(0xFF14110E)..strokeWidth = 3);
      }
      c.drawCircle(rc, bh * 0.03, Paint()..color = const Color(0xFF14110E));
    }
    c.restore();
  }

  void _aurora(Canvas c, double sz, Offset ctr, double hue) {
    final r = sz * 0.36;
    final e = s.energy;
    c.drawCircle(ctr, r * (1.15 + 0.1 * e), glowPaint(s.a.withOpacity(0.35), 30, s.lite));
    final rect = Rect.fromCircle(center: ctr, radius: r);
    c.drawCircle(
      ctr,
      r,
      Paint()
        ..shader = SweepGradient(
          transform: GradientRotation(s.spin * 0.5),
          colors: [hueColor(hue, l: 0.55), s.a, s.b, hueColor(hue + 80, l: 0.5), hueColor(hue, l: 0.55)],
        ).createShader(rect),
    );
    c.drawCircle(ctr, r, Paint()..shader = RadialGradient(colors: [Colors.white.withOpacity(0.25), Colors.transparent], center: const Alignment(-0.4, -0.5), radius: 0.9).createShader(rect));
    c.drawArc(Rect.fromCircle(center: ctr, radius: r * 0.9), -2.6, 1.0, false, strokePaint(Colors.white.withOpacity(0.5), 3));
  }

  void _synth(Canvas c, double sz, Offset ctr, double hue) {
    final r = sz * 0.38;
    final rect = Rect.fromCircle(center: ctr, radius: r);
    c.drawCircle(ctr, r * 1.1, glowPaint(s.b.withOpacity(0.4 + 0.2 * s.energy), 28, s.lite));
    c.save();
    c.clipPath(Path()..addOval(rect));
    c.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFFFFE066), s.b, s.a]).createShader(rect));
    final off = (s.t * 6) % 1;
    for (int i = 0; i < 8; i++) {
      final f = (i + off) / 8;
      final yy = ctr.dy - r + r * 2 * f;
      c.drawRect(Rect.fromLTWH(ctr.dx - r, yy, r * 2, 1 + f * 7), Paint()..color = Color.lerp(s.bg.first, s.bg.last, 0.5)!);
    }
    c.restore();
  }

  void _galaxy(Canvas c, double sz, Offset ctr, double hue) {
    final r = sz * 0.26;
    final rect = Rect.fromCircle(center: ctr, radius: r);
    c.save();
    c.translate(ctr.dx, ctr.dy);
    c.rotate(-0.35);
    final ring = Rect.fromCenter(center: Offset.zero, width: r * 3.4, height: r * 0.9);
    c.drawArc(ring, pi, pi, false, strokePaint(s.b.withOpacity(0.55), 5));
    c.restore();
    c.drawCircle(ctr, r * 1.25, glowPaint(s.a.withOpacity(0.35), 26, s.lite));
    c.drawCircle(ctr, r, Paint()..shader = RadialGradient(colors: [hueColor(hue, l: 0.6), hueColor(hue + 50, l: 0.25)], center: const Alignment(-0.4, -0.4)).createShader(rect));
    c.save();
    c.clipPath(Path()..addOval(rect));
    for (int i = 0; i < 5; i++) {
      c.drawRect(Rect.fromLTWH(ctr.dx - r, ctr.dy - r + r * 0.4 * i + r * 0.1 * sin(s.t + i), r * 2, r * 0.12), Paint()..color = Colors.white.withOpacity(0.08));
    }
    c.restore();
    c.save();
    c.translate(ctr.dx, ctr.dy);
    c.rotate(-0.35);
    c.drawArc(ring, 0, pi, false, strokePaint(s.b.withOpacity(0.85), 5));
    c.restore();
    for (int i = 0; i < 2; i++) {
      final a = s.spin * (0.7 + i * 0.5) + i * 3.0;
      final rr = r * (1.9 + 0.5 * i);
      c.drawCircle(ctr + Offset(cos(a) * rr, sin(a) * rr * 0.6), 5.0 - i, Paint()..color = Colors.white.withOpacity(0.9));
    }
  }

  void _liquid(Canvas c, double sz, Offset ctr, double hue) {
    final R = sz * 0.34;
    final p = Path();
    for (int i = 0; i <= 120; i++) {
      final th = i / 120 * 2 * pi;
      final rr = R * (1 + 0.08 * sin(3 * th + s.spin) + 0.06 * sin(5 * th - s.spin * 1.3) + 0.12 * s.energy * sin(2 * th + s.spin * 2));
      final pt = ctr + Offset(cos(th) * rr, sin(th) * rr);
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    p.close();
    c.drawPath(p, glowPaint(s.b.withOpacity(0.4), 24, s.lite));
    final rect = Rect.fromCircle(center: ctr, radius: R * 1.2);
    c.drawPath(p, Paint()..shader = RadialGradient(colors: [hueColor(hue, l: 0.62), s.a, s.b], stops: const [0.0, 0.55, 1.0], center: const Alignment(-0.3, -0.3)).createShader(rect));
    c.drawCircle(ctr + Offset(-R * 0.35, -R * 0.4), R * 0.14, Paint()..color = Colors.white.withOpacity(0.35));
  }

  void _bars(Canvas c, double sz, Offset ctr, double hue) {
    const n = 56;
    final r0 = sz * 0.30;
    for (int i = 0; i < n; i++) {
      final a = i / n * 2 * pi - pi / 2;
      final v = (sin(s.t * 4 + i * 0.7 + s.seed % 17) * 0.5 + 0.5) * (0.3 + 0.7 * s.energy);
      final len = sz * (0.02 + 0.14 * v);
      final p1 = ctr + Offset(cos(a), sin(a)) * (r0 + 6);
      final p2 = ctr + Offset(cos(a), sin(a)) * (r0 + 6 + len);
      c.drawLine(p1, p2, strokePaint(Color.lerp(s.a, s.b, i / n)!, 4));
    }
    final rect = Rect.fromCircle(center: ctr, radius: r0);
    c.drawCircle(ctr, r0, Paint()..shader = RadialGradient(colors: [hueColor(hue, l: 0.6), hueColor(hue + 70, l: 0.25)], center: const Alignment(-0.3, -0.3)).createShader(rect));
    c.drawCircle(ctr, r0, strokePaint(Colors.white.withOpacity(0.25), 1.5));
  }

  @override
  bool shouldRepaint(ArtPainter old) => true;
}

class Cover extends StatelessWidget {
  final int seed;
  final double size;
  final bool active;
  const Cover({super.key, required this.seed, required this.size, this.active = false});

  @override
  Widget build(BuildContext context) {
    final h = (seed % 360).toDouble();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [hueColor(h, l: 0.6), hueColor(h + 60, l: 0.35)]),
        boxShadow: active ? [BoxShadow(color: hueColor(h).withOpacity(0.6), blurRadius: 14)] : null,
      ),
      child: Icon(active ? Icons.graphic_eq : Icons.music_note, color: Colors.white.withOpacity(0.9), size: size * 0.5),
    );
  }
}
