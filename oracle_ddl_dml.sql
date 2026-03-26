-- Barbershop Appointment Management System
-- SQL komutunu string olarak çalıştır
-- Drop tables safely (ignore if not exists)
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE Payment';
    EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE ProductUsage';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE AppointmentService';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE Appointment';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE Product';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE Service';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE Customer';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE BarberShift';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE Barber';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE Chair';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE Branch';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

-- Tables

CREATE TABLE Branch (
    ID integer PRIMARY KEY,
    Name varchar2(50) NOT NULL,
    City varchar2(50) NOT NULL,
    Address varchar2(200)
);

CREATE TABLE Chair (
    ID integer PRIMARY KEY,
    ChairNo integer NOT NULL,
    Branch_ID integer NOT NULL,
    CONSTRAINT FK_Chair_Branch FOREIGN KEY (Branch_ID) REFERENCES Branch(ID)
);

CREATE TABLE Barber (
    ID integer PRIMARY KEY,
    Name varchar2(50) NOT NULL,
    Surname varchar2(50) NOT NULL,
    Phone integer,
    HireDate date,
    Salary number(10,2),
    Branch_ID integer NOT NULL,
    Boss_ID integer,
    CONSTRAINT FK_Barber_Branch FOREIGN KEY (Branch_ID) REFERENCES Branch(ID),
    CONSTRAINT FK_Barber_Boss FOREIGN KEY (Boss_ID) REFERENCES Barber(ID)
);

CREATE TABLE BarberShift (
    ID integer PRIMARY KEY,
    DayOfWeek integer NOT NULL,
    StartTime timestamp,
    EndTime timestamp,
    Barber_ID integer NOT NULL,
    CONSTRAINT FK_BarberShift_Barber FOREIGN KEY (Barber_ID) REFERENCES Barber(ID)
);

CREATE TABLE Customer (
    ID integer PRIMARY KEY,
    Name varchar2(50) NOT NULL,
    Surname varchar2(50) NOT NULL,
    Phone integer,
    Email varchar2(100),
    DateOfBirth date,
    RegisterDate date
);

CREATE TABLE Service (
    ID integer PRIMARY KEY,
    Name varchar2(50) NOT NULL,
    Price number(10,2) NOT NULL
);

CREATE TABLE Product (
    ID integer PRIMARY KEY,
    Name varchar2(50) NOT NULL,
    Brand varchar2(50),
    Price integer
);

CREATE TABLE Appointment (
    ID integer PRIMARY KEY,
    StartDateTime date NOT NULL,
    Status varchar2(100) DEFAULT 'Scheduled',
    Notes varchar2(500),
    Customer_ID integer NOT NULL,
    Barber_ID integer NOT NULL,
    Chair_ID integer NOT NULL,
    CONSTRAINT FK_Appointment_Customer FOREIGN KEY (Customer_ID) REFERENCES Customer(ID),
    CONSTRAINT FK_Appointment_Barber FOREIGN KEY (Barber_ID) REFERENCES Barber(ID),
    CONSTRAINT FK_Appointment_Chair FOREIGN KEY (Chair_ID) REFERENCES Chair(ID)
);

CREATE TABLE AppointmentService (
    Appointment_ID integer NOT NULL,
    Service_ID integer NOT NULL,
    Price integer,
    DurationTime integer,
    CONSTRAINT PK_AppointmentService PRIMARY KEY (Appointment_ID, Service_ID),
    CONSTRAINT FK_AS_Appointment FOREIGN KEY (Appointment_ID) REFERENCES Appointment(ID),
    CONSTRAINT FK_AS_Service FOREIGN KEY (Service_ID) REFERENCES Service(ID)
);

CREATE TABLE ProductUsage (
    Product_ID integer NOT NULL,
    Appointment_ID integer NOT NULL,
    CONSTRAINT PK_ProductUsage PRIMARY KEY (Product_ID, Appointment_ID),
    CONSTRAINT FK_PU_Product FOREIGN KEY (Product_ID) REFERENCES Product(ID),
    CONSTRAINT FK_PU_Appointment FOREIGN KEY (Appointment_ID) REFERENCES Appointment(ID)
);

CREATE TABLE Payment (
    ID integer PRIMARY KEY,
    Amount integer NOT NULL,
    Currency varchar2(10) DEFAULT 'TRY',
    PaymentDate date,
    PaymentMethod varchar2(50),
    Status varchar2(50) DEFAULT 'Pending',
    Appointment_ID integer NOT NULL,
    CONSTRAINT FK_Payment_Appointment FOREIGN KEY (Appointment_ID) REFERENCES Appointment(ID)
);


-- Insert data

