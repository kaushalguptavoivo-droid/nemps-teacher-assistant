# WhatsApp, Excel imports, and exports

## Manual WhatsApp messaging only

The app must never automate WhatsApp or run a WhatsApp Web client. The approved flow is:

1. Query the selected class with one of: absent only, homework pending only, fee due only, selected students, entire class.
2. Render the editable Supabase `message_templates` text using placeholders such as `{{student_name}}`, `{{class}}`, `{{amount_due}}`, and `{{teacher_name}}`.
3. Display a review/count screen.
4. Open WhatsApp per parent with `https://wa.me/<phone>?text=<encoded message>`.
5. The teacher reviews and taps Send inside WhatsApp. Record only the opened/reminder event in `fees.reminder_history` after confirmation.

The current `openWhatsApp` helper implements step 4. It has no send permission and does not communicate with an unofficial WhatsApp service.

## Excel import format

Admin CSV/XLSX headers: `class_name,section,roll_no,full_name,father_name,mother_name,whatsapp,alternate_phone,dob,address,fee_status`.

Validate the class exists, normalize Indian phone numbers to `91XXXXXXXXXX`, reject duplicate `(class_id, roll_no)`, and show a downloadable error worksheet. Production imports should run through a Supabase Edge Function using the admin’s JWT, in 100-row transactions, with an audit record.

## Reports

Attendance percentage is `present / marked-days * 100`. Homework percentage is `completed / checked-homework * 100`. Generate PDF and Excel reports from an Edge Function for consistent school branding, signed download URLs, and no data leak between classes.
