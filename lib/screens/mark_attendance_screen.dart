import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_provider.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';

class MarkAttendanceScreen extends StatefulWidget {
  final Student student;

  const MarkAttendanceScreen({super.key, required this.student});

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  DateTime? filterDate;
  bool showOnlyPresent = true;
  bool sortByDateAsc = true;

  @override
  initState() {
    super.initState();
    context.read<AttendanceProvider>().loadAttendance(widget.student.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.student.name),
        actions: [
          IconButton(
            icon: Icon(sortByDateAsc ? Icons.arrow_upward : Icons.arrow_downward),
            tooltip: "Toggle Sort Order",
            onPressed: () => setState(() => sortByDateAsc = !sortByDateAsc),
          ),
          PopupMenuButton<String>(
            onSelected: handleMenuOption,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Export CSV', child: Text('Export as CSV')),
              const PopupMenuItem(value: 'Export PDF', child: Text('Export as PDF')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummarySection(),
          _buildActionsRow(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Divider(indent: 8, endIndent: 8),
          ),
          _buildFilterRow(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Divider(indent: 8, endIndent: 8),
          ),
          Expanded(child: _buildAttendanceList()),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, child) {
        final attendanceRecords = provider.getAttendanceForStudent(widget.student.id!);
        final totalSessions = attendanceRecords.length;
        final presentSessions = attendanceRecords.where((record) => record.isPresent).length;
        final attendancePercentage = totalSessions > 0 ? (presentSessions / totalSessions * 100).toStringAsFixed(1) : '0';

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 4,
            color: Colors.lightBlue.shade50,
            child: ListTile(
              leading: const Icon(Icons.bar_chart, color: Colors.blueAccent),
              title: const Text("Attendance Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              subtitle: Text("Present: $presentSessions / Total: $totalSessions", style: TextStyle(color: Colors.blueGrey.shade600)),
              trailing: Text("$attendancePercentage%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton('Present', Icons.check_circle_outline, Colors.green, isPresent: true),
        _buildActionButton('Absent', Icons.cancel_outlined, Colors.red, isPresent: false),
        _buildActionButton('Undo', Icons.undo, Colors.grey, isUndo: true),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, {bool isPresent = false, bool isUndo = false}) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            Text(label, style: const TextStyle(color: Colors.black)),
          ]
        ),
        onPressed: () {
          if (isUndo) {
            undoLastAttendance();
          } else {
            _markAttendance(isPresent: isPresent);
          }
        },
      ),
    );
  }

  Widget _buildFilterRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text('Show Present Only'),
        const SizedBox(width: 10),
        Switch(
          value: showOnlyPresent,
          activeColor: Colors.blue.shade900,
          onChanged: (value) => setState(() => showOnlyPresent = value),
        ),
        const SizedBox(width: 20)
      ],
    );
  }

  Widget _buildAttendanceList() {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, child) {
        var attendanceList = provider.getAttendanceForStudent(widget.student.id!)
            .where((attendance) =>
        (filterDate == null || attendance.date == filterDate) &&
            (!showOnlyPresent || attendance.isPresent))
            .toList();

        attendanceList.sort((a, b) => sortByDateAsc
            ? a.date.compareTo(b.date)
            : b.date.compareTo(a.date));

        return attendanceList.isEmpty
            ? const Center(child: Text('No attendance records found.'))
            : ListView.builder(
          itemCount: attendanceList.length,
          itemBuilder: (context, index) {
            final attendance = attendanceList[index];
            return ListTile(
              leading: Icon(
                attendance.isPresent ? Icons.check : Icons.close,
                color: attendance.isPresent ? Colors.green : Colors.red,
              ),
              title: Text(DateFormat.yMd().add_jm().format(attendance.date)),
              subtitle: Text(attendance.isPresent ? 'Present' : 'Absent'),
            );
          },
        );
      },
    );
  }

  void _markAttendance({required bool isPresent}) {
    Provider.of<AttendanceProvider>(context, listen: false).markAttendance(
      Attendance(studentId: widget.student.id!, date: DateTime.now(), isPresent: isPresent),
    );
  }

  void undoLastAttendance() {
    Provider.of<AttendanceProvider>(context, listen: false).undoLastAttendance(widget.student.id!);
  }

  void handleMenuOption(String value) {
    switch (value) {
      case 'Export CSV':
        _exportAttendance('csv');
        break;
      case 'Export PDF':
        _exportAttendance('pdf');
        break;
    }
  }

  void _exportAttendance(String format) async {
    await Provider.of<AttendanceProvider>(context, listen: false).exportAttendance(format);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance data exported as $format!')),
      );
    }
  }
}
