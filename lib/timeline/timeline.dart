import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flare_flutter/flare.dart' as flare;
import 'package:flare_dart/animation/actor_animation.dart' as flare;
import 'package:flare_dart/math/aabb.dart' as flare;
import 'package:flare_dart/math/vec2d.dart' as flare;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:nima/nima.dart' as nima;
import 'package:nima/nima/actor_image.dart' as nima;
import 'package:nima/nima/animation/actor_animation.dart' as nima;
import 'package:nima/nima/math/aabb.dart' as nima;
import 'package:nima/nima/math/vec2d.dart' as nima;
import 'package:timeline/timeline/timeline_utils.dart';

import 'timeline_entry.dart';

typedef PaintCallback();
typedef ChangeEraCallback(TimelineEntry era);
typedef ChangeHeaderColorCallback(Color background, Color text);

class Timeline {
  /// 一些适当命名的常量，用于正确对齐“时间轴”视图。
  static const double LineWidth = 2.0;
  static const double LineSpacing = 10.0;
  static const double DepthOffset = LineSpacing + LineWidth;

  static const double EdgePadding = 8.0;
  static const double MoveSpeed = 10.0;
  static const double MoveSpeedInteracting = 40.0;
  static const double Deceleration = 3.0;
  static const double GutterLeft = 45.0;
  static const double GutterLeftExpanded = 75.0;

  static const double EdgeRadius = 4.0;
  static const double MinChildLength = 50.0;
  static const double BubbleHeight = 50.0;
  static const double BubbleArrowSize = 19.0;
  static const double BubblePadding = 20.0;
  static const double BubbleTextHeight = 20.0;
  static const double AssetPadding = 30.0;
  static const double Parallax = 100.0;
  static const double AssetScreenScale = 0.3;
  static const double InitialViewportPadding = 100.0;
  static const double TravelViewportPaddingTop = 400.0;

  static const double ViewportPaddingTop = 120.0;
  static const double ViewportPaddingBottom = 100.0;
  static const int SteadyMilliseconds = 500;

  /// 当前平台在引导时初始化，以正确初始化
  /// [ScrollPhysics]基于我们所使用的平台。
  final TargetPlatform _platform;

  double _start = 0.0;
  double _end = 0.0;
  double _renderStart;
  double _renderEnd;
  double _lastFrameTime = 0.0;
  double _height = 0.0;
  double _firstOnScreenEntryY = 0.0;
  double _lastEntryY = 0.0;
  double _lastOnScreenEntryY = 0.0;
  double _offsetDepth = 0.0;
  double _renderOffsetDepth = 0.0;
  double _labelX = 0.0;
  double _renderLabelX = 0.0;
  double _lastAssetY = 0.0;
  double _prevEntryOpacity = 0.0;
  double _distanceToPrevEntry = 0.0;
  double _nextEntryOpacity = 0.0;
  double _distanceToNextEntry = 0.0;
  double _simulationTime = 0.0;
  double _timeMin = 0.0;
  double _timeMax = 0.0;
  double _gutterWidth = GutterLeft;
  
  bool _showFavorites = false;
  bool _isFrameScheduled = false;
  bool _isInteracting = false;
  bool _isScaling = false;
  bool _isActive = false;
  bool _isSteady = false;

  HeaderColors _currentHeaderColors;
  
  Color _headerTextColor;
  Color _headerBackgroundColor;
  
  /// 根据当前的[Platform]，初始化不同的值
  /// 以便它们在iOS和Android上正常运行。
  ScrollPhysics _scrollPhysics;
  /// [_scrollPhysics]需要[ScrollMetrics]值才能起作用。
  ScrollMetrics _scrollMetrics;
  Simulation _scrollSimulation;

  EdgeInsets padding = EdgeInsets.zero;
  EdgeInsets devicePadding = EdgeInsets.zero;

  Timer _steadyTimer;
  
  /// 通过这两个参考，时间轴可以访问时代并进行更新
  /// 顶部标签。
  TimelineEntry _currentEra;
  TimelineEntry _lastEra;
  /// 这些引用允许维护对下一个和上一个元素的引用
  /// 时间轴的时间，具体取决于当前关注的元素。
  /// 当顶部/底部有足够的空间时，时间轴将渲染一个圆形按钮
  /// 带有箭头的链接到下一个/上一个元素。
  TimelineEntry _nextEntry;
  TimelineEntry _renderNextEntry;
  TimelineEntry _prevEntry;
  TimelineEntry _renderPrevEntry;

  /// 渐变显示在背景上，具体取决于我们所处的[_currentEra]。
  List<TimelineBackgroundColor> _backgroundColors;
  /// [Ticks]还具有自定义颜色，因此在不断变化的背景下它们始终可见。
  List<TickColors> _tickColors;
  List<HeaderColors> _headerColors;
  /// All the [TimelineEntry]s that are loaded from disk at boot (in [loadFromBundle()]).
  List<TimelineEntry> _entries;
  /// [TimelineAsset]的列表，也在启动时从磁盘加载。
  List<TimelineAsset> _renderAssets;

  Map<String, TimelineEntry> _entriesById = Map<String, TimelineEntry>();
  Map<String, nima.FlutterActor> _nimaResources =
      Map<String, nima.FlutterActor>();
  Map<String, flare.FlutterActor> _flareResources =
      Map<String, flare.FlutterActor>();

  /// 添加对此对象的引用时，由[TimelineRenderWidget]设置的回调。
  /// 它将触发[RenderBox.markNeedsPaint（）]。
  PaintCallback onNeedPaint;
  /// 接下来的两个回调势必会设置[TimelineWidget]的状态
  /// 因此它可以更改顶部AppBar的外观。
  ChangeEraCallback onEraChanged;
  ChangeHeaderColorCallback onHeaderColorsChanged;

  Timeline(this._platform) {
    setViewport(start: 1536.0, end: 3072.0);
  }

