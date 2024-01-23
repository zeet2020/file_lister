import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:async/async.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:settings_ui/settings_ui.dart';
import 'configurations.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;

class SettingPage extends StatefulWidget {
  const SettingPage({super.key, required this.title, required this.IsarRef});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;
  final Isar IsarRef;

  @override
  State<SettingPage> createState() => _SettingPage();
}

class _SettingPage extends State<SettingPage> {
  late Set<String> scanPath = Set();
  late Isar IsarRef;
  late Configurations activeConfiguration;
  bool _fileExtReadonly = true;
  bool _isScanInProgress = false;
  final TextEditingController _fileExtController = TextEditingController();
  _initializeConfiguration() {
    if (IsarRef.configurations.countSync() == 0) {
      IsarRef.writeTxnSync(() {
        var obj = Configurations();
        obj.scan_path = [];
        obj.file_ext = "mp4";
        var id = IsarRef.configurations.putSync(obj);
        activeConfiguration =
            IsarRef.configurations.getSync(id) as Configurations;
      });
    } else {
      activeConfiguration =
          IsarRef.configurations.where().findFirstSync() as Configurations;
      activeConfiguration =
          IsarRef.configurations.where().findFirstSync() as Configurations;
    }
    setState(() {
      scanPath = activeConfiguration.scan_path.toSet();
      _fileExtController.text = activeConfiguration.file_ext;
    });
  }

  void _subscribeFileExt() {
    setState(() {
      activeConfiguration.file_ext = _fileExtController.text;
      IsarRef.writeTxnSync(() {
        IsarRef.configurations.putSync(activeConfiguration);
      });
    });
  }

  @override
  void initState() {
    IsarRef = widget.IsarRef;
    _initializeConfiguration();
    _fileExtController.addListener(_subscribeFileExt);
    super.initState();
  }

  @override
  void dispose() {
    _fileExtController.removeListener(_subscribeFileExt);
    super.dispose();
  }

  // scan logic
  _scanDirectory(List<String> DirList, Isar db, String extType) {
    List<Stream> completeList = [];

    for (var i = 0; i < DirList.length; i++) {
      var dir = Directory(DirList[i]);

      var dirSub = dir.list(recursive: true, followLinks: false);

      completeList.add(dirSub);
    }
    var mergedStream = StreamGroup.merge(completeList);

    var sub = mergedStream.listen(_storeEntity);
    sub.onError((error) {
      print("error $error");
    });
    sub.onDone(() {
      setState(() {
        _isScanInProgress = false;
      });
      sub.cancel();
    });
    return sub;
  }

  void _storeEntity(fileEntity) {
    var extType = activeConfiguration.file_ext;
    var prtn = extType.split(",").join("|");
    var stat = fileEntity.statSync();
    var file_ext = p.extension(fileEntity.path);
    if ((stat.type != FileSystemEntityType.directory) &&
        file_ext.contains(RegExp('^\.($prtn)\$'))) {
      var obj = Record();
      obj.name = p.basename(fileEntity.path);
      obj.modified = stat.modified;
      obj.path = fileEntity.path;
      obj.size = stat.size;
      obj.ext = file_ext;

      IsarRef.writeTxnSync(() {
        IsarRef.records.putSync(obj);
      });
    }
  }

  Future _startScaning(context) async {
    return Future(() {
      return _scanDirectory(
        activeConfiguration.scan_path,
        IsarRef,
        activeConfiguration.file_ext,
      );
    }).onError((error, stackTrace){
      final snackBar = SnackBar(
        content: const Text("Error occured while scanning"),
        action: SnackBarAction(
          label: 'Close',
          onPressed: () {
            // Some code to undo the change.
          },
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    });
  }

  _toggleFileExt() {
    if (_fileExtReadonly) {
      return IconButton(
          onPressed: () {
            setState(() {
              _fileExtReadonly = false;
            });
            IsarRef.writeTxnSync(() {
              activeConfiguration.file_ext = _fileExtController.text;
              IsarRef.configurations.putSync(activeConfiguration);
            });
          },
          icon: Icon(Icons.edit));
    } else {
      return IconButton(
        onPressed: () {
          setState(() {
            _fileExtReadonly = true;
          });
        },
        icon: Icon(Icons.done_outline_outlined),
      );
    }
  }

  _enableStartScan() {
    var paths = activeConfiguration.scan_path;
    var ext = activeConfiguration.file_ext;

    return (paths.length > 0 &&
        ext.split(",").length > 0 &&
        !_isScanInProgress);
  }



  @override
  Widget build(BuildContext context) {
    var t = MaterialStatesController();
    return Scaffold(
        appBar: AppBar(
          // TRY THIS: Try changing the color here to a specific color (to
          // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
          // change color while the other colors stay the same.
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text(widget.title),
        ),
        body: SettingsList(
          sections: [
            SettingsSection(title: Text("Settings"), tiles: [
              CustomSettingsTile(
                  child: Container(
                      child: Card(
                shape: OutlineInputBorder(),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Add Directory"),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () async {
                              var path = await FilePicker.platform
                                  .getDirectoryPath(
                                      dialogTitle: "Select directory to scan");
                              if (path != null) {
                                setState(() {
                                  scanPath.add(path.toString());
                                });
                                activeConfiguration.scan_path =
                                    scanPath.toList();
                                IsarRef.writeTxnSync(() {
                                  IsarRef.configurations
                                      .putSync(activeConfiguration);
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 300,
                      child: ListView.builder(
                        itemCount: scanPath.length,
                        itemBuilder: (context, index) {
                          var items = scanPath.toList();
                          var path = items[index];
                          return ListTile(
                            leading: Icon(Icons.folder),
                            title: Text(path.toString()),
                            trailing: IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () async {
                                setState(() {
                                  scanPath.remove(path);
                                });
                                IsarRef.writeTxnSync(() {
                                  activeConfiguration.scan_path =
                                      scanPath.toList();
                                  IsarRef.configurations
                                      .putSync(activeConfiguration);
                                });
                              },
                            ),
                          );
                        },
                      ),
                    )
                  ],
                ),
              ))),
              CustomSettingsTile(
                child: Container(
                  child: Card(
                    child: SizedBox(
                        width: 750,
                        child: TextField(
                            controller: _fileExtController,
                            readOnly: _fileExtReadonly,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'File extenions',
                                suffixIcon: _toggleFileExt()))),
                  ),
                ),
              ),
              CustomSettingsTile(
                  child: Container(
                child: Card(
                  shape: OutlineInputBorder(),
                  child: Column(
                    children: [
                      Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 600,
                            child: OutlinedButton(
                              statesController: t,
                              style: ButtonStyle(
                                  shape: MaterialStateProperty.all(
                                      RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(0.0)))),
                              onPressed: _enableStartScan()
                                  ? () {
                                     _startScaning(context);
                                   setState(() {
                                      _isScanInProgress = true;
                                   });
                                  }
                                  : null,
                              child: _isScanInProgress
                                  ? new CircularProgressIndicator()
                                  : Text("Start the scaning"),
                            ),
                          )),
                      Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 600,
                            child: OutlinedButton(
                              style: ButtonStyle(
                                  shape: MaterialStateProperty.all(
                                      RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(0.0)))),
                              onPressed: () {
                                IsarRef.writeTxnSync(() {
                                  IsarRef.records.clearSync();
                                });
                              },
                              child: Text('Clear Database'),
                            ),
                          )),
                    ],
                  ),
                ),
              ))
            ]),
          ],
        ));
  }
}
