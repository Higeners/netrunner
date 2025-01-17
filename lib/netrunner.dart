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
import 'package:netrunner/user.dart';

//PUB KEY: 0431d80e97739e1dff6ee7e045937e45d17e9457e2f6dab10f11673df9976af5263d7f8bb5a9a8c24bb236a800a8b85e9a80aa2aa6a2178037b19dc91aaae87dbb

Future<void> main() async {
  /*var priv = PrivateKey.fromHex(
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
    ..registerAdapter(UserAdapter())
    ..registerAdapter(TaskStatusAdapter());
  await Hive.openBox<Task>("scans");
  final users = await Hive.openBox<User>("users");
  users.add(User.createUser("root", "123"));
  ProcessSignal.sigint.watch().listen((signal) {
    print("Exiting....");
    Hive.close();
    exit(signal.signalNumber);
  });
  final server = ScanServer(port);
  server.initializeServer();
}
