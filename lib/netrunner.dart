/// Support for doing something awesome.
///
/// More dartdocs go here.

import 'dart:convert';
import 'dart:io';

import 'package:netrunner/tasker.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf_static/shelf_static.dart' as shelf_static;


export 'src/netrunner_base.dart';

Future<void> main() async {
    final port = 8080;

    final cascade = Cascade()
        .add(_router.call);
        
    final server = await shelf_io.serve(
        logRequests()
            .addHandler(cascade.handler),
        InternetAddress.anyIPv4, 
        port);


    print('Serving at http://${server.address.host}:${server.port}');
}


// Router instance to handler requests.
final _router = shelf_router.Router()
  ..post('/scan', _scanHandler)
  ..get('/scaninfo/<id|[0-9]+>', _scanResult)
  ..get("/info/<id|[0-9]+>", _scanInfoHnadler)
  ..get('/', _homeHandler);

Response _homeHandler(Request request){
  print(request.requestedUri.queryParameters);
  return Response.ok('Hello, World!');
} 

Tasker _tasker = Tasker(tasks: {}, completedTasks: {});

Future<Response> _scanHandler(Request request) async {
  final queryString =  await request.readAsString();
  print(queryString);
  var query = jsonDecode(queryString);
  print(query);
  final hosts = List<String>.from(query["hosts"]);
  print(hosts[0].runtimeType);
  if (hosts != null) {
    final id = DateTime.now().hashCode;
    final scan = scanHosts(hosts, query["ports"]);
    scan.then((proccess) {
      print("Started $id task succesfully (PID ${proccess.pid})");
      var outputFile = File("scans/$id.xml").openWrite();
      outputFile.addStream(proccess.stdout);
      stderr.addStream(proccess.stderr);
      proccess.exitCode.then((value) {
        print("Ended $id task with exit code $value");
        
      },).catchError((e) {
        print(e);
      });
      _tasker.addTask(id, proccess);
      
    },).catchError((e) {
      print(e);
    });
    return Response.ok(
    _jsonEncode({'id': id}),
    headers: {
      ..._jsonHeaders,
      'Cache-Control': 'public, max-age=604800, immutable',
    },
  );
  }else{
    return Response.badRequest();
  }

}

Future<Response> _scanInfoHnadler(Request request, String id) async {
  
  final file = File('scans/$id.xml');
  if (!await file.exists()) {
    return Response.badRequest(body: "File not found");
  }
  Stream<List<int>> lines = file.openRead();
  return Response.ok(lines);
}


Future<Process> scanHosts(List<String> host, String? ports, {String speed = "4"}) {
  var args = ["-oX", "-", "-T$speed", "-oV", "--script=vuln"];
  if (ports != null) {
    args += ["-p", ports];
  }
  args += host;
  return Process.start("nmap", args, runInShell: true);
  //return Process.run("nmap", args);
}

Response _helloWorldHandler(Request request) => Response.ok('Hello, World!');

String _jsonEncode(Object? data) =>
    const JsonEncoder.withIndent(' ').convert(data);

const _jsonHeaders = {
  'content-type': 'application/json',
};

Response _sumHandler(Request request, String a, String b) {
  final aNum = int.parse(a);
  final bNum = int.parse(b);
  return Response.ok(
    _jsonEncode({'a': aNum, 'b': bNum, 'sum': aNum + bNum}),
    headers: {
      ..._jsonHeaders,
      'Cache-Control': 'public, max-age=604800, immutable',
    },
  );
}

Response _scanResult(Request request, String strid) {
  final id = int.parse(strid);
  final taskStatus =  _tasker.taskStatus(id);
  return Response.ok(
    _jsonEncode({"isCompleted": taskStatus == TaskStatus.completed, "isWorking": taskStatus == TaskStatus.working}),
    headers: {
      ..._jsonHeaders,
      'Cache-Control': 'public, max-age=604800, immutable',
    },
  );
}

final _watch = Stopwatch();

int _requestCount = 0;

final _dartVersion = () {
  final version = Platform.version;
  return version.substring(0, version.indexOf(' '));
}();

Response _infoHandler(Request request) => Response(
      200,
      headers: {
        ..._jsonHeaders,
        'Cache-Control': 'no-store',
      },
      body: _jsonEncode(
        {
          'Dart version': _dartVersion,
          'uptime': _watch.elapsed.toString(),
          'requestCount': ++_requestCount,
        },
      ),
    );

// TODO: Export any libraries intended for clients of this package.
