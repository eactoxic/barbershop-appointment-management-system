SET SERVEROUTPUT ON;

-- TEST: CreateAppointmentWithValidation Procedure

-- Test with non-existing customer (should fail)
-- we dont have ıd=999
BEGIN
    CreateAppointmentWithValidation(999, 1, 1, TO_DATE('2024-02-01 10:00', 'YYYY-MM-DD HH24:MI'), 1, 'Test');
    DBMS_OUTPUT.PUT_LINE('ERROR: Should have failed but did not!');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Expected error: ' || SQLERRM);
END;
/

-- Test with non-existing barber (should fail)
BEGIN
    CreateAppointmentWithValidation(1, 999, 1, TO_DATE('2024-02-01 10:00', 'YYYY-MM-DD HH24:MI'), 1, 'Test');
    DBMS_OUTPUT.PUT_LINE('ERROR: Should have failed but did not!');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Expected error: ' || SQLERRM);
END;
/

-- Test valid appointment
BEGIN
    CreateAppointmentWithValidation(3, 2, 2, TO_DATE('2024-02-12 14:00', 'YYYY-MM-DD HH24:MI'), 1, 'Test appointment');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Unexpected error: ' || SQLERRM);
END;
/

-- Verify appointment
SELECT * FROM Appointment
         WHERE Customer_ID = 3
           AND Barber_ID = 2;
-- verify create appointmentservice
SELECT * FROM AppointmentService
         WHERE Appointment_ID = (SELECT MAX(ID) FROM Appointment);
-- verify payment
SELECT * FROM Payment
         WHERE Appointment_ID = (SELECT MAX(ID) FROM Appointment);


-- TEST: CalculateBarberEarnings Procedure

-- Check salaries before
SELECT ID, Name, Surname, Salary FROM Barber;

-- Run procedure
BEGIN
    CalculateBarberEarnings;
END;
/

-- Check salaries after (some may have bonus added)
SELECT ID, Name, Surname, Salary FROM Barber;


-- TEST: GenerateMonthlyReport Procedure

BEGIN
    GenerateMonthlyReport(1, 2024);
END;
/


-- TEST: TR_Barber_SalaryCheck Trigger

-- Insert with salary > 10000 (should fail)
BEGIN
    INSERT INTO Barber VALUES (20, 'Test', 'User', 5559999, SYSDATE, 15000, 1, NULL);
    DBMS_OUTPUT.PUT_LINE('ERROR: Should have failed but did not!');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Expected error (salary > 10000): ' || SQLERRM);
END;
/

-- Insert with negative salary (should fail)
BEGIN
    INSERT INTO Barber VALUES (20, 'Test', 'User', 5559999, SYSDATE, -500, 1, NULL);
    DBMS_OUTPUT.PUT_LINE('ERROR: Should have failed but did not!');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Expected error (negative salary): ' || SQLERRM);
END;
/

-- Insert with salary higher than boss (should fail)
BEGIN
    INSERT INTO Barber VALUES (20, 'Test', 'User', 5559999, SYSDATE, 5500, 1, 1);
    DBMS_OUTPUT.PUT_LINE('ERROR: Should have failed but did not!');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Expected error (salary > boss): ' || SQLERRM);
END;
/

-- Insert valid barber (should work)
BEGIN
    INSERT INTO Barber VALUES (20, 'Test', 'User', 5559999, SYSDATE, 3000, 1, 1);
    DBMS_OUTPUT.PUT_LINE('Valid barber inserted successfully');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Unexpected error: ' || SQLERRM);
END;
/
SELECT * FROM Barber WHERE ID = 20;

-- Try increase more than 20% (should fail)
BEGIN
    UPDATE Barber SET Salary = 4000 WHERE ID = 20;
    DBMS_OUTPUT.PUT_LINE('ERROR: Should have failed but did not!');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Expected error (>20% increase): ' || SQLERRM);
END;
/

-- Increase within 20% (should work)
BEGIN
    UPDATE Barber SET Salary = 3500 WHERE ID = 20;
    DBMS_OUTPUT.PUT_LINE('Valid salary increase applied');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Unexpected error: ' || SQLERRM);
END;
/

-- Cleanup test barber
DELETE FROM Barber WHERE ID = 20;


-- TEST: TR_Appointment_StatusChange Trigger

-- Create test appointment
INSERT INTO Appointment VALUES (200, SYSDATE + 1, 'Scheduled', 'Status test', 1, 1, 1);
INSERT INTO AppointmentService VALUES (200, 1, 250, 30);
INSERT INTO Payment VALUES (200, 250, 'TRY', NULL, NULL, 'Pending', 200);

