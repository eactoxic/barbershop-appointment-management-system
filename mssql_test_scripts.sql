SET NOCOUNT ON;
GO

-- TEST: CreateAppointmentWithValidation Procedure

-- Test with non-existing customer (should fail)
BEGIN TRY
    EXEC CreateAppointmentWithValidation 999, 1, 1, '2024-02-01 10:00', 1, 'Test';
    PRINT 'ERROR: Should have failed!';
END TRY
BEGIN CATCH
    PRINT 'Expected error: ' + ERROR_MESSAGE();
END CATCH
GO

-- Test with non-existing barber (should fail)
BEGIN TRY
    EXEC CreateAppointmentWithValidation 1, 999, 1, '2024-02-01 10:00', 1, 'Test';
    PRINT 'ERROR: Should have failed!';
END TRY
BEGIN CATCH
    PRINT 'Expected error: ' + ERROR_MESSAGE();
END CATCH
GO

-- Test valid appointment
BEGIN TRY
    EXEC CreateAppointmentWithValidation 3, 2, 2, '2024-02-12 14:00', 1, NULL;
END TRY
BEGIN CATCH
    PRINT 'Unexpected error: ' + ERROR_MESSAGE();
END CATCH
GO

-- Verify created appointment
SELECT * FROM Appointment WHERE Customer_ID = 3 AND Barber_ID = 2;
SELECT * FROM AppointmentService WHERE Appointment_ID = (SELECT MAX(ID) FROM Appointment);
SELECT * FROM Payment WHERE Appointment_ID = (SELECT MAX(ID) FROM Appointment);
GO


-- TEST: CalculateBarberEarnings Procedure

-- Check salaries before
SELECT ID, Name, Surname, Salary FROM Barber;

-- Run procedure
EXEC CalculateBarberEarnings;

-- Check salaries after
SELECT ID, Name, Surname, Salary FROM Barber;
GO


-- TEST: GenerateMonthlyReport Procedure

EXEC GenerateMonthlyReport 1, 2024;
GO


-- TEST: TR_Barber_SalaryCheck Trigger

-- Insert with salary > 10000 (should fail)
BEGIN TRY
    INSERT INTO Barber VALUES (20, 'Test', 'User', 5559999, GETDATE(), 15000, 1, NULL);
    PRINT 'ERROR: Should have failed!';
END TRY
BEGIN CATCH
    PRINT 'Expected error (salary > 10000): ' + ERROR_MESSAGE();
END CATCH
GO

-- Insert with negative salary (should fail)
BEGIN TRY
    INSERT INTO Barber VALUES (20, 'Test', 'User', 5559999, GETDATE(), -500, 1, NULL);
    PRINT 'ERROR: Should have failed!';
END TRY
BEGIN CATCH
    PRINT 'Expected error (negative salary): ' + ERROR_MESSAGE();
END CATCH
GO

-- Insert with salary higher than boss (should fail)
BEGIN TRY
    INSERT INTO Barber VALUES (20, 'Test', 'User', 5559999, GETDATE(), 5500, 1, 1);
    PRINT 'ERROR: Should have failed!';
END TRY
BEGIN CATCH
    PRINT 'Expected error (salary > boss): ' + ERROR_MESSAGE();
END CATCH
GO

-- Insert valid barber (should work)
BEGIN TRY
    INSERT INTO Barber VALUES (20, 'Test', 'User', 5559999, GETDATE(), 3000, 1, 1);
    PRINT 'Valid barber inserted';
END TRY
BEGIN CATCH
    PRINT 'Unexpected error: ' + ERROR_MESSAGE();
END CATCH
GO
SELECT * FROM Barber WHERE ID = 20;
GO

-- Try increase more than 20% (should fail)
BEGIN TRY
    UPDATE Barber SET Salary = 4000 WHERE ID = 20;
    PRINT 'ERROR: Should have failed!';
END TRY
BEGIN CATCH
    PRINT 'Expected error (>20% increase): ' + ERROR_MESSAGE();
END CATCH
GO

-- Increase within 20% (should work)
BEGIN TRY
    UPDATE Barber SET Salary = 3500 WHERE ID = 20;
    PRINT 'Valid salary increase';
END TRY
BEGIN CATCH
    PRINT 'Unexpected error: ' + ERROR_MESSAGE();
END CATCH
GO

-- Cleanup test barber
DELETE FROM Barber WHERE ID = 20;
GO


-- TEST: TR_Appointment_StatusChange Trigger

