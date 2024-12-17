import 'dart:io';

enum TaskStatus {
  none,
  working,
  completed,
  failed
}
class Task {
  TaskStatus status = TaskStatus.none;
  Process? process;
  double procent = 0;
  Task();
  Task.createTask(this.process,this.status) {
    process!.exitCode.then((exitCode) {
      if (exitCode == 0) {
        status = TaskStatus.completed;
      }else {
        status = TaskStatus.failed;
      }
    },);
    var procentStream = process!.stdout.where((event) {
        final line = String.fromCharCodes(event);
        return line.contains("Service scan");
      },);
      procentStream.listen((event) {
        final line = String.fromCharCodes(event);
        var re = RegExp(r'([\d.]+)%');
        var match = re.firstMatch(line);
        if (match != null) {
          procent = double.parse(match.group(1) ?? "0");
        }
      },);
  }
}


class Tasker {
  //Map<int, Process> tasks;
  Map<int, Task> tasks = {};
  int workingTask = 0;

  Tasker();

  void addTask(int id, Process process) {
    tasks[id] = Task.createTask(process, TaskStatus.working);

    process.exitCode.then((exitCode) {
      workingTask -= 1;
      print("Number of working tasks: $workingTask");
    },);

    
    workingTask += 1;
    print("Number of working tasks: $workingTask");
  }

  Task? taskStatus(int id) {
    return tasks[id];   
  }

}