  double get renderOffsetDepth => _renderOffsetDepth;
  double get renderLabelX => _renderLabelX;
  double get start => _start;
  double get end => _end;
  double get renderStart => _renderStart;
  double get renderEnd => _renderEnd;
  double get gutterWidth => _gutterWidth;
  double get nextEntryOpacity => _nextEntryOpacity;
  double get prevEntryOpacity => _prevEntryOpacity;
  bool get isInteracting => _isInteracting;
  bool get showFavorites => _showFavorites;
  bool get isActive => _isActive;
  Color get headerTextColor => _headerTextColor;
  Color get headerBackgroundColor => _headerBackgroundColor;
  HeaderColors get currentHeaderColors => _currentHeaderColors;
  TimelineEntry get currentEra => _currentEra;
  TimelineEntry get nextEntry => _renderNextEntry;
  TimelineEntry get prevEntry => _renderPrevEntry;
  List<TimelineEntry> get entries => _entries;
  List<TimelineBackgroundColor> get backgroundColors => _backgroundColors;
  List<TickColors> get tickColors => _tickColors;
  List<TimelineAsset> get renderAssets => _renderAssets;

  /// 设置器，用于切换时间线左侧的装订线
  /// 快速参考时间轴上的收藏夹。
  set showFavorites(bool value) {
    if (_showFavorites != value) {
      _showFavorites = value;
      _startRendering();
    }
  }

  /// 当检测到缩放操作时，此设置程序称为：
  /// e.g. [_TimelineWidgetState.scaleStart()].
  set isInteracting(bool value) {
    if (value != _isInteracting) {
      _isInteracting = value;
      _updateSteady();
    }
  }

  /// 用于检测当前缩放操作是否仍在进行
  /// 在[advance（）]中的当前帧期间。
  set isScaling(bool value) {
    if (value != _isScaling) {
      _isScaling = value;
      _updateSteady();
    }
  }

  /// 每当时间轴可见或隐藏时，切换/停止渲染。
  set isActive(bool isIt) {
    if (isIt != _isActive) {
      _isActive = isIt;
      if (_isActive) {
        _startRendering();
      }
    }
  }

  /// 检查视口是否稳定- 即未检测到敲击，平移，缩放或其他手势。
  void _updateSteady() {
    bool isIt = !_isInteracting && !_isScaling;

    /// If a timer is currently active, dispose it.
    if (_steadyTimer != null) {
      _steadyTimer.cancel();
      _steadyTimer = null;
    }

    if (isIt) {
      /// 如果仍然需要另一个计时器，请重新创建它。
      _steadyTimer = Timer(Duration(milliseconds: SteadyMilliseconds), () {
        _steadyTimer = null;
        _isSteady = true;
        _startRendering();
      });
    } else {
      /// 否则，更新当前状态并安排新帧。
      _isSteady = false;
      _startRendering();
    }
  }

  /// 安排新框架。
  void _startRendering() {
    if (!_isFrameScheduled) {
      _isFrameScheduled = true;
      _lastFrameTime = 0.0;
      SchedulerBinding.instance.scheduleFrameCallback(beginFrame);
    }
  }

  double screenPaddingInTime(double padding, double start, double end) {
    return padding / computeScale(start, end);
  }

  /// 从开始/结束时间计算视口比例。
  double computeScale(double start, double end) {
    return _height == 0.0 ? 1.0 : _height / (end - start);
  }

