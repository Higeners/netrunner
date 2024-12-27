/// Support for doing something awesome.
///
/// More dartdocs go here.

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:netrunner/server.dart';
import 'package:netrunner/tasker.dart';
import 'package:hive/hive.dart';

import 'package:ecdsa/ecdsa.dart';

export 'src/netrunner_base.dart';

import 'package:elliptic/elliptic.dart';
import 'package:elliptic/ecdh.dart';

//PUB KEY: 0431d80e97739e1dff6ee7e045937e45d17e9457e2f6dab10f11673df9976af5263d7f8bb5a9a8c24bb236a800a8b85e9a80aa2aa6a2178037b19dc91aaae87dbb

Future<void> main() async {
  /*var ec = getP256();
  var priv = PrivateKey.fromHex(
      ec, "1c7960836c5f0c2731fb41d2fa11e436593070743fbf178a25b4f45af71146d5");
  print(priv);
  print(priv.publicKey);
  var uid = List<int>.from("1378500800859113".split('').map(
    (e) {
      return int.parse(e);
    },
  ));
  var sign = signature(priv, uid);
  print(sign);*/
  final port = 80;
  Hive
    ..init("./db")
    ..registerAdapter(TaskAdapter())
    ..registerAdapter(TaskStatusAdapter());
  await Hive.openBox<Task>("scans");
  ProcessSignal.sigint.watch().listen((signal) {
    print("Exiting....");
    Hive.close();
    exit(signal.signalNumber);
  });
  final server = ScanServer(port);
  server.initializeServer();
  /*
  final cascade = Cascade().add(_router.call);
  final server = await shelf_io.serve(
      logRequests().addHandler(cascade.handler), InternetAddress.anyIPv4, port);
  final _ = await Hive.openBox<Task>("scans");
  print('Serving at http://${server.address.host}:${server.port}');*/
}
/*
// Router instance to handler requests.
final _router = shelf_router.Router()
  ..post('/scan', _scanHandler)
  ..get('/scaninfo/<id|[0-9]+>', _scanResult)
  ..get("/info", _totalScanInfoHandler)
  ..get("/info/<id|[0-9]+>", _scanInfoHandler)
  ..get("/wsscan", _webSocketScanHandler)
  ..get("/ws", wsHandle);

Tasker _tasker = Tasker();

var wsHandle = webSocketHandler((webSocket) {
  webSocket.stream.listen((message) {
    print(message);
    webSocket.sink.add("echo $message");
    webSocket.sink.close();
  });
});

FutureOr<Response> _webSocketScanHandler(Request request) async {
  final uid = request.headers["uid"];
  if (uid != null) {
    //Check for legit uid
  } else {
    return Response.forbidden("No uid suplied");
  }
  print(_jsonEncode(request.headers));
  return webSocketHandler((webSocket) {
    print(webSocket.runtimeType);
    webSocket.sink.add(_jsonEncode(_tasker.tasks));
    webSocket.stream.listen((message) {
      var jsonMessage;
      try {
        jsonMessage = jsonDecode(message);
        print(message);
      } catch (e) {
        print(e);
        return;
      }
      final hosts = List<String>.from(jsonMessage["hosts"]);
      if (hosts.isNotEmpty) {
        final id = DateTime.now().microsecondsSinceEpoch.hashCode;
        final scan =
            scanHosts(id, hosts, jsonMessage["ports"], jsonMessage["speed"]);
        scan.then(
          (proccess) {
            print("Started $id task succesfully (PID ${proccess.pid})");
            proccess.exitCode.then(
              (value) {
                print("Ended $id task with exit code $value");
              },
            ).catchError((e) {
              print(e);
            });
            var task = _tasker.addTask(id.toString(), proccess);
            task.taskProgressStream().listen(
              (event) {
                webSocket.sink.add(_jsonEncode(event));
              },
            );
          },
        ).catchError((e) {
          print(e);
        });
      }
    });
  })(request);
}

void handleScanRequest() {}

/*var _webSocketScanHandler = webSocketHandler((webSocket) {
  print(webSocket.toString());

  webSocket.stream.listen((message) {
    var jsonMessage;
    try {
      jsonMessage = jsonDecode(message);
      print(message);
    } catch (e) {
      print(e);
      return;
    }
    final hosts = List<String>.from(jsonMessage["hosts"]);
    if (hosts.isNotEmpty) {
      final id = DateTime.now().microsecondsSinceEpoch.hashCode;
      final scan =
          scanHosts(id, hosts, jsonMessage["ports"], jsonMessage["speed"]);
      scan.then(
        (proccess) {
          print("Started $id task succesfully (PID ${proccess.pid})");
          proccess.exitCode.then(
            (value) {
              print("Ended $id task with exit code $value");
            },
          ).catchError((e) {
            print(e);
          });
          var task = _tasker.addTask(id.toString(), proccess);
          task.taskProgressStream().listen(
            (event) {
              webSocket.sink.add(_jsonEncode(event));
            },
          );
        },
      ).catchError((e) {
        print(e);
      });
    }
  });
});
*/
Future<Response> _scanHandler(Request request) async {
  final queryString = await request.readAsString();
  var query = jsonDecode(queryString);
  final hosts = List<String>.from(query["hosts"]);
  if (hosts.isNotEmpty) {
    final id = DateTime.now().microsecondsSinceEpoch.hashCode;
    Directory('scans/')
    final scan = scanHosts(id, hosts, query["ports"], query["speed"]);
    scan.then(
      (proccess) {
        print("Started $id task succesfully (PID ${proccess.pid})");
        proccess.exitCode.then(
          (value) {
            print("Ended $id task with exit code $value");
          },
        ).catchError((e) {
          print(e);
        });
        _tasker.addTask(id.toString(), proccess);
      },
    ).catchError((e) {
      print(e);
    });
    return Response.ok(
      _jsonEncode({'id': id}),
      headers: {
        ..._jsonHeaders,
        'Cache-Control': 'public, max-age=604800, immutable',
      },
    );
  } else {
    return Response.badRequest();
  }
}

