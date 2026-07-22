# 🚫 IMPORTANT FOR ALL AI AGENTS

This document is the ONLY source of truth for this project.

Never redesign the architecture.

Never replace the database.

Never modify existing modules.

Never restart implementation.

Always continue from the first incomplete milestone.

Every completed milestone MUST update this document.

If conversation credits become low,

STOP

write a CHECKPOINT

and exit safely.
# NEMPS TEACHER ASSISTANT
# PROJECT_BIBLE.md

Version: 1.0

Status: APPROVED

Last Updated: 22 July 2026 — Vercel build fix applied

---

# ⚠ IMPORTANT

This document is the ONLY source of truth for this project.

Every AI Agent (Replit AI, Codex, ChatGPT or any future AI) MUST read this file completely before writing even a single line of code.

This architecture has already been approved by the project owner.

Never redesign it.

Never replace it.

Never ignore it.

Never start from scratch.

Always continue from the first incomplete milestone.

---

# PROJECT GOAL

This application is NOT just a Teacher Assistant anymore.

The final goal is to build a complete School ERP while keeping every existing feature stable.

Existing modules must continue working exactly as they work today.

The Examination Module will become the foundation for all future modules.

Future modules include:

• Examination
• Report Card
• Promotion
• Merit List
• Result Analytics
• WhatsApp Result
• Character Certificate
• Transfer Certificate
• Bonafide Certificate
• Admission Register
• Student Progress History
• Printable Registers
• Fee Module (Future)
• Library Module (Future)

This project must remain scalable for many years.

---

# EXISTING PROJECT

Technology

Flutter

Riverpod

Supabase

Realtime

Offline Queue

Material Design

---

# EXISTING MODULES

The following modules already exist.

THEY ARE STABLE.

THEY MUST NEVER BREAK.

Authentication

Profiles

Teacher Login

Admin Panel

Dashboard

Students

Classes

Teacher-Class Mapping

Attendance

Homework

Reports

WhatsApp Notifications

Realtime

Offline Queue

---

# DATABASE PRINCIPLE

The following tables already exist.

Never rename them.

Never delete them.

Never recreate them.

Reuse them whenever possible.

profiles

students

classes

teacher_classes

attendance

homework

teacher_activity

notices

class_whatsapp_groups

whatsapp_notifications

These tables are production tables.

The Examination Module must integrate with them instead of replacing them.

---

# DEVELOPMENT RULES

Rule 1

Never modify an existing feature unless absolutely required.

Rule 2

Never break Attendance.

Rule 3

Never break Homework.

Rule 4

Never break Reports.

Rule 5

Never break Authentication.

Rule 6

Never remove existing code.

Rule 7

Never rename existing files.

Rule 8

Never rename existing tables.

Rule 9

Never edit old migrations.

Always create new migrations.

Rule 10

Every new feature belongs inside

lib/src/features/examination/

Nothing related to examination should be mixed inside other modules.

---

# ARCHITECTURE PRINCIPLES

The Examination Module must be completely independent.

If one day Examination Module is removed,

Attendance,

Homework,

Reports,

WhatsApp,

Students,

Teacher Management

must still continue working.

This means every dependency should point FROM Examination Module TO existing modules.

Existing modules must never depend upon Examination Module.

---

# PROJECT PHILOSOPHY

Configuration over Hardcoding.

Nothing should be hardcoded.

Everything must be configurable.

Examples

Subjects

Exam Types

Marks

Grades

Report Card Layout

Printing

School Name

Logo

Principal

Remarks

Sessions

Promotion Rules

Everything should come from database configuration.

---

# ACADEMIC STRUCTURE

School Classes

Nursery

Prep

Pre First

Class 1

Class 2

Class 3

Class 4

Class 5

Class 6

Class 7

Class 8

Academic Session Example

2026-27

Everything must be session wise.

Never overwrite previous year's data.

---

# EXAMINATION STRUCTURE

Nursery

No Unit Tests

Only

Oral

Written

Marks

Oral = 40