  /// 从本地捆绑包加载所有资源。
  /// 
  /// 此功能将从磁盘加载并解码`timline.json`，
  /// 解码JSON文件，然后填充所有[TimelineEntry]。
  Future<List<TimelineEntry>> loadFromBundle(String filename) async {
    String data = await rootBundle.loadString(filename);
    List jsonEntries = json.decode(data) as List;

    List<TimelineEntry> allEntries = List<TimelineEntry>();
    _backgroundColors = List<TimelineBackgroundColor>();
    _tickColors = List<TickColors>();
    _headerColors = List<HeaderColors>();

    /// JSON解码不提供强类型，因此我们将进行迭代
    /// 在[jsonEntries]列表中的动态条目上。
    for (dynamic entry in jsonEntries) {
      Map map = entry as Map;

      /// Sanity check.
      if (map != null) {
        /* 如果是“ Incident”，则创建当前条目并填写当前日期；如果是“ Era”，请创建“ start”属性。 */
        /// 有些条目将具有一个“开始”元素，但没有指定一个“结束”元素。
        /// 这些条目指定了一个特定事件，例如历史上“人类”的出现，但尚未结束。
        TimelineEntry timelineEntry = TimelineEntry();
        if (map.containsKey("date")) {
          timelineEntry.type = TimelineEntryType.Incident;
          dynamic date = map["date"];
          timelineEntry.start = date is int ? date.toDouble() : date;
        } else if (map.containsKey("start")) {
          timelineEntry.type = TimelineEntryType.Era;
          dynamic start = map["start"];

          timelineEntry.start = start is int ? start.toDouble() : start;
        } else {
          continue;
        }

        /// 如果为此[TimelineEntry]指定了自定义背景色，请提取其RGB值并将其与当前条目的开始日期一起保存以供参考。
        if (map.containsKey("background")) {
          dynamic bg = map["background"];
          if (bg is List && bg.length >= 3) {
            _backgroundColors.add(TimelineBackgroundColor()
              ..color =
                  Color.fromARGB(255, bg[0] as int, bg[1] as int, bg[2] as int)
              ..start = timelineEntry.start);
          }
        }

        /// 有时还会指定强调色。
        dynamic accent = map["accent"];
        if (accent is List && accent.length >= 3) {
          timelineEntry.accent = Color.fromARGB(
              accent.length > 3 ? accent[3] as int : 255,
              accent[0] as int,
              accent[1] as int,
              accent[2] as int);
        }

        /// [Ticks]也可以具有自定义颜色，因此即使使用自定义彩色背景，也可以看到所有内容。
        if (map.containsKey("ticks")) {
          dynamic ticks = map["ticks"];
          if (ticks is Map) {
            Color bgColor = Colors.black;
            Color longColor = Colors.black;
            Color shortColor = Colors.black;
            Color textColor = Colors.black;

            dynamic bg = ticks["background"];
            if (bg is List && bg.length >= 3) {
              bgColor = Color.fromARGB(bg.length > 3 ? bg[3] as int : 255,
                  bg[0] as int, bg[1] as int, bg[2] as int);
            }
            dynamic long = ticks["long"];
            if (long is List && long.length >= 3) {
              longColor = Color.fromARGB(long.length > 3 ? long[3] as int : 255,
                  long[0] as int, long[1] as int, long[2] as int);
            }
            dynamic short = ticks["short"];
            if (short is List && short.length >= 3) {
              shortColor = Color.fromARGB(
                  short.length > 3 ? short[3] as int : 255,
                  short[0] as int,
                  short[1] as int,
                  short[2] as int);
            }
            dynamic text = ticks["text"];
            if (text is List && text.length >= 3) {
              textColor = Color.fromARGB(text.length > 3 ? text[3] as int : 255,
                  text[0] as int, text[1] as int, text[2] as int);
            }

            _tickColors.add(TickColors()
              ..background = bgColor
              ..long = longColor
              ..short = shortColor
              ..text = textColor
              ..start = timelineEntry.start
              ..screenY = 0.0);
          }
        }

        /// 如果存在“ header”元素，则也要对其颜色反序列化。
        if (map.containsKey("header")) {
          dynamic header = map["header"];
          if (header is Map) {
            Color bgColor = Colors.black;
            Color textColor = Colors.black;

            dynamic bg = header["background"];
            if (bg is List && bg.length >= 3) {
              bgColor = Color.fromARGB(bg.length > 3 ? bg[3] as int : 255,
                  bg[0] as int, bg[1] as int, bg[2] as int);
            }
            dynamic text = header["text"];
            if (text is List && text.length >= 3) {
              textColor = Color.fromARGB(text.length > 3 ? text[3] as int : 255,
                  text[0] as int, text[1] as int, text[2] as int);
            }

            _headerColors.add(HeaderColors()
              ..background = bgColor
              ..text = textColor
              ..start = timelineEntry.start
              ..screenY = 0.0);
          }
        }

        
        /// 一些元素将指定“结束”时间。
        /// 如果此条目中没有`end`键，则创建基于
        /// 关于事件的类型：
        /// - 时代使用当前年份作为结束时间。
        /// - 其他条目只是单个时间点（开始==结束）。
        if (map.containsKey("end")) {
          dynamic end = map["end"];
          timelineEntry.end = end is int ? end.toDouble() : end;
        } else if (timelineEntry.type == TimelineEntryType.Era) {
          timelineEntry.end = DateTime.now().year.toDouble() * 10.0;
        } else {
          timelineEntry.end = timelineEntry.start;
        }

        /// lable是当前条目的简短描述。
        if (map.containsKey("label")) {
          timelineEntry.label = map["label"] as String;
        }
        if (map.containsKey("sublabel")) {
          timelineEntry.sublabel = map["sublabel"] as String;
        }

        /// 一些条目还将具有一个ID
        if (map.containsKey("id")) {
          timelineEntry.id = map["id"] as String;
          _entriesById[timelineEntry.id] = timelineEntry;
        }
        if (map.containsKey("article")) {
          timelineEntry.articleFilename = map["article"] as String;
        }

        /// 当前条目中的“ asset”键包含将在时间轴上播放的 nima / flare 动画文件的所有信息。
        ///
        ///
        ///
        /// `asset` is a JSON object thus made:
        ///
        ///
        /// {   /***  --flare各方法使用规则  ***/
        ///
        ///   - source: the name of the nima/flare file in the assets folder;
        ///   - width/height/offset/bounds/gap: 动画的大小，以使其在时间轴中正确对齐，以及其Axis-Aligned Bounding Box容器。
        ///   - intro: 某些文件在闲置前播放有“介绍”动画。
        ///   - idle: 有些文件具有一个或多个空闲动画，这些是它们的名称。
        ///   - loop: 某些动画不应该循环播放（例如“大爆炸”），而只需适应其空闲动画即可。在这种情况下，将引发此标志。
        ///   - scale: 自定义比例值。
        ///
        ///
        ///
        if (map.containsKey("asset")) {
          TimelineAsset asset;
          Map assetMap = map["asset"] as Map;
          String source = assetMap["source"];
          String filename = "assets/" + source;
          String extension = getExtension(source);
          /// 根据文件扩展名实例化正确的对象。
          switch (extension) {
            case "flr":
              TimelineFlare flareAsset = TimelineFlare();
              asset = flareAsset;
              flare.FlutterActor actor = _flareResources[filename];
              if (actor == null) {
                actor = flare.FlutterActor();

                /// Flare库函数可加载[FlutterActor]
                bool success = await actor.loadFromBundle(rootBundle, filename);
                if (success) {
                  /// 填充地图。
                  _flareResources[filename] = actor;
                }
              }
              if (actor != null) {
                /// 区分实际演员及其角色.
                flareAsset.actorStatic = actor.artboard;
				flareAsset.actorStatic.initializeGraphics();
                flareAsset.actor = actor.artboard.makeInstance();
				flareAsset.actor.initializeGraphics();
                /// 他们的第一个动画参考.
                flareAsset.animation = actor.artboard.animations[0];

                dynamic name = assetMap["idle"];
                if (name is String) {
                  if ((flareAsset.idle = flareAsset.actor.getAnimation(name)) !=
                      null) {
                    flareAsset.animation = flareAsset.idle;
                  }
                } else if (name is List) {
                  for (String animationName in name) {
                    flare.ActorAnimation animation =
                        flareAsset.actor.getAnimation(animationName);
                    if (animation != null) {
                      if (flareAsset.idleAnimations == null) {
                        flareAsset.idleAnimations =
                            List<flare.ActorAnimation>();
                      }
                      flareAsset.idleAnimations.add(animation);
                      flareAsset.animation = animation;
                    }
                  }
                }

                name = assetMap["intro"];
                if (name is String) {
                  if ((flareAsset.intro =
                          flareAsset.actor.getAnimation(name)) !=
                      null) {
                    flareAsset.animation = flareAsset.intro;
                  }
                }

                /// 确保为参与者和参与者实例设置了所有初始值。
                flareAsset.animationTime = 0.0;
                flareAsset.actor.advance(0.0);
                flareAsset.setupAABB = flareAsset.actor.computeAABB();
                flareAsset.animation
                    .apply(flareAsset.animationTime, flareAsset.actor, 1.0);
                flareAsset.animation.apply(
                    flareAsset.animation.duration, flareAsset.actorStatic, 1.0);
                flareAsset.actor.advance(0.0);
                flareAsset.actorStatic.advance(0.0);

                dynamic loop = assetMap["loop"];
                flareAsset.loop = loop is bool ? loop : true;
                dynamic offset = assetMap["offset"];
                flareAsset.offset = offset == null
                    ? 0.0
                    : offset is int ? offset.toDouble() : offset;
                dynamic gap = assetMap["gap"];
                flareAsset.gap =
                    gap == null ? 0.0 : gap is int ? gap.toDouble() : gap;

                dynamic bounds = assetMap["bounds"];
                if (bounds is List) {
                  /// Override the AABB for this entry with custom values.
                  flareAsset.setupAABB = flare.AABB.fromValues(
                      bounds[0] is int ? bounds[0].toDouble() : bounds[0],
                      bounds[1] is int ? bounds[1].toDouble() : bounds[1],
                      bounds[2] is int ? bounds[2].toDouble() : bounds[2],
                      bounds[3] is int ? bounds[3].toDouble() : bounds[3]);
                }
              }
              break;
            case "nma":
              TimelineNima nimaAsset = TimelineNima();
              asset = nimaAsset;
              nima.FlutterActor actor = _nimaResources[filename];
              if (actor == null) {
                actor = nima.FlutterActor();

                bool success = await actor.loadFromBundle(filename);
                if (success) {
                  _nimaResources[filename] = actor;
                }
              }
              if (actor != null) {
                nimaAsset.actorStatic = actor;
                nimaAsset.actor = actor.makeInstance();

                dynamic name = assetMap["idle"];
                if (name is String) {
                  nimaAsset.animation = nimaAsset.actor.getAnimation(name);
                } else {
                  nimaAsset.animation = actor.animations[0];
                }
                nimaAsset.animationTime = 0.0;
                nimaAsset.actor.advance(0.0);

                nimaAsset.setupAABB = nimaAsset.actor.computeAABB();
                nimaAsset.animation
                    .apply(nimaAsset.animationTime, nimaAsset.actor, 1.0);
                nimaAsset.animation.apply(
                    nimaAsset.animation.duration, nimaAsset.actorStatic, 1.0);
                nimaAsset.actor.advance(0.0);
                nimaAsset.actorStatic.advance(0.0);
                dynamic loop = assetMap["loop"];
                nimaAsset.loop = loop is bool ? loop : true;
                dynamic offset = assetMap["offset"];
                nimaAsset.offset = offset == null
                    ? 0.0
                    : offset is int ? offset.toDouble() : offset;
                dynamic gap = assetMap["gap"];
                nimaAsset.gap =
                    gap == null ? 0.0 : gap is int ? gap.toDouble() : gap;
                dynamic bounds = assetMap["bounds"];
                if (bounds is List) {
                  nimaAsset.setupAABB = nima.AABB.fromValues(
                      bounds[0] is int ? bounds[0].toDouble() : bounds[0],
                      bounds[1] is int ? bounds[1].toDouble() : bounds[1],
                      bounds[2] is int ? bounds[2].toDouble() : bounds[2],
                      bounds[3] is int ? bounds[3].toDouble() : bounds[3]);
                }
              }
              break;

            default:
              /// 旧版后备案例：某些元素可能只是图像。
              TimelineImage imageAsset = TimelineImage();
              asset = imageAsset;

              ByteData data = await rootBundle.load(filename);
              Uint8List list = Uint8List.view(data.buffer);
              ui.Codec codec = await ui.instantiateImageCodec(list);
              ui.FrameInfo frame = await codec.getNextFrame();
              imageAsset.image = frame.image;

              break;
          }

          double scale = 1.0;
          if (assetMap.containsKey("scale")) {
            dynamic s = assetMap["scale"];
            scale = s is int ? s.toDouble() : s;
          }

          dynamic width = assetMap["width"];
          asset.width = (width is int ? width.toDouble() : width) * scale;

          dynamic height = assetMap["height"];
          asset.height = (height is int ? height.toDouble() : height) * scale;
          asset.entry = timelineEntry;
          asset.filename = filename;
          timelineEntry.asset = asset;
        }
        /// 将此条目添加到列表中。
        allEntries.add(timelineEntry);
      }
    }

    /// 对完整列表进行排序，以使它们按照从旧到新的顺序排列
    allEntries.sort((TimelineEntry a, TimelineEntry b) {
      return a.start.compareTo(b.start);
    });

    _backgroundColors
        .sort((TimelineBackgroundColor a, TimelineBackgroundColor b) {
      return a.start.compareTo(b.start);
    });

    _timeMin = double.maxFinite;
    _timeMax = -double.maxFinite;
    /// 列出“根”条目，即没有父母的条目。
    _entries = List<TimelineEntry>();
    /// 建立层次结构（将时代分为“跨越时代”，将事件放入其所属的时代）。
    TimelineEntry previous;
    for (TimelineEntry entry in allEntries) {
      if (entry.start < _timeMin) {
        _timeMin = entry.start;
      }
      if (entry.end > _timeMax) {
        _timeMax = entry.end;
      }
      if (previous != null) {
        previous.next = entry;
      }
      entry.previous = previous;
      previous = entry;

      TimelineEntry parent;
      double minDistance = double.maxFinite;
      for (TimelineEntry checkEntry in allEntries) {
        if (checkEntry.type == TimelineEntryType.Era) {
          double distance = entry.start - checkEntry.start;
          double distanceEnd = entry.start - checkEntry.end;
          if (distance > 0 && distanceEnd < 0 && distance < minDistance) {
            minDistance = distance;
            parent = checkEntry;
          }
        }
      }
      if (parent != null) {
        entry.parent = parent;
        if (parent.children == null) {
          parent.children = List<TimelineEntry>();
        }
        parent.children.add(entry);
      } else {
        /// 没有父母，所以这是一个根条目。
        _entries.add(entry);
      }
    }
    return allEntries;
  }

