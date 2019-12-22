import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:timeline/article/timeline_entry_widget.dart';
import 'package:timeline/bloc_provider.dart';
import 'package:timeline/colors.dart';
import 'package:timeline/timeline/timeline_entry.dart';

/// 它存储对包含相关信息的[TimelineEntry]的引用。
class ArticleWidget extends StatefulWidget {
  final TimelineEntry article;
  ArticleWidget({this.article, Key key}) : super(key: key);

  @override
  _ArticleWidgetState createState() => _ArticleWidgetState();
}

/// [ArticleWidget]的[State]将根据用于构建它的[article]参数进行更改。
/// 这是有状态的，因为我们依赖标题，副标题等信息,显示新文章时要更改的文章内容。此外，此页面上使用的[FlareWidget]（即顶部的[TimelineEntryWidget]最喜欢的按钮）依赖于生命周期参数。
class _ArticleWidgetState extends State<ArticleWidget> {
  /// The information for the current page.
  String _articleMarkdown = "";
  String _title = "";
  String sublabel = "";
  /// 此页面使用`flutter_markdown`包，因此需要使用自定义对象定义其样式。这是在[initState（）]中创建的.
  MarkdownStyleSheet _markdownStyleSheet;

  /// [FlareActor]收藏夹按钮是否处于活动状态。
  ///更改后触发Flare动画。
  bool _isFavorite = false;

  Offset _interactOffset;

  /// 设置此页面的markdown样式和本地字段变量。
  @override
  initState() {
    super.initState();

    TextStyle style = TextStyle(
        color: darkText.withOpacity(darkText.opacity * 0.68),
        fontSize: 17.0,
        height: 1.5,
        fontFamily: "Roboto"
         );
    TextStyle h1 = TextStyle(
        color: darkText.withOpacity(darkText.opacity * 0.68),
        fontSize: 32.0,
        height: 1.625,
        fontFamily: "Roboto",
        fontWeight: FontWeight.bold);
    TextStyle h2 = TextStyle(
        color: darkText.withOpacity(darkText.opacity * 0.68),
        fontSize: 24.0,
        height: 2,
        fontFamily: "Roboto",
        fontWeight: FontWeight.bold);
    TextStyle strong = TextStyle(
        color: darkText.withOpacity(darkText.opacity * 0.68),
        fontSize: 17.0,
        height: 1.5,
       fontFamily: "RobotoMedium"
    );
    TextStyle em = TextStyle(
        color: darkText.withOpacity(darkText.opacity * 0.68),
        fontSize: 17.0,
        height: 1.5,
        //fontFamily: "Roboto",
        fontStyle: FontStyle.italic);
    _markdownStyleSheet = MarkdownStyleSheet(
      a: style,
      p: style,
      code: style,
      h1: h1,
      h2: h2,
      h3: style,
      h4: style,
      h5: style,
      h6: style,
      em: em,
      strong: strong,
      blockquote: style,
      img: style,
    );
    setState(() {
      _title = widget.article.label;
      sublabel = widget.article.sublabel;
      _articleMarkdown = "";
      if (widget.article.articleFilename != null) {
        loadMarkdown(widget.article.articleFilename);
      }
    });
  }

  /// 从资产加载降价文件，并将页面内容设置为其值。
  void loadMarkdown(String filename) async {
    rootBundle.loadString("assets/Articles/" + filename).then((String data) {
      setState(() {
        _articleMarkdown = data;
      });
    });
  }

  /// 该小部件包装在[Scaffold]中，具有经典的Material Design视觉布局结构。
  ///它使用[BlocProvider]找出此元素是否是收藏夹的一部分，以正确设置图标。
  /// [SingleChildScrollView]包含一个[Column]，该[Layout]顶部的[TimelineEntryWidget]和[MarkdownBody]
  @override
  Widget build(BuildContext context) {
    EdgeInsets devicePadding = MediaQuery.of(context).padding;
    List<TimelineEntry> favs = BlocProvider.favorites(context).favorites;
    bool isFav = favs.any(
        (TimelineEntry te) => te.label.toLowerCase() == _title.toLowerCase());
    return Scaffold(
        body: Container(
            color: Color.fromRGBO(255, 255, 255, 1),
            child: Stack(children: <Widget>[
              Column(children: <Widget>[
                Container(height: devicePadding.top),
                Container(
                    height: 56.0,
                    width: double.infinity,
                    child: IconButton(
                      alignment: Alignment.centerLeft,
                      icon: Icon(Icons.arrow_back),
                      padding: EdgeInsets.only(left: 20.0, right: 20.0),
                      color: Colors.black.withOpacity(0.5),
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                    )),
                Expanded(
                    child: SingleChildScrollView(
                        padding:
                            EdgeInsets.only(left: 20, right: 20, bottom: 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            GestureDetector(
                                onPanStart: (DragStartDetails details) {
                                  setState(() {
                                    _interactOffset = details.globalPosition;
                                  });
                                },
                                onPanUpdate: (DragUpdateDetails details) {
                                  setState(() {
                                    _interactOffset = details.globalPosition;
                                  });
                                },
                                onPanEnd: (DragEndDetails details) {
                                  setState(() {
                                    _interactOffset = null;
                                  });
                                },
                                child: Container(
                                    height: 280,
                                    child: TimelineEntryWidget(
                                        isActive: true,
                                        timelineEntry: widget.article,
                                        interactOffset: _interactOffset))),
                            Padding(
                              padding: EdgeInsets.only(top: 30.0),
                              child: Row(children: [
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(_title,
                                            textAlign: TextAlign.left,
                                            style: TextStyle(
                                              color: darkText.withOpacity(
                                                  darkText.opacity * 0.87),
                                              fontSize: 25.0,
                                              height: 1.1,
                                              fontFamily: "RobotoMedium",
                                            )),
                                       Text(sublabel,
                                            textAlign: TextAlign.left,
                                            style: TextStyle(
                                                color: darkText.withOpacity(
                                                    darkText.opacity * 0.5),
                                                fontSize: 17.0,
                                                height: 1.5,
                                                fontFamily: "Roboto"))
                                      ]),
                                ),
                                GestureDetector(
                                    child: Transform.translate(
                                        offset: const Offset(15.0, 0.0),
                                        child: Container(
                                          height: 60.0,
                                          width: 60.0,
                                          padding: EdgeInsets.all(15.0),
                                          color: Colors.white,
                                          child: FlareActor(
                                              "assets/Favorite.flr",
                                              animation: isFav
                                                  ? "Favorite"
                                                  : "Unfavorite",
                                              shouldClip: false),
                                        )),
                                    onTap: () {
                                      setState(() {
                                        _isFavorite = !_isFavorite;
                                      });
                                      if (_isFavorite) {
                                        BlocProvider.favorites(context)
                                            .addFavorite(widget.article);
                                      } else {
                                        BlocProvider.favorites(context)
                                            .removeFavorite(widget.article);
                                      }
                                    })
                              ]),
                            ),
                            Container(
                                margin: EdgeInsets.only(top: 20, bottom: 20),
                                height: 1,
                                color: Colors.black.withOpacity(0.11)),
                            MarkdownBody(
                                data: _articleMarkdown,
                                styleSheet: _markdownStyleSheet),
                            SizedBox(height: 100),
                          ],
                        )))
              ])
            ])));
  }
}
