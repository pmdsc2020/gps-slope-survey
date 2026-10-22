import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'models.dart';
import 'slope.dart';

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

String summaryText(Survey s, Method chosen) {
  final r = computeSlope(s.points);
  final b = StringBuffer()
    ..writeln('Slope survey: ${s.name}${s.site.isNotEmpty ? ' (${s.site})' : ''}')
    ..writeln('Date: ${_date(s.createdAt)}${s.by.isNotEmpty ? ' · Surveyor: ${s.by}' : ''}');
  if (!r.ok) {
    b.writeln('Not enough points with elevation.');
    return b.toString().trim();
  }
  final a = r.rows.first.point.label, z = r.rows.last.point.label;
  b.writeln('Points: ${r.n} · route length ${fx(r.route!.dist, 1)} m');
  for (final f in r.all) {
    final rel = reliability(f);
    final s0 = f.slope ?? 0;
    b.writeln('${f.method.label}: ${fx(s0.abs(), 2)} % (${fx(slopeDegrees(s0), 2)}°, ${oneIn(s0)}) '
        '${f.dh < 0 ? 'fall' : 'rise'} $a→$z, ±${fx(f.unc, 2)} %${rel != null ? ' [${rel.label}]' : ''}');
  }
  final c = classOf(r.by(chosen)!.slope ?? 0);
  b
    ..writeln('Slope class: ${c.code} – ${c.name} (${c.range})')
    ..writeln('Typical treatment: ${c.treatment}');
  if (s.rem.isNotEmpty) b.writeln('Remarks: ${s.rem}');
  b.writeln('— GPS Slope Survey app');
  return b.toString().trim();
}

String _q(Object? v) {
  final t = v?.toString() ?? '';
  return RegExp(r'[",\n]').hasMatch(t) ? '"${t.replaceAll('"', '""')}"' : t;
}

String csvText(Survey s) {
  final r = computeSlope(s.points);
  final byId = {for (var i = 0; i < r.rows.length; i++) r.rows[i].point.id: i};
  final out = <List<Object?>>[
    ['Survey', s.name],
    ['Site', s.site],
    ['Surveyor', s.by],
    ['Date', _date(s.createdAt)],
    for (final f in r.all)
      ['${f.method.label} slope %', fx(f.slope, 3), '± %', fx(f.unc, 3), 'Distance m', fx(f.dist, 2), 'dH m', fx(f.dh, 3)],
    [],
    [
      'Point', 'Latitude', 'Longitude', 'GPS_Alt_m', 'Vert_Acc_m', 'Horiz_Acc_m', 'Readings', 'Alt_SD_m', 'RL_m',
      'Elevation_used_m', 'Chainage_m', 'Seg_Dist_m', 'Seg_dH_m', 'Seg_Slope_pct', 'Source', 'Note'
    ],
  ];
  for (final p in s.points) {
    final i = byId[p.id];
    final ProfileRow? row = i == null ? null : r.rows[i];
    final ProfileRow? sg = (row != null && i! > 0) ? row : null;
    out.add([
      p.label,
      p.lat.toStringAsFixed(7),
      p.lon.toStringAsFixed(7),
      p.alt == null ? '' : fx(p.alt, 3),
      p.altAcc == null ? '' : fx(p.altAcc, 2),
      p.hAcc == null ? '' : fx(p.hAcc, 2),
      p.n == 0 ? '' : p.n,
      p.sd == null ? '' : fx(p.sd, 2),
      p.hasRL ? p.rl : '',
      row == null ? '' : fx(row.elev, 3),
      row == null ? '' : fx(row.chainage, 2),
      sg == null ? '' : fx(sg.dist, 2),
      sg == null ? '' : fx(sg.dh, 3),
      sg?.slope == null ? '' : fx(sg!.slope, 3),
      p.manual ? 'Manual' : (p.hasRL ? 'RL' : 'GPS'),
      p.note,
    ]);
  }
  return out.map((r) => r.map(_q).join(',')).join('\n');
}

String _x(String t) => t
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String kmlText(Survey s) {
  final pm = s.points
      .map((p) => '<Placemark><name>${_x(p.label)}</name><description>Elevation ${fx(p.elevation, 2)} m'
          '${p.note.isNotEmpty ? ' · ${_x(p.note)}' : ''}</description><Point><coordinates>${p.lon},${p.lat},0'
          '</coordinates></Point></Placemark>')
      .join();
  final line = s.points.map((p) => '${p.lon},${p.lat},0').join(' ');
  return '<?xml version="1.0" encoding="UTF-8"?><kml xmlns="http://www.opengis.net/kml/2.2"><Document>'
      '<name>${_x(s.name)}</name><Style id="l"><LineStyle><color>ff1bb3f2</color><width>3</width></LineStyle></Style>'
      '$pm<Placemark><name>Slope line</name><styleUrl>#l</styleUrl><LineString><tessellate>1</tessellate>'
      '<coordinates>$line</coordinates></LineString></Placemark></Document></kml>';
}

String fileBase(Survey s) {
  final b = s.name.replaceAll(RegExp(r'[^\w\-]+'), '_');
  return (b.isEmpty ? 'slope_survey' : (b.length > 40 ? b.substring(0, 40) : b));
}

Future<void> shareFile(Survey s, String ext, String text, String mime) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/${fileBase(s)}.$ext');
  // A byte order mark helps Excel open the CSV in UTF-8.
  await f.writeAsString(ext == 'csv' ? '﻿$text' : text);
  await Share.shareXFiles([XFile(f.path, mimeType: mime)], subject: '${s.name} – slope survey');
}

Future<void> shareText(String text, String subject) => Share.share(text, subject: subject);
