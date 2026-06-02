enum TreeCondition {
  healthy,
  mildDamage,
  severeDamage,
  dead;

  String get displayName {
    switch (this) {
      case TreeCondition.healthy:
        return 'Sehat';
      case TreeCondition.mildDamage:
        return 'Kerusakan Ringan';
      case TreeCondition.severeDamage:
        return 'Kerusakan Berat';
      case TreeCondition.dead:
        return 'Mati';
    }
  }

  Color get color {
    switch (this) {
      case TreeCondition.healthy:
        return Colors.green;
      case TreeCondition.mildDamage:
        return Colors.orange;
      case TreeCondition.severeDamage:
        return Colors.deepOrange;
      case TreeCondition.dead:
        return Colors.red;
    }
  }
}

class Inspection {
  final String? id;
  final String blockId;
  final String blockName;
  final String? treeId;
  final TreeCondition condition;
  final String notes;
  final String? photoUrl;
  final double? latitude;
  final double? longitude;
  final String createdBy;
  final DateTime createdAt;
  final bool isSynced;

  Inspection({
    this.id,
    required this.blockId,
    required this.blockName,
    this.treeId,
    required this.condition,
    this.notes = '',
    this.photoUrl,
    this.latitude,
    this.longitude,
    required this.createdBy,
    required this.createdAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'block_id': blockId,
      'block_name': blockName,
      'tree_id': treeId,
      'condition': condition.name,
      'notes': notes,
      'photo_url': photoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Inspection.fromMap(Map<String, dynamic> map) {
    return Inspection(
      id: map['id'],
      blockId: map['block_id'],
      blockName: map['block_name'],
      treeId: map['tree_id'],
      condition: TreeCondition.values.firstWhere(
        (e) => e.name == map['condition'],
        orElse: () => TreeCondition.healthy,
      ),
      notes: map['notes'] ?? '',
      photoUrl: map['photo_url'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      createdBy: map['created_by'],
      createdAt: DateTime.parse(map['created_at']),
      isSynced: map['is_synced'] == 1,
    );
  }
}