Written = 60

Total = 100

---

Prep to Class 8

UT1 = 20

Half Yearly = 80

UT2 = 20

Annual = 80

Grand Total = 200

This pattern must remain configurable from Admin Panel.

No exam pattern should ever be hardcoded.

---

# PASSING RULES

Minimum Passing Percentage

33%

Rules

Student must pass subject-wise.

Student must also satisfy overall pass rule.

These rules should be configurable in future.

---

# SUBJECT RULES

Every class can have different subjects.

Examples

Hindi

English

Maths

EVS

GK

Computer

Sanskrit

SST

Drawing

Recitation

Dictation

Drawing always uses Grades.

All remaining subjects use Marks.

Recitation and Dictation are evaluated only in

Half Yearly

Annual

according to school rules.

No subject list should ever be hardcoded.

Admin must manage subjects.

---

END OF PART 1
---

# DATABASE ARCHITECTURE

## DESIGN PHILOSOPHY

The examination module must never duplicate existing student, class or teacher data.

Only references should be stored.

Student details must always be fetched from the existing students table.

Teacher details must always be fetched from profiles.

Class details must always be fetched from classes.

The examination module should only store examination-specific data.

---

# NEW DATABASE TABLES

The following new tables are approved.

No other tables should be created unless approved.

1. exam_configs

Purpose

Stores examination configuration for each class and academic session.

Fields

id

class_id

academic_year

exam_pattern

passing_percentage

result_type

is_locked

created_by

created_at

updated_at

Rules

One configuration per class per academic year.

Once marks entry starts, configuration becomes locked.

Only Admin can modify.

---

2. exam_terms

Purpose

Stores all examination terms.

Examples

Nursery

Oral

Written

Prep to Class 8

UT1

Half Yearly

UT2

Annual

Fields

id

exam_config_id

term_name

maximum_marks

display_order

include_in_final_result

created_at

Rules

Terms should never be hardcoded.

Admin configuration generates these automatically.

---

3. class_subjects

Purpose

Stores subjects for every class.

Fields

id

class_id

academic_year

subject_name

display_order

is_grade_subject

is_active

created_at

Rules

Drawing

is_grade_subject = true

Hindi

English

Maths

EVS

GK

Computer

Sanskrit

SST

Recitation

Dictation

is_grade_subject = false

Subject list must remain editable.

Subjects cannot be deleted after marks exist.

Only disable them.

---

4. exam_marks

Purpose

Stores marks entered by teachers.

Fields

id

student_id

class_id

subject_id

term_id

obtained_marks

grade

is_absent

remarks

entered_by

entered_at

updated_at

Rules

Drawing stores grade.

Other subjects store marks.

Marks should be updated using UPSERT.

No duplicate rows.

One student

One subject

One term

One record.

---

5. grade_configs

Purpose

Stores grading system.

Fields

id

academic_year

grade

minimum_percentage

maximum_percentage

description

display_order

Rules

Admin configurable.

No hardcoded grades.

Example

A1

A2

B1

B2

C1

C2

D

E

---

6. report_templates

Purpose

Controls report card layout.

Fields

id

template_name

academic_year

school_name

school_address

logo_url

principal_name

paper_size

orientation

show_attendance

show_grade

show_percentage

show_rank

show_remarks

footer_text

is_default

created_at

Rules

Multiple templates supported.

Half Yearly

Annual

Nursery

Future templates.

---

7. student_remarks

Purpose

Stores teacher remarks.

Fields

id

student_id

term_id

remark

entered_by

created_at

Rules

One remark per student per term.

Editable by class teacher.

---

# TABLE RELATIONSHIP

Existing Tables

profiles

↓

teacher_classes

↓

classes

↓

students

↓

exam_configs

↓

exam_terms

↓

class_subjects

↓

exam_marks

↓

student_remarks

Grade Config

↓

Report Template

↓

Report Engine

---

# DATABASE RULES

Never duplicate student information.

Never duplicate teacher information.

Never duplicate class information.

Everything must use Foreign Keys.

