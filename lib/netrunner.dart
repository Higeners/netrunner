/// Support for doing something awesome.
///
/// More dartdocs go here.

import 'dart:convert';
import 'dart:io';

import 'package:netrunner/tasker.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:hive/hive.dart';

export 'src/netrunner_base.dart';

Future<void> main() async {
    final port = 8080;
    Hive..init("./db")
        ..registerAdapter(TaskAdapter())
        ..registerAdapter(TaskStatusAdapter());
    final cascade = Cascade()
        .add(_router.call);
    final server = await shelf_io.serve(
        logRequests()
            .addHandler(cascade.handler),
        InternetAddress.anyIPv4, 
        port);
    final _ = await Hive.openBox<Task>("scans");
    ProcessSignal.sigint.watch().listen((signal) {
      print("Exiting....");
      Hive.close();
      exit(signal.signalNumber);
    });
    print('Serving at http://${server.address.host}:${server.port}');
}

// Router instance to handler requests.
final _router = shelf_router.Router()
  ..post('/scan', _scanHandler)
  ..get('/scaninfo/<id|[0-9]+>', _scanResult)
  ..get("/info", _totalScanInfoHandler)
  ..get("/info/<id|[0-9]+>", _scanInfoHandler);

Tasker _tasker = Tasker();

Future<Response> _scanHandler(Request request) async {
  final queryString =  await request.readAsString();
  var query = jsonDecode(queryString);
  final hosts = List<String>.from(query["hosts"]);
  if (hosts.isNotEmpty) {
    final id = DateTime.now().hashCode;
    final scan = scanHosts(id, hosts, query["ports"]);
    scan.then((proccess) {
      print("Started $id task succesfully (PID ${proccess.pid})");
      proccess.exitCode.then((value) {
        print("Ended $id task with exit code $value");
        
      },).catchError((e) {
        print(e);
      });
      _tasker.addTask(id.toString(), proccess);
      
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

Future<Response> _scanInfoHandler(Request request, String id) async {
  final task =  _tasker.taskStatus(id);
  if (task == null || task.status != TaskStatus.completed){
    return Response.badRequest(body: "Task has not finished");
  }
  final file = File('scans/$id.xml');
  if (!await file.exists()) {
    return Response.badRequest(body: "File not found");
  }
  Stream<List<int>> lines = file.openRead();
  return Response.ok(lines);
}

Response _totalScanInfoHandler(Request request) {
  return Response.ok(_jsonEncode(_tasker.tasks));

}


Future<Process> scanHosts(int id, List<String> host, String? ports, {String speed = "4"}) {
  var args = ["--stats-every", "10s","-oX", "scans/$id.xml", "-T$speed", "-sV", "--script=vuln"];
  if (ports != null) {
    args += ["-p", ports];
  }
  args += host;
  return Process.start("nmap", args, runInShell: true);
  //return Process.run("nmap", args);
}
String _jsonEncode(Object? data) =>
    const JsonEncoder.withIndent(' ').convert(data);

const _jsonHeaders = {
  'content-type': 'application/json',
};

Response _scanResult(Request request, String id) {
  final task =  _tasker.taskStatus(id) ?? Task();

  return Response.ok(
    _jsonEncode(task.toJson()),
    headers: {
      ..._jsonHeaders,
      'Cache-Control': 'public, max-age=604800, mutable',
    },
  );
}
