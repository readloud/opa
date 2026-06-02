class SyncQueueItem {
  final int? id;
  final String endpoint;
  final String method; // POST, PUT, DELETE
  final String payload;
  final String entityType; // harvest, inspection, fertilization
  final String entityId;
  final int retryCount;
  final String status; // pending, processing, success, failed
  final DateTime createdAt;

  SyncQueueItem({
    this.id,
    required this.endpoint,
    required this.method,
    required this.payload,
    required this.entityType,
    required this.entityId,
    this.retryCount = 0,
    this.status = 'pending',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'endpoint': endpoint,
      'method': method,
      'payload': payload,
      'entity_type': entityType,
      'entity_id': entityId,
      'retry_count': retryCount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id'],
      endpoint: map['endpoint'],
      method: map['method'],
      payload: map['payload'],
      entityType: map['entity_type'],
      entityId: map['entity_id'],
      retryCount: map['retry_count'],
      status: map['status'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}