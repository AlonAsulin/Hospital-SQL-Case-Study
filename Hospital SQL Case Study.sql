SELECT * FROM Dim_Patient
SELECT * FROM Dim_Doctor
SELECT * FROM Dim_Department
SELECT * FROM  Dim_Diagnosis
SELECT * FROM  Dim_Treatment
SELECT * FROM  Dim_PaymentMethod
SELECT * FROM  PatientVisits_2020_2021
SELECT * FROM  PatientVisits_2022_2023
SELECT * FROM  PatientVisits_2024
SELECT * FROM  PatientVisits_2025

--Data Cleaning: (DIM_Patient Table)
-- DIM_Patient Table:
--1 Remove patient rows where FirstName is missing
--2 Standardize FirstName and LastName to proper case and create a new FullName column
--3 Gender values should be either Male/Female
--4 Split CityStateCountry in 3 different columns


Create Table DIM_Patient_Clean (
	PatientID varchar (20) PRIMARY KEY,
	FullName varchar (120),
	Gender varchar (10),
	DOB date, 
	City varchar (50),
	State varchar (50),
	Country varchar (50)
)

INSERT INTO DIM_Patient_Clean (
		PatientID, FullName, Gender, DOB, City, State, Country
	)
SELECT 
p.PatientID,
UPPER(LEFT(LTRIM(RTRIM(p.FirstName)), 1)) + LOWER(SUBSTRING(LTRIM(RTRIM(p.FirstName)), 2, LEN(LTRIM(RTRIM(p.FirstName))))) + ' ' 
+ 
UPPER(LEFT(LTRIM(RTRIM(p.LastName)), 1)) + LOWER(SUBSTRING(LTRIM(RTRIM(p.LastName)), 2, LEN(LTRIM(RTRIM(p.LastName))))) AS FullName,
CASE
	WHEN p.Gender = 'M' THEN 'Male'
	WHEN p.Gender ='F' THEN 'Female'
	ELSE p.Gender
END AS Gender,
p.DOB,
PARSENAME (REPLACE(p.CityStateCountry, ',', '.'), 3) AS City,
PARSENAME (REPLACE(p.CityStateCountry, ',', '.'), 2) AS State,
PARSENAME (REPLACE(p.CityStateCountry, ',', '.'), 1) AS Country
FROM DIM_Patient as p
WHERE p.FirstName IS NOT NULL
 
SELECT * 
FROM DIM_Patient_Clean

-- Data Cleaning: (Department Table)
-- Remove departments where DepartmentCategory is missing
-- Drop HOD and DepartmentName columns
-- Use specialization as Department column

CREATE TABLE DIM_Department_Clean (
	DepartmentID varchar (20) Primary Key,
	DepartmentName varchar (100),
	DepartmentCategory varchar (100)
)

INSERT INTO DIM_Department_Clean (
	DepartmentID, DepartmentName, DepartmentCategory 
)

SELECT d.DepartmentID, d.Specialization as DepartmentName, d.DepartmentCategory
FROM DIM_Department as d
WHERE d.DepartmentCategory IS NOT NULL

SELECT*
FROM DIM_Department_Clean

-- Data Cleaning: (Patient Visits Table)
-- Merge all yearly visit table (2020 - 2025) into one PatientVisits table
CREATE TABLE PatientVisits (
    VisitID            VARCHAR(20) PRIMARY KEY,
    PatientID          VARCHAR(20),
    DoctorID           VARCHAR(20),
    DepartmentID       VARCHAR(20),
    DiagnosisID        VARCHAR(20),
    TreatmentID        VARCHAR(20),
    PaymentMethodID    VARCHAR(20),
    VisitDate           DATE,
    VisitTime           TIME,
    DischargeDate       DATE,
    BillAmount          DECIMAL(18,2),
    InsuranceAmount     DECIMAL(18,2),
    SatisfactionScore   INT,
    WaitTimeMinutes     INT,

    FOREIGN KEY (PatientID) 
        REFERENCES Dim_Patient_Clean(PatientID),

    FOREIGN KEY (DoctorID) 
        REFERENCES Dim_Doctor(DoctorID),

    FOREIGN KEY (DepartmentID) 
        REFERENCES Dim_Department_Clean(DepartmentID),

    FOREIGN KEY (DiagnosisID) 
        REFERENCES Dim_Diagnosis(DiagnosisID),

    FOREIGN KEY (TreatmentID) 
        REFERENCES Dim_Treatment(TreatmentID),

    FOREIGN KEY (PaymentMethodID) 
        REFERENCES Dim_PaymentMethod(PaymentMethodID)
);