INSERT INTO Branch VALUES (1, 'Batikent Merkez Subesi', 'Ankara', 'Batikent Mah. 1234 Sok. No:5 Yenimahalle/Ankara');
INSERT INTO Branch VALUES (2, 'Kardelen Subesi', 'Ankara', 'Kardelen Mah. 2045 Sok. No:12 Batikent/Ankara');
INSERT INTO Branch VALUES (3, 'Koru Subesi', 'Ankara', 'Koru Mah. 1456 Cad. No:8 Batikent/Ankara');
INSERT INTO Branch VALUES (4, 'Tulumtas Subesi', 'Ankara', 'Tulumtas Mah. 1678 Sok. No:3 Batikent/Ankara');
INSERT INTO Branch VALUES (5, 'Gimat Subesi', 'Ankara', 'Gimat Mah. 1890 Cad. No:15 Batikent/Ankara');

INSERT INTO Chair VALUES (1, 1, 1);
INSERT INTO Chair VALUES (2, 2, 1);
INSERT INTO Chair VALUES (3, 1, 2);
INSERT INTO Chair VALUES (4, 2, 2);
INSERT INTO Chair VALUES (5, 1, 3);
INSERT INTO Chair VALUES (6, 2, 3);

INSERT INTO Barber VALUES (1, 'Ahmet', 'Yilmaz', 5321001, TO_DATE('2020-01-15', 'YYYY-MM-DD'), 5000, 1, NULL);
INSERT INTO Barber VALUES (2, 'Mehmet', 'Kaya', 5321002, TO_DATE('2021-03-20', 'YYYY-MM-DD'), 4000, 1, 1);
INSERT INTO Barber VALUES (3, 'Mustafa', 'Demir', 5321003, TO_DATE('2021-06-10', 'YYYY-MM-DD'), 4500, 2, 1);
INSERT INTO Barber VALUES (4, 'Ali', 'Celik', 5321004, TO_DATE('2022-02-01', 'YYYY-MM-DD'), 3500, 2, 3);
INSERT INTO Barber VALUES (5, 'Hasan', 'Sahin', 5321005, TO_DATE('2022-08-15', 'YYYY-MM-DD'), 3000, 3, 1);
INSERT INTO Barber VALUES (6, 'Huseyin', 'Ozturk', 5321006, TO_DATE('2023-01-10', 'YYYY-MM-DD'), 2800, 3, 5);

INSERT INTO BarberShift VALUES (1, 1, TO_TIMESTAMP('1970-01-01 09:00:00', 'YYYY-MM-DD HH24:MI:SS'), TO_TIMESTAMP('1970-01-01 17:00:00', 'YYYY-MM-DD HH24:MI:SS'), 1);
INSERT INTO BarberShift VALUES (2, 2, TO_TIMESTAMP('1970-01-01 09:00:00', 'YYYY-MM-DD HH24:MI:SS'), TO_TIMESTAMP('1970-01-01 17:00:00', 'YYYY-MM-DD HH24:MI:SS'), 1);
INSERT INTO BarberShift VALUES (3, 1, TO_TIMESTAMP('1970-01-01 10:00:00', 'YYYY-MM-DD HH24:MI:SS'), TO_TIMESTAMP('1970-01-01 18:00:00', 'YYYY-MM-DD HH24:MI:SS'), 2);
INSERT INTO BarberShift VALUES (4, 3, TO_TIMESTAMP('1970-01-01 09:00:00', 'YYYY-MM-DD HH24:MI:SS'), TO_TIMESTAMP('1970-01-01 17:00:00', 'YYYY-MM-DD HH24:MI:SS'), 3);
INSERT INTO BarberShift VALUES (5, 4, TO_TIMESTAMP('1970-01-01 12:00:00', 'YYYY-MM-DD HH24:MI:SS'), TO_TIMESTAMP('1970-01-01 20:00:00', 'YYYY-MM-DD HH24:MI:SS'), 4);
INSERT INTO BarberShift VALUES (6, 5, TO_TIMESTAMP('1970-01-01 09:00:00', 'YYYY-MM-DD HH24:MI:SS'), TO_TIMESTAMP('1970-01-01 17:00:00', 'YYYY-MM-DD HH24:MI:SS'), 5);

INSERT INTO Customer VALUES (1, 'Emre', 'Arslan', 5332001, 'emre@email.com', TO_DATE('1990-05-15', 'YYYY-MM-DD'), TO_DATE('2023-01-10', 'YYYY-MM-DD'));
INSERT INTO Customer VALUES (2, 'Burak', 'Yildiz', 5332002, 'burak@email.com', TO_DATE('1985-08-20', 'YYYY-MM-DD'), TO_DATE('2023-02-15', 'YYYY-MM-DD'));
INSERT INTO Customer VALUES (3, 'Cem', 'Aktas', 5332003, 'cem@email.com', TO_DATE('1992-12-03', 'YYYY-MM-DD'), TO_DATE('2023-03-20', 'YYYY-MM-DD'));
INSERT INTO Customer VALUES (4, 'Deniz', 'Korkmaz', 5332004, 'deniz@email.com', TO_DATE('1988-03-25', 'YYYY-MM-DD'), TO_DATE('2023-04-05', 'YYYY-MM-DD'));
INSERT INTO Customer VALUES (5, 'Efe', 'Aydin', 5332005, 'efe@email.com', TO_DATE('1995-07-10', 'YYYY-MM-DD'), TO_DATE('2023-05-12', 'YYYY-MM-DD'));
INSERT INTO Customer VALUES (6, 'Furkan', 'Polat', 5332006, 'furkan@email.com', TO_DATE('1991-11-30', 'YYYY-MM-DD'), TO_DATE('2023-06-18', 'YYYY-MM-DD'));

