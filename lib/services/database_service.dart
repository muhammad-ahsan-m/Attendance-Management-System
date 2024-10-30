import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pdf;
import 'package:csv/csv.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';
import 'dart:io';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();
  static Database? _database;

  DatabaseService._();

  static DatabaseService get instance => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'attendance.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        studentId INTEGER,
        date TEXT,
        isPresent INTEGER,
        FOREIGN KEY(studentId) REFERENCES students(id)
      )
    ''');
  }

  Future<void> insertStudent(Student student) async {
    final db = await database;
    await db.insert('students', student.toMap());
  }

  Future<void> updateStudent(int id, String name) async {
    final db = await database;
    await db.update(
      'students',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteStudent(int id) async {
    final db = await database;
    await db.delete('students', where: 'id = ?', whereArgs: [id]);
    await db.delete('attendance', where: 'studentId = ?', whereArgs: [id]);
  }

  Future<List<Student>> fetchStudents() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('students');
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
  }

  Future<void> markAttendance(Attendance attendance) async {
    final db = await database;
    await db.insert('attendance', attendance.toMap());
  }

  Future<List<Attendance>> fetchAttendance(int studentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'studentId = ?',
      whereArgs: [studentId],
    );
    return List.generate(maps.length, (i) => Attendance.fromMap(maps[i]));
  }

  Future<void> undoLastAttendance(int studentId) async {
    final db = await database;
    final List<Map<String, dynamic>> lastEntry = await db.query(
      'attendance',
      where: 'studentId = ?',
      whereArgs: [studentId],
      orderBy: 'date DESC',
      limit: 1,
    );
    if (lastEntry.isNotEmpty) {
      await db.delete('attendance', where: 'id = ?', whereArgs: [lastEntry.first['id']]);
    }
  }

  Future<Map<int, Map<String, int>>> fetchAttendanceSummaries() async {
    final db = await database;
    final List<Map<String, dynamic>> summaryData = await db.rawQuery('''
      SELECT studentId, COUNT(*) AS total, SUM(isPresent) AS present
      FROM Attendance
      GROUP BY studentId
    ''');

    Map<int, Map<String, int>> summaries = {};
    for (var row in summaryData) {
      summaries[row['studentId']] = {
        'total': row['total'],
        'present': row['present'],
        'absent': row['total'] - row['present'],
      };
    }
    return summaries;
  }

  Future<void> exportAttendanceToCsv(Map<int, List<Attendance>> attendanceMap) async {
    List<List<String>> csvData = [
      ['Student ID', 'Date', 'Status']
    ];

    attendanceMap.forEach((studentId, attendances) {
      for (var attendance in attendances) {
        csvData.add([
          studentId.toString(),
          attendance.date.toIso8601String(),
          attendance.isPresent ? 'Present' : 'Absent'
        ]);
      }
    });

    String csvString = const ListToCsvConverter().convert(csvData);
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/attendance.csv');
    await file.writeAsString(csvString);
  }

  Future<void> exportAttendanceToPdf(Map<int, List<Attendance>> attendanceMap) async {
    final pdfDocument = pdf.Document();

    pdfDocument.addPage(
      pdf.Page(
        build: (pdf.Context context) {
          return pdf.Column(
            crossAxisAlignment: pdf.CrossAxisAlignment.start,
            children: [
              pdf.Text('Attendance Report', style: const pdf.TextStyle(fontSize: 24)),
              pdf.SizedBox(height: 20),
              ...attendanceMap.entries.map((entry) {
                int studentId = entry.key;
                List<Attendance> attendances = entry.value;

                return pdf.Column(
                  crossAxisAlignment: pdf.CrossAxisAlignment.start,
                  children: [
                    pdf.Text('Student ID: $studentId', style: const pdf.TextStyle(fontSize: 18)),
                    pdf.SizedBox(height: 10),
                    ...attendances.map((attendance) {
                      return pdf.Row(
                        mainAxisAlignment: pdf.MainAxisAlignment.spaceBetween,
                        children: [
                          pdf.Text(attendance.date.toIso8601String()),
                          pdf.Text(attendance.isPresent ? 'Present' : 'Absent'),
                        ],
                      );
                    }),
                    pdf.SizedBox(height: 20),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/attendance.pdf');
    await file.writeAsBytes(await pdfDocument.save());
  }
}