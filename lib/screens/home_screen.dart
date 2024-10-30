import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/student_model.dart';
import '../providers/attendance_provider.dart';
import 'mark_attendance_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  bool showOnlyPresent = false;
  bool sortAZ = true;
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    context.read<AttendanceProvider>().loadStudents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isSearching
          ? TextField(
            controller: searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter student name or ID',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    searchController.clear();
                    searchQuery = '';
                  });
                },
              ),
            ),
            onChanged: (value) {
              setState(() => searchQuery = value);
            },
          )
          : const Text('Attendance Management'),
        actions: [
          if (isSearching)
            IconButton(
              icon: Icon(Icons.close, color: Colors.blue.shade900),
              onPressed: () {
                setState(() {
                  isSearching = false;
                  searchQuery = '';
                  searchController.clear();
                  showOnlyPresent = false; // Reset filter
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() => isSearching = true);
              },
            ),
          if (!isSearching)
            PopupMenuButton<String>(
              onSelected: (value) => handleMenuOption(value),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'Export', child: Text('Export List')),
                const PopupMenuItem(value: 'Bulk Mark', child: Text('Mark Attendance')),
              ],
            ),
        ],
      ),
      body: Consumer<AttendanceProvider>(
        builder: (context, provider, child) {
          final students = _filterAndSortStudents(provider);
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                width: double.maxFinite,
                height: isSearching ? 50 : 0,
                child: isSearching
                  ? _buildSortAndFilterButtons() : null
              ),
              students.isEmpty
                ? const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off, size: 80, color: Colors.grey),
                      SizedBox(height: 10),
                      Text('No students found. Add students to get started!', textAlign: TextAlign.center),
                    ],
                  ),
                )
                : Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      return InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => MarkAttendanceScreen(student: student)
                            )
                          );
                        },
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 5,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(child: Text('${student.id}')),
                            title: Text(
                              student.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            subtitle: _buildAttendanceSummary(context, student),
                            trailing: _buildActionButtons(context, student),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStudentDialog(context),
        label: Text('Add Student', style: TextStyle(color: Colors.blue.shade900)),
        icon: Icon(Icons.person_add, color: Colors.grey.shade600),
      ),
    );
  }

  List<Student> _filterAndSortStudents(AttendanceProvider provider) {
    final students = provider.students
        .where((student) =>
    student.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
        student.id.toString().contains(searchQuery) &&
            (!showOnlyPresent || provider.getAttendanceForStudent(student.id!).any((record) => record.isPresent)))
        .toList();

    if (!sortAZ) students.sort((a, b) => b.name.compareTo(a.name));

    return students;
  }

  Widget _buildAttendanceSummary(BuildContext context, Student student) {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, child) {
        final attendanceSummary = provider.getAttendanceSummary(student.id!);
        final totalSessions = attendanceSummary['total'] ?? 0;
        final presentSessions = attendanceSummary['present'] ?? 0;
        final attendancePercentage = totalSessions > 0
            ? (presentSessions / totalSessions * 100).toStringAsFixed(1)
            : '0';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Present: $presentSessions / Total: $totalSessions", style: TextStyle(color: Colors.blueGrey.shade600)),
            Text("$attendancePercentage%", style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context, Student student) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.amber),
          onPressed: () => _showEditStudentDialog(context, student),
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _confirmDelete(context, student),
        ),
      ],
    );
  }

  Widget _buildSortAndFilterButtons() {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            icon: Icon(Icons.sort_by_alpha, color: Colors.grey.shade600),
            label: Text(sortAZ ? 'Sort Z-A' : 'Sort A-Z', style: TextStyle(color: Colors.blue.shade900)),
            onPressed: () => setState(() => sortAZ = !sortAZ),
          ),
          if (searchQuery.isNotEmpty)
            ElevatedButton.icon(
              icon: Icon(Icons.clear_all, color: Colors.grey.shade600),
              label: Text('Clear Filters', style: TextStyle(color: Colors.blue.shade900)),
              onPressed: () {
                setState(() {
                  searchQuery = '';
                  searchController.clear();
                  showOnlyPresent = false;
                });
              },
            ),
        ],
      ),
    );
  }

  void _showAddStudentDialog(BuildContext context) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Student'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Student Name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final studentName = nameController.text;
                if (studentName.isNotEmpty) {
                  final newStudent = Student(name: studentName);
                  Provider.of<AttendanceProvider>(context, listen: false).addStudent(newStudent);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Student "$studentName" added successfully')),
                  );
                }
              },
              child: Text('Add', style: TextStyle(color: Colors.blue.shade900)),
            ),
          ],
        );
      },
    );
  }

  void _showEditStudentDialog(BuildContext context, Student student) {
    final nameController = TextEditingController(text: student.name);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Student'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Student Name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final updatedName = nameController.text;
                if (updatedName.isNotEmpty) {
                  Provider.of<AttendanceProvider>(context, listen: false).editStudent(student.id!, updatedName);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Student name updated to "$updatedName"')),
                  );
                }
              },
              child: Text('Save', style: TextStyle(color: Colors.blue.shade900)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Student student) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Student'),
          content: Text('Are you sure you want to delete "${student.name}"?'),
          actions: [
            TextButton(
              onPressed: () {
                Provider.of<AttendanceProvider>(context, listen: false).deleteStudent(student.id!);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Student "${student.name}" deleted successfully')),
                );
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.blue.shade900)),
            ),
          ],
        );
      },
    );
  }

  void handleMenuOption(String value) {
    switch (value) {
      case 'Export':
        _showExportOptions();
        break;
      case 'Bulk Mark':
        _showBulkMarkDialog();
        break;
    }
  }

  void _showExportOptions() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Export Attendance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.insert_drive_file, color: Colors.grey.shade600),
                title: const Text('Export as CSV'),
                onTap: () {
                  context.read<AttendanceProvider>().exportAttendance('csv');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Attendance exported as CSV')),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.picture_as_pdf, color: Colors.grey.shade600),
                title: const Text('Export as PDF'),
                onTap: () {
                  context.read<AttendanceProvider>().exportAttendance('pdf');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Attendance exported as PDF')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBulkMarkDialog() {
    bool markAsPresent = true;
    DateTime selectedDate = DateTime.now();

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bulk Mark Attendance'),
          content: StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  elevation: 3,
                  clipBehavior: Clip.hardEdge,
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        // Keep the time from the current selectedDate
                        final currentTime = TimeOfDay.fromDateTime(selectedDate);
                        setState(() {
                          selectedDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            currentTime.hour,
                            currentTime.minute,
                          );
                        });
                      }
                    },
                    child: SizedBox(
                      width: double.maxFinite,
                      height: 60,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          const Text('Selected Date'),
                          Text('${selectedDate.toLocal()}'.split(' ')[0]),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Mark as: '),
                    Radio<bool>(
                      value: true,
                      groupValue: markAsPresent,
                      activeColor: Colors.green,
                      onChanged: (value) {
                        setState(() {
                          markAsPresent = value!;
                        });
                      },
                    ),
                    const Text('Present'),
                    Radio<bool>(
                      value: false,
                      groupValue: markAsPresent,
                      activeColor: Colors.green,
                      onChanged: (value) {
                        setState(() {
                          markAsPresent = value!;
                        });
                      },
                    ),
                    const Text('Absent'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                context.read<AttendanceProvider>().bulkMarkAttendance(
                  date: selectedDate,
                  isPresent: markAsPresent,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Bulk marked as ${markAsPresent ? "Present" : "Absent"} for ${selectedDate.toLocal()}',
                    ),
                  ),
                );
              },
              child: const Text('Confirm', style: TextStyle(color: Colors.green)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
