-- Drop procedures if exist
IF OBJECT_ID('CreateAppointmentWithValidation', 'P') IS NOT NULL DROP PROCEDURE CreateAppointmentWithValidation;
IF OBJECT_ID('CalculateBarberEarnings', 'P') IS NOT NULL DROP PROCEDURE CalculateBarberEarnings;
IF OBJECT_ID('GenerateMonthlyReport', 'P') IS NOT NULL DROP PROCEDURE GenerateMonthlyReport;
GO

-- Procedure to create appointment with validation
-- Uses cursor to check for conflicts
CREATE PROCEDURE CreateAppointmentWithValidation
    @p_CustomerId int,
    @p_BarberId int,
    @p_ChairId int,
    @p_AppDate datetime,
    @p_ServiceId int,
    @p_Notes varchar(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFIRST 1; -- Monday = 1

    DECLARE @v_count int;
    DECLARE @v_dayOfWeek int;
    DECLARE @v_newAppId int;
    DECLARE @v_servicePrice decimal(10,2);
    DECLARE @v_conflict bit = 0;
    DECLARE @v_existingAppId int;
    DECLARE @v_existingDate datetime;
    DECLARE @v_newPayId int;
    DECLARE @v_timeDiff int;

    DECLARE c_barberApps CURSOR FOR
        SELECT ID, StartDateTime FROM Appointment
        WHERE Barber_ID = @p_BarberId
        AND CAST(StartDateTime AS DATE) = CAST(@p_AppDate AS DATE)
        AND Status IN ('Scheduled', 'Completed');

    DECLARE c_chairApps CURSOR FOR
        SELECT ID, StartDateTime FROM Appointment
        WHERE Chair_ID = @p_ChairId
        AND CAST(StartDateTime AS DATE) = CAST(@p_AppDate AS DATE)
        AND Status = 'Scheduled';

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Check if customer exists
        SELECT @v_count = COUNT(*) FROM Customer WHERE ID = @p_CustomerId;
        IF @v_count = 0
        BEGIN
            RAISERROR('Customer with ID=%d does not exist', 16, 1, @p_CustomerId);
            RETURN;
        END

        -- Check if barber exists
        SELECT @v_count = COUNT(*) FROM Barber WHERE ID = @p_BarberId;
        IF @v_count = 0
        BEGIN
            RAISERROR('Barber with ID=%d does not exist', 16, 1, @p_BarberId);
            RETURN;
        END

        -- Check if chair exists
        SELECT @v_count = COUNT(*) FROM Chair WHERE ID = @p_ChairId;
        IF @v_count = 0
        BEGIN
            RAISERROR('Chair with ID=%d does not exist', 16, 1, @p_ChairId);
            RETURN;
        END

        -- Check if service exists
        SELECT @v_servicePrice = Price FROM Service WHERE ID = @p_ServiceId;
        IF @v_servicePrice IS NULL
        BEGIN
            RAISERROR('Service with ID=%d does not exist', 16, 1, @p_ServiceId);
            RETURN;
        END

        -- Check if barber works on this day (Monday=1 with DATEFIRST 1)
        SET @v_dayOfWeek = DATEPART(WEEKDAY, @p_AppDate);
        SELECT @v_count = COUNT(*) FROM BarberShift
        WHERE Barber_ID = @p_BarberId AND DayOfWeek = @v_dayOfWeek;
        IF @v_count = 0
        BEGIN
            RAISERROR('Barber does not work on this day', 16, 1);
            RETURN;
        END

        -- Check for barber conflicts using cursor
        OPEN c_barberApps;
        FETCH NEXT FROM c_barberApps INTO @v_existingAppId, @v_existingDate;
        WHILE @@FETCH_STATUS = 0 AND @v_conflict = 0
        BEGIN
            SET @v_timeDiff = ABS(DATEDIFF(MINUTE, @p_AppDate, @v_existingDate));
            IF @v_timeDiff < 60
                SET @v_conflict = 1;
            FETCH NEXT FROM c_barberApps INTO @v_existingAppId, @v_existingDate;
        END
        CLOSE c_barberApps;
        DEALLOCATE c_barberApps;

        IF @v_conflict = 1
        BEGIN
            RAISERROR('Barber has another appointment at this time', 16, 1);
            RETURN;
        END

        -- Check for chair conflicts using cursor
        SET @v_conflict = 0;
        OPEN c_chairApps;
        FETCH NEXT FROM c_chairApps INTO @v_existingAppId, @v_existingDate;
        WHILE @@FETCH_STATUS = 0 AND @v_conflict = 0
        BEGIN
            SET @v_timeDiff = ABS(DATEDIFF(MINUTE, @p_AppDate, @v_existingDate));
            IF @v_timeDiff < 60
                SET @v_conflict = 1;
            FETCH NEXT FROM c_chairApps INTO @v_existingAppId, @v_existingDate;
        END
        CLOSE c_chairApps;
        DEALLOCATE c_chairApps;

        IF @v_conflict = 1
        BEGIN
            RAISERROR('Chair is not available at this time', 16, 1);
            RETURN;
        END

        -- Create appointment
        SELECT @v_newAppId = ISNULL(MAX(ID), 0) + 1 FROM Appointment;
        INSERT INTO Appointment (ID, StartDateTime, Status, Notes, Customer_ID, Barber_ID, Chair_ID)
        VALUES (@v_newAppId, @p_AppDate, 'Scheduled', @p_Notes, @p_CustomerId, @p_BarberId, @p_ChairId);

        -- Add service
        INSERT INTO AppointmentService (Appointment_ID, Service_ID, Price, DurationTime)
        VALUES (@v_newAppId, @p_ServiceId, @v_servicePrice, 30);

        -- Create payment
        SELECT @v_newPayId = ISNULL(MAX(ID), 0) + 1 FROM Payment;
        INSERT INTO Payment (ID, Amount, Currency, PaymentDate, PaymentMethod, Status, Appointment_ID)
        VALUES (@v_newPayId, @v_servicePrice, 'TRY', NULL, NULL, 'Pending', @v_newAppId);

        COMMIT TRANSACTION;
        PRINT 'Appointment created with ID=' + CAST(@v_newAppId AS varchar) + ', Price=' + CAST(@v_servicePrice AS varchar) + ' TRY';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- Procedure to calculate barber earnings and give bonus
-- Uses cursor to go through all barbers
CREATE PROCEDURE CalculateBarberEarnings
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_barberId int;
    DECLARE @v_barberName varchar(50);
    DECLARE @v_barberSurname varchar(50);
    DECLARE @v_salary decimal(10,2);
    DECLARE @v_appCount int;
    DECLARE @v_totalEarnings decimal(10,2);
    DECLARE @v_bonus decimal(10,2);

    DECLARE c_barbers CURSOR FOR
        SELECT b.ID, b.Name, b.Surname, b.Salary, COUNT(a.ID) as AppCount
        FROM Barber b
        LEFT JOIN Appointment a ON b.ID = a.Barber_ID AND a.Status = 'Completed'
        GROUP BY b.ID, b.Name, b.Surname, b.Salary;

    OPEN c_barbers;
    FETCH NEXT FROM c_barbers INTO @v_barberId, @v_barberName, @v_barberSurname, @v_salary, @v_appCount;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Calculate total earnings
        SELECT @v_totalEarnings = ISNULL(SUM(aps.Price), 0)
        FROM Appointment a
        JOIN AppointmentService aps ON a.ID = aps.Appointment_ID
        WHERE a.Barber_ID = @v_barberId AND a.Status = 'Completed';

        -- Give 10% bonus if more than 2 completed appointments
        IF @v_appCount > 2
        BEGIN
            SET @v_bonus = ROUND(@v_totalEarnings * 0.10, 2);
            UPDATE Barber SET Salary = Salary + @v_bonus WHERE ID = @v_barberId;
            PRINT 'Barber ' + @v_barberName + ' ' + @v_barberSurname + ' - Earnings: ' + CAST(@v_totalEarnings AS varchar) + ' TRY, Bonus: ' + CAST(@v_bonus AS varchar) + ' TRY';
        END
        ELSE
            PRINT 'Barber ' + @v_barberName + ' ' + @v_barberSurname + ' - Earnings: ' + CAST(@v_totalEarnings AS varchar) + ' TRY, No bonus (less than 3 appointments)';

        FETCH NEXT FROM c_barbers INTO @v_barberId, @v_barberName, @v_barberSurname, @v_salary, @v_appCount;
    END

    CLOSE c_barbers;
    DEALLOCATE c_barbers;
END;
GO


-- Procedure to generate monthly report
-- Uses cursor to process appointments
CREATE PROCEDURE GenerateMonthlyReport
    @p_month int,
    @p_year int
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_appId int;
    DECLARE @v_status varchar(100);
    DECLARE @v_totalCount int = 0;
    DECLARE @v_completedCount int = 0;
    DECLARE @v_cancelledCount int = 0;
    DECLARE @v_totalRevenue decimal(10,2) = 0;
    DECLARE @v_appRevenue decimal(10,2);
    DECLARE @v_popularService varchar(50);

    DECLARE c_appointments CURSOR FOR
        SELECT a.ID, a.Status FROM Appointment a
        WHERE MONTH(a.StartDateTime) = @p_month AND YEAR(a.StartDateTime) = @p_year;

    PRINT 'Monthly Report for ' + CAST(@p_month AS varchar) + '/' + CAST(@p_year AS varchar);

    OPEN c_appointments;
    FETCH NEXT FROM c_appointments INTO @v_appId, @v_status;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @v_totalCount = @v_totalCount + 1;

        IF @v_status = 'Completed'
        BEGIN
            SET @v_completedCount = @v_completedCount + 1;
            SELECT @v_appRevenue = ISNULL(SUM(Price), 0)
            FROM AppointmentService WHERE Appointment_ID = @v_appId;
            SET @v_totalRevenue = @v_totalRevenue + @v_appRevenue;
        END
        ELSE IF @v_status = 'Cancelled'
            SET @v_cancelledCount = @v_cancelledCount + 1;

        FETCH NEXT FROM c_appointments INTO @v_appId, @v_status;
    END

    CLOSE c_appointments;
    DEALLOCATE c_appointments;

    -- Get most popular service
    SELECT TOP 1 @v_popularService = s.Name
    FROM Service s
    JOIN AppointmentService aps ON s.ID = aps.Service_ID
    JOIN Appointment a ON aps.Appointment_ID = a.ID
    WHERE MONTH(a.StartDateTime) = @p_month AND YEAR(a.StartDateTime) = @p_year
    GROUP BY s.Name ORDER BY COUNT(*) DESC;

    IF @v_popularService IS NULL SET @v_popularService = 'None';

    PRINT 'Total appointments: ' + CAST(@v_totalCount AS varchar);
    PRINT 'Completed: ' + CAST(@v_completedCount AS varchar);
    PRINT 'Cancelled: ' + CAST(@v_cancelledCount AS varchar);
    PRINT 'Total revenue: ' + CAST(@v_totalRevenue AS varchar) + ' TRY';
    PRINT 'Most popular service: ' + @v_popularService;
END;
GO
