import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';

class AttendanceProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService.instance;
  List<Student> _students = [];
  List<Attendance> _attendance = [];
  Map<int, List<Attendance>> _attendanceMap = {};
  Map<int, Map<String, int>> _attendanceSummaries = {};

  List<Student> get students => _students;
  List<Attendance> get attendance => _attendance;

  Future<void> loadAttendanceSummaries() async {
    _attendanceSummaries = await _dbService.fetchAttendanceSummaries();
    notifyListeners();
  }

  Map<String, int> getAttendanceSummary(int studentId) {
    return _attendanceSummaries[studentId] ?? {'total': 0, 'present': 0, 'absent': 0};
  }

  // Modify loadStudents to load attendance summaries
  Future<void> loadStudents() async {
    _students = await _dbService.fetchStudents();
    await _loadAllAttendance();
    await loadAttendanceSummaries();  // Load summaries
    notifyListeners();
  }

  Future<void> _loadAllAttendance() async {
    for (var student in _students) {
      _attendanceMap[student.id!] = await _dbService.fetchAttendance(student.id!);
    }
  }

  Future<void> addStudent(Student student) async {
    await _dbService.insertStudent(student);
    await loadStudents();
  }

  Future<void> editStudent(int id, String name) async {
    await _dbService.updateStudent(id, name);
    await loadStudents();
  }

  Future<void> deleteStudent(int id) async {
    await _dbService.deleteStudent(id);
    await loadStudents();
  }

  Future<void> markAttendance(Attendance attendance) async {
    await _dbService.markAttendance(attendance);
    await loadAttendance(attendance.studentId); // This updates the attendance list
    await loadAttendanceSummaries();
    notifyListeners(); // Notify listeners to update the UI
  }

  Future<void> loadAttendance(int studentId) async {
    _attendance = await _dbService.fetchAttendance(studentId);
    notifyListeners(); // Notify listeners to update the UI
  }

  Future<void> undoLastAttendance(int studentId) async {
    await _dbService.undoLastAttendance(studentId);
    await loadAttendance(studentId); // Load attendance after undoing
    await loadAttendanceSummaries();
    notifyListeners(); // Notify listeners to update the UI
  }

  List<Attendance> getAttendanceForStudent(int studentId) {
    return _attendance.where((attendance) => attendance.studentId == studentId).toList();
  }

  Map<int, Map<String, int>> getOverallAttendanceSummary() {
    Map<int, Map<String, int>> summary = {};
    for (var student in _students) {
      summary[student.id!] = getAttendanceSummary(student.id!);
    }
    return summary;
  }

  Future<void> exportAttendance(String format) async {
    if (format == 'csv') {
      // Logic to export attendance data as CSV
      await _dbService.exportAttendanceToCsv(_attendanceMap);
    } else if (format == 'pdf') {
      // Logic to export attendance data as PDF
      await _dbService.exportAttendanceToPdf(_attendanceMap);
    }
    notifyListeners();
  }

  Future<void> bulkMarkAttendance({required DateTime date, required bool isPresent}) async {
    for (var student in _students) {
      final attendance = Attendance(
        studentId: student.id!,
        date: date,
        isPresent: isPresent,
      );
      await _dbService.markAttendance(attendance);
    }
    await loadAttendanceSummaries();
    notifyListeners();
  }
}