INSERT INTO Service VALUES (1, 'Haircut', 250);
INSERT INTO Service VALUES (2, 'Beard Trim', 150);
INSERT INTO Service VALUES (3, 'Shaving', 200);
INSERT INTO Service VALUES (4, 'Hair Coloring', 500);
INSERT INTO Service VALUES (5, 'Hair Wash', 100);
INSERT INTO Service VALUES (6, 'Kids Haircut', 180);

INSERT INTO Product VALUES (1, 'Hair Gel', 'Gatsby', 120);
INSERT INTO Product VALUES (2, 'Shampoo', 'HeadShoulders', 150);
INSERT INTO Product VALUES (3, 'Hair Wax', 'American Crew', 180);
INSERT INTO Product VALUES (4, 'Aftershave', 'Nivea', 100);
INSERT INTO Product VALUES (5, 'Hair Oil', 'Moroccan', 200);
INSERT INTO Product VALUES (6, 'Beard Oil', 'Viking', 220);

INSERT INTO Appointment VALUES (1, TO_DATE('2024-01-15 10:00', 'YYYY-MM-DD HH24:MI'), 'Completed', 'Regular customer', 1, 1, 1);
INSERT INTO Appointment VALUES (2, TO_DATE('2024-01-15 11:00', 'YYYY-MM-DD HH24:MI'), 'Completed', NULL, 2, 2, 2);
INSERT INTO Appointment VALUES (3, TO_DATE('2024-01-16 09:30', 'YYYY-MM-DD HH24:MI'), 'Completed', 'First visit', 3, 3, 3);
INSERT INTO Appointment VALUES (4, TO_DATE('2024-01-16 14:00', 'YYYY-MM-DD HH24:MI'), 'Cancelled', 'Customer called to cancel', 4, 4, 4);
INSERT INTO Appointment VALUES (5, TO_DATE('2024-01-17 10:00', 'YYYY-MM-DD HH24:MI'), 'Completed', NULL, 5, 5, 5);
INSERT INTO Appointment VALUES (6, TO_DATE('2024-01-18 15:00', 'YYYY-MM-DD HH24:MI'), 'Scheduled', 'VIP customer', 1, 1, 1);
INSERT INTO Appointment VALUES (7, TO_DATE('2024-01-19 11:00', 'YYYY-MM-DD HH24:MI'), 'Scheduled', NULL, 2, 2, 2);

INSERT INTO AppointmentService VALUES (1, 1, 250, 30);
INSERT INTO AppointmentService VALUES (1, 2, 150, 15);
INSERT INTO AppointmentService VALUES (2, 1, 250, 30);
INSERT INTO AppointmentService VALUES (3, 1, 250, 30);
INSERT INTO AppointmentService VALUES (3, 3, 200, 20);
INSERT INTO AppointmentService VALUES (4, 1, 250, 30);
INSERT INTO AppointmentService VALUES (5, 4, 500, 60);
INSERT INTO AppointmentService VALUES (6, 1, 250, 30);
INSERT INTO AppointmentService VALUES (7, 2, 150, 15);

INSERT INTO ProductUsage VALUES (1, 1);
INSERT INTO ProductUsage VALUES (2, 1);
INSERT INTO ProductUsage VALUES (3, 2);
INSERT INTO ProductUsage VALUES (4, 3);
INSERT INTO ProductUsage VALUES (1, 5);
INSERT INTO ProductUsage VALUES (5, 5);

INSERT INTO Payment VALUES (1, 400, 'TRY', TO_DATE('2024-01-15', 'YYYY-MM-DD'), 'Cash', 'Paid', 1);
INSERT INTO Payment VALUES (2, 250, 'TRY', TO_DATE('2024-01-15', 'YYYY-MM-DD'), 'CreditCard', 'Paid', 2);
INSERT INTO Payment VALUES (3, 450, 'TRY', TO_DATE('2024-01-16', 'YYYY-MM-DD'), 'DebitCard', 'Paid', 3);
INSERT INTO Payment VALUES (4, 0, 'TRY', NULL, 'Cash', 'Refunded', 4);
INSERT INTO Payment VALUES (5, 500, 'TRY', TO_DATE('2024-01-17', 'YYYY-MM-DD'), 'Cash', 'Paid', 5);
INSERT INTO Payment VALUES (6, 250, 'TRY', NULL, 'CreditCard', 'Pending', 6);

COMMIT;
