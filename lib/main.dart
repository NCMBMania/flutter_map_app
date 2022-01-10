import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:latlng/latlng.dart';
import 'package:map/map.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:ncmb/ncmb.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future main() async {
  await dotenv.load(fileName: '.env');
  var applicationKey =
      dotenv.get('APPLICATION_KEY', fallback: 'No application key found.');
  var clientKey = dotenv.get('CLIENT_KEY', fallback: 'No client key found.');
  NCMB(applicationKey, clientKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final mapboxAccessToken = '';
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

// 最初の画面用のStatefulWidget
class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // タイトル
  final title = '地図アプリ';

  // 表示するタブ
  final _tab = <Tab>[
    const Tab(text: '地図', icon: Icon(Icons.map_outlined)),
    const Tab(text: 'インポート', icon: Icon(Icons.settings)),
  ];

  // AppBarとタブを表示
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tab.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
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

// 地図画面用のStatefulWidget
class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);
  @override
  State<MapPage> createState() => _MapPageState();
}

// 地図画面
class _MapPageState extends State<MapPage> {
  // 地図コントローラーの初期化
  final controller = MapController(
    location: LatLng(35.6585805, 139.7454329),
    zoom: 13,
  );
  // ドラッグ操作用
  Offset? _dragStart;
  double _scaleStart = 1.0;

  Map? _map;

  // タップした位置の情報
  final List<LatLng> _clickLocations = [];
  // 表示するマーカー
  List<Widget> _markers = [];

  // 初期のスケール情報
  void _onScaleStart(ScaleStartDetails details) {
    _dragStart = details.focalPoint;
    _scaleStart = 1.0;
  }

  // ピンチ/パンによるズーム操作用
  void _onScaleUpdate(ScaleUpdateDetails details) {
    final scaleDiff = details.scale - _scaleStart;
    _scaleStart = details.scale;
    if (scaleDiff > 0) {
      controller.zoom += 0.4;
      setState(() {});
    } else if (scaleDiff < 0) {
      controller.zoom -= 0.4;
      setState(() {});
    } else {
      final now = details.focalPoint;
      final diff = now - _dragStart!;
      _dragStart = now;
      controller.drag(diff.dx, diff.dy);
      setState(() {});
    }
  }

  // マーカーウィジェットを作成する
  Widget _buildMarkerWidget(Offset pos, Color color) {
    return Positioned(
      left: pos.dx - 16,
      top: pos.dy - 16,
      width: 40,
      height: 40,
      child: Icon(Icons.location_on, color: color),
    );
  }

  // 駅情報検索用
  Future<List<NCMBObject>> getStations() async {
    if (_clickLocations.length == 2) {
      // マーカーが2つある場合は矩形検索
      return await getStationsSquare();
    } else {
      // マーカーが1つの場合は付近の検索
      return await getStationsNear();
    }
  }

  // 1つのマーカーをターゲットにした付近検索
  Future<List<NCMBObject>> getStationsNear() async {
    // 位置情報
    var location = _clickLocations[0];
    // NCMBGeoPointに変換
    var geo = NCMBGeoPoint(location.latitude, location.longitude);
    // 検索用のクエリークラス
    var query = NCMBQuery('Station');
    // 位置情報を中心に2.5km範囲で検索
    query.withinKilometers('geo', geo, 2.5);
    // レスポンスを取得
    var ary = await query.fetchAll();
    // List<NCMBObject>に変換
    return ary.map((obj) => obj as NCMBObject).toList();
  }

  // 2つのマーカーをターゲットした矩形検索
  Future<List<NCMBObject>> getStationsSquare() async {
    // 位置情報をNCMBGeoPointに変換
    var locations = getClickedGeoPoint();
    // 検索用のクエリークラス
    var query = NCMBQuery('Station');
    // 2つの位置情報を使って、その中にある駅情報を検索
    query.withinSquare('geo', locations[0], locations[1]);
    // レスポンスを取得
    var ary = await query.fetchAll();
    // List<NCMBObject>に変換
    return ary.map((obj) => obj as NCMBObject).toList();
  }

  // NCMBGeoPointをマーカーウィジェットに変換する
  List<Widget> getMarkers(
      MapTransformer transformer, List<NCMBGeoPoint> geos, Color color) {
    return geos.map((geo) {
      var pos = transformer
          .fromLatLngToXYCoords(LatLng(geo.latitude!, geo.longitude!));
      return _buildMarkerWidget(pos, color);
    }).toList();
  }

