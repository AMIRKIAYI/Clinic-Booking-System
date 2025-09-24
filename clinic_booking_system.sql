-- clinic_booking_system.sql
-- DROP existing objects to allow re-running the script safely
DROP DATABASE IF EXISTS clinic_db;

-- Create database and use it
CREATE DATABASE clinic_db
  CHARACTER SET = utf8mb4
  COLLATE = utf8mb4_general_ci;
USE clinic_db;

-- =====================================================================
-- Roles (for system users / staff)
-- =====================================================================
CREATE TABLE roles (
  role_id      INT AUTO_INCREMENT PRIMARY KEY,
  role_name    VARCHAR(50) NOT NULL UNIQUE, -- e.g., 'admin', 'receptionist', 'doctor', 'pharmacist'
  description  VARCHAR(255)
) ENGINE=InnoDB;

-- =====================================================================
-- Users (staff accounts). Doctors may have an entry here (and also in doctors table)
-- =====================================================================
CREATE TABLE users (
  user_id      INT AUTO_INCREMENT PRIMARY KEY,
  username     VARCHAR(100) NOT NULL UNIQUE,
  email        VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL, -- assume hashed password
  first_name   VARCHAR(100) NOT NULL,
  last_name    VARCHAR(100) NOT NULL,
  phone        VARCHAR(20),
  role_id      INT NOT NULL,
  created_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (role_id) REFERENCES roles(role_id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- Patients
-- =====================================================================
CREATE TABLE patients (
  patient_id       INT AUTO_INCREMENT PRIMARY KEY,
  first_name       VARCHAR(100) NOT NULL,
  last_name        VARCHAR(100) NOT NULL,
  date_of_birth    DATE,
  gender           ENUM('male','female','other') DEFAULT 'other',
  national_id      VARCHAR(50) UNIQUE, -- optional national id / patient number
  email            VARCHAR(255),
  phone            VARCHAR(20),
  address          VARCHAR(255),
  emergency_contact_name  VARCHAR(150),
  emergency_contact_phone VARCHAR(20),
  created_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- =====================================================================
-- Doctors (one-to-one with user account optional)
-- =====================================================================
CREATE TABLE doctors (
  doctor_id        INT AUTO_INCREMENT PRIMARY KEY,
  user_id          INT NULL UNIQUE, -- optional link to users table (if doctor has login)
  license_number   VARCHAR(100) NOT NULL UNIQUE,
  specialization   VARCHAR(150),
  bio              TEXT,
  phone            VARCHAR(20),
  consultation_fee DECIMAL(10,2) DEFAULT 0.00 CHECK (consultation_fee >= 0),
  created_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON DELETE SET NULL
    ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- Rooms (for consultations)
-- =====================================================================
CREATE TABLE rooms (
  room_id    INT AUTO_INCREMENT PRIMARY KEY,
  room_name  VARCHAR(100) NOT NULL UNIQUE,
  floor      VARCHAR(50),
  notes      VARCHAR(255)
) ENGINE=InnoDB;

-- =====================================================================
-- Services (consultation types, lab services, etc.)
-- =====================================================================
CREATE TABLE services (
  service_id    INT AUTO_INCREMENT PRIMARY KEY,
  service_name  VARCHAR(150) NOT NULL,
  code          VARCHAR(50) UNIQUE, -- internal code
  description   VARCHAR(255),
  price         DECIMAL(10,2) DEFAULT 0.00 CHECK (price >= 0),
  duration_minutes INT DEFAULT 30 CHECK (duration_minutes > 0)
) ENGINE=InnoDB;

-- Ensure a service name + code uniqueness
CREATE UNIQUE INDEX ux_services_name_code ON services(service_name, code);

-- =====================================================================
-- Appointments
-- One patient has many appointments (one-to-many)
-- One doctor has many appointments (one-to-many)
-- Appointments may take place in a room (optional)
-- =====================================================================
CREATE TABLE appointments (
  appointment_id   INT AUTO_INCREMENT PRIMARY KEY,
  patient_id       INT NOT NULL,
  doctor_id        INT NOT NULL,
  room_id          INT NULL,
  scheduled_at     DATETIME NOT NULL, -- start datetime
  duration_minutes INT NOT NULL DEFAULT 30 CHECK (duration_minutes > 0),
  status           ENUM('scheduled','checked_in','completed','cancelled','no_show') DEFAULT 'scheduled',
  reason           VARCHAR(255),
  created_by_user  INT NULL, -- receptionist or system user who booked
  created_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_apt_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_apt_doctor FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_apt_room FOREIGN KEY (room_id) REFERENCES rooms(room_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_apt_createdby FOREIGN KEY (created_by_user) REFERENCES users(user_id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Prevent exact duplicate appointment for same doctor at same datetime
-- (Note: this is a simple guard; real overlap prevention requires richer logic)
CREATE UNIQUE INDEX ux_doctor_sched_at ON appointments (doctor_id, scheduled_at);

-- =====================================================================
-- Many-to-many: Appointment <-> Services
-- An appointment can include multiple services (e.g., consultation + lab), and a service can belong to many appointments
-- =====================================================================
CREATE TABLE appointment_services (
  appointment_id INT NOT NULL,
  service_id     INT NOT NULL,
  price_at_time  DECIMAL(10,2) NOT NULL CHECK (price_at_time >= 0),
  PRIMARY KEY (appointment_id, service_id),
  FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (service_id) REFERENCES services(service_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- Medications (inventory)
-- =====================================================================
CREATE TABLE medications (
  medication_id    INT AUTO_INCREMENT PRIMARY KEY,
  name             VARCHAR(200) NOT NULL,
  sku              VARCHAR(100) UNIQUE,
  manufacturer     VARCHAR(150),
  unit_price       DECIMAL(10,2) DEFAULT 0.00 CHECK (unit_price >= 0),
  quantity_in_stock INT DEFAULT 0 CHECK (quantity_in_stock >= 0),
  created_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- =====================================================================
-- Prescriptions produced after appointments
-- =====================================================================
CREATE TABLE prescriptions (
  prescription_id INT AUTO_INCREMENT PRIMARY KEY,
  appointment_id   INT NOT NULL,
  doctor_id        INT NOT NULL,
  patient_id       INT NOT NULL,
  issued_at        DATETIME DEFAULT CURRENT_TIMESTAMP,
  notes            TEXT,
  FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Prescription items: which meds + dose + qty
CREATE TABLE prescription_items (
  prescription_id INT NOT NULL,
  medication_id   INT NOT NULL,
  dosage TEXT NOT NULL, -- e.g., "1 tablet twice a day"
  quantity INT NOT NULL CHECK (quantity > 0),
  instructions TEXT,
  PRIMARY KEY (prescription_id, medication_id),
  FOREIGN KEY (prescription_id) REFERENCES prescriptions(prescription_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (medication_id) REFERENCES medications(medication_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- Billing (basic invoice structure)
-- =====================================================================
CREATE TABLE invoices (
  invoice_id     INT AUTO_INCREMENT PRIMARY KEY,
  patient_id     INT NOT NULL,
  appointment_id INT NULL,
  invoice_date   DATETIME DEFAULT CURRENT_TIMESTAMP,
  total_amount   DECIMAL(12,2) DEFAULT 0.00 CHECK (total_amount >= 0),
  status         ENUM('unpaid','paid','partially_paid','cancelled') DEFAULT 'unpaid',
  notes          VARCHAR(255),
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE invoice_items (
  invoice_item_id INT AUTO_INCREMENT PRIMARY KEY,
  invoice_id      INT NOT NULL,
  description     VARCHAR(255) NOT NULL,
  quantity        INT NOT NULL CHECK (quantity > 0),
  unit_price      DECIMAL(12,2) NOT NULL CHECK (unit_price >= 0),
  line_total      DECIMAL(12,2) AS (quantity * unit_price) STORED,
  FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- Audit log (simple)
-- =====================================================================
CREATE TABLE audit_logs (
  log_id     INT AUTO_INCREMENT PRIMARY KEY,
  entity     VARCHAR(100) NOT NULL,
  entity_id  INT,
  action     VARCHAR(50) NOT NULL, -- e.g., 'create','update','delete'
  performed_by_user INT NULL,
  performed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  details    TEXT,
  FOREIGN KEY (performed_by_user) REFERENCES users(user_id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- Sample constraints / checks examples (MySQL 8+ supports CHECK)
-- =====================================================================
-- Example: ensure status values are valid (enforced by ENUM already)
-- Additional helpful indexes:
CREATE INDEX idx_patients_name ON patients (last_name, first_name);
CREATE INDEX idx_doctors_specialization ON doctors (specialization);
CREATE INDEX idx_appointments_patient ON appointments (patient_id);
CREATE INDEX idx_appointments_doctor ON appointments (doctor_id);
CREATE INDEX idx_appointments_scheduled_at ON appointments (scheduled_at);

-- =====================================================================
-- Example: sample data (optional). Comment out if not desired.
-- =====================================================================
-- Uncomment the following sample inserts to create initial roles and a sample user/doctor
/*
INSERT INTO roles (role_name, description) VALUES
  ('admin','System administrator'),
  ('receptionist','Front desk staff'),
  ('doctor','Medical doctor'),
  ('pharmacist','Pharmacy staff');

INSERT INTO users (username, email, password_hash, first_name, last_name, phone, role_id)
VALUES ('admin','admin@clinic.example','$2y$...','System','Admin','+000000000', 1);

INSERT INTO doctors (user_id, license_number, specialization, phone)
VALUES (NULL, 'LIC-12345', 'General Practitioner', '+254700000000');

INSERT INTO patients (first_name, last_name, date_of_birth, gender, national_id, phone)
VALUES ('Amina', 'Ali', '1998-05-14', 'female', 'NID12345', '+254712345678');
*/

-- =====================================================================
-- End of schema
-- =====================================================================
