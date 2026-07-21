// Teacher Marks Entry Screen
// Spreadsheet-style grid: Students (rows) × Subjects (columns)
// One tab per term. Auto-save with offline fallback. Lock-aware.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/offline_queue.dart';
import '../../core/models/models.dart';
import '../../data/providers.dart';
import '../data/exam_providers.dart';
import '../models/exam_models.dart';

class MarksEntryScreen extends ConsumerStatefulWidget {
  const MarksEntryScreen({super.key, required this.classId});
  final String classId;

  @override
  ConsumerState<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends ConsumerState<MarksEntryScreen>
    with TickerProviderStateMixin {
  TabController? _tabCtrl;
  List<ExamTerm> _terms = [];
  bool _ready = false;

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  void _initTabs(List<ExamTerm> terms) {
    if (terms.length == _terms.length) return;
    _tabCtrl?.dispose();
    _terms = terms;
    _tabCtrl = TabController(length: terms.length, vsync: this);
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marks Entry'),
        bottom: _ready && _terms.isNotEmpty
            ? TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: _terms
                    .map((t) => Tab(text: t.termName))
                    .toList(),
              )
            : null,
      ),
      body: activeSession.when(
        data: (session) {
          if (session == null) {
            return const Center(
              child: Text(
                'Koi active session nahi.\nAdmin se poochein.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return _ConfigLoader(
            classId: widget.classId,
            academicYear: session.label,
            onTermsReady: _initTabs,
            tabCtrl: _tabCtrl,
            terms: _terms,
            ready: _ready,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ── Config loader ─────────────────────────────────────────────────────────────

class _ConfigLoader extends ConsumerWidget {
  const _ConfigLoader({
    required this.classId,
    required this.academicYear,
    required this.onTermsReady,
    required this.tabCtrl,
    required this.terms,
    required this.ready,
  });
  final String classId;
  final String academicYear;
  final ValueChanged<List<ExamTerm>> onTermsReady;
  final TabController? tabCtrl;
  final List<ExamTerm> terms;
  final bool ready;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(
      examConfigProvider((classId: classId, year: academicYear)),
    );

    return configAsync.when(
      data: (config) {
        if (config == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Is class ka exam configuration nahi bana.\n\n'
                'Admin Panel → Exam Mgmt → Exam Configuration mein jaayein.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return _TermsLoader(
          classId: classId,
          academicYear: academicYear,
          config: config,
          onTermsReady: onTermsReady,
          tabCtrl: tabCtrl,
          terms: terms,
          ready: ready,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _TermsLoader extends ConsumerWidget {
  const _TermsLoader({
    required this.classId,
    required this.academicYear,
    required this.config,
    required this.onTermsReady,
    required this.tabCtrl,
    required this.terms,
    required this.ready,
  });
  final String classId;
  final String academicYear;
  final ExamConfig config;
  final ValueChanged<List<ExamTerm>> onTermsReady;
  final TabController? tabCtrl;
  final List<ExamTerm> terms;
  final bool ready;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termsAsync = ref.watch(examTermsProvider(config.id));
    final subjectsAsync = ref.watch(
      classSubjectsProvider((classId: classId, year: academicYear)),
    );
    final studentsAsync = ref.watch(studentsProvider(classId));

    return termsAsync.when(
      data: (loadedTerms) {
        // Notify parent to build tabs
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onTermsReady(loadedTerms);
        });

        return subjectsAsync.when(
          data: (subjects) => studentsAsync.when(
            data: (students) {
              if (!ready || tabCtrl == null || loadedTerms.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (subjects.isEmpty) {
                return const Center(
                  child: Text(
                    'Is class ke subjects nahi bane.\nAdmin → Subject Configuration.',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              if (students.isEmpty) {
                return const Center(child: Text('Is class mein koi student nahi.'));
              }
              return TabBarView(
                controller: tabCtrl,
                children: loadedTerms.map((term) {
                  return _MarksGrid(
                    classId: classId,
                    term: term,
                    subjects: subjects,
                    students: students,
                    isLocked: config.isLocked,
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ── Marks grid ────────────────────────────────────────────────────────────────

class _MarksGrid extends ConsumerStatefulWidget {
  const _MarksGrid({
    required this.classId,
    required this.term,
    required this.subjects,
    required this.students,
    required this.isLocked,
  });
  final String classId;
  final ExamTerm term;
  final List<ClassSubject> subjects;
  final List<Student> students;
  final bool isLocked;

  @override
  ConsumerState<_MarksGrid> createState() => _MarksGridState();
}

class _MarksGridState extends ConsumerState<_MarksGrid>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Local draft: key = "studentId__subjectId"
  final Map<String, String?> _draft = {};
  // Absent map: key = "studentId__subjectId"
  final Map<String, bool> _absent = {};
  // Loaded marks from DB
  Map<String, ExamMark> _loaded = {};
  bool _loadingMarks = true;
  bool _saving = false;

  final _outbox = OfflineQueue(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _loadMarks();
  }

  String _key(String studentId, String subjectId) =>
      '${studentId}__$subjectId';

  Future<void> _loadMarks() async {
    setState(() => _loadingMarks = true);
    try {
      final marks = await ref
          .read(examRepoProvider)
          .getMarksForTerm(widget.classId, widget.term.id);
      final map = <String, ExamMark>{};
      for (final m in marks) {
        map[_key(m.studentId, m.subjectId)] = m;
      }
      if (mounted) {
        setState(() {
          _loaded = map;
          // Pre-fill draft with loaded values
          for (final entry in map.entries) {
            final m = entry.value;
            if (m.isAbsent) {
              _absent[entry.key] = true;
            } else if (m.grade != null) {
              _draft[entry.key] = m.grade;
            } else if (m.obtainedMarks != null) {
              _draft[entry.key] =
                  m.obtainedMarks!.toStringAsFixed(0);
            }
          }
          _loadingMarks = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMarks = false);
    }
  }

  Future<void> _saveMark({
    required Student student,
    required ClassSubject subject,
    String? value,
    bool? absent,
  }) async {
    if (widget.isLocked) return;
    final k = _key(student.id, subject.id);
    final isAbsent = absent ?? _absent[k] ?? false;
    double? marks;
    String? grade;

    if (!isAbsent) {
      if (subject.isGradeSubject) {
        grade = value ?? _draft[k];
      } else {
        final raw = value ?? _draft[k];
        if (raw != null && raw.isNotEmpty) {
          marks = double.tryParse(raw);
          if (marks == null) return;
          if (marks < 0 || marks > widget.term.maximumMarks) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    marks < 0
                        ? 'Marks negative nahi ho sakti!'
                        : 'Max marks: ${widget.term.maximumMarks.toStringAsFixed(0)}',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }
      }
    }

    // Save to Supabase or offline queue
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final row = {
      'student_id': student.id,
      'class_id': widget.classId,
      'subject_id': subject.id,
      'term_id': widget.term.id,
      'obtained_marks': isAbsent ? null : marks,
      'grade': isAbsent ? null : grade,
      'is_absent': isAbsent,
      'entered_by': uid,
      'entered_at': DateTime.now().toIso8601String(),
    };

    try {
      await Supabase.instance.client
          .from('exam_marks')
          .upsert(row, onConflict: 'student_id,subject_id,term_id');
    } catch (_) {
      // Offline fallback
      await _outbox.enqueue('exam_marks', row);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loadingMarks) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Lock banner
        if (widget.isLocked)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            color: Colors.red.withOpacity(0.1),
            child: const Row(
              children: [
                Icon(Icons.lock_rounded, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Text(
                  'Result locked hai — marks enter nahi ho sakti.',
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ],
            ),
          ),

        // Term info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 8),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
          child: Text(
            '${widget.term.termName}  •  Max: ${widget.term.maximumMarks.toStringAsFixed(0)} marks',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),

        // Spreadsheet
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.primaryContainer,
                ),
                columnSpacing: 8,
                horizontalMargin: 12,
                columns: [
                  const DataColumn(
                    label: Text('Student',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ...widget.subjects.map(
                    (s) => DataColumn(
                      label: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            s.subjectName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                          if (s.isGradeSubject)
                            const Text('(Grade)',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.purple)),
                        ],
                      ),
                    ),
                  ),
                ],
                rows: widget.students.map((student) {
                  return DataRow(
                    cells: [
                      // Student name cell
                      DataCell(
                        SizedBox(
                          width: 120,
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.fullName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Roll: ${student.rollNo}',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Subject mark cells
                      ...widget.subjects.map((subject) {
                        final k = _key(student.id, subject.id);
                        final isAbsent = _absent[k] ?? false;
                        return DataCell(
                          _MarkCell(
                            key: ValueKey(k),
                            value: _draft[k],
                            isAbsent: isAbsent,
                            isGradeSubject: subject.isGradeSubject,
                            maxMarks: widget.term.maximumMarks,
                            isLocked: widget.isLocked,
                            onChanged: (val) {
                              setState(() => _draft[k] = val);
                              _saveMark(
                                  student: student,
                                  subject: subject,
                                  value: val);
                            },
                            onAbsentToggle: (val) {
                              setState(() {
                                _absent[k] = val;
                                if (val) _draft[k] = null;
                              });
                              _saveMark(
                                  student: student,
                                  subject: subject,
                                  absent: val);
                            },
                          ),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        // Bulk save button
        if (!widget.isLocked)
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _bulkSave,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: Text(
                    _saving ? 'Saving...' : 'Saari Marks Save Karein'),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _bulkSave() async {
    setState(() => _saving = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
      final rows = <Map<String, dynamic>>[];

      for (final student in widget.students) {
        for (final subject in widget.subjects) {
          final k = _key(student.id, subject.id);
          final isAbsent = _absent[k] ?? false;
          final raw = _draft[k];
          double? marks;
          String? grade;

          if (!isAbsent && raw != null && raw.isNotEmpty) {
            if (subject.isGradeSubject) {
              grade = raw;
            } else {
              marks = double.tryParse(raw);
              if (marks != null &&
                  (marks < 0 || marks > widget.term.maximumMarks)) {
                continue; // Skip invalid
              }
            }
          }

          rows.add({
            'student_id': student.id,
            'class_id': widget.classId,
            'subject_id': subject.id,
            'term_id': widget.term.id,
            'obtained_marks': isAbsent ? null : marks,
            'grade': isAbsent ? null : grade,
            'is_absent': isAbsent,
            'entered_by': uid,
            'entered_at': DateTime.now().toIso8601String(),
          });
        }
      }

      if (rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Koi marks enter nahi kiye.')),
          );
        }
        return;
      }

      try {
        await Supabase.instance.client.from('exam_marks').upsert(
              rows,
              onConflict: 'student_id,subject_id,term_id',
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${rows.length} marks save ho gaye! ✓'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (_) {
        // Offline: queue all
        for (final row in rows) {
          await _outbox.enqueue('exam_marks', row);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Offline — marks queue mein hain, sync hoga jab internet aaye.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Mark cell widget ──────────────────────────────────────────────────────────

class _MarkCell extends StatefulWidget {
  const _MarkCell({
    super.key,
    required this.value,
    required this.isAbsent,
    required this.isGradeSubject,
    required this.maxMarks,
    required this.isLocked,
    required this.onChanged,
    required this.onAbsentToggle,
  });
  final String? value;
  final bool isAbsent;
  final bool isGradeSubject;
  final double maxMarks;
  final bool isLocked;
  final ValueChanged<String?> onChanged;
  final ValueChanged<bool> onAbsentToggle;

  @override
  State<_MarkCell> createState() => _MarkCellState();
}

class _MarkCellState extends State<_MarkCell> {
  late TextEditingController _ctrl;

  static const _grades = ['A+', 'A', 'B+', 'B', 'C+', 'C', 'D', 'E'];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(_MarkCell old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !widget.isGradeSubject) {
      _ctrl.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.isGradeSubject ? 90 : 72,
      child: widget.isAbsent
          ? Center(
              child: GestureDetector(
                onTap: widget.isLocked
                    ? null
                    : () => widget.onAbsentToggle(false),
                child: const Chip(
                  label: Text('Ab',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(horizontal: 2),
                ),
              ),
            )
          : widget.isGradeSubject
              ? DropdownButtonFormField<String>(
                  value: _grades.contains(widget.value)
                      ? widget.value
                      : null,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('—')),
                    ..._grades.map((g) =>
                        DropdownMenuItem(value: g, child: Text(g))),
                    DropdownMenuItem(
                      value: '__ab',
                      child: const Text('Absent',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                  onChanged: widget.isLocked
                      ? null
                      : (val) {
                          if (val == '__ab') {
                            widget.onAbsentToggle(true);
                          } else {
                            widget.onChanged(val);
                          }
                        },
                )
              : Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        enabled: !widget.isLocked,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d{0,3}(\.\d{0,2})?$')),
                        ],
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                          hintText: widget.maxMarks
                              .toStringAsFixed(0),
                          hintStyle: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                        style: const TextStyle(fontSize: 13),
                        textInputAction: TextInputAction.next,
                        onChanged: widget.onChanged,
                      ),
                    ),
                    // Absent toggle button
                    if (!widget.isLocked)
                      GestureDetector(
                        onTap: () => widget.onAbsentToggle(true),
                        child: Tooltip(
                          message: 'Absent mark karein',
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.person_off_rounded,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
