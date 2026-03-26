-- Barbershop Appointment Management System

-- Drop tables safely
IF OBJECT_ID('Payment', 'U') IS NOT NULL DROP TABLE Payment;
IF OBJECT_ID('ProductUsage', 'U') IS NOT NULL DROP TABLE ProductUsage;
IF OBJECT_ID('AppointmentService', 'U') IS NOT NULL DROP TABLE AppointmentService;
IF OBJECT_ID('Appointment', 'U') IS NOT NULL DROP TABLE Appointment;
IF OBJECT_ID('Product', 'U') IS NOT NULL DROP TABLE Product;
IF OBJECT_ID('Service', 'U') IS NOT NULL DROP TABLE Service;
IF OBJECT_ID('Customer', 'U') IS NOT NULL DROP TABLE Customer;
IF OBJECT_ID('BarberShift', 'U') IS NOT NULL DROP TABLE BarberShift;
IF OBJECT_ID('Barber', 'U') IS NOT NULL DROP TABLE Barber;
IF OBJECT_ID('Chair', 'U') IS NOT NULL DROP TABLE Chair;
IF OBJECT_ID('Branch', 'U') IS NOT NULL DROP TABLE Branch;
GO

-- Tables

CREATE TABLE Branch (
    ID int PRIMARY KEY,
    Name varchar(50) NOT NULL,
    City varchar(50) NOT NULL,
    Address varchar(200)
);

CREATE TABLE Chair (
    ID int PRIMARY KEY,
    ChairNo int NOT NULL,
    Branch_ID int NOT NULL,
    CONSTRAINT FK_Chair_Branch FOREIGN KEY (Branch_ID) REFERENCES Branch(ID)
);

CREATE TABLE Barber (
    ID int PRIMARY KEY,
    Name varchar(50) NOT NULL,
    Surname varchar(50) NOT NULL,
    Phone int,
    HireDate date,
    Salary decimal(10,2),
    Branch_ID int NOT NULL,
    Boss_ID int,
    CONSTRAINT FK_Barber_Branch FOREIGN KEY (Branch_ID) REFERENCES Branch(ID),
    CONSTRAINT FK_Barber_Boss FOREIGN KEY (Boss_ID) REFERENCES Barber(ID)
);

CREATE TABLE BarberShift (
    ID int PRIMARY KEY,
    DayOfWeek int NOT NULL,
    StartTime time,
    EndTime time,
    Barber_ID int NOT NULL,
    CONSTRAINT FK_BarberShift_Barber FOREIGN KEY (Barber_ID) REFERENCES Barber(ID)
);

CREATE TABLE Customer (
    ID int PRIMARY KEY,
    Name varchar(50) NOT NULL,
    Surname varchar(50) NOT NULL,
    Phone int,
    Email varchar(100),
    DateOfBirth date,
    RegisterDate date
);

CREATE TABLE Service (
    ID int PRIMARY KEY,
    Name varchar(50) NOT NULL,
    Price decimal(10,2) NOT NULL
);

CREATE TABLE Product (
    ID int PRIMARY KEY,
    Name varchar(50) NOT NULL,
    Brand varchar(50),
    Price int
);

CREATE TABLE Appointment (
    ID int PRIMARY KEY,
    StartDateTime datetime NOT NULL,
    Status varchar(100) DEFAULT 'Scheduled',
    Notes varchar(500),
    Customer_ID int NOT NULL,
    Barber_ID int NOT NULL,
    Chair_ID int NOT NULL,
    CONSTRAINT FK_Appointment_Customer FOREIGN KEY (Customer_ID) REFERENCES Customer(ID),
    CONSTRAINT FK_Appointment_Barber FOREIGN KEY (Barber_ID) REFERENCES Barber(ID),
    CONSTRAINT FK_Appointment_Chair FOREIGN KEY (Chair_ID) REFERENCES Chair(ID)
);

CREATE TABLE AppointmentService (
    Appointment_ID int NOT NULL,
    Service_ID int NOT NULL,
    Price decimal(10,2),
    DurationTime int,
    CONSTRAINT PK_AppointmentService PRIMARY KEY (Appointment_ID, Service_ID),
    CONSTRAINT FK_AS_Appointment FOREIGN KEY (Appointment_ID) REFERENCES Appointment(ID),
    CONSTRAINT FK_AS_Service FOREIGN KEY (Service_ID) REFERENCES Service(ID)
);

CREATE TABLE ProductUsage (
    Product_ID int NOT NULL,
    Appointment_ID int NOT NULL,
    CONSTRAINT PK_ProductUsage PRIMARY KEY (Product_ID, Appointment_ID),
    CONSTRAINT FK_PU_Product FOREIGN KEY (Product_ID) REFERENCES Product(ID),
    CONSTRAINT FK_PU_Appointment FOREIGN KEY (Appointment_ID) REFERENCES Appointment(ID)
);

