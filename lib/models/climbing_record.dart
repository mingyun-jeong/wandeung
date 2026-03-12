class ClimbingRecord {
  final String? id;
  final String userId;
  final String? gymId;
  final String? gymName;
  final String grade;
  final String difficultyColor;
  final String status;
  final String? videoPath;
  final String? thumbnailPath;
  final List<String> tags;
  final String? memo;
  final DateTime recordedAt;
  final DateTime? createdAt;
  final String? parentRecordId;
  final int? videoDurationSeconds;

  bool get isLocalVideo => videoPath != null && videoPath!.startsWith('/');

  ClimbingRecord({
    this.id,
    required this.userId,
    this.gymId,
    this.gymName,
    required this.grade,
    required this.difficultyColor,
    required this.status,
    this.videoPath,
    this.thumbnailPath,
    this.tags = const [],
    this.memo,
    required this.recordedAt,
    this.createdAt,
    this.parentRecordId,
    this.videoDurationSeconds,
  });

  Map<String, dynamic> toInsertMap() => {
        'user_id': userId,
        'gym_id': gymId,
        'grade': grade,
        'difficulty_color': difficultyColor,
        'status': status,
        'video_path': videoPath,
        'thumbnail_path': thumbnailPath,
        'tags': tags,
        'memo': memo,
        'recorded_at': recordedAt.toIso8601String().split('T')[0],
        if (parentRecordId != null) 'parent_record_id': parentRecordId,
        if (videoDurationSeconds != null)
          'video_duration_seconds': videoDurationSeconds,
      };

  factory ClimbingRecord.fromMap(Map<String, dynamic> map) => ClimbingRecord(
        id: map['id'],
        userId: map['user_id'],
        gymId: map['gym_id'],
        gymName: (map['climbing_gyms'] as Map?)?['name'] as String?,
        grade: map['grade'],
        difficultyColor: map['difficulty_color'],
        status: map['status'],
        videoPath: map['video_path'],
        thumbnailPath: map['thumbnail_path'],
        tags: List<String>.from(map['tags'] ?? []),
        memo: map['memo'],
        recordedAt: DateTime.parse(map['recorded_at']),
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'])
            : null,
        parentRecordId: map['parent_record_id'],
        videoDurationSeconds: map['video_duration_seconds'],
      );
}