  /// [MenuVignette]的辅助功能.
  TimelineEntry getById(String id) {
    return _entriesById[id];
  }

  /// 确保滚动时我们在正确的时间轴范围内。
  clampScroll() {
    _scrollMetrics = null;
    _scrollPhysics = null;
    _scrollSimulation = null;

    /// 获取当前视口的测量值。
    double scale = computeScale(_start, _end);
    double padTop = (devicePadding.top + ViewportPaddingTop) / scale;
    double padBottom = (devicePadding.bottom + ViewportPaddingBottom) / scale;
    bool fixStart = _start < _timeMin - padTop;
    bool fixEnd = _end > _timeMax + padBottom;

    /// 随着比例的变化，我们需要重新解决正确的填充
    /// 不要以为有一个分析性的单一解决方案，因此我们会逐步采取正确的答案。
    for (int i = 0; i < 20; i++) {
      double scale = computeScale(_start, _end);
      double padTop = (devicePadding.top + ViewportPaddingTop) / scale;
      double padBottom = (devicePadding.bottom + ViewportPaddingBottom) / scale;
      if (fixStart) {
        _start = _timeMin - padTop;
      }
      if (fixEnd) {
        _end = _timeMax + padBottom;
      }
    }
    if (_end < _start) {
      _end = _start + _height / scale;
    }
    /// 确保重新安排新的框架。
    if (!_isFrameScheduled) {
      _isFrameScheduled = true;
      _lastFrameTime = 0.0;
      SchedulerBinding.instance.scheduleFrameCallback(beginFrame);
    }
  }