Every table must support academic_year.

No calculated totals should be stored.

Total

Percentage

Grade

Rank

must always be calculated dynamically.

This prevents incorrect results after editing marks.

---

# ROW LEVEL SECURITY

Admin

Full Access

Teacher

Can access only assigned class.

Teacher cannot view marks of another class.

Teacher cannot modify another class.

Teacher cannot delete records.

Delete permission belongs only to Admin.

---

# MIGRATION RULES

Never edit previous migrations.

Always create new migration files.

Migration names

20260722_exam_configs.sql

20260722_exam_terms.sql

20260722_class_subjects.sql

20260722_exam_marks.sql

20260722_grade_configs.sql

20260722_report_templates.sql

20260722_student_remarks.sql

Every migration must contain

CREATE

INDEX

RLS

ROLLBACK

---

# DATA SAFETY

Never delete marks automatically.

Never delete subjects with marks.

Never delete examination sessions.

Use soft delete where required.

Every important action should be logged.

---

END OF PART 2
---

# ADMIN PANEL

The Examination module must add a new section inside the existing Admin Panel.

Menu Name

Exam Management

Inside Exam Management

1. Academic Session

2. Examination Configuration

3. Subject Configuration

4. Grade Configuration

5. Report Template

6. Print Configuration

7. Lock / Unlock Results

8. Promotion

9. Result Analytics

Nothing should be hardcoded.

Everything must come from database configuration.

------------------------------------------------------------

# ACADEMIC SESSION

Admin should create sessions like

2026-27

2027-28

2028-29

Only one session remains ACTIVE.

Every examination configuration belongs to one session.

Changing active session should never delete previous data.

------------------------------------------------------------

# EXAM CONFIGURATION

Admin selects

Academic Session

↓

Class

↓

Exam Pattern

Nursery

OR

Prep to 8

System automatically creates

Nursery

Oral

Written

Prep

UT1

Half Yearly

UT2

Annual

Marks

40

60

20

80

20

80

Admin may edit maximum marks if school rules change.

------------------------------------------------------------

# SUBJECT CONFIGURATION

Every class manages subjects independently.

Examples

Nursery

Hindi

English

Maths

EVS

GK

Drawing

Prep

Hindi

English

Maths

EVS

GK

Drawing

Recitation

Dictation

Higher Classes

Hindi

English

Maths

Science

SST

Computer

Sanskrit

Drawing

Recitation

Dictation

Admin Features

Add Subject

Rename Subject

Disable Subject

Reorder Subject

Change Display Order

Convert Marks Subject to Grade Subject

Rules

Subject deletion not allowed if marks exist.

------------------------------------------------------------

# GRADE CONFIGURATION

Admin defines

Grade

Minimum %

Maximum %

Description

Example

A1

91

100

Outstanding

A2

81

90

Excellent

B1

71

80

Very Good

B2

61

70

Good

C1

51

60

Average

C2

41

50

Needs Improvement

D

33

40

Pass

E

0

32

Fail

Nothing hardcoded.

------------------------------------------------------------

# REPORT TEMPLATE

Admin can configure

School Name

School Address

Principal Name

Logo

Watermark

Footer

Header

Signature

Paper Size

Portrait

Landscape

Attendance Visibility

Percentage Visibility

Rank Visibility

Remarks Visibility

Future

Multiple Report Templates

Nursery

Half Yearly

Annual

------------------------------------------------------------

# TEACHER WORKFLOW

Teacher Login

↓

Dashboard

↓

Assigned Class

↓

Exam Marks

↓

Choose Exam

↓

Marks Entry

↓

Review

↓

Submit

↓

Print Report Card

Teacher must never see another class.

------------------------------------------------------------

# MARKS ENTRY

Marks entry should be spreadsheet style.

Rows

Students

Columns

Subjects

Teacher clicks one cell.

Enters marks.

Press Enter.

Cursor moves next.

Features

Auto Save

Draft Save

Bulk Save

Absent Checkbox

Grade Dropdown

