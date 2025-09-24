Clinic Booking System – Database Design
Overview

This project is a relational database for managing a small clinic.
It supports patients, doctors, appointments, prescriptions, services, billing, and staff users.

The database was designed and implemented in MySQL 8.

Database Schema

Key Entities:

Patients – stores patient personal and contact details.

Doctors – medical staff with specialization and license numbers.

Users – staff accounts (admin, receptionist, doctor, pharmacist).

Appointments – scheduled visits between patients and doctors, with status tracking.

Services – consultation, lab, or diagnostic services.

Appointment_Services – many-to-many relationship linking appointments to services.

Prescriptions & Prescription_Items – medications prescribed to patients.

Medications – pharmacy inventory.

Invoices & Invoice_Items – billing records for services/medications.

Audit_Logs – record of system actions for accountability.

Relationships

One-to-Many

A patient can have many appointments.

A doctor can handle many appointments.

An appointment can have many prescriptions.

One-to-One

A doctor may be linked to exactly one user account.

Many-to-Many

Appointments ↔ Services (via appointment_services).

Prescriptions ↔ Medications (via prescription_items).

Constraints

PRIMARY KEY: every table has a unique ID.

FOREIGN KEY: ensures referential integrity between related tables.

NOT NULL: applied to required fields (e.g., patient names, service names).

UNIQUE: prevents duplicates (e.g., usernames, license numbers).

CHECK: enforces valid values (e.g., consultation fee ≥ 0).

How to Run

Install MySQL 8+.

Import the schema:

mysql -u root -p < clinic_booking_system.sql


(Optional) Add sample data using your own INSERT statements.

Example Query

List all upcoming appointments with patient and doctor names:

SELECT a.appointment_id, a.scheduled_at, 
       p.first_name AS patient, p.last_name AS patient_last,
       d.specialization, d.phone AS doctor_contact
FROM appointments a
JOIN patients p ON a.patient_id = p.patient_id
JOIN doctors d ON a.doctor_id = d.doctor_id
WHERE a.status = 'scheduled';
