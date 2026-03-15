/// 섹터별 세팅 날짜
class SettingSector {
  final String name;
  final List<String> dates; // "YYYY-MM-DD"

  SettingSector({required this.name, required this.dates});

  factory SettingSector.fromMap(Map<String, dynamic> map) => SettingSector(
        name: map['name'] as String,
        dates: (map['dates'] as List).cast<String>(),
      );

  Map<String, dynamic> toMap() => {'name': name, 'dates': dates};

  SettingSector copyWith({String? name, List<String>? dates}) => SettingSector(
        name: name ?? this.name,
        dates: dates ?? this.dates,
      );
}

/// 암장 세팅일정 (월별 1레코드)
class GymSettingSchedule {
  final String? id;
  final String gymId;
  final String? gymName; // climbing_gyms JOIN으로 가져옴
  final String yearMonth; // "YYYY-MM"
  final List<SettingSector> sectors;
  final String? sourceImageUrl;
  final String? submittedBy;
  final String? submitterEmail;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GymSettingSchedule({
    this.id,
    required this.gymId,
    this.gymName,
    required this.yearMonth,
    required this.sectors,
    this.sourceImageUrl,
    this.submittedBy,
    this.submitterEmail,
    this.status = 'approved',
    this.createdAt,
    this.updatedAt,
  });

  factory GymSettingSchedule.fromMap(Map<String, dynamic> map) {
    final sectorsRaw = map['sectors'] as List? ?? [];

    // climbing_gyms JOIN 결과에서 gym name 추출
    String? gymName;
    final gymData = map['climbing_gyms'];
    if (gymData is Map<String, dynamic>) {
      gymName = gymData['name'] as String?;
    }
    // 직접 전달된 경우
    gymName ??= map['gym_name'] as String?;

    return GymSettingSchedule(
      id: map['id'] as String?,
      gymId: map['gym_id'] as String,
      gymName: gymName,
      yearMonth: map['year_month'] as String,
      sectors: sectorsRaw
          .map((s) => SettingSector.fromMap(s as Map<String, dynamic>))
          .toList(),
      sourceImageUrl: map['source_image_url'] as String?,
      submittedBy: map['submitted_by'] as String?,
      submitterEmail: map['submitted_by_email'] as String?,
      status: map['status'] as String? ?? 'approved',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'gym_id': gymId,
        'year_month': yearMonth,
        'sectors': sectors.map((s) => s.toMap()).toList(),
        if (sourceImageUrl != null) 'source_image_url': sourceImageUrl,
        if (submittedBy != null) 'submitted_by': submittedBy,
        'status': status,
      };

  /// 이메일 앞 2글자 + "님" (예: kimhyun@gmail.com → "ki님")
  String? get submitterDisplayName {
    if (submitterEmail == null) return null;
    final local = submitterEmail!.split('@').first;
    if (local.length < 2) return '$local님';
    return '${local.substring(0, 2)}님';
  }

  /// sectors에서 특정 날짜에 해당하는 섹터 목록
  List<SettingSector> sectorsForDate(String dateStr) {
    return sectors.where((s) => s.dates.contains(dateStr)).toList();
  }

  /// 모든 날짜 목록 (중복 제거)
  Set<String> get allDates {
    final dates = <String>{};
    for (final sector in sectors) {
      dates.addAll(sector.dates);
    }
    return dates;
  }
}
