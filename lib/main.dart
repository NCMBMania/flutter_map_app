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
          SettingPage(),
          MapPage(),
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
    location: LatLng(35.68, 51.41),
    zoom: 17,
  );
  final String _mapboxAccessToken =
      'pk.eyJ1IjoibW9vbmdpZnQiLCJhIjoiY2lqNzMxd3lzMDAxcnpzbHZsMWVraXAzeSJ9.0kLZ692L3dLWZzrvGeY37w';

  final markers = [
    LatLng(35.674, 51.41),
    LatLng(35.676, 51.41),
    LatLng(35.678, 51.41),
    LatLng(35.68, 51.41),
    LatLng(35.682, 51.41),
    LatLng(35.684, 51.41),
    LatLng(35.686, 51.41),
  ];

  Offset? _dragStart;
  double _scaleStart = 1.0;
  void _onScaleStart(ScaleStartDetails details) {
    _dragStart = details.focalPoint;
    _scaleStart = 1.0;
  }

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

  @override
  Widget build(BuildContext context) {
    return MapLayoutBuilder(
      controller: controller,
      builder: (context, transformer) {
        final markerPositions =
            markers.map(transformer.fromLatLngToXYCoords).toList();

        final markerWidgets = markerPositions.map(
          (pos) => _buildMarkerWidget(pos, Colors.red),
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () {
            controller.zoom += 0.8;
            setState(() {});
          },
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onTapUp: (details) {
            final location =
                transformer.fromXYCoordsToLatLng(details.localPosition);

            final clicked = transformer.fromLatLngToXYCoords(location);
            print('onTapUp');
            print('${location.longitude}, ${location.latitude}');
            print('${clicked.dx}, ${clicked.dy}');
            print('${details.localPosition.dx}, ${details.localPosition.dy}');
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
                ...markerWidgets,
              ],
            ),
          ),
        );
      },
    );
  }
}

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);
  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  String _log = '';

  Future<void> importGeoPoint() async {
    String loadData = await rootBundle.loadString('json/yamanote.json');
    final stations = json.decode(loadData);
    stations.forEach((params) async {
      var geo = NCMBGeoPoint(
          double.parse(params['latitude']), double.parse(params['longitude']));
      var station = NCMBObject('Station');
      station
        ..set('name', params['name'])
        ..set('geo', geo);
      await station.save();
      setState(() {
        _log = "$station.get('name')を保存しました\n$_log";
      });
      // print(station));
    });
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
        Text(_log),
      ],
    ));
  }
}
/*
class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text(
            'You have pushed the button this many times:',
          ),
          Text(
            '$_counter',
            style: Theme.of(context).textTheme.headline4,
          ),
        ],
      ),
    );
  }
}
*/