INSERT INTO PatientVisits (
	VisitID,PatientID,DoctorID,DepartmentID,DiagnosisID,TreatmentID,
	PaymentMethodID,VisitDate,VisitTime,DischargeDate,BillAmount,InsuranceAmount,SatisfactionScore,
    WaitTimeMinutes
)
SELECT
    VisitID,PatientID,DoctorID,DepartmentID,DiagnosisID,TreatmentID,
	PaymentMethodID,VisitDate,VisitTime,DischargeDate,BillAmount,InsuranceAmount,SatisfactionScore,
    WaitTimeMinutes
FROM PatientVisits_2020_2021

UNION ALL

SELECT
 VisitID,PatientID,DoctorID,DepartmentID,DiagnosisID,TreatmentID,
	PaymentMethodID,VisitDate,VisitTime,DischargeDate,BillAmount,InsuranceAmount,SatisfactionScore,
    WaitTimeMinutes
FROM PatientVisits_2022_2023

UNION ALL 

SELECT VisitID,PatientID,DoctorID,DepartmentID,DiagnosisID,TreatmentID,
	PaymentMethodID,VisitDate,VisitTime,DischargeDate,BillAmount,InsuranceAmount,SatisfactionScore,
    WaitTimeMinutes
FROM PatientVisits_2024

UNION ALL 

SELECT VisitID,PatientID,DoctorID,DepartmentID,DiagnosisID,TreatmentID,
	PaymentMethodID,VisitDate,VisitTime,DischargeDate,BillAmount,InsuranceAmount,SatisfactionScore,
    WaitTimeMinutes
FROM PatientVisits_2025;

SELECT *
FROM PatientVisits

-- Data Exploration:

--Q1 For each doctor, ount how many distinct patients they have treated:
  
SELECT D.DoctorID, D.FirstName+ ' ' + D.LastName AS DoctorName, COUNT(DISTINCT P.PatientID) as DistinctPatients
FROM PatientVisits as P INNER JOIN Dim_Doctor AS D on P.DoctorID = D.DoctorID
GROUP BY D.DoctorID, D.LastName, D.FirstName
ORDER BY DistinctPatients DESC

--Q2 Show the revenue split by each payment method, along with total visits

SELECT PM.PaymentMethod, COUNT(P.VisitID) AS TotalVisits, SUM(P.BillAmount) as TotalRevenue
FROM PatientVisits as P INNER JOIN Dim_PaymentMethod AS PM on P.PaymentMethodID = PM.PaymentMethodID
GROUP BY PM.PaymentMethod

--Q3 Categorize patients into age groups and calculate the average bill amount for each age (assume age at time of visit based on VisitDate):

WITH CTE_PatientAge as (
SELECT P.BillAmount, P.VisitID,
	CASE
		WHEN DATEDIFF(YEAR, PC.DOB, P.VisitDate) < 18 THEN '0-17' 
		WHEN DATEDIFF(YEAR, PC.DOB, P.VisitDate) BETWEEN 18 AND 35 THEN '18-35'
		WHEN DATEDIFF(YEAR, PC.DOB, P.VisitDate) BETWEEN 36 AND 55 THEN '36-55'
		ELSE '56+'
	END AS AgeGroup
FROM PatientVisits AS P INNER JOIN DIM_Patient_Clean AS PC ON P.PatientID = PC.PatientID
)
SELECT AgeGroup, COUNT(*) AS TotalVisits, AVG(BillAmount) as AVGBillAmount
FROM CTE_PatientAge 
GROUP BY AgeGroup
ORDER BY AgeGroup DESC

