import 'dart:math';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:opa_app/domain/entities/map_block.dart';

class MapService {
  static const String mapboxToken = 'YOUR_MAPBOX_ACCESS_TOKEN';
  
  // Buat style URL untuk Mapbox
  String getMapStyle() {
    return 'mapbox://styles/mapbox/satellite-streets-v12';
  }

  // Konversi polygon ke GeoJSON string untuk Mapbox
  String polygonToGeoJson(List<MapBlock> blocks) {
    final features = <Map<String, dynamic>>[];
    
    for (var block in blocks) {
      for (var polygon in block.polygonCoordinates) {
        final coordinates = polygon.map((point) => [point.longitude, point.latitude]).toList();
        
        features.add({
          'type': 'Feature',
          'geometry': {
            'type': 'Polygon',
            'coordinates': [coordinates],
          },
          'properties': {
            'id': block.id,
            'name': block.name,
            'estateName': block.estateName,
            'area': block.area,
            'color': _colorToHex(block.color),
          },
        });
      }
    }

    return {
      'type': 'FeatureCollection',
      'features': features,
    }.toString();
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  // Hitung area polygon (Hektar)
  double calculatePolygonArea(List<LatLng> points) {
    double area = 0;
    final int n = points.length;
    
    for (int i = 0; i < n; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % n];
      area += (p1.longitude * p2.latitude - p2.longitude * p1.latitude);
    }
    
    area = area.abs() / 2.0;
    // Konversi ke hektar (1 derajat ≈ 111 km)
    final hectares = area * 111319.9 * 111319.9 / 10000;
    return hectares;
  }

  // Hitung jarak antara dua titik (meter)
  double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // meter
    
    final dLat = _toRadians(point2.latitude - point1.latitude);
    final dLon = _toRadians(point2.longitude - point1.longitude);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(point1.latitude)) * cos(_toRadians(point2.latitude)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Cek apakah titik berada di dalam polygon
  bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;
      
      final intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi);
      
      if (intersect) inside = !inside;
    }
    return inside;
  }

  // Dapatkan pusat polygon (centroid)
  LatLng getPolygonCentroid(List<LatLng> polygon) {
    double cx = 0, cy = 0;
    double area = 0;
    
    for (int i = 0; i < polygon.length - 1; i++) {
      final p1 = polygon[i];
      final p2 = polygon[i + 1];
      final cross = p1.longitude * p2.latitude - p2.longitude * p1.latitude;
      area += cross;
      cx += (p1.longitude + p2.longitude) * cross;
      cy += (p1.latitude + p2.latitude) * cross;
    }
    
    area /= 2;
    cx /= (6 * area);
    cy /= (6 * area);
    
    return LatLng(cy, cx);
  }
}