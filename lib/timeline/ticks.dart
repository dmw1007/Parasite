import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:timeline/timeline/timeline.dart';
import 'package:timeline/timeline/timeline_utils.dart';

/// [TimelineRenderWidget]使用此类来在屏幕左侧渲染刻度线。
/// 
/// 它具有在[TimelineRenderObject.paint（）]中调用的单个[paint（）]方法。
class Ticks {
  /// 以下`const`变量用于在时间线左侧正确对齐，填充和布局刻度线。
  static const double Margin = 20.0;
  static const double Width = 40.0;
  static const double LabelPadLeft = 5.0;
  static const double LabelPadRight = 1.0;
  static const int TickDistance = 16;
  static const int TextTickDistance = 64;
  static const double TickSize = 15.0;
  static const double SmallTickSize = 5.0;

  /// 除了提供[PaintingContext]来允许刻度线绘画自己之外，
  /// 其他相关的大小调整信息以及[Timeline]的引用都传递给此paint（）方法。
  void paint(PaintingContext context, Offset offset, double translation,
      double scale, double height, Timeline timeline) {
    final Canvas canvas = context.canvas;

    double bottom = height;
    double tickDistance = TickDistance.toDouble();
    double textTickDistance = TextTickDistance.toDouble();
    /// 如果收藏夹视图被激活，则左面板的宽度可以扩展和收缩，
    /// 通过按下时间轴右上角的按钮。
    double gutterWidth = timeline.gutterWidth;

    /// 根据当前比例计算间距
    double scaledTickDistance = tickDistance * scale;
    if (scaledTickDistance > 2 * TickDistance) {
      while (scaledTickDistance > 2 * TickDistance && tickDistance >= 2.0) {
        scaledTickDistance /= 2.0;
        tickDistance /= 2.0;
        textTickDistance /= 2.0;
      }
    } else {
      while (scaledTickDistance < TickDistance) {
        scaledTickDistance *= 2.0;
        tickDistance *= 2.0;
        textTickDistance *= 2.0;
      }
    }
    /// 绘制的刻度数。
    int numTicks = (height / scaledTickDistance).ceil() + 2;
    if (scaledTickDistance > TextTickDistance) {
      textTickDistance = tickDistance;
    }
    /// 找出屏幕左上角的位置
    double tickOffset = 0.0;
    double startingTickMarkValue = 0.0;
    double y = ((translation - bottom) / scale);
    startingTickMarkValue = y - (y % tickDistance);
    tickOffset = -(y % tickDistance) * scale - scaledTickDistance;

    /// 向后移动一格。
    tickOffset -= scaledTickDistance;
    startingTickMarkValue -= tickDistance;
    /// 刻度可以更改颜色，因为时间轴背景也会根据当前时代更改颜色。
    /// timeline_utils.dart中的[TickColors]对象包装了此信息。
    List<TickColors> tickColors = timeline.tickColors;
    if (tickColors != null && tickColors.length > 0) {
      /// 建立线性渐变的色标。
      double rangeStart = tickColors.first.start;
      double range = tickColors.last.start - tickColors.first.start;
      List<ui.Color> colors = <ui.Color>[];
      List<double> stops = <double>[];
      for (TickColors bg in tickColors) {
        colors.add(bg.background);
        stops.add((bg.start - rangeStart) / range);
      }
      double s =
          timeline.computeScale(timeline.renderStart, timeline.renderEnd);
      /// 起点和终点元素的y坐标。
      double y1 = (tickColors.first.start - timeline.renderStart) * s;
      double y2 = (tickColors.last.start - timeline.renderStart) * s;

      /// Fill Background.
      ui.Paint paint = ui.Paint()
        ..shader = ui.Gradient.linear(
            ui.Offset(0.0, y1), ui.Offset(0.0, y2), colors, stops)
        ..style = ui.PaintingStyle.fill;

      /// Fill in top/bottom if necessary.
      if (y1 > offset.dy) {
        canvas.drawRect(
            Rect.fromLTWH(
                offset.dx, offset.dy, gutterWidth, y1 - offset.dy + 1.0),
            ui.Paint()..color = tickColors.first.background);
      }
      if (y2 < offset.dy + height) {
        canvas.drawRect(
            Rect.fromLTWH(
                offset.dx, y2 - 1, gutterWidth, (offset.dy + height) - y2),
            ui.Paint()..color = tickColors.last.background);
      }
      /// Draw the gutter.
      canvas.drawRect(
          Rect.fromLTWH(offset.dx, y1, gutterWidth, y2 - y1), paint);

    } else {
      canvas.drawRect(Rect.fromLTWH(offset.dx, offset.dy, gutterWidth, height),
          Paint()..color = Color.fromRGBO(246, 246, 246, 0.95));
    }

    Set<String> usedValues = Set<String>();

    /// Draw all the ticks.
    for (int i = 0; i < numTicks; i++) {
      tickOffset += scaledTickDistance;

      int tt = startingTickMarkValue.round();
      tt = -tt;
      int o = tickOffset.floor();
      TickColors colors = timeline.findTickColors(offset.dy + height - o);
      if (tt % textTickDistance == 0) {
        /// 每个`textTickDistance`都会画一个较宽的刻度，并在其顶部放置一个标签。
        canvas.drawRect(
            Rect.fromLTWH(offset.dx + gutterWidth - TickSize,
                offset.dy + height - o, TickSize, 1.0),
            Paint()..color = colors.long);
        /// 通过直接使用[ParagraphBuilder]将文本绘制到[画布]。
        ui.ParagraphBuilder builder = ui.ParagraphBuilder(ui.ParagraphStyle(
            textAlign: TextAlign.end, fontFamily: "Roboto", fontSize: 10.0))
          ..pushStyle(ui.TextStyle(
              color: colors.text));

        int value = tt.round().abs();
        /// 很好地格式化标签，具体取决于刻度线放置的时间。
        String label;
        if (value < 9000) {
          label = value.toStringAsFixed(0);
        } else {
          NumberFormat formatter = NumberFormat.compact();
          label = formatter.format(value);
          int digits = formatter.significantDigits;
          while (usedValues.contains(label) && digits < 10) {
            formatter.significantDigits = ++digits;
            label = formatter.format(value);
          }
        }
        usedValues.add(label);
        builder.addText(label);
        ui.Paragraph tickParagraph = builder.build();
        tickParagraph.layout(ui.ParagraphConstraints(
            width: gutterWidth - LabelPadLeft - LabelPadRight));
        canvas.drawParagraph(
            tickParagraph,
            Offset(offset.dx + LabelPadLeft - LabelPadRight,
                offset.dy + height - o - tickParagraph.height - 5));
      } else {
        /// 如果我们在两个文字提示之间，请画一条较小的线。
        canvas.drawRect(
            Rect.fromLTWH(offset.dx + gutterWidth - SmallTickSize,
                offset.dy + height - o, SmallTickSize, 1.0),
            Paint()..color = colors.short);
      }
      startingTickMarkValue += tickDistance;
    }
  }
}