  /// 此方法根据当前的开始和结束位置来限制当前视口。
  void setViewport(
      {double start = double.maxFinite,
      bool pad = false,
      double end = double.maxFinite,
      double height = double.maxFinite,
      double velocity = double.maxFinite,
      bool animate = false}) {
    /// 计算当前高度。
    if (height != double.maxFinite) {
      if (_height == 0.0 && _entries != null && _entries.length > 0) {
        double scale = height / (_end - _start);
        _start = _start - padding.top / scale;
        _end = _end + padding.bottom / scale;
      }
      _height = height;
    }

    /// 如果提供了开始和结束的值，请评估顶部/底部位置
    /// 当前视口的位置。
    /// 否则，请分别构建值。
    if (start != double.maxFinite && end != double.maxFinite) {
      _start = start;
      _end = end;
      if (pad && _height != 0.0) {
        double scale = _height / (_end - _start);
        _start = _start - padding.top / scale;
        _end = _end + padding.bottom / scale;
      }
    } else {
      if (start != double.maxFinite) {
        double scale = height / (_end - _start);
        _start = pad ? start - padding.top / scale : start;
      }
      if (end != double.maxFinite) {
        double scale = height / (_end - _start);
        _end = pad ? end + padding.bottom / scale : end;
      }
    }

    /// 如果已经传递了速度值，请使用[ScrollPhysics]创建一个模拟并本地滚动到当前平台.
    if (velocity != double.maxFinite) {
      double scale = computeScale(_start, _end);
      double padTop =
          (devicePadding.top + ViewportPaddingTop) / computeScale(_start, _end);
      double padBottom = (devicePadding.bottom + ViewportPaddingBottom) /
          computeScale(_start, _end);
      double rangeMin = (_timeMin - padTop) * scale;
      double rangeMax = (_timeMax + padBottom) * scale - _height;
      if (rangeMax < rangeMin) {
        rangeMax = rangeMin;
      }

      _simulationTime = 0.0;
      if (_platform == TargetPlatform.iOS) {
        _scrollPhysics = BouncingScrollPhysics();
      } else {
        _scrollPhysics = ClampingScrollPhysics();
      }
      _scrollMetrics = FixedScrollMetrics(
          minScrollExtent: double.negativeInfinity,
          maxScrollExtent: double.infinity,
          pixels: 0.0,
          viewportDimension: _height,
          axisDirection: AxisDirection.down);

      _scrollSimulation =
          _scrollPhysics.createBallisticSimulation(_scrollMetrics, velocity);
    }
    if (!animate) {
      _renderStart = start;
      _renderEnd = end;
      advance(0.0, false);
      if (onNeedPaint != null) {
        onNeedPaint();
      }
    } else if (!_isFrameScheduled) {
      _isFrameScheduled = true;
      _lastFrameTime = 0.0;
      SchedulerBinding.instance.scheduleFrameCallback(beginFrame);
    }
  }

  /// 确保已根据时间轴的当前状态渲染和推进所有可见资产。
  void beginFrame(Duration timeStamp) {
    _isFrameScheduled = false;
    final double t =
        timeStamp.inMicroseconds / Duration.microsecondsPerMillisecond / 1000.0;
    if (_lastFrameTime == 0.0) {
      _lastFrameTime = t;
      _isFrameScheduled = true;
      SchedulerBinding.instance.scheduleFrameCallback(beginFrame);
      return;
    }

    double elapsed = t - _lastFrameTime;
    _lastFrameTime = t;

    if (!advance(elapsed, true) && !_isFrameScheduled) {
      _isFrameScheduled = true;
      SchedulerBinding.instance.scheduleFrameCallback(beginFrame);
    }

    if (onNeedPaint != null) {
      onNeedPaint();
    }
  }

  TickColors findTickColors(double screen) {
    if (_tickColors == null) {
      return null;
    }
    for (TickColors color in _tickColors.reversed) {
      if (screen >= color.screenY) {
        return color;
      }
    }

    return screen < _tickColors.first.screenY
        ? _tickColors.first
        : _tickColors.last;
  }

  HeaderColors _findHeaderColors(double screen) {
    if (_headerColors == null) {
      return null;
    }
    for (HeaderColors color in _headerColors.reversed) {
      if (screen >= color.screenY) {
        return color;
      }
    }

    return screen < _headerColors.first.screenY
        ? _headerColors.first
        : _headerColors.last;
  }