-- Complete appointment (should update payment)
UPDATE Appointment SET Status = 'Completed' WHERE ID = 200;
SELECT * FROM Payment WHERE Appointment_ID = 200;

-- Try to change completed appointment (should fail)
BEGIN
    UPDATE Appointment SET Status = 'Scheduled' WHERE ID = 200;
    DBMS_OUTPUT.PUT_LINE('ERROR: Should have failed but did not!');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Expected error (modify completed): ' || SQLERRM);
END;
/

-- Create another appointment for cancel test
INSERT INTO Appointment VALUES (201, SYSDATE + 2, 'Scheduled', 'Cancel test', 2, 2, 2);
INSERT INTO AppointmentService VALUES (201, 2, 150, 15);
INSERT INTO Payment VALUES (201, 150, 'TRY', NULL, NULL, 'Pending', 201);

-- Cancel appointment (should refund)
UPDATE Appointment SET Status = 'Cancelled' WHERE ID = 201;
SELECT * FROM Payment WHERE Appointment_ID = 201;

-- Try to reactivate cancelled (should fail)
BEGIN
    UPDATE Appointment SET Status = 'Scheduled' WHERE ID = 201;
    DBMS_OUTPUT.PUT_LINE('ERROR: Should have failed but did not!');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Expected error (reactivate cancelled): ' || SQLERRM);
END;
/


-- TEST: TR_Appointment_Cascade Trigger

-- Create test appointment with related records
INSERT INTO Appointment VALUES (202, SYSDATE + 3, 'Scheduled', 'Delete test', 3, 3, 3);
INSERT INTO AppointmentService VALUES (202, 1, 250, 30);
INSERT INTO ProductUsage VALUES (1, 202);
INSERT INTO Payment VALUES (202, 400, 'TRY', NULL, 'Cash', 'Pending', 202);

-- Check related records exist
SELECT COUNT(*) as service_count FROM AppointmentService WHERE Appointment_ID = 202;
SELECT COUNT(*) as product_count FROM ProductUsage WHERE Appointment_ID = 202;
SELECT COUNT(*) as payment_count FROM Payment WHERE Appointment_ID = 202;

-- Delete appointment (should cascade)
DELETE FROM Appointment WHERE ID = 202;

-- Verify related records deleted
SELECT COUNT(*) as service_count FROM AppointmentService WHERE Appointment_ID = 202;
SELECT COUNT(*) as product_count FROM ProductUsage WHERE Appointment_ID = 202;
SELECT COUNT(*) as payment_count FROM Payment WHERE Appointment_ID = 202;

-- Try to delete completed appointment (should fail)
BEGIN
    DELETE FROM Appointment WHERE ID = 200;
    DBMS_OUTPUT.PUT_LINE('ERROR: Should have failed but did not!');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Expected error (delete completed): ' || SQLERRM);
END;
/


-- Cleanup test data (only non-completed appointments)
-- Note: Appointment 200 is Completed, cannot be deleted by trigger
-- We need to update status first or delete related records manually
BEGIN
    DELETE FROM Payment WHERE Appointment_ID = 201;
    DELETE FROM AppointmentService WHERE Appointment_ID = 201;
    DELETE FROM Appointment WHERE ID = 201;
    DBMS_OUTPUT.PUT_LINE('Cleanup: Appointment 201 deleted');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Cleanup error: ' || SQLERRM);
END;
/

-- For Appointment 200 (Completed), we leave it or manually clean
-- Manual cleanup for 200 (bypassing trigger by disabling temporarily)
BEGIN
    EXECUTE IMMEDIATE 'ALTER TRIGGER TR_Appointment_Cascade DISABLE';
    DELETE FROM Payment WHERE Appointment_ID = 200;
    DELETE FROM AppointmentService WHERE Appointment_ID = 200;
    DELETE FROM Appointment WHERE ID = 200;
    EXECUTE IMMEDIATE 'ALTER TRIGGER TR_Appointment_Cascade ENABLE';
    DBMS_OUTPUT.PUT_LINE('Cleanup: Appointment 200 deleted (trigger disabled)');
EXCEPTION
    WHEN OTHERS THEN
        EXECUTE IMMEDIATE 'ALTER TRIGGER TR_Appointment_Cascade ENABLE';
        DBMS_OUTPUT.PUT_LINE('Cleanup error: ' || SQLERRM);
END;
/

COMMIT;
