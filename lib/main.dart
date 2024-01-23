import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'settings.dart';
import 'configurations.dart';
import 'package:isar/isar.dart';
import "package:path_provider/path_provider.dart";

import 'package:open_app_file/open_app_file.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  final Isar IsarRef =
      Isar.openSync([RecordSchema, ConfigurationsSchema], directory: dir.path);
  if (Platform.isWindows || Platform.isLinux) {
    WindowManager.instance.setMinimumSize(const Size(1000, 800));
    //WindowManager.instance.
    //WindowManager.instance.setMaximumSize(const Size(1200, 600));
  }
  runApp(MyApp(IsarRef: IsarRef));
}

class MyApp extends StatelessWidget {
  final Isar IsarRef;
  MyApp({super.key, required this.IsarRef});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File lister',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a blue toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MyHomePage(title: 'File lister', IsarRef: IsarRef),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final Isar IsarRef;
  const MyHomePage({super.key, required this.title, required this.IsarRef});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late ScrollController scrollController;

  late Isar IsarRef;
  late TextEditingController _searchbarController = TextEditingController();
  late List<Record> _recordList;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    IsarRef = widget.IsarRef;
    _searchUpdate();
    _searchbarController..addListener(_searchUpdate);
    //searchUpdate("");
    scrollController = ScrollController()..addListener(_scrollListener);
  }

  @override
  void dispose() {
    scrollController.removeListener(_scrollListener);
    _searchbarController.removeListener(_searchUpdate);
    super.dispose();
  }

  void _randomPlay() {
    if (_recordList.length > 0) {
      var rnd = new Random();
      var idx = rnd.nextInt(_recordList.length);
      var item = _recordList[idx];
      OpenAppFile.open(item.path);
    }
  }

  void _scrollListener() {
    if (scrollController.position.extentAfter < 500) {}
  }

  _searchUpdate() {
    var searchStr = _searchbarController.text;
    List<Record> _records = [];
    if (searchStr.trim().length > 0) {
      _records = IsarRef.records.filter().nameContains(searchStr).findAllSync();
    } else {
      _records = IsarRef.records.filter().nameIsNotEmpty().findAllSync();
    }
    setState(() {
      _recordList = _records;
    });
  }

  _buildList() {
    if (_recordList.length == 0) {
      return Container(
          child: Center(
        child: Text("No item found"),
      ));
    }

    return ListView.builder(
        controller: scrollController,
        itemCount: _recordList.length,
        itemBuilder: (context, index) {
          var r = _recordList[index];
          return Card(
              key: Key(index.toString()),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0.0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExpansionTile(
                    leading: Icon(Icons.file_present),
                    title: Text(r.name),
                    subtitle: Text(r.path),
                    trailing: IconButton(
                      icon: Icon(Icons.file_open),
                      onPressed: () {
                        OpenAppFile.open(r.path);
                      },
                    ),
                    //expandedAlignment: Alignment.topLeft,
                    childrenPadding: EdgeInsets.only(bottom: 10, top: 20),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Text("Size : " + r.size.toString()),
                          Text("created : " + r.modified.toLocal().toString())
                        ],
                      )
                    ],
                  )
                ],
              ));
        });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        actions: [
          Text("Item count: " + _recordList.length.toString()),
          IconButton(
              onPressed: () {
                _randomPlay();
              },
              icon: Icon(Icons.play_circle)),
          Padding(
            padding: EdgeInsets.all(5),
            child: SearchBar(
              controller: _searchbarController,
              leading: Icon(Icons.search),
              shape: MaterialStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(0.0),
                ),
              ),
              constraints: BoxConstraints.tight(Size.fromWidth(400)),
              trailing: [
                IconButton(
                    onPressed: () {
                      _searchbarController.clear();
                    },
                    icon: Icon(Icons.clear))
              ],
            ),
          ),
          IconButton(
              onPressed: () {
                Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (context) =>
                            SettingPage(title: "Settings", IsarRef: IsarRef)))
                    .then((val) {
                  //print("Event");
                  _searchUpdate();
                });
              },
              icon: Icon(Icons.settings_outlined))
        ],
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Container(
            padding: EdgeInsets.only(left: 10, top: 5),
            // Column is also a layout widget. It takes a list of children and
            // arranges them vertically. By default, it sizes itself to fit its
            // children horizontally, and tries to be as tall as its parent.
            //
            // Column has various properties to control how it sizes itself and
            // how it positions its children. Here we use mainAxisAlignment to
            // center the children vertically; the main axis here is the vertical
            // axis because Columns are vertical (the cross axis would be
            // horizontal).
            //
            // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
            // action in the IDE, or press "p" in the console), to see the
            // wireframe for each widget.

            child: _buildList()),
      ),
    );
  }
}
