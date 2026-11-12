import 'dart:math';
import 'package:flutter/material.dart';
import '../models/mind_map_data.dart';

class EdgePainter extends CustomPainter {
  final List<MindMapNode> nodes;
  final List<MindMapEdge> edges;
  final String mapType;
  final bool isDark;
  EdgePainter({
    required this.nodes,
    required this.edges,
    required this.mapType,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size ){
    final nodeMap = <String, MindMapNode>{};
    for (var node in nodes) {
      nodeMap[node.id] = node;
    }

    for (final edge in edges) {
      final fromNode = nodeMap[edge.idFrom];
      final toNode = nodeMap[edge.idTo];
      if (fromNode == null || toNode == null) {
        continue; // Skip if either node is not found
      }

      // start point (center-bottom of source node)
      Offset start = Offset(
        fromNode.position.dx + fromNode.size.width / 2,
        fromNode.position.dy + fromNode.size.height,
      );

      // end point (center-top of target node)
      Offset end = Offset(
        toNode.position.dx + toNode.size.width /  2,
        toNode.position.dy,
      );

      //bubble and concept maps : connect from center to center
      if (mapType == 'bubble' || mapType == 'concept') {
        start = Offset(
          fromNode.position.dx + fromNode.size.width / 2,
          fromNode.position.dy + fromNode.size.height / 2,
        );
        end = Offset(
          toNode.position.dx + toNode.size.width / 2,
          toNode.position.dy + toNode.size.height / 2,
        );
      }

      if (mapType == 'tree') continue;

      final paint = Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.4)
            : Colors.blueGrey.withValues(alpha: 0.5)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

        if (mapType == 'bubble' || mapType == 'concept') {
          //straight line for bubble and concept maps
          canvas.drawLine(start, end, paint);
        } else {
          //curve lines using cubic bezier for hierarchical maps:
          final path = Path()
            ..moveTo(start.dx, start.dy)
            ..cubicTo(start.dx, start.dy + 40, end.dx, end.dy - 40, end.dx, end.dy);
          canvas.drawPath(path, paint);
        }
      
      // --- Draw arrowhead ---
      if (mapType != 'bubble') {
        _drawArrowhead(canvas, start, end, isDark);
      }

      // --- Draw edge label (for Concept Maps) ---
      if (edge.label != null && edge.label!.isNotEmpty && mapType == 'concept') {
        // the label at the midpoint of the line
        _drawEdgeLabel(canvas, start, end, edge.label!, isDark);
      } 
    }
  }

  void _drawArrowhead(Canvas canvas, Offset start, Offset end, bool isDark) {
    final arrowPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.4) : Colors.blueGrey.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    const double arrowSize = 10.0;
    final angle = atan2(end.dy - start.dy, end.dx - start.dx);
    final path = Path();
    path.moveTo(end.dx, end.dy);
    path.lineTo(end.dx - arrowSize * cos(angle - pi / 6), end.dy - arrowSize * sin(angle - pi / 6));
    path.lineTo(end.dx - arrowSize * cos(angle + pi / 6), end.dy - arrowSize * sin(angle + pi / 6));
    path.close();
    canvas.drawPath(path, arrowPaint);
  }

  void _drawEdgeLabel(Canvas canvas, Offset start, Offset end, String label, bool isDark){
    final midpoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);

    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        color: isDark ? Colors.white70 : Colors.blueAccent,
        fontSize: 12,
        fontStyle: FontStyle.italic,
      )
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Removed background pill as per user request to avoid overlapping boxes
    // Just draw the text centered on the midpoint
    textPainter.paint(
      canvas, 
      Offset(midpoint.dx - textPainter.width / 2, midpoint.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Always repaint for simplicity; can be optimized
  }

}
  
