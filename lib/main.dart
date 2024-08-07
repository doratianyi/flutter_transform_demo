import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() {
  final rootBlock = generateRandomBlocks(6, 4);

  runApp(
    App(
      rootBlock: rootBlock,
    ),
  );
}

/// A moving block that can be hittested.
class MovingBlock {
  /// The delta transform to apply to this block each tick.
  final Matrix4 deltaTransform;

  /// The size of this block.
  final Size size;

  /// The offset of this block from the parent.
  final Offset offset;

  /// The color of this block.
  final Color color;

  MovingBlock(
    this.size,
    this.offset,
    this.color,
    this.deltaTransform,
  );

  /// The transform that this block applies to its children.
  late final currentTransform = ValueNotifier(Matrix4.identity());

  /// Whether this block is hit during last hit test.
  final isHit = ValueNotifier(false);

  /// The children of this block.
  final children = <MovingBlock>[];

  /// Recursively updates the transform of this block and its children by
  /// applying [deltaTransform].
  void tick() {
    currentTransform.value = currentTransform.value * deltaTransform;
    for (final child in children) {
      child.tick();
    }
  }

  /// Recursively hit tests this block and its children. After hit testing
  /// [isHit] will be updated to reflect whether this block is hit.
  void hitTest(Offset position) {
    final localPosition = position - offset;

    if ((Offset.zero & size).contains(localPosition)) {
      isHit.value = true;
    } else {
      isHit.value = false;
    }

    for (final child in children) {
      final transformedPosition = MatrixUtils.transformPoint(
        Matrix4.inverted(currentTransform.value),
        position,
      );
      child.hitTest(transformedPosition);
    }
  }
}

/// Generates a random block with children.
MovingBlock generateRandomBlocks(int depth, int childrenPerBlock) {
  final random = Random();

  final deltaTransform = Matrix4.identity()
    ..setEntry(3, 2, 0.001)
    ..translate(random.nextDouble() * 0.1, random.nextDouble() * 0.1)
    ..rotateZ((random.nextDouble() - 0.5) * 0.001);

  final block = MovingBlock(
    const Size(100, 100),
    const Offset(100, 100),
    Color.fromARGB(
      255,
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
    ),
    deltaTransform,
  );

  if (depth > 0) {
    for (var i = 0; i < childrenPerBlock; i++) {
      block.children.add(generateRandomBlocks(depth - 1, childrenPerBlock));
    }
  }
  return block;
}

class App extends StatefulWidget {
  const App({super.key, required this.rootBlock});

  final MovingBlock rootBlock;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  /// The last position of the mouse.
  Offset? _lastPosition;

  void _onTick(elapsed) {
    widget.rootBlock.tick();
    if (_lastPosition != null) {
      widget.rootBlock.hitTest(_lastPosition!);
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MouseRegion(
        onHover: (event) {
          _lastPosition = event.localPosition;
        },
        child: CustomPaint(
          painter: BlockPainter(widget.rootBlock),
        ),
      ),
    );
  }
}

class BlockPainter extends CustomPainter {
  final MovingBlock rootBlock;

  BlockPainter(this.rootBlock);

  @override
  void paint(Canvas canvas, Size size) {
    paintBlock(canvas, rootBlock, size);
  }

  void paintBlock(Canvas canvas, MovingBlock block, Size size) {
    canvas.drawRect(
      block.offset & block.size,
      Paint()
        ..color = block.color
        ..style = block.isHit.value ? PaintingStyle.fill : PaintingStyle.stroke,
    );

    canvas.save();
    canvas.transform(block.currentTransform.value.storage);
    for (final child in block.children) {
      paintBlock(canvas, child, size);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
