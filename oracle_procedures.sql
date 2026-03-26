-- Procedure to create appointment with validation
-- Uses cursor to check for conflicts
CREATE OR REPLACE PROCEDURE CreateAppointmentWithValidation(
    p_CustomerId integer,
    p_BarberId integer,
    p_ChairId integer,
    p_AppDate date,
    p_ServiceId integer,
    p_Notes varchar2 DEFAULT NULL
)
IS
    --coming to appointment
    CURSOR c_barberApps IS
        SELECT ID, StartDateTime
        FROM Appointment
        WHERE Barber_ID = p_BarberId
        AND TRUNC(StartDateTime) = TRUNC(p_AppDate)
        AND Status IN ('Scheduled', 'Completed');

    CURSOR c_chairApps IS
        SELECT ID, StartDateTime
        FROM Appointment
        WHERE Chair_ID = p_ChairId
        AND TRUNC(StartDateTime) = TRUNC(p_AppDate)
        AND Status = 'Scheduled';

    v_count integer;
    v_dayOfWeek integer;
    v_newAppId integer;
    v_servicePrice number(10,2);
    v_conflict boolean := FALSE;
    v_existingAppId integer;
    v_existingDate date;
    v_newPayId integer;
BEGIN
    -- Check if customer exists
    SELECT COUNT(*) INTO v_count        --how many customer
                    FROM Customer
                    WHERE ID = p_CustomerId;
    IF v_count = 0 THEN
        raise_application_error(-20001, 'Customer with ID=' || p_CustomerId || ' does not exist');
    END IF;

    -- Check if barber exists
    SELECT COUNT(*) INTO v_count
                    FROM Barber
                    WHERE ID = p_BarberId;
    IF v_count = 0 THEN
        raise_application_error(-20002, 'Barber with ID=' || p_BarberId || ' does not exist');
    END IF;

    -- Check if chair exists
    SELECT COUNT(*) INTO v_count
                    FROM Chair
                    WHERE ID = p_ChairId;
    IF v_count = 0 THEN
        raise_application_error(-20003, 'Chair with ID=' || p_ChairId || ' does not exist');
    END IF;

    -- Check if service exists
    BEGIN
        SELECT Price INTO v_servicePrice
                     FROM Service
                     WHERE ID = p_ServiceId;
    EXCEPTION
        WHEN no_data_found THEN
            raise_application_error(-20004, 'Service with ID=' || p_ServiceId || ' does not exist');
    END;

    -- Check if barber works on this day (ISO week: Monday=1, Sunday=7)
    v_dayOfWeek := TRUNC(p_AppDate) - TRUNC(p_AppDate, 'IW') + 1;
    SELECT COUNT(*) INTO v_count
        FROM BarberShift
        WHERE Barber_ID = p_BarberId
        AND DayOfWeek = v_dayOfWeek;
    IF v_count = 0 THEN
        raise_application_error(-20005, 'Barber does not work on this day');
    END IF;

    -- Check for conflicts using cursor
    OPEN c_barberApps;                  -- opening cursor run the query
    LOOP
        FETCH c_barberApps INTO v_existingAppId, v_existingDate;
        EXIT WHEN c_barberApps%NotFound;       --Exit the loop if there are no more rows

        -- DATE difference in minutes: (date1 - date2) * 24 * 60
        IF ABS((p_AppDate - v_existingDate) * 24 * 60) < 60 THEN  -- ABS is ABSOLUTE VALUE
            v_conflict := TRUE;
            EXIT;
        END IF;
    END LOOP;
    CLOSE c_barberApps;       -- close the cursor

    IF v_conflict THEN
        raise_application_error(-20006, 'Barber has another appointment at this time');
    END IF;

    -- Check chair availability using cursor
    v_conflict := FALSE;     -- clean to other control
    OPEN c_chairApps;
    LOOP
        FETCH c_chairApps INTO v_existingAppId, v_existingDate;
        EXIT WHEN c_chairApps%NotFound;
        IF ABS((p_AppDate - v_existingDate) * 24 * 60) < 60 THEN
            v_conflict := TRUE;
            EXIT;
        END IF;
    END LOOP;
    CLOSE c_chairApps;

    IF v_conflict THEN
        raise_application_error(-20007, 'Chair is not available at this time');
    END IF;

    -- Create appointment
    SELECT NVL(MAX(ID), 0) + 1 --NEW ID GOING TO BE 8
    INTO v_newAppId
    FROM Appointment;
-- add new appointment
    INSERT INTO Appointment (ID, StartDateTime, Status,
                             Notes, Customer_ID, Barber_ID, Chair_ID
    )
    VALUES (v_newAppId, p_AppDate, 'Scheduled', p_Notes,
            p_CustomerId, p_BarberId, p_ChairId);

    -- Add service to appointment
    INSERT INTO AppointmentService (Appointment_ID, Service_ID, Price, DurationTime)
    VALUES (v_newAppId, p_ServiceId,
            v_servicePrice, 30);

    -- Create payment record
    SELECT NVL(MAX(ID), 0) + 1
    INTO v_newPayId
    FROM Payment;
    INSERT INTO Payment (ID, Amount, Currency, PaymentDate,
                         PaymentMethod, Status, Appointment_ID
    )
    VALUES (v_newPayId, v_servicePrice, 'TRY',
            NULL, NULL, 'Pending', v_newAppId); --pendin = waiting
