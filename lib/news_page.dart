import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart';
import 'package:html/parser.dart';
import 'package:html/dom.dart' as dom;

import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:shared_preferences/shared_preferences.dart';



class News {
  String title;
  String description;
  String url;
  String imgUrl;
  String date;
}

class NewsPage extends StatefulWidget {
  Function setDarkTheme;
  NewsPage(this.setDarkTheme);
  @override
  createState() => new NewsPageState();
}

class NewsPageState extends State<NewsPage> {
  BuildContext scaffoldContext;
  List<News> _newsList = [];

  bool _isLoading = true;

  SharedPreferences prefs;

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
  new GlobalKey<RefreshIndicatorState>();


  @override
  void initState() {
    _initList();

    super.initState();
  }

  _initList() async {
    prefs = await SharedPreferences.getInstance();

    try {
      await _fetchData();
    } catch (e) {
      debugPrint('NewsPage: ' + e.toString());
    }

  }

  Future _refreshList() async {
    _newsList = [];
    _fetchData();
  }


  @override
  Widget build(BuildContext context) {
    return buildHome();
  }

  Widget buildHome() {
    return new Scaffold(
        appBar: new AppBar(title: new Text('OverWidget', style: TextStyle(fontFamily: 'GoogleSans', color: Theme.of(context).accentColor) ), actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (String result) {
              switch (result) {
                case 'darkTheme':
                  widget.setDarkTheme(!prefs.getBool('darkTheme'));
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem(
                  value: 'darkTheme',
                  child: IgnorePointer(child: SwitchListTile(
                      dense: true,
                      title: Text("Dark Theme"),
                      value: prefs.getBool('darkTheme'),
                      onChanged: (value) {},
                      activeColor: Theme.of(context).accentColor
                  ))
              )
            ],
          )
        ]),
        body: new Builder(builder: (BuildContext context) {
          scaffoldContext = context;
          scaffoldContext = context;
          return _isLoading ? new Center(child: new CircularProgressIndicator())
              : _buildList();
        })
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _refreshList,
        child: ListView.builder(
            itemCount: _newsList.length,
            itemBuilder: (context, index) {
              return _buildItem(_newsList[index]);
            }
        )
    );
  }

  Widget _buildItem(News news) {
    return Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.all(12),
        child: InkWell(
            onTap: () => _launchURL(news.url),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                    child: Ink.image(image: NetworkImage(news.imgUrl), height: 200, fit: BoxFit.cover)
                ),
                ListTile(
                    title: Text(news.title/*, style: TextStyle(fontSize: 18)*/),
                    subtitle: Padding(
                        padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget> [
                              Text(news.description/*, style: TextStyle(fontSize: 16)*/),
                              Padding(child: Text(news.date), padding: EdgeInsets.only(top: 8))
                            ]
                        )
                    )
                )
              ],
            )
        )
    );
  }

  void _launchURL(final String url) async {
    try {
      await launch(url,
          option: new CustomTabsOption(
            toolbarColor: Theme.of(scaffoldContext).primaryColor,
            enableDefaultShare: true,
            enableUrlBarHiding: true,
            showPageTitle: true,
          ));
    } catch (e) {
      debugPrint(e.toString());
    }
  }


  Future _fetchData() async {

    try {
      var client = Client();
      Response response = await client.get('https://playoverwatch.com/news');

      var document = parse(response.body);
      List<dom.Element> blogs = document.querySelectorAll(
          'ul.blog-list > li.blog-info');

      for (var blog in blogs) {
        News news = new News()
          ..title = blog.querySelector('a.link-title').text
          ..url = 'https://playoverwatch.com' + blog.querySelector('a.link-title').attributes['href']
          ..imgUrl = 'https:' + blog.querySelector('img').attributes['src']
          ..description = blog.querySelector('div.summary').text
          ..date = blog.querySelectorAll('div.sub-title > span')[1].text;

        _newsList.add(news);
      }

    } catch (e) {
      Scaffold.of(scaffoldContext).showSnackBar(SnackBar(content: Text('Error fetching news')));
    }

    setState(() {
      _isLoading = false;
    });
  }


}