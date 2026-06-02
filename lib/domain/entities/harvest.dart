class Harvest {
  final String? id;
  final String blockId;
  final String blockName;
  final double tonase;
  final DateTime harvestDate;
  final String? photoUrl;
  final String createdBy;
  final DateTime createdAt;
  final bool isSynced;
  final String? syncError;

  Harvest({
    this.id,
    required this.blockId,
    required this.blockName,
    required this.tonase,
    required this.harvestDate,
    this.photoUrl,
    required this.createdBy,
    required this.createdAt,
    this.isSynced = false,
    this.syncError,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'block_id': blockId,
      'block_name': blockName,
      'tonase': tonase,
      'harvest_date': harvestDate.toIso8601String(),
      'photo_url': photoUrl,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'sync_error': syncError,
    };
  }

  factory Harvest.fromMap(Map<String, dynamic> map) {
    return Harvest(
      id: map['id'],
      blockId: map['block_id'],
      blockName: map['block_name'],
      tonase: map['tonase'],
      harvestDate: DateTime.parse(map['harvest_date']),
      photoUrl: map['photo_url'],
      createdBy: map['created_by'],
      createdAt: DateTime.parse(map['created_at']),
      isSynced: map['is_synced'] == 1,
      syncError: map['sync_error'],
    );
  }
}