  bool advance(double elapsed, bool animate) {
    if (_height <= 0) {
      /// Done rendering. Need to wait for height.
      return true;
    }
    /// 基于渲染区域的当前比例。
    double scale = _height / (_renderEnd - _renderStart);

    bool doneRendering = true;
    bool stillScaling = true;

    /// 如果时间轴正在执行滚动操作，请根据经过的时间调整视口。
    if (_scrollSimulation != null) {
      doneRendering = false;
      _simulationTime += elapsed;
      double scale = _height / (_end - _start);
      double velocity = _scrollSimulation.dx(_simulationTime);

      double displace = velocity * elapsed / scale;

      _start -= displace;
      _end -= displace;
      
      /// 如果滚动已终止，请清理资源。
      if (_scrollSimulation.isDone(_simulationTime)) {
        _scrollMetrics = null;
        _scrollPhysics = null;
        _scrollSimulation = null;
      }
    }

    /// 检查左侧装订线是否已切换。
    /// If visible, make room for it .
    double targetGutterWidth = _showFavorites ? GutterLeftExpanded : GutterLeft;
    double dgw = targetGutterWidth - _gutterWidth;
    if (!animate || dgw.abs() < 1) {
      _gutterWidth = targetGutterWidth;
    } else {
      doneRendering = false;
      _gutterWidth += dgw * min(1.0, elapsed * 10.0);
    }

    /// Animate movement.
    double speed =
        min(1.0, elapsed * (_isInteracting ? MoveSpeedInteracting : MoveSpeed));
    double ds = _start - _renderStart;
    double de = _end - _renderEnd;

    /// 如果当前视图是动画，请根据交互速度调整[_renderStart] / [_ renderEnd]。
    if (!animate || ((ds * scale).abs() < 1.0 && (de * scale).abs() < 1.0)) {
      stillScaling = false;
      _renderStart = _start;
      _renderEnd = _end;
    } else {
      doneRendering = false;
      _renderStart += ds * speed;
      _renderEnd += de * speed;
    }
    isScaling = stillScaling;

    /// 更改渲染范围后更新缩放比例。
    scale = _height / (_renderEnd - _renderStart);

    /// Update color screen positions.
    if (_tickColors != null && _tickColors.length > 0) {
      double lastStart = _tickColors.first.start;
      for (TickColors color in _tickColors) {
        color.screenY =
            (lastStart + (color.start - lastStart / 2.0) - _renderStart) *
                scale;
        lastStart = color.start;
      }
    }
    if (_headerColors != null && _headerColors.length > 0) {
      double lastStart = _headerColors.first.start;
      for (HeaderColors color in _headerColors) {
        color.screenY =
            (lastStart + (color.start - lastStart / 2.0) - _renderStart) *
                scale;
        lastStart = color.start;
      }
    }

    _currentHeaderColors = _findHeaderColors(0.0);

    if (_currentHeaderColors != null) {
      if (_headerTextColor == null) {
        _headerTextColor = _currentHeaderColors.text;
        _headerBackgroundColor = _currentHeaderColors.background;
      } else {
        bool stillColoring = false;
        Color headerTextColor = interpolateColor(
            _headerTextColor, _currentHeaderColors.text, elapsed);

        if (headerTextColor != _headerTextColor) {
          _headerTextColor = headerTextColor;
          stillColoring = true;
          doneRendering = false;
        }
        Color headerBackgroundColor = interpolateColor(
            _headerBackgroundColor, _currentHeaderColors.background, elapsed);
        if (headerBackgroundColor != _headerBackgroundColor) {
          _headerBackgroundColor = headerBackgroundColor;
          stillColoring = true;
          doneRendering = false;
        }
        if (stillColoring) {
          if (onHeaderColorsChanged != null) {
            onHeaderColorsChanged(_headerBackgroundColor, _headerTextColor);
          }
        }
      }
    }

    /// 检查所有可见的条目，并使用辅助函数[advanceItems（）]将其状态与经过的时间对齐。
    /// 将所有初始值设置为默认值，以便所有内容保持一致。
    _lastEntryY = -double.maxFinite;
    _lastOnScreenEntryY = 0.0;
    _firstOnScreenEntryY = double.maxFinite;
    _lastAssetY = -double.maxFinite;
    _labelX = 0.0;
    _offsetDepth = 0.0;
    _currentEra = null;
    _nextEntry = null;
    _prevEntry = null;
    if (_entries != null) {
      /// 一次将项目层次结构上移一个级别。
      if (_advanceItems(
          _entries, _gutterWidth + LineSpacing, scale, elapsed, animate, 0)) {
        doneRendering = false;
      }

      /// 推进所有资产并将渲染的资产添加到[_renderAssets]中。
      _renderAssets = List<TimelineAsset>();
      if (_advanceAssets(_entries, elapsed, animate, _renderAssets)) {
        doneRendering = false;
      }
    }

    if (_nextEntryOpacity == 0.0) {
      _renderNextEntry = _nextEntry;
    }

    /// Determine next entry's opacity and interpolate, if needed, towards that value.
    double targetNextEntryOpacity = _lastOnScreenEntryY > _height / 1.7 ||
            !_isSteady ||
            _distanceToNextEntry < 0.01 ||
            _nextEntry != _renderNextEntry
        ? 0.0
        : 1.0;
    double dt = targetNextEntryOpacity - _nextEntryOpacity;

    if (!animate || dt.abs() < 0.01) {
      _nextEntryOpacity = targetNextEntryOpacity;
    } else {
      doneRendering = false;
      _nextEntryOpacity += dt * min(1.0, elapsed * 10.0);
    }

    if (_prevEntryOpacity == 0.0) {
      _renderPrevEntry = _prevEntry;
    }

    /// Determine previous entry's opacity and interpolate, if needed, towards that value.
    double targetPrevEntryOpacity = _firstOnScreenEntryY < _height / 2.0 ||
            !_isSteady ||
            _distanceToPrevEntry < 0.01 ||
            _prevEntry != _renderPrevEntry
        ? 0.0
        : 1.0;
    dt = targetPrevEntryOpacity - _prevEntryOpacity;

    if (!animate || dt.abs() < 0.01) {
      _prevEntryOpacity = targetPrevEntryOpacity;
    } else {
      doneRendering = false;
      _prevEntryOpacity += dt * min(1.0, elapsed * 10.0);
    }

    /// 插入标签的水平位置。
    double dl = _labelX - _renderLabelX;
    if (!animate || dl.abs() < 1.0) {
      _renderLabelX = _labelX;
    } else {
      doneRendering = false;
      _renderLabelX += dl * min(1.0, elapsed * 6.0);
    }

    /// 如果当前处于一个新时代，请回调。
    if (_currentEra != _lastEra) {
      _lastEra = _currentEra;
      if (onEraChanged != null) {
        onEraChanged(_currentEra);
      }
    }

    if (_isSteady) {
      double dd = _offsetDepth - renderOffsetDepth;
      if (!animate || dd.abs() * DepthOffset < 1.0) {
        _renderOffsetDepth = _offsetDepth;
      } else {
        /// Needs a second run.
        doneRendering = false;
        _renderOffsetDepth += dd * min(1.0, elapsed * 12.0);
      }
    }

    return doneRendering;
  }

