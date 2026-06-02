import 'package:geojson/geojson.dart';

class MapBlock {
  final String id;
  final String name;
  final String estateId;
  final String estateName;
  final double? area;
  final List<List<LatLng>> polygonCoordinates;
  final Color color;
  final bool isSelected;

  MapBlock({
    required this.id,
    required this.name,
    required this.estateId,
    required this.estateName,
    this.area,
    required this.polygonCoordinates,
    this.color = Colors.green,
    this.isSelected = false,
  });

  factory MapBlock.fromJson(Map<String, dynamic> json) {
    // Parse GeoJSON polygon
    final geometry = json['geometry'];
    final List<List<LatLng>> coordinates = [];

    if (geometry != null && geometry['coordinates'] != null) {
      final coords = geometry['coordinates'][0] as List;
      for (var coord in coords) {
        coordinates.add([LatLng(coord[1], coord[0])]);
      }
    }

    return MapBlock(
      id: json['id'],
      name: json['name'],
      estateId: json['estateId'],
      estateName: json['estate']['name'] ?? '',
      area: json['area']?.toDouble(),
      polygonCoordinates: coordinates,
      color: _getColorFromStatus(json.get('status')),
    );
  }

  static Color _getColorFromStatus(String? status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'critical':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}

class LatLng {
  final double latitude;
  final double longitude;

  LatLng(this.latitude, this.longitude);

  @override
  String toString() => '($latitude, $longitude)';
}