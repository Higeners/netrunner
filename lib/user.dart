import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:hive/hive.dart';

part 'user.g.dart';

@HiveType(typeId: 2)
class User {
  @HiveField(0)
  String name;
  @HiveField(1)
  late String hashedPassword;
  User(this.name, this.hashedPassword);
  User.createUser(this.name, String password) {
    hashedPassword = crypto.md5.convert(utf8.encode(password)).toString();
  }

  Map<String, dynamic> toJson() => {
        'username': name,
        'hashedPassword': hashedPassword,
      };
}