-- Create test appointment
INSERT INTO Appointment VALUES (200, DATEADD(DAY, 1, GETDATE()), 'Scheduled', 'Status test', 1, 1, 1);
INSERT INTO AppointmentService VALUES (200, 1, 250, 30);
INSERT INTO Payment VALUES (200, 250, 'TRY', NULL, NULL, 'Pending', 200);
GO

-- Complete appointment (should update payment)
UPDATE Appointment SET Status = 'Completed' WHERE ID = 200;
SELECT * FROM Payment WHERE Appointment_ID = 200;
GO

-- Try to change completed appointment (should fail)
BEGIN TRY
    UPDATE Appointment SET Status = 'Scheduled' WHERE ID = 200;
    PRINT 'ERROR: Should have failed!';
END TRY
BEGIN CATCH
    PRINT 'Expected error (modify completed): ' + ERROR_MESSAGE();
END CATCH
GO

-- Create another appointment for cancel test
INSERT INTO Appointment VALUES (201, DATEADD(DAY, 2, GETDATE()), 'Scheduled', 'Cancel test', 2, 2, 2);
INSERT INTO AppointmentService VALUES (201, 2, 150, 15);
INSERT INTO Payment VALUES (201, 150, 'TRY', NULL, NULL, 'Pending', 201);
GO

-- Cancel appointment (should refund)
UPDATE Appointment SET Status = 'Cancelled' WHERE ID = 201;
SELECT * FROM Payment WHERE Appointment_ID = 201;
GO

-- Try to reactivate cancelled (should fail)
BEGIN TRY
    UPDATE Appointment SET Status = 'Scheduled' WHERE ID = 201;
    PRINT 'ERROR: Should have failed!';
END TRY
BEGIN CATCH
    PRINT 'Expected error (reactivate cancelled): ' + ERROR_MESSAGE();
END CATCH
GO


-- TEST: TR_Appointment_PreventDelete Trigger

-- Create test appointment with related records
INSERT INTO Appointment VALUES (202, DATEADD(DAY, 3, GETDATE()), 'Scheduled', 'Delete test', 3, 3, 3);
INSERT INTO AppointmentService VALUES (202, 1, 250, 30);
INSERT INTO ProductUsage VALUES (1, 202);
INSERT INTO Payment VALUES (202, 400, 'TRY', NULL, 'Cash', 'Pending', 202);
GO

-- Check related records exist
SELECT COUNT(*) as ServiceCount FROM AppointmentService WHERE Appointment_ID = 202;
SELECT COUNT(*) as ProductCount FROM ProductUsage WHERE Appointment_ID = 202;
SELECT COUNT(*) as PaymentCount FROM Payment WHERE Appointment_ID = 202;
GO

-- Delete appointment (should cascade)
DELETE FROM Appointment WHERE ID = 202;
GO

-- Verify related records deleted
SELECT COUNT(*) as ServiceCount FROM AppointmentService WHERE Appointment_ID = 202;
SELECT COUNT(*) as ProductCount FROM ProductUsage WHERE Appointment_ID = 202;
SELECT COUNT(*) as PaymentCount FROM Payment WHERE Appointment_ID = 202;
GO

-- Try to delete completed appointment (should fail)
BEGIN TRY
    DELETE FROM Appointment WHERE ID = 200;
    PRINT 'ERROR: Should have failed!';
END TRY
BEGIN CATCH
    PRINT 'Expected error (delete completed): ' + ERROR_MESSAGE();
END CATCH
GO


-- Cleanup test data
BEGIN TRY
    DELETE FROM Payment WHERE Appointment_ID = 201;
    DELETE FROM AppointmentService WHERE Appointment_ID = 201;
    DELETE FROM Appointment WHERE ID = 201;
    PRINT 'Cleanup: Appointment 201 deleted';
END TRY
BEGIN CATCH
    PRINT 'Cleanup error: ' + ERROR_MESSAGE();
END CATCH
GO

-- For Appointment 200 (Completed), disable trigger
BEGIN TRY
    DISABLE TRIGGER TR_Appointment_PreventDelete ON Appointment;
    DELETE FROM Payment WHERE Appointment_ID = 200;
    DELETE FROM AppointmentService WHERE Appointment_ID = 200;
    DELETE FROM Appointment WHERE ID = 200;
    ENABLE TRIGGER TR_Appointment_PreventDelete ON Appointment;
    PRINT 'Cleanup: Appointment 200 deleted';
END TRY
BEGIN CATCH
    ENABLE TRIGGER TR_Appointment_PreventDelete ON Appointment;
    PRINT 'Cleanup error: ' + ERROR_MESSAGE();
END CATCH
GO
