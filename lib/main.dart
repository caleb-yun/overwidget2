import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'localstorage.dart';
import 'player.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transparent_image/transparent_image.dart';

LocalStorage localStorage = new LocalStorage();

void main() async {
  runApp(MainApp());
}

class MainApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new PlayerListView();
  }
}

class PlayerListView extends StatefulWidget {
  @override
  createState() => new PlayerListViewState();
}

class PlayerListViewState extends State<PlayerListView> {
  BuildContext scaffoldContext;
  SharedPreferences prefs;
  List<Player> _playerList = [];
  //List<dynamic> _dataList = [];

  bool _isDarkTheme = false;
  bool _isLoading = true;

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      new GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();

    SharedPreferences.getInstance().then((SharedPreferences sp) {
      prefs = sp;
      _isDarkTheme = prefs.getBool('darkTheme');
      if (_isDarkTheme == null) {
        print('Prefs not found');
        setDarkTheme(false);
      }
      setState(() {
        _isDarkTheme = prefs.getBool('darkTheme');
      });

      setNavigationTheme();
    });


    _initList();
  }

  _initList() async {
    try {
      //localStorage.clearFile();
      String contents = await localStorage.readFile();
      _playerList = fromJson(contents);
      //String contents = '[{"battletag":"Kala30#1473"}]';

      await _refreshList();

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      print('_initList(): ' + e.toString());
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _refreshList() async {
    var dataList = _playerList;
    _playerList = [];

    for (Player player in dataList) {
      await _fetchData(player.name, player.platform, player.region);
    }
  }

  void setDarkTheme(bool value) {
    setState(() {
      _isDarkTheme = value;
    });
    prefs.setBool('darkTheme', value);

    setNavigationTheme();
  }

  void setNavigationTheme() {
    if (_isDarkTheme) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    } else {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark));
    }
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
        //debugShowCheckedModeBanner: false,
        title: 'OverWidget',
        theme: _isDarkTheme
            ? ThemeData(
                brightness: Brightness.dark,
                accentColor: Colors.red,
              )
            : ThemeData(
                primaryColor: Colors.white,
                primaryColorDark: Colors.grey[300],
                accentColor: Colors.orange,
                inputDecorationTheme: new InputDecorationTheme(
                    labelStyle: new TextStyle(color: Colors.orange),
                    border: new UnderlineInputBorder(
                        borderSide: new BorderSide(
                            color: Colors.orange, style: BorderStyle.solid)))),
        home: buildHome());
  }

  Widget buildHome() {
    return new Scaffold(
        appBar: new AppBar(title: new Text('OverWidget'), actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (String result) {
              switch (result) {
                case 'darkTheme':
                  setDarkTheme(!_isDarkTheme);
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  CheckedPopupMenuItem(
                    checked: _isDarkTheme,
                    value: 'darkTheme',
                    child: Text('Dark Theme'),
                  )
                ],
          )
        ]),
        body: _isLoading
            ? new Center(child: new CircularProgressIndicator())
            : new Builder(builder: (BuildContext context) {
                scaffoldContext = context;
                return _buildList();
              }),
        floatingActionButton: new FloatingActionButton(
            onPressed: _promptAddItem,
            tooltip: 'Add player',
            child: new Icon(Icons.add)));
  }

  Widget _buildList() {
    return RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _refreshList,
        child: ListView.builder(itemBuilder: (context, index) {
          if (index < _playerList.length) {
            return _buildItem(_playerList[index], index);
          }
        }));
  }

  Widget _buildItem(Player player, int index) {
    return Dismissible(
        background: Container(
          color: Colors.red,
        ),
        key: Key(_playerList[index].name),
        onDismissed: (direction) {
          var player = _playerList[index];
          Scaffold.of(scaffoldContext).showSnackBar(SnackBar(
            content: Text("Removed ${player.name}"),
            duration: new Duration(seconds: 5),
            action: SnackBarAction(
                label: 'UNDO',
                onPressed: () {
                  _addItem(player.name, player.platform, player.region);
                }),
          ));

          _removeItem(index);
        },
        child: new ListTile(
            title: new Text(player.name),
            leading: new Container(
                height: 64,
                width: 64,
                child: new FadeInImage.memoryNetwork(
                    placeholder: kTransparentImage,
                    image: player.icon,
                    fadeInDuration: Duration(milliseconds: 500),
                    fit: BoxFit.contain)
            ),
            subtitle: new Text('Level ${player.level}\n' + (player.gamesWon > 0 ? '${player.gamesWon} games won' : '')),
            trailing: new Column(children: <Widget>[
              Container(
                  height: 48,
                  width: 48,
                  child: FadeInImage.memoryNetwork(placeholder: kTransparentImage, image: player.ratingIcon)
              ),
              Text(player.rating > 0 ? '${player.rating}' : '')
            ]),
            isThreeLine: true,
            onLongPress: () => _promptRemoveItem(index),
            onTap: () => _promptWeb(index)));
  }

  void _addItem(String battletag, String platform, String region) async {
    Scaffold.of(scaffoldContext).showSnackBar(SnackBar(
        content: Text('Adding $battletag...'),
        duration: new Duration(seconds: 1)));

    _fetchData(battletag, platform, region);
  }

  void _removeItem(int index) {
    setState(() => _playerList.removeAt(index));
    localStorage.writeFile(toJson(_playerList));
  }

  void _promptRemoveItem(int index) {
    showDialog(
        context: scaffoldContext,
        builder: (BuildContext context) {
          return new AlertDialog(
              title: new Text('Remove ${_playerList[index].name}?'),
              actions: <Widget>[
                new FlatButton(
                    child: new Text('CANCEL'),
                    onPressed: () => Navigator.of(context).pop()),
                new FlatButton(
                    child: new Text('REMOVE'),
                    onPressed: () {
                      _removeItem(index);
                      Navigator.of(context).pop();
                    })
              ]);
        });
  }

  void _promptAddItem() {
    showDialog(
        context: scaffoldContext,
        builder: (BuildContext context) {
          TextEditingController inputController = new TextEditingController();

          return new AlertDialog(
              title: new Text('Add player'),
              content: new Theme(
                  data: new ThemeData(
                      brightness: Theme.of(context).brightness,
                      primaryColor: Theme.of(context).accentColor,
                      primaryColorDark: Theme.of(context).accentColor,
                      accentColor: Theme.of(context).accentColor),
                  child: new TextField(
                    autofocus: true,
                    controller: inputController,
                    //onSubmitted: (val) {
                    //  Navigator.of(context).pop();
                    //},
                    decoration: new InputDecoration(
                        labelText: 'Username', hintText: 'Battletag#1234'),
                  )),
              actions: <Widget>[
                new FlatButton(
                    child: new Text('CANCEL'),
                    onPressed: () => Navigator.of(context).pop()),
                new FlatButton(
                    child: new Text('ADD'),
                    onPressed: () {
                      _addItem(inputController.text, 'pc',
                          'us'); // ADD PLATFROM AND REGION
                      Navigator.pop(context);
                    })
              ]);
        });
  }

  void _promptWeb(int index) {
    Player player = _playerList[index];
    showDialog(
        context: scaffoldContext,
        builder: (BuildContext context) {
          return new SimpleDialog(
              title: new Text('Open in Browser'),
              children: <Widget>[
                new SimpleDialogOption(
                    onPressed: () {
                      _launchURL(
                          'https://playoverwatch.com/career/${player.platform}/${player.name.replaceAll('#', '-')}');
                      Navigator.pop(context);
                    },
                    child: Row(children: <Widget>[
                      Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.open_in_new)),
                      Text('PlayOverwatch')
                    ])),
                new SimpleDialogOption(
                    onPressed: () {
                      _launchURL(
                          'https://overbuff.com/players/${player.platform}/${player.name.replaceAll('#', '-')}');
                      Navigator.pop(context);
                    },
                    child: Row(children: <Widget>[
                      Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.open_in_new)),
                      Text('Overbuff')
                    ])),
                new SimpleDialogOption(
                    onPressed: () {
                      _launchURL(
                          'https://overwatchtracker.com/profile/${player.platform}/global/${player.name.replaceAll('#', '-')}');
                      Navigator.pop(context);
                    },
                    child: Row(children: <Widget>[
                      Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.open_in_new)),
                      Text('Tracker Network')
                    ])),
                new SimpleDialogOption(
                    onPressed: () {
                      _launchURL(
                          'https://masteroverwatch.com/profile/${player.platform}/global/${player.name.replaceAll('#', '-')}');
                      Navigator.pop(context);
                    },
                    child: Row(children: <Widget>[
                      Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.open_in_new)),
                      Text('Master Overwatch')
                    ])),
              ]);
        });
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

  Future<void> _fetchData(String battletag, String platform, String region) async {
    //try {
      final url =
          "https://ow-api.com/v1/stats/$platform/$region/${battletag.replaceAll('#', '-')}/profile";
      final response = await http.get(url);

      if (response.statusCode == 200) {
        var map = json.decode(response.body);
        if (map['name'] != null) {
            Player player = new Player()
              ..name = map['name']
              ..platform = platform
              ..region = region

              ..level = map['prestige']*100 + map['level']
              ..icon = map['icon']
              ..endorsement = map['endorsement']

              ..gamesWon = map['gamesWon']
              ..rating = map['rating']
              ..ratingIcon = map['ratingIcon'];

            setState(() {
              _playerList.add(player);
            });

            localStorage.writeFile(toJson(_playerList));

        } else {
          Scaffold.of(scaffoldContext)
              .showSnackBar(SnackBar(content: Text('Player not found')));
        }
      }
    /*} catch (e) {
      print(e.toString());
      Scaffold.of(scaffoldContext)
          .showSnackBar(SnackBar(content: Text('Network Error')));
    }*/
  }
}
