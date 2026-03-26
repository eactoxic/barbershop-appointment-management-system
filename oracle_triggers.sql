-- Trigger to check salary rules before insert/update
-- Uses COMPOUND TRIGGER to avoid mutating table error
-- Boss salary check needs SELECT from BARBER while BARBER is being modified.
-- Doing that in a row-level trigger may raise (mutating table).
-- Solution: collect changed rows in BEFORE EACH ROW, check boss salary in AFTER STATEMENT.
CREATE OR REPLACE TRIGGER TR_Barber_SalaryCheck
FOR INSERT OR UPDATE ON Barber
COMPOUND TRIGGER
---- Buffer (in-memory list) to store affected employees
    TYPE t_barber_rec IS RECORD (
        id Barber.ID%TYPE,
        salary Barber.Salary%TYPE,
        boss_id Barber.Boss_ID%TYPE,
        old_salary Barber.Salary%TYPE
    );

    TYPE t_barber_tab IS TABLE OF t_barber_rec
         INDEX BY PLS_INTEGER;

    v_barbers t_barber_tab;  -- list of barber
    v_idx PLS_INTEGER := 0;   -- index counter

BEFORE EACH ROW IS
    v_increasePercent number(5,2);   --Salary increase percentage
BEGIN
    -- Check if salary is negative
    IF :NEW.Salary < 0 THEN
        raise_application_error(-20001, 'Salary cannot be negative');
    END IF;

    -- Check if salary exceeds limit
    IF :NEW.Salary > 10000 THEN
        raise_application_error(-20002, 'Salary cannot exceed 10000');
    END IF;

    -- Check salary increase percentage (only for UPDATE) cap increase percentage to 20%
    IF UPDATING('Salary') AND :OLD.Salary > 0 THEN
        v_increasePercent := ((:NEW.Salary - :OLD.Salary) / :OLD.Salary) * 100;

        IF v_increasePercent > 20 THEN
            raise_application_error(-20003, 'Salary increase cannot exceed 20%');
        END IF;

        DBMS_OUTPUT.PUT_LINE(
                            'Salary updated from ' || :OLD.Salary ||
                            ' to ' || :NEW.Salary
                            );
    END IF;

    -- Auto set hire date if not provided
    IF INSERTING AND :NEW.HireDate IS NULL THEN
        :NEW.HireDate := SYSDATE;   --seting todays date
    END IF;

    -- Store data for boss salary check in AFTER STATEMENT
    IF :NEW.Boss_ID IS NOT NULL THEN
        v_idx := v_idx + 1;
        v_barbers(v_idx).id := :NEW.ID;
        v_barbers(v_idx).salary := :NEW.Salary;
        v_barbers(v_idx).boss_id := :NEW.Boss_ID;
        v_barbers(v_idx).old_salary := :OLD.Salary;
    END IF;

END BEFORE EACH ROW;

AFTER STATEMENT IS    --After statements are changeing
    v_bossSalary Barber.Salary%TYPE;
BEGIN
-- Neden AFTER STATEMENT'ta?
    -- Çünkü BEFORE EACH ROW'da Barber tablosundan SELECT yapamazsın (mutating table)

    -- Check if employee earns more than boss (after statement to avoid mutating table)
    FOR i IN 1..v_barbers.COUNT LOOP
        BEGIN
        -- get boss salary
            SELECT Salary INTO v_bossSalary
                          FROM Barber
                          WHERE ID = v_barbers(i).boss_id;
-- employee must not earn much than boss
            IF v_barbers(i).salary >= v_bossSalary THEN
                raise_application_error(-20004, 'Employee cannot earn more than boss');
            END IF;

        EXCEPTION
            WHEN no_data_found THEN --if we dont find the boss
                raise_application_error(-20005, 'Boss with ID=' || v_barbers(i).boss_id || ' does not exist');
        END;
    END LOOP;