Undo Last Change

Validation

Cannot enter more than Maximum Marks.

Cannot enter negative marks.

Warning before overwrite.

------------------------------------------------------------

# OFFLINE SUPPORT

If internet unavailable

Marks saved locally.

Offline Queue stores pending changes.

When internet returns

Queue syncs automatically.

Teacher should never lose marks.

------------------------------------------------------------

# RESULT ENGINE

Result Engine should NEVER store

Percentage

Rank

Total

Everything calculated dynamically.

Formula

Subject Total

↓

Exam Total

↓

Overall Total

↓

Percentage

↓

Grade

↓

Pass / Fail

Rules configurable.

------------------------------------------------------------

# PASS RULES

Subject Pass

AND

Overall Pass

Required.

Future

Grace Marks

Compartment

Re-Test

should be supported.

------------------------------------------------------------

# REPORT CARD ENGINE

Report Card should support

Single Student

Selected Students

Whole Class

Roll Number Range

Print Preview

Share PDF

Download PDF

No report card layout should be hardcoded.

------------------------------------------------------------

# BULK PRINT ENGINE

Generate

One Student

OR

Whole Class

One PDF

Report cards should automatically start on new pages.

No page should split one report card.

------------------------------------------------------------

# AUDIT LOG

Every marks modification stores

Teacher

Date

Time

Old Marks

New Marks

Reason

Admin may view history.

Teachers cannot delete audit logs.

------------------------------------------------------------

# RESULT LOCK

Admin locks

UT1

Half Yearly

UT2

Annual

Locked result cannot be modified.

Admin may unlock if required.

------------------------------------------------------------

END OF PART 3
---

# PROMOTION ENGINE

The Examination Module must support automatic promotion.

Promotion Status

PASS

FAIL

COMPARTMENT

DETENTION

PROMOTED

NOT PROMOTED

Future support

Grace Marks

Re-Exam

Improvement Exam

Admin can override promotion manually.

No promotion should overwrite previous academic session.

Student history must always remain available.

------------------------------------------------------------

# MERIT LIST ENGINE

System should generate

Class Topper

Section Topper

Subject Topper

Overall Topper

Highest Marks

Lowest Marks

Average Marks

Pass Percentage

Girls Topper

Boys Topper

Rank calculation must always be dynamic.

Never store rank in database.

------------------------------------------------------------

# ANALYTICS

Admin Dashboard should support

Overall Pass %

Class-wise Pass %

Subject-wise Pass %

Highest Performing Class

Weakest Subject

Highest Marks

Lowest Marks

Average Marks

Attendance vs Result

Exam comparison

Session comparison

------------------------------------------------------------

# CERTIFICATE ENGINE

Future support

Transfer Certificate

Character Certificate

Bonafide Certificate

Migration Certificate

Study Certificate

All certificates should use

Existing Student Table

Existing School Details

Existing Academic Session

Nothing duplicated.

------------------------------------------------------------

# WHATSAPP RESULT

Future Integration

Generate Result PDF

↓

Upload

↓

Generate Secure Link

↓

Send to Parent

↓

Track Delivery

↓

Track Read Status

No examination logic should be duplicated.

------------------------------------------------------------

# PDF ENGINE

Support

A4

Legal

Custom Size

Portrait

Landscape

Whole Class PDF

Selected Students PDF

Single Student PDF

Roll Number Range PDF

High Resolution

School Logo

Header

Footer

Watermark

Principal Signature

Teacher Signature

Student Photograph (Future)

Barcode / QR Code (Future)

------------------------------------------------------------

# PERFORMANCE RULES

Never load unnecessary records.

Always paginate large data.

Use indexes on

student_id

class_id

academic_year

subject_id

term_id

Use batch inserts for marks.

Use batch PDF generation.

Avoid duplicate queries.

------------------------------------------------------------

# SECURITY RULES

Teacher

Only Assigned Class

Admin

Full Access

No direct SQL from UI.

Always use Repository Layer.

Always validate marks before saving.

