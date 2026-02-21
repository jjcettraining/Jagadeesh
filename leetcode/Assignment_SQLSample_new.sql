-- DATABASE CREATION
DROP DATABASE IF EXISTS university_db;

CREATE DATABASE university_db
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE university_db;

-- PHYSICAL DATA MODEL
-- STUDENT
CREATE TABLE Student (
    student_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name  VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    enrollment_date DATE NOT NULL
) ENGINE=InnoDB;

-- INSTRUCTOR
CREATE TABLE Instructor (
    instructor_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name  VARCHAR(50) NOT NULL,
    department VARCHAR(50) NOT NULL
) ENGINE=InnoDB;

-- COURSE
CREATE TABLE Course (
    course_id INT AUTO_INCREMENT PRIMARY KEY,
    course_name VARCHAR(100) NOT NULL,
    credits INT NOT NULL,
    instructor_id INT NOT NULL,

    CONSTRAINT chk_credits CHECK (credits BETWEEN 1 AND 6),

    CONSTRAINT fk_course_instructor
        FOREIGN KEY (instructor_id)
        REFERENCES Instructor(instructor_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ENROLLMENT
CREATE TABLE Enrollment (
    enrollment_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    course_id INT NOT NULL,
    enrollment_date DATE NOT NULL,
    grade CHAR(2),

    CONSTRAINT fk_enroll_student
        FOREIGN KEY (student_id)
        REFERENCES Student(student_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_enroll_course
        FOREIGN KEY (course_id)
        REFERENCES Course(course_id)
        ON DELETE CASCADE,

    CONSTRAINT uq_student_course UNIQUE (student_id, course_id),

    CONSTRAINT chk_grade CHECK (grade IN ('A','B','C','D','F'))
) ENGINE=InnoDB;

-- PERFORMANCE INDEXES
CREATE INDEX idx_enrollment_student ON Enrollment(student_id);
CREATE INDEX idx_enrollment_course ON Enrollment(course_id);
CREATE INDEX idx_course_instructor ON Course(instructor_id);

-- SAMPLE DATA
INSERT INTO Student (first_name,last_name,email,enrollment_date)
VALUES ('John','Doe','john@uni.edu','2023-09-01');

INSERT INTO Instructor (first_name,last_name,department)
VALUES ('Alice','Smith','Computer Science');

INSERT INTO Course (course_name,credits,instructor_id)
VALUES ('Database Systems',3,1);

INSERT INTO Enrollment (student_id,course_id,enrollment_date,grade)
VALUES (1,1,'2024-01-10','A');

-- REFERENTIAL INTEGRITY AUDITS (CROSS-VALIDATION)
-- Enrollment → Student
SELECT e.*
FROM Enrollment e
LEFT JOIN Student s ON e.student_id = s.student_id
WHERE s.student_id IS NULL;

-- Enrollment → Course
SELECT e.*
FROM Enrollment e
LEFT JOIN Course c ON e.course_id = c.course_id
WHERE c.course_id IS NULL;

-- Course → Instructor
SELECT c.*
FROM Course c
LEFT JOIN Instructor i ON c.instructor_id = i.instructor_id
WHERE i.instructor_id IS NULL;

-- DOMAIN & BUSINESS RULE VALIDATION
-- Invalid Grades
SELECT DISTINCT grade
FROM Enrollment
WHERE grade NOT IN ('A','B','C','D','F')
  AND grade IS NOT NULL;

-- Credit Range Violations
SELECT *
FROM Course
WHERE credits < 1 OR credits > 6;

-- Mandatory Attributes Missing
SELECT *
FROM Student
WHERE first_name IS NULL
   OR last_name IS NULL
   OR email IS NULL
   OR enrollment_date IS NULL;
   
-- CONSTRAINT VIOLATION DETECTION QUERIES
-- Duplicate Enrollment Detection
SELECT student_id, course_id, COUNT(*) AS duplicate_count
FROM Enrollment
GROUP BY student_id, course_id
HAVING COUNT(*) > 1;

-- Primary Key Duplication Proof
SELECT student_id, COUNT(*) FROM Student GROUP BY student_id HAVING COUNT(*) > 1;
SELECT instructor_id, COUNT(*) FROM Instructor GROUP BY instructor_id HAVING COUNT(*) > 1;
SELECT course_id, COUNT(*) FROM Course GROUP BY course_id HAVING COUNT(*) > 1;
SELECT enrollment_id, COUNT(*) FROM Enrollment GROUP BY enrollment_id HAVING COUNT(*) > 1;


-- LOGICAL CONSISTENCY CHECKS
-- Courses Without Enrollments
SELECT c.*
FROM Course c
LEFT JOIN Enrollment e ON c.course_id = e.course_id
WHERE e.enrollment_id IS NULL;

-- Students Without Enrollments
SELECT s.*
FROM Student s
LEFT JOIN Enrollment e ON s.student_id = e.student_id
WHERE e.enrollment_id IS NULL;

-- NEGATIVE TEST CASES (SHOULD FAIL)
-- Duplicate Enrollment  
INSERT INTO Enrollment (student_id,course_id,enrollment_date,grade)
VALUES (1,1,'2024-02-01','A');

-- Invalid Grade
INSERT INTO Enrollment (student_id,course_id,enrollment_date,grade)
VALUES (1,1,'2024-02-01','Z');

-- Invalid Credits
INSERT INTO Course (course_name,credits,instructor_id)
VALUES ('Invalid Course',10,1);

-- SECURITY: ROLE-BASED ACCESS CONTROL
CREATE ROLE instructor_role;

GRANT SELECT ON university_db.Course TO instructor_role;
GRANT SELECT ON university_db.Enrollment TO instructor_role;

-- VIEWS (ABSTRACTION & REPORTING)
/* =========================================================
   LEGENDARY BUSINESS ANALYTICS VIEW
   ========================================================= */

DROP VIEW IF EXISTS v_course_analytics;

CREATE VIEW v_course_analytics AS
SELECT
    c.course_id,
    c.course_name,
    e.student_id,
    e.grade
FROM Course c
JOIN Enrollment e
    ON c.course_id = e.course_id;


/* =========================================================
   BUSINESS QUERY 1: TOP 3 MOST POPULAR COURSES
   ========================================================= */

SELECT
    course_id,
    course_name,
    COUNT(student_id) AS total_students
FROM v_course_analytics
GROUP BY course_id, course_name
ORDER BY total_students DESC
LIMIT 3;


/* =========================================================
   BUSINESS QUERY 2: COURSE GPA REPORT
   ========================================================= */

SELECT
    course_id,
    course_name,
    ROUND(
        AVG(
            CASE grade
                WHEN 'A' THEN 4.0
                WHEN 'B' THEN 3.0
                WHEN 'C' THEN 2.0
                WHEN 'D' THEN 1.0
                WHEN 'F' THEN 0.0
            END
        ), 2
    ) AS course_gpa
FROM v_course_analytics
GROUP BY course_id, course_name
ORDER BY course_gpa DESC;