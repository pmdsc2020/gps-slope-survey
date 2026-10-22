import 'dart:math' as math;

String newId() {
  final r = math.Random();
  return DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
      r.nextInt(1 << 30).toRadixString(36);
}

double? _d(Object? v) => v == null ? null : (v as num).toDouble();

/// One surveyed point. Elevation comes from [rl] when the surveyor typed one,
/// otherwise from the averaged GPS altitude [alt].
class SurveyPoint {
  SurveyPoint({
    String? id,
    required this.label,
    required this.lat,
    required this.lon,
    this.alt,
    this.altAcc,
    this.hAcc,
    this.n = 0,
    this.sd,
    this.rl,
    this.note = '',
    int? t,
    this.manual = false,
  })  : id = id ?? newId(),
        t = t ?? DateTime.now().millisecondsSinceEpoch;

  final String id;
  String label;
  double lat;
  double lon;
  double? alt; // averaged GPS altitude, m (WGS84 ellipsoid)
  double? altAcc; // vertical accuracy, m
  double? hAcc; // horizontal accuracy, m
  int n; // readings averaged
  double? sd; // spread of the altitude readings, m
  double? rl; // reduced level typed in, m
  String note;
  int t;
  bool manual;

  bool get hasRL => rl != null && rl!.isFinite;

  double? get elevation => hasRL ? rl : ((alt != null && alt!.isFinite) ? alt : null);

  /// Standard error used for slope uncertainty.
  double get sigma => hasRL ? 0.02 : ((altAcc != null && altAcc!.isFinite) ? altAcc! : 10.0);

  String get source => manual ? 'MANUAL' : (hasRL ? 'RL' : 'GPS');

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'lat': lat,
        'lon': lon,
        'alt': alt,
        'altAcc': altAcc,
        'hAcc': hAcc,
        'n': n,
        'sd': sd,
        'rl': rl,
        'note': note,
        't': t,
        'manual': manual,
      };

  factory SurveyPoint.fromJson(Map<String, dynamic> j) => SurveyPoint(
        id: j['id'] as String?,
        label: (j['label'] ?? 'P') as String,
        lat: _d(j['lat']) ?? 0,
        lon: _d(j['lon']) ?? 0,
        alt: _d(j['alt']),
        altAcc: _d(j['altAcc']),
        hAcc: _d(j['hAcc']),
        n: (j['n'] as num?)?.toInt() ?? 0,
        sd: _d(j['sd']),
        rl: _d(j['rl']),
        note: (j['note'] ?? '') as String,
        t: (j['t'] as num?)?.toInt(),
        manual: (j['manual'] ?? false) as bool,
      );
}

class Survey {
  Survey({
    String? id,
    required this.name,
    this.site = '',
    this.by = '',
    this.rem = '',
    String? created,
    List<SurveyPoint>? points,
    this.example = false,
  })  : id = id ?? newId(),
        created = created ?? DateTime.now().toIso8601String(),
        points = points ?? <SurveyPoint>[];

  final String id;
  String name;
  String site;
  String by;
  String rem;
  final String created;
  final List<SurveyPoint> points;
  bool example;

  DateTime get createdAt => DateTime.tryParse(created) ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'site': site,
        'by': by,
        'rem': rem,
        'created': created,
        'example': example,
        'points': points.map((p) => p.toJson()).toList(),
      };

  factory Survey.fromJson(Map<String, dynamic> j) => Survey(
        id: j['id'] as String?,
        name: (j['name'] ?? 'Survey') as String,
        site: (j['site'] ?? '') as String,
        by: (j['by'] ?? '') as String,
        rem: (j['rem'] ?? '') as String,
        created: j['created'] as String?,
        example: (j['example'] ?? false) as bool,
        points: ((j['points'] as List?) ?? const [])
            .map((e) => SurveyPoint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  /// A sample transect so the app opens with something to look at.
  factory Survey.example() {
    final s = Survey(name: 'Example transect', site: 'Sample site (example)', example: true);
    const elev = [412.6, 409.1, 405.8, 401.2, 398.9, 395.4];
    const acc = [3.8, 4.2, 3.5, 4.6, 3.9, 4.1];
    for (var i = 0; i < elev.length; i++) {
      s.points.add(SurveyPoint(
        label: 'P${i + 1}',
        lat: 21.82500 - 0.00035 * i - (i.isOdd ? 0.00004 : 0),
        lon: 74.21800 + 0.00040 * i,
        alt: elev[i],
        altAcc: acc[i],
        hAcc: 3.0 + i % 3,
        n: 28,
        sd: 0.9,
      ));
    }
    return s;
  }
}

/// One GPS reading as delivered by the phone.
class Fix {
  const Fix({
    required this.lat,
    required this.lon,
    this.alt,
    this.altAcc,
    required this.hAcc,
    required this.time,
  });
  final double lat;
  final double lon;
  final double? alt;
  final double? altAcc;
  final double hAcc;
  final DateTime time;
}
