import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';

part 'tasker.g.dart';

@HiveType(typeId: 1)
enum TaskStatus {
  @HiveField(0)
  none,
  @HiveField(1)
  working,
  @HiveField(2)
  completed,
  @HiveField(3)
  failed
}

@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  late int id;
  @HiveField(1)
  TaskStatus status = TaskStatus.none;
  Process? process;
  @HiveField(2)
  double procent = 0;
  StreamController<Map<String, dynamic>> progressStream = StreamController();
  Task();
  Task.createTask(this.process, this.status, this.id) {
    process!.exitCode.then(
      (exitCode) {
        if (exitCode == 0) {
          status = TaskStatus.completed;
          procent = 100;
        } else {
          status = TaskStatus.failed;
        }
        progressStream.add(toJson());
        save();
      },
    );
    var procentStream = process!.stdout.where(
      (event) {
        final line = String.fromCharCodes(event);
        return line.contains("Service scan");
      },
    );
    procentStream.listen(
      (event) {
        final line = String.fromCharCodes(event);
        var re = RegExp(r'([\d.]+)%');
        var match = re.firstMatch(line);
        if (match != null) {
          procent = double.parse(match[1]!);
        }
        progressStream.add(toJson());
        save();
      },
    );
  }

  Stream<Map<String, dynamic>> taskProgressStream() {
    return progressStream.stream;
  }

  Map<String, dynamic> toJson() => {
        'taskStatus': status.name,
        'taskProcent': procent,
      };
}

class Tasker {
  Map<String, Task> tasks = {};
  int workingTask = 0;
  Tasker() {
    final box = Hive.box<Task>("scans");
    tasks = box.toMap().map((key, value) => MapEntry(key.toString(), value));
    print(JsonEncoder().convert(tasks["1012592287"]!.toJson()));
  }
  Task addTask(String id, Process process) {
    final task = Task.createTask(process, TaskStatus.working, int.parse(id));
    tasks[id] = task;
    final box = Hive.box<Task>("scans");
    box.put(id, task);
    process.exitCode.then(
      (exitCode) {
        workingTask -= 1;
        print("Number of working tasks: $workingTask");
      },
    );

    workingTask += 1;
    print("Number of working tasks: $workingTask");
    return task;
  }

  Task? taskStatus(String id) {
    return Hive.box<Task>("scans").get(id);
  }
}
