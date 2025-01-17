import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ecdsa/ecdsa.dart';
import 'package:netrunner/tasker.dart';
import 'package:netrunner/user.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:hive/hive.dart';

import 'package:elliptic/elliptic.dart';
import 'package:elliptic/ecdh.dart';

class ScanServer {
  late final _router = shelf_router.Router()
    ..get('/scaninfo/<id|[0-9]+>', _scanResult)
    ..get("/info", _totalScanInfoHandler)
    ..get("/users", usersHandler)
    ..get("/info/<id|[0-9]+>", _scanInfoHandler)
    ..get("/wsscan", _webSocketScanHandler);
  late final _pipeline = Pipeline().addHandler(_auth);
  final Tasker _tasker = Tasker();
  late final EllipticCurve p256 = getP256();
  late final PublicKey pubKey = PublicKey.fromHex(p256,
      "0431d80e97739e1dff6ee7e045937e45d17e9457e2f6dab10f11673df9976af5263d7f8bb5a9a8c24bb236a800a8b85e9a80aa2aa6a2178037b19dc91aaae87dbb");
  Response usersHandler(Request request) {
    final users = Hive.box<User>("users").toMap().map(
          (key, value) => MapEntry(key.toString(), value),
        );
    return Response.ok(jsonEncode(users));
  }

  FutureOr<Response> _auth(Request request) {
    print(JsonEncoder.withIndent(' ').convert(request.headers));
    final uid = request.headers["uid"];
    final token = request.headers["token"];
    if (uid != null && token != null) {
      var uidHash = List<int>.from(uid.split('').map((e) {
        return int.parse(e);
      }));
      try {
        var sign = Signature.fromASN1Hex(token);
        if (!verify(pubKey, uidHash, sign)) {
          return Response.forbidden("Authentication failure");
        }
      } catch (e) {
        print(e);
        return Response.forbidden("Authentication failure");
      }
    } else {
      return Response.forbidden("No uid suplied");
    }
    return Response.notFound("");
  }

  Response _scanResult(Request request, String id) {
    final task = _tasker.taskStatus(id);
    if (task != null) {
      return Response.ok(
        jsonEncode(task.toJson()),
        headers: {
          ..._jsonHeaders,
          'Cache-Control': 'public, max-age=604800, mutable',
        },
      );
    } else {
      return Response.ok(
        jsonEncode({
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

  FutureOr<Response> _webSocketScanHandler(Request request) async {
    final uid = request.headers["uid"];
    print(jsonEncode(request.headers));
    return webSocketHandler((webSocket) {
      webSocket.sink.add(jsonEncode(_tasker.tasks));
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
          final request = ScanRequest(uid!, id.toString(), hosts,
              ports: jsonMessage["ports"],
              speed: jsonMessage["speed"],
              intrusive: jsonMessage["intrusive"]);
          Directory("scans/$uid").create(recursive: true);
          final scan = scanHosts(request);
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
                  webSocket.sink.add(jsonEncode(event));
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

  final _jsonHeaders = {
    'content-type': 'application/json',
  };

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
    return Response.ok(jsonEncode(_tasker.tasks));
  }

  Future<Process> scanHosts(ScanRequest request) {
    var args = [
      "--stats-every",
      "10s",
      "-oX",
      "scans/${request.uid}/${request.id}.xml",
      "-T${request.speed ?? "4"}",
      "-sV",
      "--script",
      "vuln${(request.intrusive ?? false) ? "" : " and not intrusive"}"
    ];
    final ports = request.ports;
    if (ports != null) {
      args += ["-p", ports];
    }
    args += request.hosts;
    print(args);
    return Process.start("nmap", args, runInShell: true);
  }

  final int port;
  ScanServer(this.port);
  void initializeServer() async {
    final cascade = Cascade().add(_pipeline.call).add(_router.call);
    final server = await shelf_io.serve(
        logRequests().addHandler(cascade.handler),
        InternetAddress.anyIPv4,
        port);
    print('Serving at http://${server.address.host}:${server.port}');
  }
}

class ScanRequest {
  String uid;
  String id;
  List<String> hosts;
  String? ports;
  String? speed;
  bool? intrusive;
  ScanRequest(this.uid, this.id, this.hosts,
      {this.ports, this.speed, this.intrusive});
}