  // タップした位置情報をNCMBGeoPointに変換する
  List<NCMBGeoPoint> getClickedGeoPoint() {
    return _clickLocations
        .map((location) => NCMBGeoPoint(location.latitude, location.longitude))
        .toList();
  }

  // 地図をタップした際のイベント
  void _onTapUp(MapTransformer transformer, TapUpDetails details) async {
    // 地図上のXY
    final location = transformer.fromXYCoordsToLatLng(details.localPosition);
    // すでに2つクリックした箇所がある場合は、最初のデータを削除
    if (_clickLocations.length == 2) {
      _clickLocations[0] = _clickLocations[1];
      _clickLocations.removeAt(1);
    }
    // 位置情報を追加
    _clickLocations.add(location);
    // 位置情報をNCMBGeoPointに変換する
    final clicked = getClickedGeoPoint();
    // タップした位置情報をマーカーに変換する
    final markers = getMarkers(transformer, clicked, Colors.purple);
    // NCMBを検索して駅情報を取得
    final stations = await getStations();
    setState(() {
      // 駅情報をマーカーに変換して_markersを更新
      _markers = getMarkers(
          transformer,
          stations.map((obj) => obj.get('geo') as NCMBGeoPoint).toList(),
          Colors.red);
      // タップしたマーカーを_markersに追加
      for (var m in markers) {
        _markers.add(m);
      }
    });
  }

  // Mapbox用のアクセストークンを非同期で取得してウィジェットの初期化を行う関数
  Future<void> initMap() async {
    // .envから読み込み
    await dotenv.load(fileName: '.env');
    // アクセストークン取得
    var mapboxAccessToken = dotenv.get('MAPBOX_ACCESS_TOKEN',
        fallback: 'No mapbox access token found.');
    // ウィジェットを作成
    setState(() {
      _map = Map(
        controller: controller,
        builder: (context, x, y, z) {
          // MapboxのURLを指定
          final url =
              'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/$z/$x/$y?access_token=$mapboxAccessToken';
          return Image(image: NetworkImage(url));
        },
      );
    });
  }

  // 初期化用
  @override
  void initState() {
    super.initState();
    initMap();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: MapLayoutBuilder(
        controller: controller,
        builder: (context, transformer) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            // タップした際のズーム処理
            onDoubleTap: () {
              controller.zoom += 0.8;
              setState(() {});
            },
            // ピンチ/パン処理
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            // タップした際の処理
            onTapUp: (details) async {
              _onTapUp(transformer, details);
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
                  // Mapboxのウィジェットが初期化されているかどうかで処理分け
                  children: _map != null
                      ? [_map!, ..._markers]
                      : [const Text('Loading...')]),
            ),
          );
        },
      ),
      // フローティングボタン
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // タップ、検索結果のマーカーを消す
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

// 設定画面用のStatefulWidget
class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);
  @override
  State<SettingPage> createState() => _SettingPageState();
}

// 設定画面
class _SettingPageState extends State<SettingPage> {
  final List<String> _logs = [];
  final String _className = 'Station';

  // データストアからすべての駅情報を削除
  Future<void> deleteAllStations() async {
    // 駅情報を検索するクエリークラス
    final query = NCMBQuery(_className);
    // 検索結果の取得件数
    query.limit(100);
    // 検索
    final ary = await query.fetchAll();
    // 順番に削除
    for (var station in ary) {
      station.delete();
    }
  }

  // 位置情報のJSONを取り込む処理
  Future<void> importGeoPoint() async {
    // ログを消す
    setState(() {
      _logs.clear();
    });
    // 全駅情報を消す
    deleteAllStations();
    // JSONファイルを読み込む
    String loadData = await rootBundle.loadString('json/yamanote.json');
    final stations = json.decode(loadData);
    // JSONファイルに従って処理
    stations.forEach((params) async {
      // 駅情報を作成
      var station = await saveStation(params);
      // ログを更新
      setState(() {
        _logs.add("${station.get('name')}を保存しました");
      });
    });
  }

  // 駅情報を作成する処理
  Future<NCMBObject> saveStation(params) async {
    // NCMBGeoPointを作成
    var geo = NCMBGeoPoint(
        double.parse(params['latitude']), double.parse(params['longitude']));
    // NCMBObjectを作成
    var station = NCMBObject(_className);
    // 位置情報、駅名をセット
    station
      ..set('name', params['name'])
      ..set('geo', geo);
    // 保存
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