Never trust client-side validation only.

------------------------------------------------------------

# CODING STANDARDS

Use Riverpod.

Follow existing project architecture.

Never create duplicate repositories.

Never duplicate models.

Never create business logic inside UI.

Business logic belongs inside Repository / Services.

UI should remain lightweight.

------------------------------------------------------------

# TESTING CHECKLIST

Before every commit verify

✓ Login works

✓ Dashboard works

✓ Attendance works

✓ Homework works

✓ Reports work

✓ WhatsApp works

✓ Student list works

✓ Examination works

No existing feature should break.

------------------------------------------------------------

# IMPLEMENTATION MILESTONES

Phase 1

Database

Status

COMPLETE — 22 July 2026

Files Created

supabase/migrations/20260722_academic_sessions.sql

supabase/migrations/20260722_exam_configs.sql

supabase/migrations/20260722_exam_terms.sql

supabase/migrations/20260722_class_subjects.sql

supabase/migrations/20260722_exam_marks.sql

supabase/migrations/20260722_grade_configs.sql

supabase/migrations/20260722_report_templates.sql

supabase/migrations/20260722_student_remarks.sql

Summary

8 migration files created. Each contains CREATE, INDEX, RLS policies, and ROLLBACK comment.
exam_marks includes full audit log table and trigger.
grade_configs seeded with default A1-E grades for 2026-27.
Existing tables untouched. All new tables use foreign keys to existing tables.

Phase 2

Models

Repository

Providers

Status

COMPLETE — 22 July 2026

Files Created

lib/src/features/examination/models/exam_models.dart

lib/src/features/examination/data/exam_repository.dart

lib/src/features/examination/data/exam_providers.dart

Summary

All 8 models defined with fromMap / toMap. Result engine calculates totals, percentage, grade and rank dynamically — nothing stored.
ExamRepository covers all CRUD operations including bulk marks save, session activation, result calculation.
Riverpod providers mirror existing providers.dart pattern. MarksEntryNotifier holds draft marks before bulk save.
No existing files modified.

Phase 3

Admin Configuration

Status

COMPLETE — 22 July 2026

Files Created

lib/src/features/examination/presentation/admin_exam_tab.dart

lib/src/features/examination/presentation/academic_session_screen.dart

lib/src/features/examination/presentation/exam_config_screen.dart

lib/src/features/examination/presentation/subject_config_screen.dart

lib/src/features/examination/presentation/grade_config_screen.dart

Files Modified

lib/src/features/presentation/admin_panel_screen.dart

Summary

New "Exam Mgmt" tab added to existing AdminPanelScreen (tab count 5 → 6, one import added).
admin_exam_tab.dart: menu screen linking to all 4 config sub-screens.
academic_session_screen.dart: create sessions, activate one, previous data never deleted.
exam_config_screen.dart: class + pattern picker, auto-term creation, max marks editing, lock/unlock toggle.
subject_config_screen.dart: add/rename/reorder/toggle-grade/disable subjects, drag-to-reorder.
grade_config_screen.dart: full A1–E grade range CRUD per academic year with color-coded cards.
No existing tabs or features modified.

Phase 4

Teacher Marks Entry

Status

COMPLETE — 22 July 2026

Files Created

lib/src/features/examination/presentation/marks_entry_screen.dart

Files Modified

lib/src/app.dart

lib/src/features/presentation/class_detail_screen.dart

Summary

marks_entry_screen.dart: Spreadsheet-style grid with DataTable. Rows = students, columns = subjects. One tab per term. TextField for marks subjects (with max-marks validation, absent toggle button). DropdownButtonFormField for grade subjects (A+/A/B+/.../E + Absent option). Lock banner when result is locked. Auto-save per cell on onChanged. Bulk save button with offline fallback via OfflineQueue. AutomaticKeepAliveClientMixin keeps each tab loaded. Loaded marks from DB pre-fill the draft map on screen open.
app.dart: Added /exam-marks/:id route → MarksEntryScreen.
class_detail_screen.dart: Added "Exam Marks" tile (purple) in the 2×3 actions grid. No other change.

