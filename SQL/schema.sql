-- HR Autopilot: schema + synthetic seed data (all data is fake)
DROP TABLE IF EXISTS audit_log, alerts, shifts, documents, employees CASCADE;

CREATE TABLE employees (
  id SERIAL PRIMARY KEY,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  role TEXT NOT NULL,
  employee_type TEXT NOT NULL CHECK (employee_type IN ('working_student','international_staff','regular')),
  start_date DATE NOT NULL,
  end_date DATE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','offboarding','left'))
);

CREATE TABLE documents (
  id SERIAL PRIMARY KEY,
  employee_id INT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  doc_type TEXT NOT NULL CHECK (doc_type IN ('residence_permit','enrollment_certificate','sick_note','contract','timesheet')),
  file_name TEXT NOT NULL,
  name_on_document TEXT,
  issued_on DATE,
  expires_on DATE,
  extracted_fields JSONB DEFAULT '{}',
  confidence NUMERIC(3,2),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','verified','needs_review','rejected')),
  expected_status TEXT,
  uploaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE alerts (
  id SERIAL PRIMARY KEY,
  employee_id INT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  document_id INT REFERENCES documents(id) ON DELETE SET NULL,
  alert_type TEXT NOT NULL,
  due_date DATE NOT NULL,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE shifts (
  id SERIAL PRIMARY KEY,
  employee_id INT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  shift_start TIMESTAMPTZ NOT NULL,
  shift_end TIMESTAMPTZ NOT NULL,
  break_minutes INT NOT NULL DEFAULT 0,
  CHECK (shift_end > shift_start)
);

CREATE TABLE audit_log (
  id BIGSERIAL PRIMARY KEY,
  ts TIMESTAMPTZ DEFAULT now(),
  actor TEXT NOT NULL,
  action TEXT NOT NULL,
  entity TEXT NOT NULL,
  entity_id INT,
  details JSONB DEFAULT '{}'
);

CREATE INDEX idx_documents_employee ON documents(employee_id);
CREATE INDEX idx_documents_expiry ON documents(expires_on);
CREATE INDEX idx_shifts_employee_start ON shifts(employee_id, shift_start);

-- Block public API access; your own Postgres connection (n8n) still works
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts    ENABLE ROW LEVEL SECURITY;
ALTER TABLE shifts    ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- 12 fake employees (ids 1-12 in this order)
INSERT INTO employees (full_name, email, role, employee_type, start_date) VALUES
 ('Lena Hartmann','lena.hartmann@example.test','Warehouse','working_student','2026-04-01'),
 ('Tarek Nasser','tarek.nasser@example.test','Kitchen','international_staff','2025-11-15'),
 ('Mia Brandt','mia.brandt@example.test','Retail','working_student','2026-02-01'),
 ('Arjun Mehta','arjun.mehta@example.test','Warehouse','international_staff','2026-01-10'),
 ('Sofia Keller','sofia.keller@example.test','Office','regular','2024-06-01'),
 ('Jonas Weber','jonas.weber@example.test','Retail','working_student','2026-05-01'),
 ('Amira Yilmaz','amira.yilmaz@example.test','Kitchen','international_staff','2026-03-01'),
 ('Paul Neumann','paul.neumann@example.test','Warehouse','regular','2023-09-01'),
 ('Chen Wei','chen.wei@example.test','Office','international_staff','2026-06-15'),
 ('Hanna Schulz','hanna.schulz@example.test','Retail','working_student','2025-10-01'),
 ('Omar Haddad','omar.haddad@example.test','Kitchen','international_staff','2025-08-01'),
 ('Greta Vogel','greta.vogel@example.test','Office','regular','2022-03-01');

-- Documents with known correct answers in expected_status (dates relative to 2026-10-06)
INSERT INTO documents (employee_id, doc_type, file_name, name_on_document, issued_on, expires_on, expected_status, extracted_fields) VALUES
 (1,'enrollment_certificate','lena_enroll.pdf','Lena Hartmann', DATE '2026-10-06'-150, DATE '2026-10-06'+150,'verified','{"seed_note":"valid"}'),
 (2,'residence_permit','tarek_permit.pdf','Tarek Nasser', DATE '2026-10-06'-300, DATE '2026-10-06'+25,'verified','{"seed_note":"expires in 25 days, 30-day alert"}'),
 (3,'enrollment_certificate','mia_enroll.pdf','Mia Brand', DATE '2026-10-06'-120, DATE '2026-10-06'+200,'needs_review','{"seed_note":"name mismatch Brand vs Brandt"}'),
 (4,'residence_permit','arjun_permit.pdf','Arjun Mehta', DATE '2026-10-06'-700, DATE '2026-10-06'-12,'rejected','{"seed_note":"expired 12 days ago"}'),
 (5,'contract','sofia_contract.pdf','Sofia Keller', DATE '2026-10-06'-800, NULL,'verified','{"seed_note":"permanent contract"}'),
 (6,'enrollment_certificate','jonas_enroll.pdf','Jonas Weber', DATE '2026-10-06'-400, DATE '2026-10-06'-30,'rejected','{"seed_note":"enrollment lapsed"}'),
 (7,'residence_permit','amira_permit.pdf','Amira Yilmaz', DATE '2026-10-06'-200, DATE '2026-10-06'+160,'verified','{"seed_note":"valid"}'),
 (8,'sick_note','paul_sick.pdf','Paul Neumann', DATE '2026-10-06'-2, DATE '2026-10-06'+3,'verified','{"seed_note":"valid sick note"}'),
 (9,'residence_permit','chen_permit.pdf','Chen Wei', DATE '2026-10-06'-100, DATE '2026-10-06'+55,'verified','{"seed_note":"expires in 55 days, 60-day alert"}'),
 (10,'enrollment_certificate','hanna_enroll.pdf',NULL, DATE '2026-10-06'-60, DATE '2026-10-06'+120,'needs_review','{"seed_note":"name missing, unreadable scan"}'),
 (11,'residence_permit','omar_permit.pdf','Omar Haddad', DATE '2026-10-06'-500, DATE '2026-10-06'+6,'verified','{"seed_note":"expires in 6 days, 7-day alert"}'),
 (12,'contract','greta_contract.pdf','Greta Vogel', DATE '2026-10-06'-1500, NULL,'verified','{"seed_note":"permanent contract"}');

-- Shifts: test inputs for the rules module (verify real rules from official sources later)
INSERT INTO shifts (employee_id, shift_start, shift_end, break_minutes) VALUES
 (1,'2026-10-01 09:00+00','2026-10-01 15:00+00',30),
 (1,'2026-10-03 09:00+00','2026-10-03 15:00+00',30),
 (3,'2026-10-02 15:00+00','2026-10-02 23:00+00',30),  -- then 06:00 next day: 7h rest
 (3,'2026-10-03 06:00+00','2026-10-03 14:00+00',30),
 (6,'2026-10-02 14:00+00','2026-10-02 22:00+00',30),  -- then 09:00: exactly 11h rest
 (6,'2026-10-03 09:00+00','2026-10-03 17:00+00',30),
 (2,'2026-10-02 15:00+00','2026-10-02 23:01+00',30),  -- then 10:00: 10h59m rest
 (2,'2026-10-03 10:00+00','2026-10-03 18:00+00',30),
 (8,'2026-10-04 06:00+00','2026-10-04 18:00+00',15);  -- 12h shift, short break

INSERT INTO audit_log (actor, action, entity, details)
VALUES ('setup','seed_synthetic_data','database','{"note":"all data is synthetic"}');

-- Check: should return employees 12, documents 12, alerts 0, shifts 9, audit_log 1
SELECT 'employees' AS tbl, COUNT(*) FROM employees
UNION ALL SELECT 'documents', COUNT(*) FROM documents
UNION ALL SELECT 'alerts', COUNT(*) FROM alerts
UNION ALL SELECT 'shifts', COUNT(*) FROM shifts
UNION ALL SELECT 'audit_log', COUNT(*) FROM audit_log;
