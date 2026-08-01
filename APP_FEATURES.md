# NEMPS Teacher Assistant — Screen-by-Screen Features

## Login / Signup
- Email + password login (Supabase Auth), session persists (bar-bar login nahi karna padta)
- Naya account banane ka signup flow
- Login ke baad role (Teacher / Admin) ke hisaab se dashboard aur nav menu alag

## Dashboard
- Role-based quick actions (Attendance, Homework, Absent Notify, Reports/Admin) — admin/teacher ke hisaab se alag cards
- Apni classes ki list, cards par aaj attendance hui ya nahi uska status
- Live search bar — student ka naam ya roll no type karke turant dhoondo (apni classes ya, admin ke liye, saari classes mein)
- Notices banner — school ke notices dikhte hain dashboard ke top par

## Class Detail
- Ek class ka overview: total students, aaj attendance ka status
- Roll No / Naam se sort toggle
- Seedha Attendance, Homework, Absent Notify, Students, Marks Entry, Results, Attendance Register par jaane ke shortcuts
- WhatsApp group link set/edit karna

## Students (per class)
- Class ke saare students ki list, Roll No / Naam sort toggle
- Naya student add karna, existing edit karna, remove (deactivate) karna
- CSV export
- Student tap karke details modal (attendance history, etc.)

## Attendance
- Daily attendance lena (Present / Absent / Holiday status)
- Roll No / Naam sort toggle
- CSV import
- "Attendance already li gayi hai aaj" indicator

## Attendance Register
- Ek class ka pura register view — multiple dates ek saath, grid-style
- Roll No wise fixed order

## Homework
- Homework assign karna, subject-wise
- Kis student ne complete kiya uska tracking/marking
- WhatsApp group link par homework bhejna (agar link set hai), warna button disabled rehta hai
- CSV import
- Roll No wise sorted student list

## Absent Notify (WhatsApp)
- Aaj ke absent students ki list, unke parents ko WhatsApp par notify karna
- Roll No / Naam sort toggle
- Kisko message gaya, kisko nahi — track hota hai

## Reports & Summary
- Attendance Report (class-wise daily)
- Homework Report (subject-wise completion rate)
- WhatsApp Report (aaj kitne messages gaye)
- Attendance Range Report — Weekly / Monthly / Half-Yearly / Yearly
- WhatsApp Range Report — same ranges
- Print Result Cards (class-wise PDF)

## Admin Panel (Admin-only)
- **Classes** — classes create/edit/delete, sections manage
- **Students** — saare students (sab classes), class-filter ke saath (filter lagane par ab Roll No order mein aata hai), add/edit/deactivate
- **Teachers** — teacher accounts manage, classes assign/remove
- **Notices** — school-wide notices post karna, class-specific ya sab ke liye
- **Activity** — teachers ki activity log (kisne kab attendance/homework mark ki)
- **Exams** — exam configuration ka entry point
- **Fees** — fee management ka entry point

## Fees Management (Admin)
- **Fees Home** — overview/menu
- **Fee Types** — fee categories banana (tuition, transport, etc.)
- **Class Fee Config** — class-wise fee structure set karna
- **Fee Collection** — student choose karke (Roll No order mein, ab fix ho gaya) payment collect karna, months select karna, partial payment, receipt generate
- **Fee Reports** — collection reports, pending dues list
- **Advanced Fee Config** — detailed/bulk fee setup

## Examination Module
- **Academic Sessions** — naya session banana, active session switch karna
- **Subject Config** — class ke liye subjects define karna, CSV import
- **Exam Config** — exam terms banana, max marks set karna, CSV import
- **Grade Config** — grading scale (A+, A, B...) define karna
- **Marks Entry** — subject-wise spreadsheet-style marks entry, CSV/Excel import-export
- **Results** — class results, rank-wise sorted, pass/fail filter
- **Report Card** — individual student ka printable report card (traditional format)
- **Bulk Print** — poori class ke report cards ek saath PDF mein print
- **Promotion Engine** — session-end par students ko next class mein promote karna, manual override ke saath
- **Analytics** — result analytics/trends

## Cross-cutting
- Light/Dark mode toggle (ab dono modes fully consistent styled hain)
- Mobile: bottom nav + drawer; Desktop/tablet: sidebar layout — same features, responsive
- Offline queue — internet na ho to save later automatically sync ho jata hai jab wapas online aaye
