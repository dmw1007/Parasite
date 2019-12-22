import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import "package:flutter/services.dart" show rootBundle;
import 'package:timeline/timeline/timeline.dart';
import 'package:timeline/timeline/timeline_entry.dart';

/// 在[MenuData.loadFromBundle（）]中加载的Section的数据容器。
class MenuSectionData {
  String label;
  Color textColor;
  Color backgroundColor;
  String assetId;
  List<MenuItemData> items = List<MenuItemData>();
}

/// [MenuSection]的所有子元素的数据容器。
class MenuItemData {
  String label;
  double start;
  double end;
  bool pad = false;
  double padTop = 0.0;
  double padBottom = 0.0;

  MenuItemData();
  /// 从[TimelineEntry]初始化此对象时，请根据提供的[entry]填写字段。该条目实际上指定了[label]，[start]和[end]时间。
  /// 根据提供的[entry]的类型来构建填充。
  MenuItemData.fromEntry(TimelineEntry entry) {
    label = entry.label;

    /// 填充屏幕边缘。
    pad = true;
    TimelineAsset asset = entry.asset;
    /// 最上面的基础的额外填充不占用资产的大小。
    padTop = asset == null ? 0.0 : asset.height * Timeline.AssetScreenScale;
    if (asset is TimelineAnimatedAsset) {
      padTop += asset.gap;
    }

    if (entry.type == TimelineEntryType.Era) {
      start = entry.start;
      end = entry.end;
    } else {
      /// 由于我们集中在单个项目上，因此无需在此处填充。
      double rangeBefore = double.maxFinite;
      for (TimelineEntry prev = entry.previous;
          prev != null;
          prev = prev.previous) {
        double diff = entry.start - prev.start;
        if (diff > 0.0) {
          rangeBefore = diff;
          break;
        }
      }

      double rangeAfter = double.maxFinite;
      for (TimelineEntry next = entry.next; next != null; next = next.next) {
        double diff = next.start - entry.start;
        if (diff > 0.0) {
          rangeAfter = diff;
          break;
        }
      }
      double range = min(rangeBefore, rangeAfter) / 2.0;
      start = entry.start;
      end = entry.end + range;
    }
  }
}

/// 此类的唯一目的是从存储中加载资源并适当地反序列化JSON文件。
/// 
/// `menu.json` contains an array of objects, each with:
/// * label - the title for the section
/// * background - the color on the section background
/// * color - the accent color for the menu section
/// * asset - the background Flare/Nima asset id that will play the section background
/// * items - 一组元素，分别提供该链接的开始和结束时间以及要在[MenuSection]中显示的标签。
class MenuData {
  List<MenuSectionData> sections = [];
  Future<bool> loadFromBundle(String filename) async {
    List<MenuSectionData> menu = List<MenuSectionData>();
    String data = await rootBundle.loadString(filename);
    List jsonEntries = json.decode(data) as List;
    for (dynamic entry in jsonEntries) {
      Map map = entry as Map;

      if (map != null) {
        MenuSectionData menuSection = MenuSectionData();
        menu.add(menuSection);
        if (map.containsKey("label")) {
          menuSection.label = map["label"] as String;
        }
        if (map.containsKey("background")) {
          menuSection.backgroundColor = Color(int.parse(
                  (map["background"] as String).substring(1, 7),
                  radix: 16) +
              0xFF000000);
        }
        if (map.containsKey("color")) {
          menuSection.textColor = Color(
              int.parse((map["color"] as String).substring(1, 7), radix: 16) +
                  0xFF000000);
        }
        if (map.containsKey("asset")) {
          menuSection.assetId = map["asset"] as String;
        }
        if (map.containsKey("items")) {
          List items = map["items"] as List;
          for (dynamic item in items) {
            Map itemMap = item as Map;
            if (itemMap == null) {
              continue;
            }
            MenuItemData itemData = MenuItemData();
            if (itemMap.containsKey("label")) {
              itemData.label = itemMap["label"] as String;
            }
            if (itemMap.containsKey("start")) {
              dynamic start = itemMap["start"];
              itemData.start = start is int ? start.toDouble() : start;
            }
            if (itemMap.containsKey("end")) {
              dynamic end = itemMap["end"];
              itemData.end = end is int ? end.toDouble() : end;
            }
            menuSection.items.add(itemData);
          }
        }
      }
    }
    sections = menu;
    return true;
  }
}
