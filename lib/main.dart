import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:latlng/latlng.dart';
import 'package:map/map.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:ncmb/ncmb.dart';

void main() {
  NCMB('9170ffcb91da1bbe0eff808a967e12ce081ae9e3262ad3e5c3cac0d9e54ad941',
      '9e5014cd2d76a73b4596deffdc6ec4028cfc1373529325f8e71b7a6ed553157d');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.lightBlue,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final _tab = <Tab>[
    const Tab(text: '地図', icon: Icon(Icons.map_outlined)),
    const Tab(text: 'インポート', icon: Icon(Icons.settings)),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tab.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text('地図アプリ'.toString()),
          bottom: TabBar(
            tabs: _tab,
          ),
        ),
        body: const TabBarView(children: [
          MapPage(),
          SettingPage(),
        ]),
      ),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final controller = MapController(
    location: LatLng(35.6585805, 139.7454329),
    zoom: 13,
  );
  final String _mapboxAccessToken =
      'pk.eyJ1IjoibW9vbmdpZnQiLCJhIjoiY2lqNzMxd3lzMDAxcnpzbHZsMWVraXAzeSJ9.0kLZ692L3dLWZzrvGeY37w';
  Offset? _dragStart;
  double _scaleStart = 1.0;
  void _onScaleStart(ScaleStartDetails details) {
    _dragStart = details.focalPoint;
    _scaleStart = 1.0;
  }

  final List<LatLng> _clickLocations = [];
  List<Widget> _markers = [];
  MapTransformer? _transformer;

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final scaleDiff = details.scale - _scaleStart;
    _scaleStart = details.scale;

    if (scaleDiff > 0) {
      controller.zoom += 0.02;
      setState(() {});
    } else if (scaleDiff < 0) {
      controller.zoom -= 0.02;
      setState(() {});
    } else {
      final now = details.focalPoint;
      final diff = now - _dragStart!;
      _dragStart = now;
      controller.drag(diff.dx, diff.dy);
      setState(() {});
    }
  }

  Widget _buildMarkerWidget(Offset pos, Color color) {
    return Positioned(
      left: pos.dx - 16,
      top: pos.dy - 16,
      width: 40,
      height: 40,
      child: Icon(Icons.location_on, color: color),
    );
  }

  Future<List<NCMBObject>> getStations() async {
    if (_clickLocations.length == 2) {
      return await getStationsSquare();
    } else {
      return await getStationsNear();
    }
  }

  Future<List<NCMBObject>> getStationsNear() async {
    var location = _clickLocations[0];
    var geo = NCMBGeoPoint(location.latitude, location.longitude);
    var query = NCMBQuery('Station');
    query.withinKilometers('geo', geo, 2.5);
    var ary = await query.fetchAll();
    return ary.map((obj) => obj as NCMBObject).toList();
  }

  Future<List<NCMBObject>> getStationsSquare() async {
    var locations = _clickLocations
        .map((location) => NCMBGeoPoint(location.latitude, location.longitude))
        .toList();
    var query = NCMBQuery('Station');
    query.withinSquare('geo', locations[0], locations[1]);
    var ary = await query.fetchAll();
    return ary.map((obj) => obj as NCMBObject).toList();
  }

  List<Widget> getMarkers(List<NCMBGeoPoint> geos, Color color) {
    return geos.map((geo) {
      var pos = _transformer!
          .fromLatLngToXYCoords(LatLng(geo.latitude!, geo.longitude!));
      return _buildMarkerWidget(pos, color);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: MapLayoutBuilder(
        controller: controller,
        builder: (context, transformer) {
          _transformer = transformer;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: () {
              controller.zoom += 0.8;
              setState(() {});
            },
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onTapUp: (details) async {
              final location =
                  transformer.fromXYCoordsToLatLng(details.localPosition);
              if (_clickLocations.length == 2) {
                _clickLocations[0] = _clickLocations[1];
                _clickLocations[1] = location;
              } else {
                _clickLocations.add(location);
              }
              var clicked = _clickLocations
                  .map((location) =>
                      NCMBGeoPoint(location.latitude, location.longitude))
                  .toList();
              final markers = getMarkers(clicked, Colors.purple);
              var ary = await getStations();
              setState(() {
                _markers = getMarkers(
                    ary.map((obj) => obj.get('geo') as NCMBGeoPoint).toList(),
                    Colors.red);
                markers.forEach((makrer) => _markers.add(makrer));
              });
            },
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  final delta = event.scrollDelta;
                  controller.zoom -= delta.dy / 1000.0;
                  setState(() {});
                }
              },
              child: Stack(
                children: [
                  Map(
                    controller: controller,
                    builder: (context, x, y, z) {
                      //Mapbox Streets
                      final url =
                          'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/$z/$x/$y?access_token=$_mapboxAccessToken';
                      return Image(image: NetworkImage(url));
                    },
                  ),
                  ..._markers,
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _clickLocations.clear();
            _markers.clear();
          });
        },
        child: const Icon(Icons.remove_circle_outline),
      ),
    );
  }
}

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);
  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final List<String> _logs = [];
  final String className = 'Station';

  Future<void> deleteAllStations() async {
    var query = NCMBQuery(className);
    query.limit(100);
    var ary = await query.fetchAll();
    for (var station in ary) {
      station.delete();
    }
  }

  Future<void> importGeoPoint() async {
    setState(() {
      _logs.clear();
    });
    deleteAllStations();
    String loadData = await rootBundle.loadString('json/yamanote.json');
    final stations = json.decode(loadData);
    stations.forEach((params) async {
      var station = await saveStation(params);
      setState(() {
        _logs.add("${station.get('name')}を保存しました");
      });
    });
  }

  Future<NCMBObject> saveStation(params) async {
    var geo = NCMBGeoPoint(
        double.parse(params['latitude']), double.parse(params['longitude']));
    var station = NCMBObject(className);
    station
      ..set('name', params['name'])
      ..set('geo', geo);
    await station.save();
    return station;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '山手線のデータをインポートします',
        ),
        TextButton(onPressed: importGeoPoint, child: const Text('インポート')),
        Expanded(
          child: ListView.builder(
              itemBuilder: (BuildContext context, int index) =>
                  Text(_logs[index]),
              itemCount: _logs.length),
        )
      ],
    ));
  }
}