Phase 5

Report Engine

Status

COMPLETE — 22 July 2026

Files Created

lib/src/features/examination/presentation/result_screen.dart

lib/src/features/examination/presentation/report_card_screen.dart

Files Modified

lib/src/app.dart

lib/src/features/presentation/class_detail_screen.dart

Summary

result_screen.dart: Class-level result overview. Loads active session → exam config → terms → subjects → grades → students, calls classResultsProvider (Phase 2 Result Engine). Displays ranked list of all students with rank badge, name, roll no, total marks, percentage, grade, pass/fail chip. Summary banner shows total/pass/fail counts, pass%, and class topper. Filter popup (All / Pass / Fail). Tap any student opens their individual report card.
report_card_screen.dart: Individual student report card. Shows header card (name, roll no, session, total, %, grade, rank, pass/fail). Subject-wise DataTable with columns for each term + total + grade + P/F. Overall summary card. PDF generation using pdf package — A4 layout with school name (from ReportTemplate), student info, subject table, grand total, pass/fail result, class teacher + principal signature fields. Share PDF via share_plus.
app.dart: Added /results/:id → ResultScreen and /report-card/:classId/:studentId → ReportCardScreen routes. ReportCardArgs passed via GoRouter extra so no duplicate Supabase fetch needed.
class_detail_screen.dart: Added "Results" tile (teal, bar_chart icon) in actions grid alongside existing 5 tiles. No other change.

Phase 6

PDF Engine

Status

COMPLETE — 22 July 2026

Files Created

lib/src/features/examination/presentation/bulk_print_screen.dart

Files Modified

lib/src/features/examination/presentation/result_screen.dart

lib/src/app.dart

Summary

bulk_print_screen.dart: Three print modes — All Students (whole class), Selected Students (checkbox list with Select All / None), Roll Number Range (from/to fields). Paper size picker: A4, Legal, A5. Generates one PDF with one page per student using pdf.addPage() — guaranteed page break between students. Same layout as individual report card (Phase 5): school header, student info, subject table, grand total box, signatures. LinearProgressIndicator shows X/Y progress during generation. Share button appears after PDF is ready via share_plus.
result_screen.dart: Added BulkPrintArgs class (holds precomputed allResults so BulkPrintScreen never re-fetches from Supabase). Added onBulkArgsReady callback chain through _ResultLoader → _DependencyLoader → _ResultsView. _ResultsView notifies parent via addPostFrameCallback once results load. Bulk Print AppBar icon (print_rounded) visible only after results are loaded.
app.dart: Added /bulk-print/:classId route → BulkPrintScreen. Import added.

Phase 7

Promotion Engine

Status

COMPLETE — 22 July 2026

Files Created

supabase/migrations/20260722_promotion_records.sql

lib/src/features/examination/presentation/promotion_screen.dart

Files Modified

lib/src/features/examination/models/exam_models.dart

lib/src/features/examination/data/exam_repository.dart

lib/src/features/examination/data/exam_providers.dart

lib/src/features/examination/presentation/admin_exam_tab.dart

lib/src/app.dart

Summary

promotion_records migration: UUID PK, unique(student_id, class_id, academic_year), result_status (pass/fail/compartment/pending), promotion_status (promoted/not_promoted/pending), is_manual_override bool, override_reason text, overridden_by FK. RLS: Admin full access, Teacher read-only for assigned classes. Updated-at trigger. Previous years never overwritten — academic_year scopes every row.
exam_models.dart: PromotionRecord class with fromMap + toUpsertMap added before Result Calculation Helpers.
exam_repository.dart: getPromotionRecords, generatePromotions (auto-populates from StudentResult list, skips manually-overridden rows), overridePromotion (upserts with is_manual_override=true).
exam_providers.dart: promotionRecordsProvider (FutureProvider.family by classId+year, invalidated after generate/override).
promotion_screen.dart: Admin picks class from dropdown → loads config + results → promotion table. Banner shows Total/Pass/Promoted/NotPromoted/Pending counts. "Auto-Generate" button calls generatePromotions, skips manual overrides. Per-student tile shows roll, name, PASS/FAIL chip, promotion status chip, override icon button. Override dialog: SegmentedButton (Promoted/Not Promoted) + optional reason field.
admin_exam_tab.dart: "Promotion Engine" tile added (teal, school icon), navigates via GoRouter push to /promotion.
app.dart: /promotion route → PromotionScreen added.

