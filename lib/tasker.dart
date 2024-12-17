import 'dart:async';
import 'dart:ffi';
import 'dart:io';

enum TaskStatus {
  none,
  working,
  completed
}

class Tasker {
  Map<int, Process> tasks;
  Set<int> completedTasks;
  int len = 0;

  Tasker({required this.tasks, required this.completedTasks});

  void addTask(int id, Process task) {
    tasks[id] = task;
    
    task.exitCode.then((exitCode) {
      tasks.remove(id);
      if (exitCode == 0) {
        completedTasks.add(id);
      }
      //  Save result to file //
      len -= 1;
    },);
    len += 1;
  }

  TaskStatus taskStatus(int id) {
    final completed = completedTasks.contains(id);
    final working = tasks.containsKey(id);
    if (completed && !working) {
      return TaskStatus.completed;
    } else if (working && !completed) {
      return TaskStatus.working;
    }else {
      return TaskStatus.none;
    }
    
  }

}