  double bubbleHeight(TimelineEntry entry) {
    return BubblePadding * 2.0 + entry.lineCount * BubbleTextHeight;
  }

  /// Advance entry [assets] with the current [elapsed] time.
  bool _advanceItems(List<TimelineEntry> items, double x, double scale,
      double elapsed, bool animate, int depth) {
        
    bool stillAnimating = false;
    double lastEnd = -double.maxFinite;
    for (int i = 0; i < items.length; i++)
    {
      TimelineEntry item = items[i];

      double start = item.start - _renderStart;
      double end =
          item.type == TimelineEntryType.Era ? item.end - _renderStart : start;

      /// 该元素的垂直位置.
      double y = start * scale; ///+pad;
      if (i > 0 && y - lastEnd < EdgePadding) {
        y = lastEnd + EdgePadding;
      }
      /// 根据当前比例值进行调整。
      double endY = end * scale; ///-pad;
      /// 将引用更新为最后找到的元素。
      lastEnd = endY;

      item.length = endY - y;

      /// 计算 气泡/ 标签的最佳位置。
      double targetLabelY = y;
      double itemBubbleHeight = bubbleHeight(item);
      double fadeAnimationStart = itemBubbleHeight + BubblePadding / 2.0;
      if (targetLabelY - _lastEntryY < fadeAnimationStart
          /// 标签的最佳位置被遮挡，让我们看看是否可以将其向前推...
          &&
          item.type == TimelineEntryType.Era &&
          _lastEntryY + fadeAnimationStart < endY) {
        targetLabelY = _lastEntryY + fadeAnimationStart + 0.5;
      }

      /// 确定标签是否在视图中。
      double targetLabelOpacity =
          targetLabelY - _lastEntryY < fadeAnimationStart ? 0.0 : 1.0;

      /// 防反跳标签变得可见。
      if (targetLabelOpacity > 0.0 && item.targetLabelOpacity != 1.0) {
        item.delayLabel = 0.5;
      }
      item.targetLabelOpacity = targetLabelOpacity;
      if (item.delayLabel > 0.0) {
        targetLabelOpacity = 0.0;
        item.delayLabel -= elapsed;
        stillAnimating = true;
      }

      double dt = targetLabelOpacity - item.labelOpacity;
      if (!animate || dt.abs() < 0.01) {
        item.labelOpacity = targetLabelOpacity;
      } else {
        stillAnimating = true;
        item.labelOpacity += dt * min(1.0, elapsed * 25.0);
      }

      /// 分配当前垂直位置。
      item.y = y;
      item.endY = endY;

      double targetLegOpacity = item.length > EdgeRadius ? 1.0 : 0.0;
      double dtl = targetLegOpacity - item.legOpacity;
      if (!animate || dtl.abs() < 0.01) {
        item.legOpacity = targetLegOpacity;
      } else {
        stillAnimating = true;
        item.legOpacity += dtl * min(1.0, elapsed * 20.0);
      }

      double targetItemOpacity = item.parent != null
          ? item.parent.length < MinChildLength ||
                  (item.parent != null && item.parent.endY < y)
              ? 0.0
              : y > item.parent.y ? 1.0 : 0.0
          : 1.0;
      dtl = targetItemOpacity - item.opacity;
      if (!animate || dtl.abs() < 0.01) {
        item.opacity = targetItemOpacity;
      } else {
        stillAnimating = true;
        item.opacity += dtl * min(1.0, elapsed * 20.0);
      }

      /// Animate the label position.
      double targetLabelVelocity = targetLabelY - item.labelY;
      double dvy = targetLabelVelocity - item.labelVelocity;
      if (dvy.abs() > _height) {
        item.labelY = targetLabelY;
        item.labelVelocity = 0.0;
      } else {
        item.labelVelocity += dvy * elapsed * 18.0;
        item.labelY += item.labelVelocity * elapsed * 20.0;
      }
      /// 检查是否到达最终位置，否则升起一个标志。
      if (animate &&
          (item.labelVelocity.abs() > 0.01 ||
              targetLabelVelocity.abs() > 0.01)) {
        stillAnimating = true;
      }

      if (item.targetLabelOpacity > 0.0) {
        _lastEntryY = targetLabelY;
        if (_lastEntryY < _height && _lastEntryY > devicePadding.top) {
          _lastOnScreenEntryY = _lastEntryY;
          if (_firstOnScreenEntryY == double.maxFinite) {
            _firstOnScreenEntryY = _lastEntryY;
          }
        }
      }

      if (item.type == TimelineEntryType.Era &&
          y < 0 &&
          endY > _height &&
          depth > _offsetDepth) {
        _offsetDepth = depth.toDouble();
      }
      /// 当前正处于一个新时代。
      if (item.type == TimelineEntryType.Era && y < 0 && endY > _height / 2.0) {
        _currentEra = item;
      }

      /// 检查气泡是否在视线之外，并将y位置直接设置为目标位置。
      if (y > _height + itemBubbleHeight) {
        item.labelY = y;
        if (_nextEntry == null) {
          _nextEntry = item;
          _distanceToNextEntry = (y - _height) / _height;
        }
      } else if (endY < devicePadding.top) {
        _prevEntry = item;
        _distanceToPrevEntry = ((y - _height) / _height).abs();
      } else if (endY < -itemBubbleHeight) {
        item.labelY = y;
      }

      double lx = x + LineSpacing + LineSpacing;
      if (lx > _labelX) {
        _labelX = lx;
      }

      if (item.children != null && item.isVisible) {
        /// Advance the rest of the hierarchy.
        if (_advanceItems(item.children, x + LineSpacing + LineWidth, scale,
            elapsed, animate, depth + 1)) {
          stillAnimating = true;
        }
      }
    }
    return stillAnimating;
  }