-- writing on screen
    DBMS_OUTPUT.PUT_LINE(
            'Appointment created with ID=' || v_newAppId ||
            ', Price=' || v_servicePrice || ' TRY');
    COMMIT;  --save all changes
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/


-- Procedure to calculate barber earnings and give bonus
-- Uses cursor to go through all barbers
CREATE OR REPLACE PROCEDURE CalculateBarberEarnings
IS
    CURSOR c_barbers IS
        SELECT b.ID, b.Name, b.Surname, b.Salary,
               COUNT(a.ID) as AppCount     --Number of completed appointments
        FROM Barber b
        LEFT JOIN Appointment a    -- show the barber even if he dont have appointment
            ON b.ID = a.Barber_ID AND a.Status = 'Completed'
        GROUP BY b.ID, b.Name, b.Surname, b.Salary;

    v_barberId Barber.ID%type;
    v_barberName Barber.Name%type;
    v_barberSurname Barber.Surname%type;
    v_salary Barber.Salary%type;
    v_appCount integer;
    v_totalEarnings number(10,2);
    v_bonus number(10,2);
BEGIN
    OPEN c_barbers;          -- open the cursor
    LOOP
        FETCH c_barbers INTO     --get a information of Barber
            v_barberId, v_barberName, v_barberSurname,
            v_salary, v_appCount;

        EXIT WHEN c_barbers%NotFound;

        -- Calculate total earnings from completed appointments
        SELECT NVL(SUM(aps.Price), 0)
        INTO v_totalEarnings
        FROM Appointment a
        JOIN AppointmentService aps
            ON a.ID = aps.Appointment_ID
        WHERE a.Barber_ID = v_barberId
          AND a.Status = 'Completed';    --appointment

        -- Give 10% bonus if more than 2 completed appointments
        IF v_appCount > 2 THEN
            v_bonus := ROUND(
                    v_totalEarnings * 0.10, 2);

            UPDATE Barber
            SET Salary = Salary + v_bonus
            WHERE ID = v_barberId;
            DBMS_OUTPUT.PUT_LINE('Barber ' || v_barberName || ' ' || v_barberSurname ||
                ' - Earnings: ' || v_totalEarnings || ' TRY, Bonus: ' || v_bonus || ' TRY');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Barber ' || v_barberName || ' ' || v_barberSurname ||
                ' - Earnings: ' || v_totalEarnings || ' TRY, No bonus (less than 3 appointments)');
        END IF;
    END LOOP;
    CLOSE c_barbers;  -- close the cursor
END;
/


-- Procedure to generate monthly report
-- Uses cursor to process appointments
CREATE OR REPLACE PROCEDURE GenerateMonthlyReport(
    p_month integer,
    p_year integer
)
IS
    --GET ALL APPOINTMENTS FOR A SPECIFIC MONTH
    CURSOR c_appointments IS
        SELECT a.ID, a.Status
        FROM Appointment a
        WHERE EXTRACT(MONTH FROM a.StartDateTime) = p_month  --geting month of appointment
        AND EXTRACT(YEAR FROM a.StartDateTime) = p_year;

    v_appId Appointment.ID%type;
    v_status Appointment.Status%type;
    v_totalCount integer := 0;
    v_completedCount integer := 0;
    v_cancelledCount integer := 0;
    v_totalRevenue number(10,2) := 0;
    v_appRevenue number(10,2);
    v_popularService varchar2(50);
BEGIN
    DBMS_OUTPUT.PUT_LINE('Monthly Report for ' || p_month || '/' || p_year);

    OPEN c_appointments;
    LOOP
        FETCH c_appointments INTO v_appId, v_status;
        EXIT WHEN c_appointments%NotFound;
        v_totalCount := v_totalCount + 1;

        CASE v_status
            WHEN 'Completed' THEN
                v_completedCount := v_completedCount + 1;
--calculate the revenue
                SELECT NVL(SUM(Price), 0)
                INTO v_appRevenue
                FROM AppointmentService
                WHERE Appointment_ID = v_appId;

                v_totalRevenue := v_totalRevenue + v_appRevenue;

            WHEN 'Cancelled' THEN
                v_cancelledCount := v_cancelledCount + 1;

            ELSE NULL;
        END CASE;
    END LOOP;
    CLOSE c_appointments;

    -- Get most popular service (Oracle 11g compatible)
    BEGIN
        SELECT Name INTO v_popularService
        FROM (
            SELECT s.Name
            FROM Service s
            JOIN AppointmentService aps ON s.ID = aps.Service_ID
            JOIN Appointment a ON aps.Appointment_ID = a.ID
            WHERE EXTRACT(MONTH FROM a.StartDateTime) = p_month
            AND EXTRACT(YEAR FROM a.StartDateTime) = p_year
            GROUP BY s.Name              -- group by service
            ORDER BY COUNT(*) DESC     --Sort by most used to least used
        )
        WHERE ROWNUM = 1;
    EXCEPTION
        WHEN no_data_found THEN v_popularService := 'None';
    END;

    DBMS_OUTPUT.PUT_LINE('Total appointments: ' || v_totalCount);
    DBMS_OUTPUT.PUT_LINE('Completed: ' || v_completedCount);
    DBMS_OUTPUT.PUT_LINE('Cancelled: ' || v_cancelledCount);
    DBMS_OUTPUT.PUT_LINE('Total revenue: ' || v_totalRevenue || ' TRY');
    DBMS_OUTPUT.PUT_LINE('Most popular service: ' || v_popularService);
END;
/
