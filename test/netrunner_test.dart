import 'dart:convert';
import 'dart:io';

import 'package:netrunner/netrunner.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    var files = [];
    setUp(() {
      for (var i = 2; i < 26; i++) {
        files.add(
            File("db/cve/nvdcve-1.1-20${i.toString().padLeft(2, '0')}.json")
                .readAsStringSync());
      }
      // Additional setup goes here.
    });

    test('First Test', () {
      var i = 0;
      for (var file in files) {
        var map = jsonDecode(file);
        var arr = map["CVE_Items"];
        for (var element in arr) {
          if (findCpe(element)) {
            i += 1;
          }
        }
      }
      print(i);
    });
  });
}

bool findCpe(dynamic element) {
  var config = element["configurations"];
  final search = "vlc:";
  var i = 0;
  for (var node in config["nodes"]) {
    for (var cpe in node["cpe_match"]) {
      if ((cpe["cpe23Uri"] as String).contains(search)) {
        //  .contains(RegExp(r"vlc_media_player:(1\.0\.1|\*)"))) {
        //print(JsonEncoder.withIndent("  ").convert(element));
        print(element["cve"]["CVE_data_meta"]["ID"]);
        return true;
      }
    }
    for (var child in node["children"]) {
      for (var cpe in child["cpe_match"]) {
        if ((cpe["cpe23Uri"] as String).contains(search)) {
          //print(JsonEncoder.withIndent("  ").convert(element));
          print(element["cve"]["CVE_data_meta"]["ID"]);
          return true;
        }
      }
    }
  }
  return false;
}