  /// Advance asset [items] with the [elapsed] time.
  bool _advanceAssets(List<TimelineEntry> items, double elapsed, bool animate,
      List<TimelineAsset> renderAssets) {
    bool stillAnimating = false;
    for (TimelineEntry item in items) {
      /// Sanity check.
      if (item.asset != null) {
        double y = item.labelY;
        double halfHeight = _height / 2.0;
        double thresholdAssetY = y +
            ((y - halfHeight) / halfHeight) *
                Parallax;
        double targetAssetY =
            thresholdAssetY - item.asset.height * AssetScreenScale / 2.0;
        /// 确定当前条目是否可见。
        double targetAssetOpacity =
            (thresholdAssetY - _lastAssetY < 0 ? 0.0 : 1.0) *
                item.opacity *
                item.labelOpacity;

        /// Debounce asset becoming visible.
        if (targetAssetOpacity > 0.0 && item.targetAssetOpacity != 1.0) {
          item.delayAsset = 0.25;
        }
        item.targetAssetOpacity = targetAssetOpacity;
        if (item.delayAsset > 0.0) {
          /// 如果该项目已被反跳，请更新其反跳时间。
          targetAssetOpacity = 0.0;
          item.delayAsset -= elapsed;
          stillAnimating = true;
        }

        /// 确定是否需要缩放条目。
        double targetScale = targetAssetOpacity;
        double targetScaleVelocity = targetScale - item.asset.scale;
        if (!animate || targetScale == 0) {
          item.asset.scaleVelocity = targetScaleVelocity;
        } else {
          double dvy = targetScaleVelocity - item.asset.scaleVelocity;
          item.asset.scaleVelocity += dvy * elapsed * 18.0;
        }

        item.asset.scale += item.asset.scaleVelocity *
            elapsed * 20.0;
        if (animate &&
            (item.asset.scaleVelocity.abs() > 0.01 ||
                targetScaleVelocity.abs() > 0.01)) {
          stillAnimating = true;
        }

        TimelineAsset asset = item.asset;
        if (asset.opacity == 0.0) {
          /// 该项目不可见，只需将其弹出到正确的位置并停止速度即可。
          asset.y = targetAssetY;
          asset.velocity = 0.0;
        }

        /// 确定不透明度增量，并根据需要向该值插值。
        double da = targetAssetOpacity - asset.opacity;
        if (!animate || da.abs() < 0.01) {
          asset.opacity = targetAssetOpacity;
        } else {
          stillAnimating = true;
          asset.opacity += da * min(1.0, elapsed * 15.0);
        }

        /// This asset is visible.
        if (asset.opacity > 0.0) 
        {
          /// 计算垂直增量，并指定插值。
          double targetAssetVelocity = max(_lastAssetY, targetAssetY) - asset.y;
          double dvay = targetAssetVelocity - asset.velocity;
          if (dvay.abs() > _height) {
            asset.y = targetAssetY;
            asset.velocity = 0.0;
          } else {
            asset.velocity += dvay * elapsed * 15.0;
            asset.y += asset.velocity * elapsed * 17.0;
          }
          /// 检查我们是否达到了目标，如果未达到目标，则进行标记。
          if (asset.velocity.abs() > 0.01 || targetAssetVelocity.abs() > 0.01) {
            stillAnimating = true;
          }

          _lastAssetY = targetAssetY +
              asset.height * AssetScreenScale + AssetPadding;
          if (asset is TimelineNima) {
            _lastAssetY += asset.gap;
          } else if (asset is TimelineFlare) {
            _lastAssetY += asset.gap;
          }
          if (asset.y > _height ||
              asset.y + asset.height * AssetScreenScale < 0.0) {
            /// 它不在视野中：将其剔除。确保我们不前进动画。
            if (asset is TimelineNima) {
              TimelineNima nimaAsset = asset;
              if (!nimaAsset.loop) {
                nimaAsset.animationTime = -1.0;
              }
            } else if (asset is TimelineFlare) {
              TimelineFlare flareAsset = asset;
              if (!flareAsset.loop) {
                flareAsset.animationTime = -1.0;
              } else if (flareAsset.intro != null) {
                flareAsset.animationTime = -1.0;
                flareAsset.animation = flareAsset.intro;
              }
            }
          } else {
            /// 在项目中，应用新的动画时间并提高演员。
            if (asset is TimelineNima && isActive) {
              asset.animationTime += elapsed;
              if (asset.loop) {
                asset.animationTime %= asset.animation.duration;
              }
              asset.animation.apply(asset.animationTime, asset.actor, 1.0);
              asset.actor.advance(elapsed);
              stillAnimating = true;
            } else if (asset is TimelineFlare && isActive) {
              asset.animationTime += elapsed;
              /// Flare动画可以具有空闲动画以及简介动画。
              /// 区分哪个是最高优先级并相应地应用它。
              if (asset.idleAnimations != null) {
                double phase = 0.0;
                for (flare.ActorAnimation animation in asset.idleAnimations) {
                  animation.apply(
                      (asset.animationTime + phase) % animation.duration,
                      asset.actor,
                      1.0);
                  phase += 0.16;
                }
              } else {
                if (asset.intro == asset.animation &&
                    asset.animationTime >= asset.animation.duration) {
                  asset.animationTime -= asset.animation.duration;
                  asset.animation = asset.idle;
                }
                if (asset.loop && asset.animationTime > 0) {
                  asset.animationTime %= asset.animation.duration;
                }
                asset.animation.apply(asset.animationTime, asset.actor, 1.0);
              }
              asset.actor.advance(elapsed);
              stillAnimating = true;
            }
            /// 将此资产添加到渲染资产列表中。
            renderAssets.add(item.asset);
          }
        } else {
          /// [项目]不可见。
          item.asset.y = max(_lastAssetY, targetAssetY);
        }
      }

      if (item.children != null && item.isVisible) {
        /// 继续进行层次结构。
        if (_advanceAssets(item.children, elapsed, animate, renderAssets)) {
          stillAnimating = true;
        }
      }
    }
    return stillAnimating;
  }
}
