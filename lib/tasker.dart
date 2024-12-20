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
class Task {
  @HiveField(0)
  TaskStatus status = TaskStatus.none;
  Process? process;
  @HiveField(1)
  double procent = 0;
  Task();

  Task.createTask(this.process, this.status) {
    process!.exitCode.then(
      (exitCode) {
        if (exitCode == 0) {
          status = TaskStatus.completed;
          procent = 100;
        } else {
          status = TaskStatus.failed;
        }
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
          procent = double.parse(match.group(1) ?? "0");
        }
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'taskStatus': status.name,
        'taskProcent': procent,
      };
}

class Tasker {
  Map<String, Task> tasks = {};
  int workingTask = 0;

  void addTask(String id, Process process) {
    final task = Task.createTask(process, TaskStatus.working);
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
  }

  Task? taskStatus(String id) {
    return Hive.box<Task>("scans").get(id);
  }
}
