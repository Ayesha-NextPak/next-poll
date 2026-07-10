import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper
{
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();
  static Database? _database;

  Future<Database> get database async
  {
    if(_database!=null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async
  {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'my_database.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
        '''
        CREATE TABLE polls(
          id TEXT PRIMARY KEY,
          title TEXT,
          creatorId TEXT,
          createdAt INTEGER,
          total_votes INTEGER,
          status TEXT
        )
        '''  
        );
        await db.execute(
        '''
        CREATE TABLE poll_options(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          pollId TEXT,
          name TEXT,
          imageUrl TEXT,
          votes INTEGER,
          FOREIGN KEY (pollId) REFERENCES polls(id) ON DELETE CASCADE
        )
        '''  
        );
      },
      );
  }
  Future<void> insertPollWithFiles({
    required String pollId,
    required String title,
    required String creatorId,
    required DateTime createdAt,
    required List<String> optionNames,
    required List<File?> optionFiles
  })
  async {
    final db = await database;
    await db.insert('polls', {
      'id':pollId,
      'title': title,
      'creatorId' : creatorId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'total_votes':0,
      'status': 'add'
    });
    for(int i=0;i<optionNames.length;i++)
    {
      final filePath = optionFiles[i]?.path??'';
      await db.insert('poll_options', {
        'pollId': pollId,
        'name': optionNames[i],
        'imageUrl': filePath,
        'votes':0
      });
    }
  }
  Future<List<Map<String, dynamic>>> getAllPolls()async
  {
    final db = await database;
    return await db.query('polls');
  }
  Future<List<Map<String, dynamic>>>  getOptionsForPoll(String pollId) async
  {
    final db = await database;
    return await db.query(
      'poll_options',
      where: 'pollId = ?',
      whereArgs: [pollId]
    );
  }
  Future<void> updatePollWithOptions(String pollId, String newTitle, List<Map<String, dynamic>> updatedOptions)async{
    final db = await database;
    final existingPolls = await db.query(
      'polls',
      where:'id = ?',
      whereArgs: [pollId]
    );
    if(existingPolls.isEmpty)
    {
      await db.insert('polls', {
        'id':pollId,
        'title': newTitle,
        'status':'update'
      });
    }else
    {
      await db.update(
        'polls', {
          'title':newTitle,
          'status':'update'
        },
        where: 'id = ?',
        whereArgs: [pollId]
        );
    }
    await db.delete(
      'poll_options',
      where: 'pollId = ?',
      whereArgs: [pollId]
    );
    for(var option in updatedOptions)
    {
      await db.insert('poll_options', {
        'pollId':pollId,
        'name':option['name'],
        'imageUrl': option['imageUrl'],
        'votes':0
      });
    }
  }
  Future<void> insertPollForDeletion(String pollId)async
  {
    final db = await database;
    await db.insert(
      'polls',
      {
        'id':pollId,
        'title':'',
        'creatorId':'',
        'createdAt':DateTime.now().millisecondsSinceEpoch,
        'total_votes':0,
        'status':'delete'
      }
    );
    
  }
  Future<void> deletePoll(String pollId) async
  {
    final db = await database;
    await db.delete('poll_options', where: 'pollId = ?', whereArgs:  [pollId]);
    await db.delete('polls', where: 'id = ?', whereArgs: [pollId]);
  }
}