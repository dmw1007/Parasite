import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:timeline/colors.dart';
import 'package:url_launcher/url_launcher.dart';

/// 从[MainMenuWidget]打开About页面时，此窗口小部件可见。
/// 
/// 它显示有关应用程序开发的所有信息,开发过程中使用的灵感来源，工具和SDK。
/// 
/// This page uses the package `url_launcher` available at https://pub.dartlang.org/packages/url_launcher
/// to open up urls in a WebView on both iOS & Android.
class AboutPage extends StatelessWidget {
  /// 打开网址之前进行健全性检查。
  _launchUrl(String url) {
    canLaunch(url).then((bool success) {
      if (success) {
        launch(url);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: false,
          backgroundColor: lightGrey,
          iconTheme: IconThemeData(color: Colors.black.withOpacity(0.54)),
          elevation: 0.0,
          leading: IconButton(
            alignment: Alignment.centerLeft,
            icon: Icon(Icons.arrow_back),
            padding: EdgeInsets.only(left: 20.0, right: 20.0),
            color: Colors.black.withOpacity(0.5),
            onPressed: () {
              Navigator.pop(context, true);
            },
          ),
          titleSpacing:
              9.0, // Note that the icon has 20 on the right due to its padding, so we add 10 to get our desired 29
          title: Text("关于",
              textAlign: TextAlign.left,
              style: TextStyle(
                  fontFamily: "RobotoMedium",
                  fontSize: 20.0,
                  color: darkText.withOpacity(darkText.opacity * 0.75))),
        ),
        body: Padding(
          padding: EdgeInsets.only(top: 30, bottom: 20, left: 20, right: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "The Parasite",
                style: TextStyle(
                    fontFamily: "RobotoMedium",
                    fontSize: 34.0,
                    color: darkText.withOpacity(darkText.opacity * 0.75)),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 17.0, bottom: 14.0),
                child: Text(
                  "v1.0",
                  style: TextStyle(
                      fontFamily: "Roboto",
                      fontSize: 17.0,
                      height: 1.5,
                      color: darkText.withOpacity(darkText.opacity * 0.5)),
                ),
              ),
              Expanded(
                  child: Column(children: [
                RichText(
                    text: TextSpan(
                        style: TextStyle(
                            color:
                                darkText.withOpacity(darkText.opacity * 0.75),
                            fontFamily: "Roboto",
                            fontSize: 17.0,
                            height: 1.5),
                        children: [
                      TextSpan(
                        text: "    The Parasite 是使用Flutter框架开发，基于开源项目“万物起源”制作的跨平台应用。 软件内部分图片来源网络。",
                      ),
                      /*TextSpan(
                          text: "Flutter",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()
                            ..onTap =
                                () => _launchUrl("https://www.flutter.io")),*/
                     /* TextSpan(
                        text: " by ",
                      ),*/
                  /*    TextSpan(
                          text: "2Dimensions",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () =>
                                _launchUrl("https://www.2dimensions.com")),*/
                    /*  TextSpan(
                        text:
                            ". The graphics and animations were created using tools by ",
                      ),*/
                     /* TextSpan(
                          text: "2Dimensions",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () =>
                                _launchUrl("https://www.2dimensions.com")),*/
                    /*  TextSpan(
                        text: ".\n\nInspired by the Kurzgesagt video ",
                      ),*/
                    /*  TextSpan(
                          text: "The History & Future of Everything",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => _launchUrl(
                                "https://www.youtube.com/watch?v=5TbUxGZtwGI")),*/
                   /*   TextSpan(
                        text: ".",
                      )*/
                    ]))
              ])
              ),

              Text(
                "Built with",
                style: TextStyle(
                    fontFamily: "Roboto",
                    fontSize: 17.0,
                    height: 1.5,
                    color: Colors.black.withOpacity(0.5)),
              ),
              GestureDetector(
                onTap: () => _launchUrl("https://www.flutter.io"),
                child: Padding(
                    padding: EdgeInsets.only(top: 10.0, bottom: 20.0),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset("assets/flutter_logo.png",
                              height: 45.0, width: 37.0),
                          Container(
                            margin: const EdgeInsets.only(left: 5.0),
                            child: Text(
                              "Flutter",
                              style: TextStyle(
                                  fontSize: 26.0,
                                  color: darkText
                                      .withOpacity(darkText.opacity * 0.6)),
                            ),
                          )
                        ])),
              )
            ],
          ),
        ));
  }
}
