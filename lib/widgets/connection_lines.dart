import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Polyline createConnectionLine({
  required LatLng from,
  required LatLng to,
  required bool isAccepted,
}) {
  return Polyline(
    polylineId: PolylineId('connection_${from.latitude}_${from.longitude}'),
    points: [from, to],
    color: isAccepted ? Colors.green : Colors.blue,
    width: 3,
    patterns: isAccepted
        ? [PatternItem.dash(10), PatternItem.gap(5)]
        : [PatternItem.dash(5), PatternItem.gap(3)],
  );
}