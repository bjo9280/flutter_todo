import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() {
  runApp(MyApp());
}

class Todo {
  int? id;
  String content;

  Todo({this.id, required this.content});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
    };
  }
}

class DatabaseHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await initDatabase();
    return _database!;
  }

  Future<Database> initDatabase() async {
    String path = join(await getDatabasesPath(), 'todo.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE todos(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT
          )
        ''');
      },
    );
  }

  Future<int> insertTodo(Todo todo) async {
    Database db = await database;
    return await db.insert('todos', todo.toMap());
  }

  Future<List<Todo>> getTodos() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('todos');
    return List.generate(maps.length, (index) {
      return Todo(
        id: maps[index]['id'],
        content: maps[index]['content'],
      );
    });
  }

  Future<void> updateTodo(Todo todo) async {
    Database db = await database;
    await db.update(
      'todos',
      todo.toMap(),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  Future<void> deleteTodo(int id) async {
    Database db = await database;
    await db.delete(
      'todos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

class MyApp extends StatelessWidget {
  final DatabaseHelper dbHelper = DatabaseHelper();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Todo App'),
        ),
        body: TodoScreen(dbHelper: dbHelper),
      ),
    );
  }
}

class TodoScreen extends StatefulWidget {
  final DatabaseHelper dbHelper;

  TodoScreen({required this.dbHelper});

  @override
  _TodoScreenState createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  late Future<List<Todo>> todos;
  TextEditingController contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    todos = widget.dbHelper.getTodos();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: contentController,
            decoration: InputDecoration(hintText: 'Enter your todo'),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              String content = contentController.text;
              if (content.isNotEmpty) {
                await widget.dbHelper.insertTodo(Todo(content: content));
                contentController.clear();
                setState(() {
                  todos = widget.dbHelper.getTodos();
                });
              }
            },
            child: Text('Add Todo'),
          ),
          SizedBox(height: 20),
          FutureBuilder(
            future: todos,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator();
              } else if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              } else {
                List<Todo> todoList = snapshot.data as List<Todo>;
                return Expanded(
                  child: ListView.builder(
                    itemCount: todoList.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(todoList[index].content),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () {
                                _editTodo(context, todoList[index]);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () {
                                _deleteTodo(context, todoList[index]);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _editTodo(BuildContext context, Todo todo) {
    contentController.text = todo.content;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Todo'),
          content: TextField(
            controller: contentController,
            decoration: InputDecoration(hintText: 'Enter your edited todo'),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                String content = contentController.text;
                if (content.isNotEmpty) {
                  todo.content = content;
                  await widget.dbHelper.updateTodo(todo);
                  Navigator.pop(context);
                  setState(() {
                    todos = widget.dbHelper.getTodos();
                  });
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteTodo(BuildContext context, Todo todo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Todo'),
          content: Text('Are you sure you want to delete this todo?'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await widget.dbHelper.deleteTodo(todo.id!);
                Navigator.pop(context);
                setState(() {
                  todos = widget.dbHelper.getTodos();
                });
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
