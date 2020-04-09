import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart';
import 'package:html/parser.dart';
import 'package:html/dom.dart' as dom;
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Patch {
  String title;
  String url;
  String date;
  String description;
}

class PatchPage extends StatefulWidget {
  final Function setDarkTheme;
  PatchPage(this.setDarkTheme);
  @override
  createState() => new PatchPageState();
}

class PatchPageState extends State<PatchPage> {
  BuildContext scaffoldContext;
  List<Patch> _patchList = [];

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
      debugPrint('PatchPage: ' + e.toString());
    }
  }

  Future _refreshList() async {
    _patchList = [];
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return buildHome();
  }

  Widget buildHome() {
    return new Scaffold(
        appBar: new AppBar(
            title: new Text('OverWidget',
                style: TextStyle(
                    fontFamily: 'GoogleSans',
                    color: Theme.of(context).accentColor)),
            actions: <Widget>[
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
                      child: IgnorePointer(
                          child: SwitchListTile(
                              dense: true,
                              title: Text("Dark Theme"),
                              value: prefs.getBool('darkTheme'),
                              onChanged: (value) {},
                              activeColor: Theme.of(context).accentColor)))
                ],
              )
            ]),
        body: new Builder(builder: (BuildContext context) {
          scaffoldContext = context;
          return _isLoading
              ? new Center(child: new CircularProgressIndicator())
              : _buildList();
        }));
  }

  Widget _buildList() {
    return RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _refreshList,
        child: _patchList.length > 0 ? ListView.builder(
            itemCount: _patchList.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _buildFeatured(_patchList[0]);
              return _buildItem(_patchList[index - 1]);
            })
            : Center(child: Icon(Icons.error_outline, size: 48))
    );
  }

  Widget _buildItem(Patch patch) {
    return ListTile(
        title: Text(patch.title),
        subtitle: Text(patch.date),
        onTap: () => _launchURL(patch.url));
  }

  Widget _buildFeatured(Patch patch) {
    return Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.all(12),
        child: InkWell(
            onTap: () => _launchURL(patch.url),
            child: Column(
              children: <Widget>[
                Padding(
                    padding: EdgeInsets.all(16),
                    child: Align(
                        child: Text('Latest', style: Theme.of(context).textTheme.headline5),
                        alignment: Alignment.centerLeft
                    )
                ),
                ListTile(
                    title: Text(patch.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                            padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
                            child: Text(patch.description)),
                        Align(
                            alignment: Alignment.centerRight,
                            child: FlatButton(
                                child: new Text('MORE'),
                                textTheme: ButtonTextTheme.accent,
                                onPressed: () => _launchURL(patch.url)))
                      ]))
              ],
            )));
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
      Response response =
          await client.get('https://playoverwatch.com/news/patch-notes/pc');

      var document = parse(response.body);
      List<dom.Element> patches = document.querySelectorAll(
          'div.PatchNotesSideNav > ul > li.PatchNotesSideNav-listItem');

      for (var item in patches) {
        Patch patch = new Patch()
          ..title = item.querySelector('h3').text
          ..url = 'https://playoverwatch.com/news/patch-notes/pc' +
              item.querySelector('a').attributes['href']
          ..date = item.querySelector('p').text;

        _patchList.add(patch);
      }

      // Featured
      dom.Element featured =
          document.querySelector('.patch-notes-body > .patch-notes-patch');
      _patchList[0].description = featured.querySelector('h2').text;
    } catch (e) {
      Scaffold.of(scaffoldContext)
          .showSnackBar(SnackBar(content: Text('Error fetching news')));
    }

    setState(() {
      _isLoading = false;
    });
  }
}