CREATE TABLE Payment (
    ID int PRIMARY KEY,
    Amount decimal(10,2) NOT NULL,
    Currency varchar(10) DEFAULT 'TRY',
    PaymentDate date,
    PaymentMethod varchar(50),
    Status varchar(50) DEFAULT 'Pending',
    Appointment_ID int NOT NULL,
    CONSTRAINT FK_Payment_Appointment FOREIGN KEY (Appointment_ID) REFERENCES Appointment(ID)
);
GO


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

INSERT INTO Barber VALUES (1, 'Ahmet', 'Yilmaz', 5321001, '2020-01-15', 5000, 1, NULL);
INSERT INTO Barber VALUES (2, 'Mehmet', 'Kaya', 5321002, '2021-03-20', 4000, 1, 1);
INSERT INTO Barber VALUES (3, 'Mustafa', 'Demir', 5321003, '2021-06-10', 4500, 2, 1);
INSERT INTO Barber VALUES (4, 'Ali', 'Celik', 5321004, '2022-02-01', 3500, 2, 3);
INSERT INTO Barber VALUES (5, 'Hasan', 'Sahin', 5321005, '2022-08-15', 3000, 3, 1);
INSERT INTO Barber VALUES (6, 'Huseyin', 'Ozturk', 5321006, '2023-01-10', 2800, 3, 5);

INSERT INTO BarberShift VALUES (1, 1, '09:00:00', '17:00:00', 1);
INSERT INTO BarberShift VALUES (2, 2, '09:00:00', '17:00:00', 1);
INSERT INTO BarberShift VALUES (3, 1, '10:00:00', '18:00:00', 2);
INSERT INTO BarberShift VALUES (4, 3, '09:00:00', '17:00:00', 3);
INSERT INTO BarberShift VALUES (5, 4, '12:00:00', '20:00:00', 4);
INSERT INTO BarberShift VALUES (6, 5, '09:00:00', '17:00:00', 5);

INSERT INTO Customer VALUES (1, 'Emre', 'Arslan', 5332001, 'emre@email.com', '1990-05-15', '2023-01-10');
INSERT INTO Customer VALUES (2, 'Burak', 'Yildiz', 5332002, 'burak@email.com', '1985-08-20', '2023-02-15');
INSERT INTO Customer VALUES (3, 'Cem', 'Aktas', 5332003, 'cem@email.com', '1992-12-03', '2023-03-20');
INSERT INTO Customer VALUES (4, 'Deniz', 'Korkmaz', 5332004, 'deniz@email.com', '1988-03-25', '2023-04-05');
INSERT INTO Customer VALUES (5, 'Efe', 'Aydin', 5332005, 'efe@email.com', '1995-07-10', '2023-05-12');
INSERT INTO Customer VALUES (6, 'Furkan', 'Polat', 5332006, 'furkan@email.com', '1991-11-30', '2023-06-18');

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

INSERT INTO Appointment VALUES (1, '2024-01-15 10:00', 'Completed', 'Regular customer', 1, 1, 1);
INSERT INTO Appointment VALUES (2, '2024-01-15 11:00', 'Completed', NULL, 2, 2, 2);
INSERT INTO Appointment VALUES (3, '2024-01-16 09:30', 'Completed', 'First visit', 3, 3, 3);
INSERT INTO Appointment VALUES (4, '2024-01-16 14:00', 'Cancelled', 'Customer called to cancel', 4, 4, 4);
INSERT INTO Appointment VALUES (5, '2024-01-17 10:00', 'Completed', NULL, 5, 5, 5);
INSERT INTO Appointment VALUES (6, '2024-01-18 15:00', 'Scheduled', 'VIP customer', 1, 1, 1);
INSERT INTO Appointment VALUES (7, '2024-01-19 11:00', 'Scheduled', NULL, 2, 2, 2);

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

INSERT INTO Payment VALUES (1, 400, 'TRY', '2024-01-15', 'Cash', 'Paid', 1);
INSERT INTO Payment VALUES (2, 250, 'TRY', '2024-01-15', 'CreditCard', 'Paid', 2);
INSERT INTO Payment VALUES (3, 450, 'TRY', '2024-01-16', 'DebitCard', 'Paid', 3);
INSERT INTO Payment VALUES (4, 0, 'TRY', NULL, 'Cash', 'Refunded', 4);
INSERT INTO Payment VALUES (5, 500, 'TRY', '2024-01-17', 'Cash', 'Paid', 5);
INSERT INTO Payment VALUES (6, 250, 'TRY', NULL, 'CreditCard', 'Pending', 6);
