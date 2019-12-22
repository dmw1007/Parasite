import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flare_flutter/flare.dart' as flare;
import 'package:flare_dart/animation/actor_animation.dart' as flare;
import 'package:flare_dart/math/aabb.dart' as flare;
import 'package:flare_dart/math/vec2d.dart' as flare;
import 'package:nima/nima.dart' as nima;
import 'package:nima/nima/animation/actor_animation.dart' as nima;
import 'package:nima/nima/math/aabb.dart' as nima;

/// An object representing the renderable assets loaded from `timeline.json`.
/// 
///每个[TimelineAsset]都封装了所有相关的绘制属性，并维护了对其原始[TimelineEntry]的引用。
class TimelineAsset {
  double width;
  double height;
  double opacity = 0.0;
  double scale = 0.0;
  double scaleVelocity = 0.0;
  double y = 0.0;
  double velocity = 0.0;
  String filename;
  TimelineEntry entry;
}

/// 可渲染的图像。
class TimelineImage extends TimelineAsset {
  ui.Image image;
}

/// 该资产还具有有关其动画的信息。
class TimelineAnimatedAsset extends TimelineAsset {
  bool loop;
  double animationTime = 0.0;
  double offset = 0.0;
  double gap = 0.0;
}

/// An `Nima` Asset.
class TimelineNima extends TimelineAnimatedAsset {
  nima.FlutterActor actorStatic;
  nima.FlutterActor actor;
  nima.ActorAnimation animation;
  nima.AABB setupAABB;
}

/// A `Flare` Asset.
class TimelineFlare extends TimelineAnimatedAsset {
  flare.FlutterActorArtboard actorStatic;
  flare.FlutterActorArtboard actor;
  flare.ActorAnimation animation;

  /// 一些Flare素材资源将具有多个闲置动画（例如“人类”），
  /// others will have an intro&idle animation (e.g. 'Sun is Born'). 
  /// 所有这些信息都位于“ timeline.json”文件中，并在启动期间调用的[Timeline.loadFromBundle（）]方法中反序列化。
  /// 以及自定义计算的AABB范围，以将其正确放置在时间轴上。
  flare.ActorAnimation intro;
  flare.ActorAnimation idle;
  List<flare.ActorAnimation> idleAnimations;
  flare.AABB setupAABB;

}

/// [TimelineEntry]的标签。
enum TimelineEntryType { Era, Incident }

/// 时间轴中的每个条目都由该对象的一个​​实例表示。
/// 每个收藏夹，搜索结果和详细信息页面都将从对该对象的引用中获取信息。
/// 
/// 它们都在启动时由[BlocProvider]构造函数初始化。
class TimelineEntry {
  TimelineEntryType type;

  /// 用于计算在时间轴中为气泡绘制多少条线。
  int lineCount = 1;
  /// 
  String _label;
  String sublabel;
  String articleFilename;
  String id;

  Color accent;

  /// 每个条目构成一棵树的元素：
  /// 时代被分为跨越时代，事件被置于它们所属的时代。
  TimelineEntry parent;
  List<TimelineEntry> children;
  /// 所有时间线条目也链接在一起，以轻松访问下一个/上一个事件。
  /// 在时间轴上闲置几秒钟后，将出现上一个/下一个输入按钮，使用户可以在相邻事件之间更快地导航。
  TimelineEntry next;  //“上一个”button
  TimelineEntry previous;  //“下一个”button

  /// [时间轴]对象使用所有这些参数来正确定位当前条目。
  double start;
  double end;
  double y = 0.0;
  double endY = 0.0;
  double length = 0.0;
  double opacity = 0.0;
  double labelOpacity = 0.0;
  double targetLabelOpacity = 0.0;
  double delayLabel = 0.0;
  double targetAssetOpacity = 0.0;
  double delayAsset = 0.0;
  double legOpacity = 0.0;
  double labelY = 0.0;
  double labelVelocity = 0.0;
  double favoriteY = 0.0;
  bool isFavoriteOccluded = false;

  TimelineAsset asset;

  bool get isVisible {
    return opacity > 0.0;
  }

  String get label => _label;
  /// 一些标签已经具有换行符以调整其对齐方式。
  /// 检测事件并添加有关行数的信息。
  set label(String value) {
    _label = value;
    int start = 0;
    lineCount = 1;
    while (true) {
      start = _label.indexOf("\n", start);
      if (start == -1) {
        break;
      }
      lineCount++;
      start++;
    }
  }

  /// 报名日期打印精美。
  String formatYearsAgo() {
    if (start > 0) {
      return start.round().toString();
    }
    return TimelineEntry.formatYears(start) + " Ago";
  }
  /// 调试信息。
  @override
  String toString() {
    return "TIMELINE ENTRY: $label -($start,$end)";
  }

  /// 辅助方法。
  static String formatYears(double start) {
    String label;
    int valueAbs = start.round().abs();
    if (valueAbs > 1000000000) {
      double v = (valueAbs / 100000000.0).floorToDouble() / 10.0;

      label = (valueAbs / 1000000000)
              .toStringAsFixed(v == v.floorToDouble() ? 0 : 1) +
          " Billion";
    } else if (valueAbs > 1000000) {
      double v = (valueAbs / 100000.0).floorToDouble() / 10.0;
      label =
          (valueAbs / 1000000).toStringAsFixed(v == v.floorToDouble() ? 0 : 1) +
              " Million";
    } else if (valueAbs > 10000) // N.B. < 10,000
    {
      double v = (valueAbs / 100.0).floorToDouble() / 10.0;
      label =
          (valueAbs / 1000).toStringAsFixed(v == v.floorToDouble() ? 0 : 1) +
              " Thousand";
    } else {
      label = valueAbs.toStringAsFixed(0);
    }
    return label + " Years";
  }
}