Future<Response> _scanInfoHandler(Request request, String id) async {
  final task = _tasker.taskStatus(id);
  if (task == null || task.status != TaskStatus.completed) {
    return Response.badRequest(body: "Task has not finished");
  }
  final file = File('scans/$id.xml');
  if (!await file.exists()) {
    return Response.notFound("File not found");
  }
  Stream<List<int>> lines = file.openRead();
  return Response.ok(lines);
}

Response _totalScanInfoHandler(Request request) {
  return Response.ok(_jsonEncode(_tasker.tasks));
}

Future<Process> scanHosts(
    String uid, int id, List<String> host, String? ports, String? speed) {
  var args = [
    "--stats-every",
    "10s",
    "-oX",
    "scans/$uid/$id.xml",
    "-T${speed ?? "4"}",
    "-sV",
    "--script=vuln"
  ];
  if (ports != null) {
    args += ["-p", ports];
  }
  args += host;
  print(args);
  return Process.start("nmap", args, runInShell: true);
}

String _jsonEncode(Object? data) =>
    const JsonEncoder.withIndent(' ').convert(data);

const _jsonHeaders = {
  'content-type': 'application/json',
};

Response _scanResult(Request request, String id) {
  final task = _tasker.taskStatus(id);
  if (task != null) {
    return Response.ok(
      _jsonEncode(task.toJson()),
      headers: {
        ..._jsonHeaders,
        'Cache-Control': 'public, max-age=604800, mutable',
      },
    );
  } else {
    return Response.ok(
      _jsonEncode({
        'taskStatus': TaskStatus.none.name,
        'taskProcent': 0.0,
      }),
      headers: {
        ..._jsonHeaders,
        'Cache-Control': 'public, max-age=604800, mutable',
      },
    );
  }
}
*/
