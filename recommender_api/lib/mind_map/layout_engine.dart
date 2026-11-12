import 'dart:math';
import 'package:flutter/widgets.dart';
import '../models/mind_map_data.dart';

// Assign (x,y) to each node
class LayoutEngine {
  static void applyLayout(MindMapResponseData mindMapData) {
    // 1. Measure text and assign dynamic bounds to all nodes
    for (var node in mindMapData.nodes) {
      if (mindMapData.mapType != 'tree') {
        node.size = _measureNodeText(node);
      }
    }

    // 2. Apply layout algorithms
    // Note: 'flowchart' map rendering was rejected due to layout defects
    // (text cut off, isolated map in the corner). It cleanly falls back to hierarchical layout.
    switch (mindMapData.mapType) {
      case 'bubble':
        _layoutBubble(mindMapData);
        break;
      case 'tree':
        _layoutTreeMap(mindMapData);
        break;
      case 'concept':
        _layoutConcept(mindMapData);
        break;
      case 'flowchart':
      default:
        _layoutHierarchical(mindMapData);
    }
  }

  static Size _measureNodeText(MindMapNode node) {
    double fontSize;
    FontWeight fontWeight;

    switch (node.type) {
      case 'root':
        fontSize = 16.0;
        fontWeight = FontWeight.bold;
        break;
      case 'branch':
        fontSize = 13.0;
        fontWeight = FontWeight.w600;
        break;
      default:
        fontSize = 12.0;
        fontWeight = FontWeight.w500;
    }

    // Allow wider max text width for detailed educational content
    final double maxTextWidth = node.type == 'root' ? 240.0 : 200.0;

    final textPainter = TextPainter(
      text: TextSpan(
        text: node.label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontFamily: 'Inter',
          height: 1.35,
        ),
      ),
      textDirection: TextDirection.ltr,
      // Removed maxLines cap so height is measured accurately for ALL lines of text!
    )..layout(minWidth: 0, maxWidth: maxTextWidth);

