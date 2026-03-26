-- Drop triggers if exist
IF OBJECT_ID('TR_Barber_SalaryCheck', 'TR') IS NOT NULL DROP TRIGGER TR_Barber_SalaryCheck;
IF OBJECT_ID('TR_Appointment_StatusChange', 'TR') IS NOT NULL DROP TRIGGER TR_Appointment_StatusChange;
IF OBJECT_ID('TR_Appointment_PreventDelete', 'TR') IS NOT NULL DROP TRIGGER TR_Appointment_PreventDelete;
GO

-- Trigger to check salary rules before insert/update
-- Uses Inserted and Deleted tables
CREATE TRIGGER TR_Barber_SalaryCheck
ON Barber
FOR INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_salary money, @v_oldSalary money, @v_barberId int, @v_barberName varchar(50);
    DECLARE @v_bossId int, @v_bossSalary money, @v_increasePercent decimal(5,2);

    SELECT @v_salary = i.Salary, @v_barberId = i.ID, @v_barberName = i.Name, @v_bossId = i.Boss_ID
    FROM Inserted i;
    SELECT @v_oldSalary = d.Salary FROM Deleted d;

    -- Check if salary is negative
    IF @v_salary < 0
    BEGIN
        RAISERROR('Salary cannot be negative', 16, 1);
        ROLLBACK;
        RETURN;
    END;

    -- Check if salary exceeds limit
    IF @v_salary > 10000
    BEGIN
        RAISERROR('Salary cannot exceed 10000', 16, 1);
        ROLLBACK;
        RETURN;
    END;

    -- Check salary increase percentage (only for UPDATE)
    IF @v_oldSalary IS NOT NULL AND @v_oldSalary > 0
    BEGIN
        SET @v_increasePercent = ((@v_salary - @v_oldSalary) / @v_oldSalary) * 100;
        IF @v_increasePercent > 20
        BEGIN
            RAISERROR('Salary increase cannot exceed 20 percent', 16, 1);
            ROLLBACK;
            RETURN;
        END
        PRINT 'Salary updated from ' + CAST(@v_oldSalary AS varchar(10)) + ' to ' + CAST(@v_salary AS varchar(10));
    END

    -- Check if employee earns more than boss
    IF @v_bossId IS NOT NULL
    BEGIN
        SELECT @v_bossSalary = Salary FROM Barber WHERE ID = @v_bossId;
        IF @v_salary >= @v_bossSalary
        BEGIN
            RAISERROR('Employee cannot earn more than boss', 16, 1);
            ROLLBACK;
            RETURN;
        END
    END
END;
GO


-- Trigger for appointment status changes
-- Uses Inserted and Deleted tables
CREATE TRIGGER TR_Appointment_StatusChange
ON Appointment
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_appId int, @v_oldStatus varchar(100), @v_newStatus varchar(100);
    DECLARE @v_totalAmount money, @v_payExists int, @v_newPayId int;

    SELECT @v_appId = i.ID, @v_newStatus = i.Status FROM Inserted i;
    SELECT @v_oldStatus = d.Status FROM Deleted d;

    -- Skip if status did not change
    IF @v_oldStatus = @v_newStatus
        RETURN;

    -- Cannot change completed appointment
    IF @v_oldStatus = 'Completed'
    BEGIN
        RAISERROR('Cannot modify completed appointment', 16, 1);
        ROLLBACK;
        RETURN;
    END

    -- Cannot reactivate cancelled appointment
    IF @v_oldStatus = 'Cancelled'
    BEGIN
        RAISERROR('Cannot reactivate cancelled appointment', 16, 1);
        ROLLBACK;
        RETURN;
    END

    PRINT 'Status changed from ' + @v_oldStatus + ' to ' + @v_newStatus;

    -- If completing, update payment
    IF @v_newStatus = 'Completed'
    BEGIN
        SELECT @v_payExists = COUNT(*) FROM Payment WHERE Appointment_ID = @v_appId;
        SELECT @v_totalAmount = ISNULL(SUM(Price), 0) FROM AppointmentService WHERE Appointment_ID = @v_appId;

        IF @v_payExists = 0
        BEGIN
            SELECT @v_newPayId = ISNULL(MAX(ID), 0) + 1 FROM Payment;
            INSERT INTO Payment (ID, Amount, Currency, PaymentDate, PaymentMethod, Status, Appointment_ID)
            VALUES (@v_newPayId, @v_totalAmount, 'TRY', GETDATE(), 'Cash', 'Paid', @v_appId);
            PRINT 'Payment created: ' + CAST(@v_totalAmount AS varchar(10)) + ' TRY';
        END
        ELSE
        BEGIN
            UPDATE Payment SET Status = 'Paid', PaymentDate = GETDATE(), Amount = @v_totalAmount
            WHERE Appointment_ID = @v_appId;
            PRINT 'Payment updated: ' + CAST(@v_totalAmount AS varchar(10)) + ' TRY';
        END
    END

    -- If cancelling, refund payment
    IF @v_newStatus = 'Cancelled'
    BEGIN
        UPDATE Payment SET Status = 'Refunded', Amount = 0 WHERE Appointment_ID = @v_appId;
        PRINT 'Payment refunded';
    END
END;
GO


-- INSTEAD OF trigger for appointment deletion
-- Prevents deletion of completed appointments
-- Cascade deletes related records
CREATE TRIGGER TR_Appointment_PreventDelete
ON Appointment
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_appId int, @v_status varchar(100);
    DECLARE @v_serviceCount int, @v_productCount int, @v_paymentCount int;

    SELECT @v_appId = ID, @v_status = Status FROM Deleted;

    -- Cannot delete completed appointment
    IF @v_status = 'Completed'
    BEGIN
        RAISERROR('Cannot delete completed appointments', 16, 1);
        RETURN;
    END

    -- Delete related records
    SELECT @v_serviceCount = COUNT(*) FROM AppointmentService WHERE Appointment_ID = @v_appId;
    DELETE FROM AppointmentService WHERE Appointment_ID = @v_appId;

    SELECT @v_productCount = COUNT(*) FROM ProductUsage WHERE Appointment_ID = @v_appId;
    DELETE FROM ProductUsage WHERE Appointment_ID = @v_appId;

    SELECT @v_paymentCount = COUNT(*) FROM Payment WHERE Appointment_ID = @v_appId;
    DELETE FROM Payment WHERE Appointment_ID = @v_appId;

    -- Delete appointment
    DELETE FROM Appointment WHERE ID = @v_appId;

    PRINT 'Appointment with ID=' + CAST(@v_appId AS varchar(10)) + ' deleted.';
    PRINT 'Removed ' + CAST(@v_serviceCount AS varchar(10)) + ' services, ' +
          CAST(@v_productCount AS varchar(10)) + ' products, ' +
          CAST(@v_paymentCount AS varchar(10)) + ' payments';
END;
GO