--Q4 Find total revenue and number of visits for each department:
SELECT D.DepartmentID, D.DepartmentName, COUNT(P.VisitID) AS TotalVisits, SUM(P.BillAmount) as TotalRevenue
FROM PatientVisits as P INNER JOIN DIM_Department_Clean AS D on P.DepartmentID = D.DepartmentID
GROUP BY D.DepartmentID, D.DepartmentName
ORDER BY TotalRevenue DESC

--Q5 Rank departments based on their total revenue within each department category:

SELECT DepartmentCategory, DepartmentName, TotalRevenue,
	RANK() OVER(PARTITION BY DepartmentCategory ORDER BY TotalRevenue DESC) AS RevenueRank
FROM (
	SELECT D.DepartmentCategory, D.DepartmentName, SUM(P.BillAmount) as TotalRevenue
	FROM PatientVisits AS P INNER JOIN DIM_Department_Clean as D on P.DepartmentID=D.DepartmentID
	GROUP BY D.DepartmentCategory, D.DepartmentName
) as t

--Q6 For each department, find the average satisfication score and average wait time:
select D.DepartmentName, AVG(P.SatisfactionScore) as AVGSatisfaction, AVG(P.WaitTimeMinutes) as AVGVisitTime
from PatientVisits AS P INNER JOIN DIM_Department_Clean AS D ON P.DepartmentID=D.DepartmentID
GROUP BY D.DepartmentName
ORDER BY AVGSatisfaction DESC

-- Q7 Compare the total number of hospital visits on weekdays vs weekends:
SELECT DayType, COUNT(*) AS TotalVisits
FROM
( SELECT
	CASE 
		WHEN DATENAME(Weekday, VisitDate) in ('Saturday','Sunday') THEN 'Weekend'
		ELSE 'Weekday'
	END AS DayType
FROM PatientVisits 
) as t
Group By DayType

--Q8 For each month, calculate total visits and a running cumulative total of visits:

WITH CTE_Monthlyvisits as (
	SELECT DATEFROMPARTS(YEAR(VisitDate), MONTH(VisitDate), 1) as Monthstart, COUNT(VisitID) as TotalVisits
	FROM PatientVisits
	GROUP BY YEAR(VisitDate), MONTH(VisitDate)
)
SELECT Monthstart, TotalVisits, 
	SUM(TotalVisits) OVER( ORDER BY MonthStart
	ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS CumulativeVisits

FROM CTE_Monthlyvisits
Order by Monthstart

--Q9 Find the doctors with the highest average satisfaction score (minimum 100 visits):
SELECT P.DoctorID, D.FirstName + ' ' + D.LastName as DoctorName, AVG(P.SatisfactionScore) as AVGSatisfaction,
COUNT(P.VisitID) as TotalVisits
FROM PatientVisits AS P INNER JOIN Dim_Doctor as D on P.DoctorID=D.DoctorID
GROUP BY P.DoctorID, D.FirstName,D.LastName
HAVING COUNT(VisitID) >= 100

--Q10 Identify the most commonly prescried treatment for each diagnosis:

WITH CTE_Treatment as (
SELECT D.DiagnosisName, T.TreatmentName, COUNT(*) AS TreatmentCount, 
RANK() OVER(PARTITION BY D.DiagnosisName Order By COUNT(*) DESC) AS rn
FROM PatientVisits AS P INNER JOIN Dim_Treatment as T on P.TreatmentID=T.TreatmentID INNER JOIN Dim_Diagnosis as D
ON D.DiagnosisID=P.DiagnosisID
GROUP BY D.DiagnosisName, T.TreatmentName
)
SELECT DiagnosisName, TreatmentName, TreatmentCount
FROM CTE_Treatment
WHERE rn = 1



 