    // Padding (horizontal: 12*2 = 24 + 12 safety = 36; vertical: 8*2 = 16 + 18 safety = 34)
    return Size(
      max(120.0, textPainter.size.width + 36.0),
      max(56.0, textPainter.size.height + 34.0),
    );
  }

  // Helper methods
  static Map<String, List<String>> _buildAdjacencyMap(List<MindMapEdge> edges) {
    final map = <String, List<String>>{};
    for (var edge in edges) {
      map.putIfAbsent(edge.idFrom, () => []).add(edge.idTo);
    }
    return map;
  }

  static Map<String, MindMapNode> _buildNodeMap(List<MindMapNode> nodes) {
    final map = <String, MindMapNode>{};
    for (var node in nodes) {
      map[node.id] = node;
    }
    return map;
  }

  static MindMapNode _findRoot(List<MindMapNode> nodes, List<MindMapEdge> edges) {
    // Find the root node (type == 'root', or the node with no incoming edges)
    final allTargets = edges.map((e) => e.idTo).toSet();
    for (var node in nodes) {
      if (!allTargets.contains(node.id)) return node;
    }

    for (var node in nodes) {
      if (node.type == 'root') return node;
    }

    return nodes.first; // fallback to the first node
  }

  // Hierarchical layout
  static void _layoutHierarchical(MindMapResponseData mindMapData) {
    if (mindMapData.nodes.isEmpty) return;
    final adjacency = _buildAdjacencyMap(mindMapData.edges);
    final nodeMap = _buildNodeMap(mindMapData.nodes);
    final root = _findRoot(mindMapData.nodes, mindMapData.edges);

    const double verticalSpacing = 160.0;

    // Calculate exact pixel width of each subtree to prevent overlapping
    Map<String, double> subtreeWidths = {};
    double calculateSubtreeWidth(String nodeId, Set<String> visited) {
      if (visited.contains(nodeId)) {
        return 0.0; // Avoid cycles or double-counting in DAGs
      }
      visited.add(nodeId);

      final node = nodeMap[nodeId]!;
      final children = adjacency[nodeId] ?? [];
      
      // Minimum width of this node itself + a gap
      final minWidth = node.size.width + 40.0; 

      if (children.isEmpty) {
        subtreeWidths[nodeId] = minWidth;
        return minWidth;
      }

      double totalChildrenWidth = 0;
      for (var childId in children) {
        if (!visited.contains(childId)) {
          totalChildrenWidth += calculateSubtreeWidth(childId, visited);
        }
      }
      
      double finalWidth = max(minWidth, totalChildrenWidth);
      subtreeWidths[nodeId] = finalWidth;
      return finalWidth;
    }

    Set<String> globalVisitedWidth = {};
    for (var node in mindMapData.nodes) {
       if (!globalVisitedWidth.contains(node.id)) {
           calculateSubtreeWidth(node.id, globalVisitedWidth);
       }
    }

    // Position each node using DFS 
    void positionNode(String nodeId, int depth, double xOffset, Set<String> visited) {
      if (visited.contains(nodeId)) return;
      visited.add(nodeId);

      final node = nodeMap[nodeId]!;
      final children = adjacency[nodeId] ?? [];
      final width = subtreeWidths[nodeId] ?? (node.size.width + 40.0);

      // Center the node within its allocated subtree width
      double centerX = xOffset + (width / 2) - (node.size.width / 2);
      double y = 80.0 + (depth * verticalSpacing);
      node.position = Offset(centerX, y);

      double childXOffset = xOffset;
      
      double totalChildrenWidth = 0;
      for (var childId in children) {
         if (!visited.contains(childId)) {
           totalChildrenWidth += subtreeWidths[childId] ?? 0;
         }
      }
      if (totalChildrenWidth < width) {
         childXOffset += (width - totalChildrenWidth) / 2;
      }

      // Position children side-by-side
      for (var childId in children) {
        if (!visited.contains(childId)) {
          double childWidth = subtreeWidths[childId] ?? 0;
          if (childWidth > 0) {
            positionNode(childId, depth + 1, childXOffset, visited);
            childXOffset += childWidth;
          }
        }
      }
    }

    Set<String> globalVisitedPosition = {};
    double currentRootX = 0.0;
    
    // First, position the main root tree
    positionNode(root.id, 0, currentRootX, globalVisitedPosition);
    currentRootX += subtreeWidths[root.id] ?? (root.size.width + 40.0);
    
    // Position any orphan nodes neatly in a secondary sub-row instead of a single long horizontal line
    final orphans = mindMapData.nodes.where((n) => !globalVisitedPosition.contains(n.id)).toList();
    if (orphans.isNotEmpty) {
      double orphanY = 80.0 + (3 * verticalSpacing);
      double orphanX = 100.0;
      for (int i = 0; i < orphans.length; i++) {
        orphans[i].position = Offset(orphanX, orphanY);
        orphanX += orphans[i].size.width + 40.0;
        if ((i + 1) % 4 == 0) {
          orphanX = 100.0;
          orphanY += verticalSpacing;
        }
      }
    }

    // Normalize coordinates
    _normalizePositions(mindMapData.nodes, 100, 80);
  }

  // Bubble Map (Bilateral Radial Arcs)
  static void _layoutBubble(MindMapResponseData data) {
    if (data.nodes.isEmpty) return;
    final adjacency = _buildAdjacencyMap(data.edges);
    final nodeMap = _buildNodeMap(data.nodes);
    final root = _findRoot(data.nodes, data.edges);
    
    final Offset center = const Offset(1000, 500);
    root.size = Size(root.size.width + 40, root.size.height + 20);
    root.position = Offset(center.dx - root.size.width / 2, center.dy - root.size.height / 2);

    final Set<String> visited = {root.id};
    final firstLevel = adjacency[root.id] ?? [];
    
    // Split first level into left and right hemispheres
    final leftNodes = <String>[];
    final rightNodes = <String>[];
    for (int i = 0; i < firstLevel.length; i++) {
      visited.add(firstLevel[i]);
      if (i % 2 == 0) {
        rightNodes.add(firstLevel[i]);
      } else {
        leftNodes.add(firstLevel[i]);
      }
    }

    void layoutHemisphere(List<String> nodes, bool isRight) {
      if (nodes.isEmpty) return;
      final double totalArc = 160.0 * (pi / 180.0);
      final double startAngle = isRight ? -totalArc / 2 : pi - (totalArc / 2);
      final double angleStep = nodes.length > 1 ? totalArc / (nodes.length - 1) : 0;
      final double radius = 340.0;

      for (int i = 0; i < nodes.length; i++) {
        double angle = startAngle + (i * angleStep);
        double x = center.dx + (radius * cos(angle));
        double y = center.dy + (radius * sin(angle));

        final child = nodeMap[nodes[i]]!;
        child.position = Offset(x - child.size.width / 2, y - child.size.height / 2);

        final secondLevel = adjacency[child.id] ?? [];
        if (secondLevel.isEmpty) continue;
        
        Offset childCenter = Offset(x, y);
        double subArc = 120.0 * (pi / 180.0);
        double baseAngle = atan2(y - center.dy, x - center.dx);
        double subStartAngle = baseAngle - (subArc / 2);
        double subStep = secondLevel.length > 1 ? subArc / (secondLevel.length - 1) : 0;
        double subRadius = 240.0;

        for (int j = 0; j < secondLevel.length; j++) {
          visited.add(secondLevel[j]);
          double subAngle = subStartAngle + (j * subStep);
          double sx = childCenter.dx + (subRadius * cos(subAngle));
          double sy = childCenter.dy + (subRadius * sin(subAngle));

          final subChild = nodeMap[secondLevel[j]]!;
          subChild.position = Offset(sx - subChild.size.width / 2, sy - subChild.size.height / 2);
        }
      }
    }

    layoutHemisphere(leftNodes, false);
    layoutHemisphere(rightNodes, true);

    // Position any orphan / unvisited nodes in an outer 360-degree orbit
    final unvisited = data.nodes.where((n) => !visited.contains(n.id)).toList();
    if (unvisited.isNotEmpty) {
      double orphanArc = 2 * pi;
      double orphanAngleStep = orphanArc / unvisited.length;
      double orphanRadius = 520.0;
      for (int i = 0; i < unvisited.length; i++) {
        double angle = i * orphanAngleStep;
        double ox = center.dx + (orphanRadius * cos(angle));
        double oy = center.dy + (orphanRadius * sin(angle));
        unvisited[i].position = Offset(ox - unvisited[i].size.width / 2, oy - unvisited[i].size.height / 2);
      }
    }

    _normalizePositions(data.nodes, 100, 100);
  }

  // Tree Map
  static void _layoutTreeMap(MindMapResponseData data) {
    if (data.nodes.isEmpty) return;
    final adjacency = _buildAdjacencyMap(data.edges);
    final nodeMap = _buildNodeMap(data.nodes);
    final root = _findRoot(data.nodes, data.edges);

    const double canvasWidth = 1600.0;
    const double canvasHeight = 900.0;
    const double padding = 6.0;
    root.position = const Offset(0, 0);
    root.size = const Size(canvasWidth, canvasHeight);

    void sliceRectangle(String nodeId, bool sliceVertically) {
      MindMapNode parent = nodeMap[nodeId]!;
      List<String> children = adjacency[nodeId] ?? [];
      if (children.isEmpty) return;
      
      double headerHeight = 30.0;
      double innerX = parent.position.dx + padding;
      double innerY = parent.position.dy + headerHeight + padding;
      double innerWidth = parent.size.width - (padding * 2);
      double innerHeight = parent.size.height - headerHeight - (padding * 2);

      if (innerWidth <= 0 || innerHeight <= 0) return;

      for (int i = 0; i < children.length; i++) {
        MindMapNode child = nodeMap[children[i]]!;
        double childWidth, childHeight, startX, startY;
        if (sliceVertically) {
          childWidth = innerWidth / children.length;
          childHeight = innerHeight;
          startX = innerX + (i * childWidth);
          startY = innerY;
        } else {
          childWidth = innerWidth;
          childHeight = innerHeight / children.length;
          startX = innerX;
          startY = innerY + (i * childHeight);
        }

        child.position = Offset(startX, startY);
        child.size = Size(childWidth, childHeight);

        sliceRectangle(child.id, !sliceVertically);
      }
    }
    sliceRectangle(root.id, true);
  }

  // Concept Map (Force-Directed Web Layout with Central Gravity)
  static void _layoutConcept(MindMapResponseData data) {
    if (data.nodes.isEmpty) return;

    const double k = 220.0; // Optimal distance between connected nodes
    const double repulsionK = 28000.0; // Repulsion constant
    const int iterations = 70;
    const double initialTemperature = 120.0;
    final Offset graphCenter = const Offset(500, 500);
    
    final random = Random(42);
    for (var node in data.nodes) {
      node.position = Offset(
        graphCenter.dx + (random.nextDouble() - 0.5) * 600,
        graphCenter.dy + (random.nextDouble() - 0.5) * 600,
      );
    }

    double temperature = initialTemperature;

    for (int iter = 0; iter < iterations; iter++) {
      Map<String, Offset> displacements = {
        for (var node in data.nodes) node.id: Offset.zero
      };

      // 1. Calculate Repulsive forces between all node pairs
      for (int i = 0; i < data.nodes.length; i++) {
        for (int j = i + 1; j < data.nodes.length; j++) {
          final u = data.nodes[i];
          final v = data.nodes[j];
          
          Offset delta = u.position - v.position;
          double distance = delta.distance;
          if (distance == 0) distance = 0.01;

          double force = repulsionK / distance;
          Offset displacement = (delta / distance) * force;

          displacements[u.id] = displacements[u.id]! + displacement;
          displacements[v.id] = displacements[v.id]! - displacement;
        }
      }

      // 2. Calculate Attractive forces along edges
      for (var edge in data.edges) {
        final u = data.nodes.firstWhere((n) => n.id == edge.idFrom, orElse: () => data.nodes.first);
        final v = data.nodes.firstWhere((n) => n.id == edge.idTo, orElse: () => data.nodes.first);
        
        Offset delta = u.position - v.position;
        double distance = delta.distance;
        if (distance == 0) distance = 0.01;

        double force = (distance * distance) / k;
        Offset displacement = (delta / distance) * force;

        displacements[u.id] = displacements[u.id]! - displacement;
        displacements[v.id] = displacements[v.id]! + displacement;
      }

      // 3. Central Gravity force (prevents orphan / disconnected nodes from floating off)
      for (var node in data.nodes) {
        Offset centerDelta = graphCenter - node.position;
        double centerDist = centerDelta.distance;
        if (centerDist > 0) {
          Offset gravity = (centerDelta / centerDist) * (centerDist * 0.08);
          displacements[node.id] = displacements[node.id]! + gravity;
        }
      }

      // 4. Apply displacements bounded by temperature
      for (var node in data.nodes) {
        Offset disp = displacements[node.id]!;
        double dist = disp.distance;
        if (dist > 0) {
          double cappedDist = min(dist, temperature);
          node.position += (disp / dist) * cappedDist;
        }
      }

      temperature *= 0.94;
    }
    
    _normalizePositions(data.nodes, 100, 100);
  }

  // Normalizes positions so the top-left node is at (minX, minY)
  static void _normalizePositions(List<MindMapNode> nodes, double minX, double minY) {
    if (nodes.isEmpty) return;
    double currentMinX = double.infinity;
    double currentMinY = double.infinity;
    for (var node in nodes) {
      if (node.position.dx < currentMinX) currentMinX = node.position.dx;
      if (node.position.dy < currentMinY) currentMinY = node.position.dy;
    }

    double shiftX = minX - currentMinX;
    double shiftY = minY - currentMinY;

    for (var node in nodes) {
      node.position = Offset(node.position.dx + shiftX, node.position.dy + shiftY);
    }
  }
}