END AFTER STATEMENT;

END TR_Barber_SalaryCheck;
/


-- Trigger for appointment status changes
-- Cannot modify completed appointments
-- Cannot reactivate cancelled appointments
-- Auto updates payment when status changes
CREATE OR REPLACE TRIGGER TR_Appointment_StatusChange
BEFORE UPDATE OF Status ON Appointment
FOR EACH ROW
DECLARE
    v_totalAmount number(10,2);
BEGIN
    -- Cannot change completed appointment
    IF :OLD.Status = 'Completed' AND :NEW.Status <> 'Completed' THEN
        raise_application_error(-20010, 'Cannot modify completed appointment');
    END IF;

    -- Cannot reactivate cancelled appointment
    IF :OLD.Status = 'Cancelled' AND :NEW.Status <> 'Cancelled' THEN
        raise_application_error(-20011, 'Cannot reactivate cancelled appointment');
    END IF;

    -- If completing, update payment
    IF :NEW.Status = 'Completed' AND :OLD.Status <> 'Completed' THEN
-- total amount of service
        SELECT NVL(SUM(Price), 0) INTO v_totalAmount
        FROM AppointmentService
        WHERE Appointment_ID = :OLD.ID;

        UPDATE Payment
        SET
            Status = 'Paid',
            PaymentDate = SYSDATE,
            Amount = v_totalAmount
        WHERE Appointment_ID = :OLD.ID
          AND Status = 'Pending';   -- only update on waiting payment

DBMS_OUTPUT.PUT_LINE('Appointment with ID=' || :OLD.ID || ' completed. Payment: ' || v_totalAmount || ' TRY');
    END IF;

    -- If cancelling, refund payment
    IF :NEW.Status = 'Cancelled' AND :OLD.Status <> 'Cancelled' THEN
       -- refund the payment
       UPDATE Payment
        SET Status = 'Refunded',
            Amount = 0
        WHERE Appointment_ID = :OLD.ID;

        DBMS_OUTPUT.PUT_LINE('Appointment with ID=' || :OLD.ID || ' cancelled. Payment refunded.');
    END IF;
END;
/


-- Trigger for appointment deletion
-- Prevents deletion of completed appointments
-- Cascade deletes related records
CREATE OR REPLACE TRIGGER TR_Appointment_Cascade
BEFORE DELETE ON Appointment
FOR EACH ROW
DECLARE
    v_serviceCount integer;   -- number of deleting to service
    v_productCount integer;   -- number of deleting to product
    v_paymentCount integer;   -- number of deleting to payment
BEGIN
    -- Cannot delete completed appointment
    IF :OLD.Status = 'Completed' THEN   -- giving the deleting rows data
        raise_application_error(-20020, 'Cannot delete completed appointments');
    END IF;

    -- Delete related records remove
    -- Manual cascade: delete AppointmentService, ProductUsage, Payment rows for this appointment
    SELECT COUNT(*) INTO v_serviceCount
                    FROM AppointmentService
                    WHERE Appointment_ID = :OLD.ID;
    DELETE
        FROM AppointmentService
        WHERE Appointment_ID = :OLD.ID;

    SELECT COUNT(*) INTO v_productCount
                    FROM ProductUsage
                    WHERE Appointment_ID = :OLD.ID;
    DELETE
        FROM ProductUsage
        WHERE Appointment_ID = :OLD.ID;

    SELECT COUNT(*) INTO v_paymentCount
                    FROM Payment
                    WHERE Appointment_ID = :OLD.ID;
    DELETE
        FROM Payment
        WHERE Appointment_ID = :OLD.ID;
--shows how many dependent rows were removed
    DBMS_OUTPUT.PUT_LINE('Appointment with ID=' || :OLD.ID || ' deleted. Removed ' ||
        v_serviceCount || ' services, ' || v_productCount || ' products, ' || v_paymentCount || ' payments');
END;
/