Phase 8

Analytics

Status

COMPLETE — 22 July 2026

Files Created

lib/src/features/examination/presentation/analytics_screen.dart

Files Modified

lib/src/features/examination/models/exam_models.dart

lib/src/features/examination/data/exam_repository.dart

lib/src/features/examination/data/exam_providers.dart

lib/src/features/examination/presentation/admin_exam_tab.dart

lib/src/app.dart

Summary

analytics_screen.dart: Four sections — (1) Overall stats grid cards (Total Classes, Students, Overall Pass%, Average%); (2) Class-wise performance with color-coded LinearProgressIndicator bars (green ≥75%, amber ≥50%, red <50%), pass count/total, avg/highest/lowest%; (3) Subject weakness table sorted by lowest average% across all classes — warning icon for <50% subjects; (4) Class Toppers list with gold trophy icon. No new packages; uses only Material widgets. Loads all class results in parallel via Riverpod family providers.
exam_models.dart: ClassAnalyticsSummary (with static fromResults factory), SubjectAnalyticsStat, ExamConfigWithClass models added.
exam_repository.dart: getExamConfigsWithClassNames uses Supabase nested select (classes(name)) to fetch configs joined with class names in a single query.
exam_providers.dart: examConfigsWithClassProvider (FutureProvider.family by year).
admin_exam_tab.dart: "Result Analytics" tile (purple, analytics icon) → /analytics.
app.dart: /analytics route added.

Phase 9

Testing

Status

COMPLETE — 22 July 2026

Files Created

test/examination/result_engine_test.dart

Files Modified

lib/src/features/examination/presentation/promotion_screen.dart

Summary

result_engine_test.dart: 20 unit tests — covers GradeConfig.resolveGrade (boundary values, empty config), ClassAnalyticsSummary.fromResults (pass count, fail count, topper, highest/lowest%, average%, subject stats sorting, grade subjects excluded), PromotionRecord fromMap/toUpsertMap round-trip (null optional fields omitted), ExamTerm.toInsertMap, SubjectAnalyticsStat.passPercent (0/50/100%).
promotion_screen.dart bug fix: changed classesProvider (teacher-assigned only) to allClassesProvider (all classes — admin needs full list); AsyncValue type corrected from List<dynamic> to List<ClassRoom>; class name now uses ClassRoom.label ('name-section') instead of nonexistent .className field.

Whenever a phase completes

Update this document.

Add

Date

Files Modified

Summary

Next Phase

------------------------------------------------------------

# REPLIT AI RULES

Whenever Replit AI starts,

it MUST first read this PROJECT_BIBLE.md.

It must NEVER redesign the architecture.

It must NEVER restart the project.

It must NEVER rewrite existing working files.

It must NEVER rename existing tables.

It must NEVER remove existing features.

It must complete ONLY ONE milestone at a time.

If credits become low

STOP.

Print

========================

CHECKPOINT

Completed Work

Modified Files

Database Changes

Remaining Work

Next Milestone

========================

After printing CHECKPOINT

Do not continue.

------------------------------------------------------------

# FINAL PROJECT OBJECTIVE

This application should become a complete School ERP while preserving all existing functionality.

Primary Goals

✓ Stable

✓ Modular

✓ Future Proof

✓ Configurable

✓ Fast

✓ Offline Ready

✓ Easy Printing

✓ Dynamic Reports

✓ Secure

✓ Scalable

Every future AI working on this repository must treat this document as the single source of truth.

END OF PROJECT_BIBLE.md
