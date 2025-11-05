import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:image_gallery_saver/image_gallery_saver.dart';

void main() {
  runApp(const PixelArtApp());
}

class PixelArtApp extends StatelessWidget {
  const PixelArtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pixel Art Painter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF87AE73), // Sage green
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const PixelArtPainter(),
      debugShowCheckedModeBanner: false,
    );
  }
}

enum ToolType {
  brush,
  eraser,
  fill,
  eyedropper,
  line,
  rectangle,
  circle,
  select,
}

enum SymmetryMode { none, vertical, horizontal, both }

class Layer {
  String name;
  List<List<Color?>> pixels;
  bool isVisible;
  double opacity;

  Layer({
    required this.name,
    required List<List<Color?>> initialPixels,
    this.isVisible = true,
    this.opacity = 1.0,
  }) : pixels = initialPixels.map((row) => List<Color?>.from(row)).toList();
}

class PixelArtPainter extends StatefulWidget {
  const PixelArtPainter({super.key});

  @override
  State<PixelArtPainter> createState() => _PixelArtPainterState();
}

class _PixelArtPainterState extends State<PixelArtPainter> {
  // Canvas dimensions - now configurable
  int gridSize = 32;

  // Current selected color
  Color selectedColor = Colors.black;

  // Layer system
  List<Layer> layers = [];
  int activeLayerIndex = 0;

  // Canvas data: gridSize x gridSize grid (deprecated, use layers instead)
  late List<List<Color?>> pixels;

  // Get active layer (with bounds checking)
  Layer get _activeLayer {
    if (layers.isEmpty) {
      // Fallback: initialize if empty (shouldn't happen, but safety check)
      _initializeCanvas();
    }
    if (activeLayerIndex < 0 || activeLayerIndex >= layers.length) {
      activeLayerIndex = 0;
    }
    return layers[activeLayerIndex];
  }

  List<List<Color?>> get _activePixels => _activeLayer.pixels;

  // Undo/Redo system
  final List<List<List<Color?>>> _history = [];
  final List<List<List<Color?>>> _redoHistory = [];
  static const int _maxHistorySize = 50;

  // Tool modes
  ToolType currentTool = ToolType.brush;

  // Drawing state for line and rectangle tools
  int? _startRow;
  int? _startCol;

  // Color history (recent colors)
  final List<Color> _colorHistory = [];
  static const int _maxColorHistory = 8;

  // Zoom level
  double _zoomLevel = 1.0;
  double _initialZoomLevel = 1.0;

  // Advanced features
  SymmetryMode _symmetryMode = SymmetryMode.none;
  bool _showGrid = true;
  int _brushSize = 1; // 1x1, 2x2, or 3x3
  List<List<Color?>>? _copiedPixels;
  bool _hasCopiedPixels = false;

  // Common colors palette
  final List<Color> palette = [
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.yellow,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.brown,
    Colors.grey,
    Colors.cyan,
    Colors.lime,
    Colors.indigo,
    Colors.teal,
    Colors.amber,
  ];

  @override
  void initState() {
    super.initState();
    _initializeCanvas();
  }

  void _initializeCanvas() {
    pixels = List.generate(
      gridSize,
      (_) => List<Color?>.generate(gridSize, (_) => null),
    );
    // Initialize with one layer
    layers = [
      Layer(
        name: 'Layer 1',
        initialPixels: List.generate(
          gridSize,
          (_) => List<Color?>.generate(gridSize, (_) => null),
        ),
      ),
    ];
    activeLayerIndex = 0;
    _saveToHistory();
  }

  void _addLayer() {
    if (!mounted) return;
    setState(() {
      layers.add(
        Layer(
          name: 'Layer ${layers.length + 1}',
          initialPixels: List.generate(
            gridSize,
            (_) => List<Color?>.generate(gridSize, (_) => null),
          ),
        ),
      );
      activeLayerIndex = layers.length - 1;
      // Ensure activeLayerIndex is valid
      if (activeLayerIndex < 0 || activeLayerIndex >= layers.length) {
        activeLayerIndex = 0;
      }
      _saveToHistory();
    });
  }

