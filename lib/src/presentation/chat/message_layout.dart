import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// One layout pass over the real paragraph, header and footer. No cloned text,
/// placeholder footer or post-frame size correction participates in wrapping.
class MessageLayout extends MultiChildRenderObjectWidget {
  MessageLayout({
    super.key,
    Widget? header,
    required Widget content,
    required Widget footer,
    this.inlineFooter = false,
  }) : assert(!inlineFooter || content is RichText || content is Text),
       super(children: [header ?? const SizedBox.shrink(), content, footer]);

  final bool inlineFooter;

  @override
  RenderMessageLayout createRenderObject(BuildContext context) =>
      RenderMessageLayout(inlineFooter);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMessageLayout renderObject,
  ) => renderObject.inlineFooter = inlineFooter;
}

class _MessageParentData extends ContainerBoxParentData<RenderBox> {}

class RenderMessageLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MessageParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MessageParentData> {
  RenderMessageLayout(this._inlineFooter);

  bool _inlineFooter;
  set inlineFooter(bool value) {
    if (_inlineFooter == value) return;
    _inlineFooter = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MessageParentData) {
      child.parentData = _MessageParentData();
    }
  }

  void _position(RenderBox child, Offset offset) =>
      (child.parentData! as ContainerBoxParentData<RenderBox>).offset = offset;

  @override
  void performLayout() {
    final header = firstChild!;
    final content = childAfter(header)!;
    final footer = lastChild!;
    final loose = BoxConstraints(maxWidth: constraints.maxWidth);
    header.layout(loose, parentUsesSize: true);
    content.layout(loose, parentUsesSize: true);
    footer.layout(loose, parentUsesSize: true);

    var width = math.max(
      header.size.width,
      math.max(content.size.width, footer.size.width),
    );
    final contentY = header.size.height == 0 ? 0.0 : header.size.height + 6;
    var footerY = content.size.height + (content.size.height == 0 ? 0 : 4);

    if (_inlineFooter && content is RenderParagraph) {
      final paragraph = content;
      final bottom = math.max(content.size.height, footer.size.height);
      final top = bottom - footer.size.height;
      // Selection offsets are UTF-16, including actual WidgetSpan placeholders.
      // Only the engine's laid-out boxes are measured, never this plain string.
      final length = paragraph.text
          .toPlainText(includeSemanticsLabels: false)
          .length;
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: length),
      );
      var occupiedRight = 0.0;
      for (final box in boxes) {
        // The footer can be taller than the last line: include every visual run
        // intersecting its vertical band, including bidi and opaque widgets.
        if (box.bottom > top && box.top < bottom && box.right > box.left) {
          occupiedRight = math.max(occupiedRight, box.right);
        }
      }
      final inlineWidth = math.max(
        width,
        occupiedRight + (occupiedRight == 0 ? 0 : 8) + footer.size.width,
      );
      if (inlineWidth <= constraints.maxWidth) {
        width = inlineWidth;
        footerY = top;
      }
    }

    size = constraints.constrain(
      Size(width, contentY + footerY + footer.size.height),
    );
    _position(header, Offset.zero);
    _position(content, Offset(0, contentY));
    _position(
      footer,
      Offset(size.width - footer.size.width, contentY + footerY),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