  void _deleteLayer(int index) {
    if (!mounted) return;
    if (layers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the last layer!'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      final wasActive = index == activeLayerIndex;
      layers.removeAt(index);
      // Adjust activeLayerIndex after deletion
      if (wasActive) {
        // If deleted layer was active, select the previous layer or first layer
        activeLayerIndex = index > 0 ? index - 1 : 0;
      } else if (index < activeLayerIndex) {
        // If deleted layer was before active, adjust index
        activeLayerIndex--;
      }
      // Ensure activeLayerIndex is valid
      if (activeLayerIndex >= layers.length) {
        activeLayerIndex = layers.length - 1;
      }
      if (activeLayerIndex < 0) activeLayerIndex = 0;
      _saveToHistory();
    });
  }

  void _moveLayer(int index, int direction) {
    if (!mounted) return;
    // direction: -1 for up, 1 for down
    if ((direction == -1 && index == 0) ||
        (direction == 1 && index == layers.length - 1)) {
      return;
    }
    setState(() {
      final newIndex = index + direction;
      final layer = layers.removeAt(index);
      layers.insert(newIndex, layer);
      // Update activeLayerIndex to follow the moved layer
      if (activeLayerIndex == index) {
        activeLayerIndex = newIndex;
      } else if (direction == -1 &&
          activeLayerIndex == newIndex &&
          activeLayerIndex < index) {
        // Layer moved up and active was at new position
        activeLayerIndex = index;
      } else if (direction == 1 &&
          activeLayerIndex == newIndex &&
          activeLayerIndex > index) {
        // Layer moved down and active was at new position
        activeLayerIndex = index;
      }
      // Ensure activeLayerIndex is valid
      if (activeLayerIndex < 0 || activeLayerIndex >= layers.length) {
        activeLayerIndex = 0;
      }
      _saveToHistory();
    });
  }

  void _toggleLayerVisibility(int index) {
    setState(() {
      layers[index].isVisible = !layers[index].isVisible;
      _saveToHistory();
    });
  }

  List<List<Color?>> _compositeLayers() {
    // Composite all visible layers into a single canvas
    final List<List<Color?>> composite = List.generate(
      gridSize,
      (_) => List<Color?>.generate(gridSize, (_) => null),
    );

    for (var layer in layers) {
      if (!layer.isVisible) continue;
      for (int r = 0; r < gridSize; r++) {
        for (int c = 0; c < gridSize; c++) {
          final layerColor = layer.pixels[r][c];
          if (layerColor != null) {
            if (composite[r][c] == null) {
              composite[r][c] = layerColor;
            } else {
              // Blend with opacity
              final existing = composite[r][c]!;
              final blended = Color.lerp(existing, layerColor, layer.opacity);
              composite[r][c] = blended ?? layerColor;
            }
          }
        }
      }
    }

    return composite;
  }

  void _saveToHistory() {
    // Save current state of active layer to history
    if (layers.isEmpty) return;
    // Ensure activeLayerIndex is valid
    if (activeLayerIndex < 0 || activeLayerIndex >= layers.length) {
      activeLayerIndex = 0;
    }
    final snapshot = _activePixels
        .map((row) => List<Color?>.from(row))
        .toList();
    _history.add(snapshot);
    if (_history.length > _maxHistorySize) {
      _history.removeAt(0);
    }
    // Clear redo history when new action is performed
    _redoHistory.clear();
  }

  void _undo() {
    if (_history.length > 1) {
      // Move current state to redo
      _redoHistory.add(_history.removeLast());
      if (_redoHistory.length > _maxHistorySize) {
        _redoHistory.removeAt(0);
      }
      // Restore previous state to active layer
      _activeLayer.pixels = _history.last
          .map((row) => List<Color?>.from(row))
          .toList();
      setState(() {});
    }
  }

  void _redo() {
    if (_redoHistory.isNotEmpty) {
      // Restore from redo history to active layer
      _activeLayer.pixels = _redoHistory
          .removeLast()
          .map((row) => List<Color?>.from(row))
          .toList();
      _history.add(_activePixels.map((row) => List<Color?>.from(row)).toList());
      setState(() {});
    }
  }

  void _addToColorHistory(Color color) {
    if (!_colorHistory.contains(color)) {
      _colorHistory.insert(0, color);
      if (_colorHistory.length > _maxColorHistory) {
        _colorHistory.removeLast();
      }
    } else {
      _colorHistory.remove(color);
      _colorHistory.insert(0, color);
    }
  }

  void _onPixelTapped(int row, int col) {
    if (currentTool == ToolType.eyedropper) {
      // Get color from composite for eyedropper
      final composite = _compositeLayers();
      final color = composite[row][col];
      if (color != null) {
        setState(() {
          selectedColor = color;
          _addToColorHistory(color);
          currentTool = ToolType.brush;
        });
      }
      return;
    }

    if (currentTool == ToolType.fill) {
      _fillArea(row, col);
      _saveToHistory();
      return;
    }

    if (currentTool == ToolType.line ||
        currentTool == ToolType.rectangle ||
        currentTool == ToolType.circle) {
      if (_startRow == null || _startCol == null) {
        setState(() {
          _startRow = row;
          _startCol = col;
        });
      } else {
        if (currentTool == ToolType.line) {
          _drawLine(_startRow!, _startCol!, row, col);
        } else if (currentTool == ToolType.rectangle) {
          _drawRectangle(_startRow!, _startCol!, row, col);
        } else if (currentTool == ToolType.circle) {
          _drawCircle(_startRow!, _startCol!, row, col);
        }
        _saveToHistory();
        setState(() {
          _startRow = null;
          _startCol = null;
        });
      }
      return;
    }

    setState(() {
      _drawWithBrush(row, col);
      if (currentTool == ToolType.brush) {
        _addToColorHistory(selectedColor);
      }
    });
    _saveToHistory();
  }

  void _onPixelDragged(int row, int col) {
    if (currentTool == ToolType.fill ||
        currentTool == ToolType.eyedropper ||
        currentTool == ToolType.line ||
        currentTool == ToolType.rectangle ||
        currentTool == ToolType.circle ||
        currentTool == ToolType.select) {
      return;
    }

    setState(() {
      _drawWithBrush(row, col);
    });
  }

  void _drawWithBrush(int row, int col) {
    // Draw with brush size on active layer
    for (int dr = -(_brushSize - 1) ~/ 2; dr <= (_brushSize - 1) ~/ 2; dr++) {
      for (int dc = -(_brushSize - 1) ~/ 2; dc <= (_brushSize - 1) ~/ 2; dc++) {
        int r = row + dr;
        int c = col + dc;
        if (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
          if (currentTool == ToolType.eraser) {
            _activePixels[r][c] = null;
          } else {
            _activePixels[r][c] = selectedColor;
          }
          // Apply symmetry
          _applySymmetry(r, c);
        }
      }
    }
  }

  void _applySymmetry(int row, int col) {
    if (_symmetryMode == SymmetryMode.none) return;

    final Color? color = _activePixels[row][col];

    if (_symmetryMode == SymmetryMode.vertical ||
        _symmetryMode == SymmetryMode.both) {
      int symCol = gridSize - 1 - col;
      if (symCol != col && symCol >= 0 && symCol < gridSize) {
        _activePixels[row][symCol] = color;
      }
    }

    if (_symmetryMode == SymmetryMode.horizontal ||
        _symmetryMode == SymmetryMode.both) {
      int symRow = gridSize - 1 - row;
      if (symRow != row && symRow >= 0 && symRow < gridSize) {
        _activePixels[symRow][col] = color;
      }

      // For both, also mirror diagonally
      if (_symmetryMode == SymmetryMode.both) {
        int symRow = gridSize - 1 - row;
        int symCol = gridSize - 1 - col;
        if ((symRow != row || symCol != col) &&
            symRow >= 0 &&
            symRow < gridSize &&
            symCol >= 0 &&
            symCol < gridSize) {
          _activePixels[symRow][symCol] = color;
        }
      }
    }
  }

  void _fillArea(int startRow, int startCol) {
    final targetColor = _activePixels[startRow][startCol];
    final Color fillColor = selectedColor;

    // If filling with the same color, do nothing
    if (targetColor == fillColor) return;

    // Flood fill algorithm
    final queue = <List<int>>[];
    queue.add([startRow, startCol]);
    final visited = <String>{};

    while (queue.isNotEmpty) {
      final pos = queue.removeAt(0);
      final r = pos[0];
      final c = pos[1];
      final key = '$r,$c';

      if (visited.contains(key)) continue;
      if (r < 0 || r >= gridSize || c < 0 || c >= gridSize) continue;
      if (_activePixels[r][c] != targetColor) continue;

      visited.add(key);
      _activePixels[r][c] = fillColor;

      queue.add([r + 1, c]);
      queue.add([r - 1, c]);
      queue.add([r, c + 1]);
      queue.add([r, c - 1]);
    }

    setState(() {});
  }

  void _drawLine(int r1, int c1, int r2, int c2) {
    // Bresenham's line algorithm
    int x0 = c1, y0 = r1, x1 = c2, y1 = r2;
    int dx = (x1 - x0).abs();
    int dy = (y1 - y0).abs();
    int sx = x0 < x1 ? 1 : -1;
    int sy = y0 < y1 ? 1 : -1;
    int err = dx - dy;

    while (true) {
      if (y0 >= 0 && y0 < gridSize && x0 >= 0 && x0 < gridSize) {
        _activePixels[y0][x0] = currentTool == ToolType.eraser
            ? null
            : selectedColor;
        _applySymmetry(y0, x0);
      }

      if (x0 == x1 && y0 == y1) break;
      int e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x0 += sx;
      }
      if (e2 < dx) {
        err += dx;
        y0 += sy;
      }
    }

    setState(() {});
  }

  void _drawRectangle(int r1, int c1, int r2, int c2) {
    final minR = r1 < r2 ? r1 : r2;
    final maxR = r1 > r2 ? r1 : r2;
    final minC = c1 < c2 ? c1 : c2;
    final maxC = c1 > c2 ? c1 : c2;

    final Color? fillColor = currentTool == ToolType.eraser
        ? null
        : selectedColor;

    for (int r = minR; r <= maxR; r++) {
      for (int c = minC; c <= maxC; c++) {
        if (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
          _activePixels[r][c] = fillColor;
          _applySymmetry(r, c);
        }
      }
    }

    setState(() {});
  }

  void _drawCircle(int r1, int c1, int r2, int c2) {
    // Calculate radius from center and end point
    int centerX = c1;
    int centerY = r1;
    double radius = math.sqrt((c2 - c1) * (c2 - c1) + (r2 - r1) * (r2 - r1));

    final Color? fillColor = currentTool == ToolType.eraser
        ? null
        : selectedColor;

    // Draw circle using midpoint algorithm
    int radiusInt = radius.round();
    for (int y = -radiusInt; y <= radiusInt; y++) {
      for (int x = -radiusInt; x <= radiusInt; x++) {
        double dist = math.sqrt(x * x + y * y);
        if ((dist - radius).abs() < 0.5) {
          int r = centerY + y;
          int c = centerX + x;
          if (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
            _activePixels[r][c] = fillColor;
            _applySymmetry(r, c);
          }
        }
      }
    }

    setState(() {});
  }

  void _clearCanvas() {
    setState(() {
      for (int r = 0; r < gridSize; r++) {
        for (int c = 0; c < gridSize; c++) {
          _activePixels[r][c] = null;
        }
      }
      _saveToHistory();
    });
  }

  void _copyCanvas() {
    setState(() {
      _copiedPixels = _compositeLayers();
      _hasCopiedPixels = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Canvas copied!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _pasteCanvas() {
    if (!_hasCopiedPixels || _copiedPixels == null) return;

    setState(() {
      // Resize if needed
      final copiedSize = _copiedPixels!.length;
      if (copiedSize != gridSize) {
        // Resize copied pixels to match current grid
        final List<List<Color?>> resized = List.generate(
          gridSize,
          (r) => List.generate(gridSize, (c) {
            if (r < copiedSize && c < copiedSize) {
              return _copiedPixels![r][c];
            }
            return null;
          }),
        );
        // Paste to active layer
        for (int r = 0; r < gridSize && r < resized.length; r++) {
          for (int c = 0; c < gridSize && c < resized[r].length; c++) {
            _activePixels[r][c] = resized[r][c];
          }
        }
      } else {
        // Paste to active layer
        for (int r = 0; r < gridSize && r < _copiedPixels!.length; r++) {
          for (int c = 0; c < gridSize && c < _copiedPixels![r].length; c++) {
            _activePixels[r][c] = _copiedPixels![r][c];
          }
        }
      }
      _saveToHistory();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Canvas pasted!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _changeGridSize(int newSize) {
    setState(() {
      final oldSize = gridSize;
      gridSize = newSize;

      // Create new canvas
      final List<List<Color?>> newPixels = List.generate(
        gridSize,
        (_) => List<Color?>.generate(gridSize, (_) => null),
      );

      // Resize all layers
      for (var layer in layers) {
        final oldLayerPixels = layer.pixels;
        final newLayerPixels = List.generate(
          gridSize,
          (_) => List<Color?>.generate(gridSize, (_) => null),
        );

        if (oldSize <= gridSize) {
          for (int r = 0; r < oldSize && r < gridSize; r++) {
            for (int c = 0; c < oldSize && c < gridSize; c++) {
              newLayerPixels[r][c] = oldLayerPixels[r][c];
            }
          }
        } else {
          for (int r = 0; r < gridSize; r++) {
            for (int c = 0; c < gridSize; c++) {
              newLayerPixels[r][c] = oldLayerPixels[r][c];
            }
          }
        }
        layer.pixels = newLayerPixels;
      }

      pixels = newPixels;
      _history.clear();
      _redoHistory.clear();
      _saveToHistory();
      _startRow = null;
      _startCol = null;
    });
  }

  void _pickCustomColor() async {
    final Color? pickedColor = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(initialColor: selectedColor),
    );
    if (pickedColor != null) {
      setState(() {
        selectedColor = pickedColor;
        _addToColorHistory(pickedColor);
        currentTool = ToolType.brush;
      });
    }
  }

  Future<void> _saveImage() async {
    try {
      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Create a picture recorder
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Calculate pixel size based on a fixed canvas size
      const double canvasSize = 512.0;
      final double pixelSize = canvasSize / gridSize;

      // Draw white background
      canvas.drawRect(
        Rect.fromLTWH(0, 0, canvasSize, canvasSize),
        Paint()..color = Colors.white,
      );

      // Draw pixels from composite layers
      final composite = _compositeLayers();
      for (int row = 0; row < gridSize; row++) {
        for (int col = 0; col < gridSize; col++) {
          final color = composite[row][col];
          if (color != null) {
            canvas.drawRect(
              Rect.fromLTWH(
                col * pixelSize,
                row * pixelSize,
                pixelSize,
                pixelSize,
              ),
              Paint()..color = color,
            );
          }
        }
      }

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        canvasSize.toInt(),
        canvasSize.toInt(),
      );
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();

        // Save to gallery
        final result = await ImageGallerySaver.saveImage(
          pngBytes,
          quality: 100,
          name: 'pixel_art_${DateTime.now().millisecondsSinceEpoch}',
        );

        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
        }

        // Show success message
        if (mounted) {
          final String message = result['isSuccess'] == true
              ? 'Image saved to gallery successfully!'
              : 'Failed to save image.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: result['isSuccess'] == true
                  ? Colors.green
                  : Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to generate image data.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving image: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildSymmetryButton(String label, SymmetryMode mode, IconData icon) {
    final isSelected = _symmetryMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _symmetryMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF87AE73).withValues(alpha: 0.2)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF87AE73) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? const Color(0xFF87AE73)
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFF87AE73)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _flipHorizontal() {
    final newPixels = List.generate(
      gridSize,
      (r) => List<Color?>.generate(
        gridSize,
        (c) => _activePixels[r][gridSize - 1 - c],
      ),
    );
    _activeLayer.pixels = newPixels;
    setState(() {});
  }

  void _flipVertical() {
    final newPixels = List.generate(
      gridSize,
      (r) => List<Color?>.generate(
        gridSize,
        (c) => _activePixels[gridSize - 1 - r][c],
      ),
    );
    _activeLayer.pixels = newPixels;
    setState(() {});
  }

  void _rotate90() {
    final newPixels = List.generate(
      gridSize,
      (r) => List<Color?>.generate(
        gridSize,
        (c) => _activePixels[gridSize - 1 - c][r],
      ),
    );
    _activeLayer.pixels = newPixels;
    setState(() {});
  }

  void _rotate180() {
    final newPixels = List.generate(
      gridSize,
      (r) => List<Color?>.generate(
        gridSize,
        (c) => _activePixels[gridSize - 1 - r][gridSize - 1 - c],
      ),
    );
    _activeLayer.pixels = newPixels;
    setState(() {});
  }

  void _rotate270() {
    final newPixels = List.generate(
      gridSize,
      (r) => List<Color?>.generate(
        gridSize,
        (c) => _activePixels[c][gridSize - 1 - r],
      ),
    );
    _activeLayer.pixels = newPixels;
    setState(() {});
  }

  Widget _buildToolButton(IconData icon, ToolType tool, String tooltip) {
    final isSelected = currentTool == tool;
    Color iconColor = Colors.grey.shade600;

    if (isSelected) {
      if (tool == ToolType.eraser) {
        iconColor = Colors.red.shade700;
      } else if (tool == ToolType.brush) {
        iconColor = selectedColor;
      } else {
        iconColor = const Color(0xFF87AE73);
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                colors: [
                  iconColor.withValues(alpha: 0.2),
                  iconColor.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: iconColor.withValues(alpha: 0.3), width: 2)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() {
            currentTool = tool;
            _startRow = null;
            _startCol = null;
          }),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: iconColor, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildLayerThumbnail(Layer layer, int gridSize) {
    // Sample pixels for thumbnail (use a reduced resolution)
    const int thumbSize = 16;
    final double pixelSize = 60.0 / thumbSize;

    return CustomPaint(
      size: const Size(60, 60),
      painter: LayerThumbnailPainter(
        layer: layer,
        gridSize: gridSize,
        thumbSize: thumbSize,
        pixelSize: pixelSize,
      ),
    );
  }

  void _showLayerPanel() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isDesktop = screenWidth >= 1200;

    // Adjust bottom sheet size based on device type
    double initialSize = 0.7;
    double minSize = 0.5;
    double maxSize = 0.9;

    if (isDesktop) {
      initialSize = 0.5;
      minSize = 0.4;
      maxSize = 0.7;
    } else if (isTablet) {
      initialSize = 0.6;
      minSize = 0.45;
      maxSize = 0.85;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: initialSize,
        minChildSize: minSize,
        maxChildSize: maxSize,
        expand: false,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setModalState) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF87AE73), Color(0xFFA8C097)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.layers_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Layer Management',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '${layers.length} ${layers.length == 1 ? "layer" : "layers"}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: layers.length,
                    itemBuilder: (context, index) {
                      final layer = layers[index];
                      final isActive = index == activeLayerIndex;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          gradient: isActive
                              ? LinearGradient(
                                  colors: [
                                    const Color(
                                      0xFF87AE73,
                                    ).withValues(alpha: 0.15),
                                    const Color(
                                      0xFFA8C097,
                                    ).withValues(alpha: 0.1),
                                  ],
                                )
                              : null,
                          color: isActive ? null : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFF87AE73)
                                : Colors.grey.shade300,
                            width: isActive ? 2.5 : 1.5,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: GestureDetector(
                            onTap: () {
                              _toggleLayerVisibility(index);
                              setModalState(() {});
                            },
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Stack(
                                  children: [
                                    _buildLayerThumbnail(layer, gridSize),
                                    if (!layer.isVisible)
                                      Container(
                                        color: Colors.black.withValues(
                                          alpha: 0.6,
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.visibility_off_rounded,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    if (isActive)
                                      const Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Icon(
                                          Icons.check_circle,
                                          color: Color(0xFF87AE73),
                                          size: 20,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            layer.name,
                            style: TextStyle(
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isActive
                                  ? const Color(0xFF87AE73)
                                  : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            isActive ? 'Active Layer' : 'Tap to activate',
                            style: TextStyle(
                              fontSize: 11,
                              color: isActive
                                  ? const Color(0xFF87AE73)
                                  : Colors.grey.shade600,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  layer.isVisible
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                  color: layer.isVisible
                                      ? const Color(0xFF87AE73)
                                      : Colors.grey,
                                ),
                                onPressed: () {
                                  _toggleLayerVisibility(index);
                                  setModalState(() {});
                                },
                              ),
                              if (index > 0)
                                IconButton(
                                  icon: const Icon(Icons.arrow_upward_rounded),
                                  onPressed: () {
                                    _moveLayer(index, -1);
                                    setModalState(() {});
                                  },
                                ),
                              if (index < layers.length - 1)
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_downward_rounded,
                                  ),
                                  onPressed: () {
                                    _moveLayer(index, 1);
                                    setModalState(() {});
                                  },
                                ),
                              if (layers.length > 1)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_rounded,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    _deleteLayer(index);
                                    setModalState(() {});
                                  },
                                ),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              if (index >= 0 && index < layers.length) {
                                activeLayerIndex = index;
                              }
                            });
                            setModalState(() {});
                          },
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _addLayer();
                        // Update the modal state to reflect new layer
                        setModalState(() {});
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add New Layer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF87AE73),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth >= 600;
    final isDesktop = screenWidth >= 1200;
    final isLandscape = screenWidth > screenHeight;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF87AE73), const Color(0xFFA8C097)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.palette, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              isTablet ? 'Pixel Art Studio' : 'Pixel Art',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        actions: [
          // Always show grid size
          PopupMenuButton<int>(
            icon: const Icon(Icons.grid_on),
            tooltip: 'Grid Size',
            onSelected: _changeGridSize,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 16, child: Text('16x16')),
              const PopupMenuItem(value: 32, child: Text('32x32')),
              const PopupMenuItem(value: 64, child: Text('64x64')),
            ],
          ),
          // Show undo/redo on all devices
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _history.length > 1 ? _undo : null,
            tooltip: 'Undo',
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: _redoHistory.isNotEmpty ? _redo : null,
            tooltip: 'Redo',
          ),
          // Show save on all devices
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveImage,
            tooltip: 'Save Image',
          ),
          // Show copy/paste on tablets and larger
          if (isTablet) ...[
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: _copyCanvas,
              tooltip: 'Copy Canvas',
            ),
            IconButton(
              icon: const Icon(Icons.paste),
              onPressed: _hasCopiedPixels ? _pasteCanvas : null,
              tooltip: 'Paste Canvas',
            ),
          ],
          // Always show layers
          IconButton(
            icon: const Icon(Icons.layers_rounded),
            onPressed: _showLayerPanel,
            tooltip: 'Layer Management',
          ),
          // Show overflow menu on small screens for copy/paste
          if (!isTablet)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More',
              onSelected: (value) {
                if (value == 'copy') _copyCanvas();
                if (value == 'paste') _pasteCanvas();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'copy',
                  child: const Row(
                    children: [
                      Icon(Icons.copy, size: 20),
                      SizedBox(width: 8),
                      Text('Copy Canvas'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'paste',
                  enabled: _hasCopiedPixels,
                  child: const Row(
                    children: [
                      Icon(Icons.paste, size: 20),
                      SizedBox(width: 8),
                      Text('Paste Canvas'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Toolbar
            Container(
              margin: EdgeInsets.all(isTablet ? 16 : 12),
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 12,
                vertical: isTablet ? 12 : 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildToolButton(Icons.brush, ToolType.brush, 'Brush'),
                    _buildToolButton(
                      Icons.auto_fix_high,
                      ToolType.eraser,
                      'Eraser',
                    ),
                    _buildToolButton(
                      Icons.format_color_fill,
                      ToolType.fill,
                      'Fill',
                    ),
                    _buildToolButton(
                      Icons.colorize,
                      ToolType.eyedropper,
                      'Eyedropper',
                    ),
                    _buildToolButton(Icons.show_chart, ToolType.line, 'Line'),
                    _buildToolButton(
                      Icons.crop_square,
                      ToolType.rectangle,
                      'Rectangle',
                    ),
                    _buildToolButton(
                      Icons.radio_button_unchecked,
                      ToolType.circle,
                      'Circle',
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _clearCanvas,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              Icons.clear_all,
                              color: Colors.red.shade600,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _pickCustomColor,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              selectedColor,
                              selectedColor.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.2),
                            width: 2.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: selectedColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.color_lens,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Color history
            if (_colorHistory.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 5,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                height: 48,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Recent',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _colorHistory.length,
                        itemBuilder: (context, index) {
                          final color = _colorHistory[index];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedColor = color;
                                currentTool = ToolType.brush;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                border: Border.all(
                                  color: selectedColor == color
                                      ? Colors.black
                                      : Colors.grey.shade300,
                                  width: selectedColor == color ? 3 : 1.5,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: selectedColor == color
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.4),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            // Color palette
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: palette.map((color) {
                    final isSelected =
                        color == selectedColor &&
                        currentTool != ToolType.eraser &&
                        currentTool != ToolType.eyedropper;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedColor = color;
                          currentTool = ToolType.brush;
                          _addToColorHistory(color);
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: isSelected ? 44 : 40,
                        height: isSelected ? 44 : 40,
                        decoration: BoxDecoration(
                          color: color,
                          border: Border.all(
                            color: isSelected
                                ? Colors.black
                                : Colors.grey.shade300,
                            width: isSelected ? 3 : 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                    spreadRadius: 1,
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            // Tool instructions
            if (currentTool == ToolType.line ||
                currentTool == ToolType.rectangle ||
                currentTool == ToolType.circle)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF87AE73).withValues(alpha: 0.1),
                      const Color(0xFFA8C097).withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF87AE73).withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF87AE73).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Color(0xFF87AE73),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _startRow == null
                          ? 'Tap to set start point'
                          : 'Tap to set end point',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF87AE73),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            // Canvas
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate optimal canvas size based on available space
                    final double availableWidth =
                        constraints.maxWidth -
                        (isTablet ? 64 : 32); // Account for margins
                    final double availableHeight =
                        constraints.maxHeight - (isTablet ? 64 : 32);
                    final double maxCanvasSize = math.min(
                      availableWidth,
                      availableHeight,
                    );
                    // Adjust max canvas size based on device type
                    double maxCanvas = 800.0;
                    if (isDesktop) {
                      maxCanvas = 1000.0;
                    } else if (isTablet) {
                      maxCanvas = 700.0;
                    } else {
                      maxCanvas = isLandscape ? 600.0 : 400.0;
                    }
                    final double canvasSize = math.min(
                      maxCanvasSize,
                      maxCanvas,
                    );

                    return Container(
                      width: canvasSize,
                      height: canvasSize,
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: LayoutBuilder(
                            builder: (context, innerConstraints) {
                              final double actualCanvasSize =
                                  innerConstraints.maxWidth;
                              final double basePixelSize =
                                  actualCanvasSize / gridSize;
                              return GestureDetector(
                                onScaleStart: (details) {
                                  _initialZoomLevel = _zoomLevel;
                                  if (details.pointerCount == 1) {
                                    final Offset localPosition =
                                        details.localFocalPoint;
                                    final double centerX =
                                        innerConstraints.maxWidth / 2;
                                    final double centerY =
                                        innerConstraints.maxHeight / 2;
                                    final double translatedX =
                                        (localPosition.dx - centerX) /
                                            _zoomLevel +
                                        centerX;
                                    final double translatedY =
                                        (localPosition.dy - centerY) /
                                            _zoomLevel +
                                        centerY;
                                    final int col =
                                        (translatedX / basePixelSize).floor();
                                    final int row =
                                        (translatedY / basePixelSize).floor();
                                    if (row >= 0 &&
                                        row < gridSize &&
                                        col >= 0 &&
                                        col < gridSize) {
                                      _onPixelTapped(row, col);
                                    }
                                  }
                                },
                                onScaleUpdate: (details) {
                                  if (details.pointerCount > 1) {
                                    setState(() {
                                      _zoomLevel =
                                          (_initialZoomLevel * details.scale)
                                              .clamp(0.5, 3.0);
                                    });
                                  } else if (details.pointerCount == 1 &&
                                      details.scale == 1.0) {
                                    final Offset localPosition =
                                        details.localFocalPoint;
                                    final double centerX =
                                        innerConstraints.maxWidth / 2;
                                    final double centerY =
                                        innerConstraints.maxHeight / 2;
                                    final double translatedX =
                                        (localPosition.dx - centerX) /
                                            _zoomLevel +
                                        centerX;
                                    final double translatedY =
                                        (localPosition.dy - centerY) /
                                            _zoomLevel +
                                        centerY;
                                    final int col =
                                        (translatedX / basePixelSize).floor();
                                    final int row =
                                        (translatedY / basePixelSize).floor();
                                    if (row >= 0 &&
                                        row < gridSize &&
                                        col >= 0 &&
                                        col < gridSize) {
                                      _onPixelDragged(row, col);
                                    }
                                  }
                                },
                                child: Center(
                                  child: Transform.scale(
                                    scale: _zoomLevel,
                                    child: SizedBox(
                                      width: actualCanvasSize,
                                      height: actualCanvasSize,
                                      child: CustomPaint(
                                        painter: PixelGridPainter(
                                          pixels: _compositeLayers(),
                                          gridSize: gridSize,
                                        ),
                                        child: GridView.builder(
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: gridSize,
                                                childAspectRatio: 1.0,
                                              ),
                                          itemCount: gridSize * gridSize,
                                          itemBuilder: (context, index) {
                                            final int row = index ~/ gridSize;
                                            final int col = index % gridSize;
                                            return GestureDetector(
                                              onTap: () =>
                                                  _onPixelTapped(row, col),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color:
                                                      _compositeLayers()[row][col] ??
                                                      Colors.white,
                                                  border: Border.all(
                                                    color: Colors.grey[300]!,
                                                    width: _showGrid
                                                        ? 0.5
                                                        : 0.0,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Advanced controls
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.brush, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('Brush:', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        ...List.generate(3, (index) {
                          final size = index + 1;
                          return GestureDetector(
                            onTap: () => setState(() => _brushSize = size),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: _brushSize == size
                                    ? const Color(0xFF87AE73)
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _brushSize == size
                                      ? const Color(0xFF87AE73)
                                      : Colors.grey.shade400,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: size * 4.0,
                                  height: size * 4.0,
                                  decoration: BoxDecoration(
                                    color: _brushSize == size
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 20,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        const Text('Symmetry:', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        _buildSymmetryButton(
                          'None',
                          SymmetryMode.none,
                          Icons.close,
                        ),
                        _buildSymmetryButton(
                          'V',
                          SymmetryMode.vertical,
                          Icons.swap_vert,
                        ),
                        _buildSymmetryButton(
                          'H',
                          SymmetryMode.horizontal,
                          Icons.swap_horiz,
                        ),
                        _buildSymmetryButton(
                          'Both',
                          SymmetryMode.both,
                          Icons.all_inclusive,
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: Icon(
                        _showGrid ? Icons.grid_on : Icons.grid_off,
                        color: _showGrid
                            ? const Color(0xFF87AE73)
                            : Colors.grey,
                      ),
                      onPressed: () => setState(() => _showGrid = !_showGrid),
                      tooltip: _showGrid ? 'Hide Grid' : 'Show Grid',
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.flip),
                      tooltip: 'Transform',
                      onSelected: (value) {
                        setState(() {
                          if (value == 'flipH') _flipHorizontal();
                          if (value == 'flipV') _flipVertical();
                          if (value == 'rotate90') _rotate90();
                          if (value == 'rotate180') _rotate180();
                          if (value == 'rotate270') _rotate270();
                        });
                        _saveToHistory();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'flipH',
                          child: Row(
                            children: [
                              Icon(Icons.flip, size: 20),
                              SizedBox(width: 8),
                              Text('Flip Horizontal'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'flipV',
                          child: Row(
                            children: [
                              Icon(Icons.flip, size: 20),
                              SizedBox(width: 8),
                              Text('Flip Vertical'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'rotate90',
                          child: Row(
                            children: [
                              Icon(Icons.rotate_right, size: 20),
                              SizedBox(width: 8),
                              Text('Rotate 90°'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'rotate180',
                          child: Row(
                            children: [
                              Icon(Icons.rotate_right, size: 20),
                              SizedBox(width: 8),
                              Text('Rotate 180°'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'rotate270',
                          child: Row(
                            children: [
                              Icon(Icons.rotate_right, size: 20),
                              SizedBox(width: 8),
                              Text('Rotate 270°'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Zoom controls
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.zoom_out),
                      onPressed: () {
                        setState(() {
                          _zoomLevel = (_zoomLevel - 0.1).clamp(0.5, 3.0);
                        });
                      },
                      tooltip: 'Zoom Out',
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF87AE73),
                          const Color(0xFFA8C097),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${(_zoomLevel * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.zoom_in),
                      onPressed: () {
                        setState(() {
                          _zoomLevel = (_zoomLevel + 0.1).clamp(0.5, 3.0);
                        });
                      },
                      tooltip: 'Zoom In',
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _zoomLevel = 1.0;
                      });
                    },
                    icon: const Icon(Icons.fit_screen, size: 18),
                    label: const Text('Reset'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF87AE73),
                      side: const BorderSide(color: Color(0xFF87AE73)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PixelGridPainter extends CustomPainter {
  final List<List<Color?>> pixels;
  final int gridSize;

  PixelGridPainter({required this.pixels, required this.gridSize});

  @override
  void paint(Canvas canvas, Size size) {
    // This is handled by the GridView, but we keep it for potential grid overlay
  }

  @override
  bool shouldRepaint(PixelGridPainter oldDelegate) {
    return pixels != oldDelegate.pixels;
  }
}

class LayerThumbnailPainter extends CustomPainter {
  final Layer layer;
  final int gridSize;
  final int thumbSize;
  final double pixelSize;

  LayerThumbnailPainter({
    required this.layer,
    required this.gridSize,
    required this.thumbSize,
    required this.pixelSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw white background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // Sample pixels for thumbnail
    final step = gridSize / thumbSize;
    for (int ty = 0; ty < thumbSize; ty++) {
      for (int tx = 0; tx < thumbSize; tx++) {
        final py = (ty * step).floor();
        final px = (tx * step).floor();
        if (py < gridSize && px < gridSize) {
          final color = layer.pixels[py][px];
          if (color != null) {
            canvas.drawRect(
              Rect.fromLTWH(
                tx * pixelSize,
                ty * pixelSize,
                pixelSize,
                pixelSize,
              ),
              Paint()..color = color,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(LayerThumbnailPainter oldDelegate) {
    return layer.pixels != oldDelegate.layer.pixels;
  }
}

class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const ColorPickerDialog({super.key, this.initialColor = Colors.blue});

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color selectedColor;

  @override
  void initState() {
    super.initState();
    selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isDesktop = screenWidth >= 1200;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop
              ? 500
              : isTablet
              ? 450
              : screenWidth * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Container(
          padding: EdgeInsets.all(isTablet ? 24 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF87AE73),
                          const Color(0xFFA8C097),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.palette,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Pick a Color',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // RGB sliders
                      _buildColorSlider(
                        'Red',
                        (selectedColor.r * 255.0).round().toDouble(),
                        (value) {
                          setState(() {
                            final int r = value.toInt();
                            final int g = (selectedColor.g * 255.0).round();
                            final int b = (selectedColor.b * 255.0).round();
                            selectedColor = Color.fromARGB(255, r, g, b);
                          });
                        },
                        Colors.red,
                      ),
                      const SizedBox(height: 16),
                      _buildColorSlider(
                        'Green',
                        (selectedColor.g * 255.0).round().toDouble(),
                        (value) {
                          setState(() {
                            final int r = (selectedColor.r * 255.0).round();
                            final int g = value.toInt();
                            final int b = (selectedColor.b * 255.0).round();
                            selectedColor = Color.fromARGB(255, r, g, b);
                          });
                        },
                        Colors.green,
                      ),
                      const SizedBox(height: 16),
                      _buildColorSlider(
                        'Blue',
                        (selectedColor.b * 255.0).round().toDouble(),
                        (value) {
                          setState(() {
                            final int r = (selectedColor.r * 255.0).round();
                            final int g = (selectedColor.g * 255.0).round();
                            final int b = value.toInt();
                            selectedColor = Color.fromARGB(255, r, g, b);
                          });
                        },
                        Colors.blue,
                      ),
                      const SizedBox(height: 24),
                      // Preview
                      Container(
                        width: double.infinity,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              selectedColor,
                              selectedColor.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: selectedColor.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'Preview',
                            style: TextStyle(
                              color: _getTextColorForBackground(selectedColor),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(selectedColor),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF87AE73),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Select',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTextColorForBackground(Color backgroundColor) {
    // Calculate relative luminance
    final double luminance = backgroundColor.computeLuminance();
    // Use white text on dark backgrounds, black on light
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  Widget _buildColorSlider(
    String label,
    double value,
    ValueChanged<double> onChanged,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${value.toInt()}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Slider(
          value: value,
          min: 0,
          max: 255,
          divisions: 255,
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
