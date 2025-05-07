CREATE DATABASE HRManagementSystem;
GO

USE HRManagementSystem;
GO

/* 1. TABLE CREATION */

-- Departments table with clustered index

CREATE TABLE Departments (
    DepartmentID INT IDENTITY(1,1) PRIMARY KEY,
    DepartmentName NVARCHAR(100) NOT NULL,
    Budget DECIMAL(18,2) NOT NULL,
    Location NVARCHAR(100)
);

-- Projects table sample 

CREATE TABLE Projects (
    ProjectID INT IDENTITY(1,1) PRIMARY KEY,
    DepartmentID INT,
    ProjectName NVARCHAR(100),
    Status NVARCHAR(50)
);

-- Non-clustered index on department name
CREATE INDEX IX_Departments_DepartmentName ON Departments(DepartmentName);

-- Employees table with clustered index
CREATE TABLE Employees (
    EmployeeID INT IDENTITY(1,1) PRIMARY KEY,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    Email NVARCHAR(100) UNIQUE,
    HireDate DATE NOT NULL,
    DepartmentID INT REFERENCES Departments(DepartmentID),
    Salary DECIMAL(18,2) NOT NULL,
    IsActive BIT DEFAULT 1
);

-- Composite index for employee searches
CREATE INDEX IX_Employees_NameDepartment ON Employees(LastName, FirstName, DepartmentID);

-- Filtered index for active employees
CREATE INDEX IX_Employees_Active ON Employees(EmployeeID) WHERE IsActive = 1;

-- Payroll table
CREATE TABLE Payroll (
    PayrollID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID INT REFERENCES Employees(EmployeeID),
    PayDate DATE NOT NULL,
    BaseSalary DECIMAL(18,2) NOT NULL,
    Bonus DECIMAL(18,2) DEFAULT 0,
    Deductions DECIMAL(18,2) DEFAULT 0,
    Tax DECIMAL(18,2) NOT NULL
);

-- Index for payroll date searches
CREATE INDEX IX_Payroll_PayDate ON Payroll(PayDate);
CREATE INDEX IX_Payroll_EmployeeID ON Payroll(EmployeeID);

/* DATA INSERTION */

-- Insert sample departments

INSERT INTO Departments (DepartmentName, Budget, Location)
VALUES
    ('Human Resources', 500000.00, 'West Wing'),
    ('IT', 1200000.00, 'Floor 5'),
    ('Finance', 850000.00, 'Floor 3'),
    ('Marketing', 750000.00, 'Floor 2'),
    ('Engineering', 2000000.00, 'Floor 4');


-- Insert sample employees with logical department assignments

INSERT INTO Employees (FirstName, LastName, Email, HireDate, DepartmentID, Salary, IsActive)
VALUES
    ('Sarah', 'Johnson', 'sarah.johnson@company.com', '2018-03-15', 
        (SELECT DepartmentID FROM Departments WHERE DepartmentName = 'Human Resources'), 68000.00, 1),
    ('Michael', 'Chen', 'michael.chen@company.com', '2020-06-01', 
        (SELECT DepartmentID FROM Departments WHERE DepartmentName = 'IT'), 85000.00, 1),
    ('Emily', 'Rodriguez', 'emily.rodriguez@company.com', '2019-11-22', 
        (SELECT DepartmentID FROM Departments WHERE DepartmentName = 'Finance'), 72000.00, 1),
    ('David', 'Kim', 'david.kim@company.com', '2021-02-10', 
        (SELECT DepartmentID FROM Departments WHERE DepartmentName = 'Marketing'), 65000.00, 1),
    ('Olivia', 'Smith', 'olivia.smith@company.com', '2022-08-05', 
        (SELECT DepartmentID FROM Departments WHERE DepartmentName = 'Engineering'), 95000.00, 1);


-- Insert payroll records for EmployeeID 1 (Sarah Johnson - HR)

INSERT INTO Payroll (EmployeeID, PayDate, BaseSalary, Bonus, Deductions, Tax)
VALUES
    (1, '2023-01-15', 68000.00, 3400.00, 1200.00, 13600.00),
    (1, '2023-02-15', 68000.00, 2500.00, 1200.00, 13600.00),
    (1, '2023-03-15', 68000.00, 4000.00, 1200.00, 13600.00);

-- Insert payroll records for EmployeeID 2 (Michael Chen - IT)

INSERT INTO Payroll (EmployeeID, PayDate, BaseSalary, Bonus, Deductions, Tax)
VALUES
    (2, '2023-01-15', 85000.00, 6000.00, 1800.00, 21250.00),
    (2, '2023-02-15', 85000.00, 4500.00, 1800.00, 21250.00),
    (2, '2023-03-15', 85000.00, 7000.00, 1800.00, 21250.00);

-- Insert payroll records for EmployeeID 3 (Emily Rodriguez - Finance)

INSERT INTO Payroll (EmployeeID, PayDate, BaseSalary, Bonus, Deductions, Tax)
VALUES
    (3, '2023-01-15', 72000.00, 3000.00, 1500.00, 14400.00),
    (3, '2023-02-15', 72000.00, 2200.00, 1500.00, 14400.00),
    (3, '2023-03-15', 72000.00, 3500.00, 1500.00, 14400.00);

-- Insert payroll records with DEFAULT values

INSERT INTO Payroll (EmployeeID, PayDate, BaseSalary, Deductions, Tax)
VALUES
    (4, '2023-01-15', 65000.00, 1100.00, 13000.00),
    (4, '2023-02-15', 65000.00, 1100.00, 13000.00),
    (5, '2023-01-15', 95000.00, 2000.00, 23750.00),
    (5, '2023-02-15', 95000.00, 2000.00, 23750.00);


/* 3. VIEW CREATION   */

-- Active Employee Directory View

CREATE VIEW vw_ActiveEmployees AS
SELECT EmployeeID, FirstName + ' ' + LastName AS FullName , Email, DepartmentName, HireDate, Salary
FROM Employees e
INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID
WHERE e.IsActive = 1;

-- Department Payroll Summary View

CREATE VIEW vw_DepartmentPayrollSummary AS
SELECT d.DepartmentID, d.DepartmentName,
COUNT(e.EmployeeID) AS EmployeeCount,
AVG(e.Salary) AS AverageSalary,
SUM(e.Salary) AS TotalSalaryBudget
FROM Departments d
LEFT JOIN Employees e ON d.DepartmentID = e.DepartmentID AND e.Isactive =1
GROUP BY d.DepartmentID, d.DepartmentName;

/* 4. STORED PROCEDURES */

-- Generate Monthly Payroll Report (Uses CTE)

CREATE PROCEDURE sp_GenerateMonthlyPayrollReport
       @ReportMonth DATE     --Parameters
AS 
BEGIN
     SET NOCOUNT ON;

	 --CTE to calculate Payroll Totals
	 WITH PayrollCTE AS(
	      SELECT d.DepartmentID, d.DepartmentName,
		  COUNT (DISTINCT p.EmployeeID) AS EmployeesPaid,
		  SUM(p.BaseSalary + p.Bonus) AS TotalGross,
		  SUM(p.Deductions + p.Tax) AS TotalDeductions,
		  SUM(p.BaseSalary + p.Bonus - p.Deductions - p.Tax) AS TotalNet
		  FROM Payroll p
		  INNER JOIN Employees e ON p.EmployeeID = e.EmployeeID
		  INNER JOIN Departments d ON e.DepartmentID = e.DepartmentID
		  WHERE 
		       YEAR(p.PayDate) = YEAR(@ReportMonth) AND
			   MONTH(p.PayDate) = MONTH(@ReportMonth)
           GROUP BY  d.DepartmentID, d.DepartmentName
		   ) 
		   SELECT * FROM PayrollCTE
		   ORDER BY DepartmentName;
END;

-- Adjust Salaries with Logical Operations

CREATE PROCEDURE sp_AdjustSalaries
       @DepartmentID INT = NULL,
	   @PercentageINCREASE DECIMAL(5,2),
	   @MaxAdjustment DECIMAL (18,2) = NULL
AS 
BEGIN 
       SET NOCOUNT ON;
	   BEGIN TRY
	         BEGIN TRANSACTION;

      UPDATE Employees
	  SET Salary = 
	  CASE 
	       WHEN @MaxAdjustment IS NOT NULL AND (Salary * @PercentageINCREASE / 100) > @MaxAdjustment
		   THEN Salary + @MaxAdjustment
		   ELSE Salary * (1 + @PercentageINCREASE / 100)
        END
    WHERE
	     IsActive = 1 AND
		 (@DepartmentID IS NULL OR DepartmentID = @DepartmentID);

		    COMMIT TRANSACTION;
       END TRY
	     BEGIN CATCH
	        ROLLBACK TRANSACTION;
			THROW;
      END CATCH;
END;

/* 5. CREATION OF SECURITY ROLES */

-- Create Roles
CREATE ROLE HR_Administrator;
CREATE ROLE Payroll_Manager;
CREATE ROLE Department_Lead;

-- Grant Permissions
GRANT SELECT, INSERT, UPDATE ON Employees TO HR_Administrator;
GRANT EXECUTE ON sp_AdjustSalaries TO HR_Administrator;

GRANT SELECT, INSERT, UPDATE ON Payroll TO Payroll_Manager;
GRANT EXECUTE ON sp_GenerateMonthlyPayrollReport TO Payroll_Manager;

GRANT SELECT ON vw_DepartmentPayrollSummary TO Department_Lead;

/* 6. ADVANCED QUERY WITH CTE AND LOGICAL OPERATIONS */

-- Identify Employees Eligible for Promotion (CTE + CASE)

WITH EmployeeTenure AS(
     SELECT EmployeeID, FirstName+' ' +LastName AS FullName, 
	 DATEDIFF(YEAR, HireDate, GETDATE()) AS YearsOfService, Salary, DepartmentID,
	 CASE
	     WHEN DATEDIFF(YEAR, HireDate, GETDATE()) >= 5 THEN 'Senior'
		 WHEN DATEDIFF(YEAR, HireDate, GETDATE()) >= 2 THEN 'Mid-Level'
		 ELSE 'Junior'
     END AS Seniority
	 FROM Employees
	 WHERE IsActive = 1
)
SELECT
      et.FullName,
	  d.DepartmentName,
	  et.YearsOfService,
	  et.Seniority,
	  CASE
	      WHEN et.Seniority = 'Senior' AND et.Salary < 80000 THEN 'Eligible for Raise'
		  ELSE 'No Action Needed'
      END AS PromotionStatus
FROM EmployeeTenure et
INNER JOIN Departments d ON et.DepartmentID = d.DepartmentID;

/* USAGE EXAMPLES*/

-- Generate a Payroll Report
EXEC sp_GenerateMonthlyPayrollReport @ReportMonth = '2023-11-01';  

-- Give 10% Salary Increase to IT Department
EXEC sp_AdjustSalaries  
    @DepartmentID = 1,  
    @PercentageIncrease = 10.00,  
    @MaxAdjustment = 10000;  


 /* 7. AUDIT TABLE & TRIGGER  */
-- Track changes to employee salaries and department budgets.

-- Audit table for tracking changes
CREATE TABLE AuditLog (
    AuditID INT IDENTITY(1,1) PRIMARY KEY,
    TableName NVARCHAR(128),
    RecordID INT,
    OperationType NVARCHAR(10),
    OldValue NVARCHAR(MAX),
    NewValue NVARCHAR(MAX),
    ModifiedBy NVARCHAR(128) DEFAULT SYSTEM_USER,
    ModifiedDate DATETIME DEFAULT GETDATE()
);

-- Trigger for Employees table changes
CREATE TRIGGER trg_Employees_Audit
ON Employees
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Track salary changes
    INSERT INTO AuditLog (TableName, RecordID, OperationType, OldValue, NewValue)
    SELECT 
        'Employees',
        COALESCE(i.EmployeeID, d.EmployeeID),
        CASE 
            WHEN i.EmployeeID IS NOT NULL AND d.EmployeeID IS NOT NULL THEN 'UPDATE'
            WHEN i.EmployeeID IS NOT NULL THEN 'INSERT'
            ELSE 'DELETE'
        END,
        CONCAT('Salary:', d.Salary, '; Department:', d.DepartmentID),
        CONCAT('Salary:', i.Salary, '; Department:', i.DepartmentID)
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.EmployeeID = d.EmployeeID
    WHERE ISNULL(i.Salary, 0) <> ISNULL(d.Salary, 0)
    OR ISNULL(i.DepartmentID, 0) <> ISNULL(d.DepartmentID, 0);
END;

/* 8. ADVANCED SALARY ADJUSTMENT LOGIC */ 

-- Enhanced salary adjustment procedure with more logical checks

CREATE PROCEDURE sp_EnhancedSalaryAdjustment
    @DepartmentID INT = NULL,
    @PercentageIncrease DECIMAL(5,2),
    @MaxAdjustment DECIMAL(18,2) = NULL,
    @MinSalaryThreshold DECIMAL(18,2) = NULL,
    @MaxSalaryThreshold DECIMAL(18,2) = NULL,
    @TenureYears INT = NULL
AS 
BEGIN 
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE e
        SET e.Salary = 
            CASE 
                WHEN @MaxAdjustment IS NOT NULL AND (e.Salary * @PercentageIncrease / 100) > @MaxAdjustment
                    THEN e.Salary + @MaxAdjustment
                
				WHEN @MinSalaryThreshold IS NOT NULL AND e.Salary < @MinSalaryThreshold
                    THEN e.Salary * 1.15 -- Larger increase for underpaid employees
                
				WHEN @MaxSalaryThreshold IS NOT NULL AND e.Salary > @MaxSalaryThreshold
                    THEN e.Salary * 1.02 -- Smaller increase for highly paid employees
                
				WHEN @TenureYears IS NOT NULL AND DATEDIFF(YEAR, e.HireDate, GETDATE()) >= @TenureYears
                    THEN e.Salary * (1 + (@PercentageIncrease + 2) / 100) -- Bonus for long-term employees
                
				ELSE e.Salary * (1 + @PercentageIncrease / 100)
            END
        FROM Employees e
        WHERE e.IsActive = 1
            AND (@DepartmentID IS NULL OR e.DepartmentID = @DepartmentID)
            AND (@MinSalaryThreshold IS NULL OR e.Salary < @MinSalaryThreshold)
            AND (@MaxSalaryThreshold IS NULL OR e.Salary > @MaxSalaryThreshold)
            AND (@TenureYears IS NULL OR DATEDIFF(YEAR, e.HireDate, GETDATE()) >= @TenureYears);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

/* 9. BUDGET COMPLIANCE CHECK */

-- Procedure to check if salary adjustments stay within department budget
CREATE PROCEDURE sp_CheckBudgetCompliance
       @DepartmentID INT, 
	   @PercentageIncrease DECIMAL(10,2)
AS 
BEGIN 
       SET NOCOUNT ON;
       DECLARE @CurrentTotalSalary DECIMAL(18,2);
	   DECLARE @ProposedTotalSalary DECIMAL(18,2);
	   DECLARE @DepartmentBudget DECIMAL(18,2);

	   SELECT @CurrentTotalSalary = SUM(Salary),
	          @DepartmentBudget = Budget
       FROM Employees e
	   INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID
	   WHERE e.DepartmentID = @DepartmentID AND e.IsActive = 1
	   GROUP BY d.Budget;

	   SET @ProposedTotalSalary = @CurrentTotalSalary * (1 + @PercentageIncrease /100);

	   SELECT
	         @DepartmentID AS DepartmentID,
			 @CurrentTotalSalary AS CurrentTotalSalary,
			 @ProposedTotalSalary AS ProposedTotalSalary,
			 @DepartmentBudget AS DepartmentBudget,
       CASE 
	        WHEN @ProposedTotalSalary > @DepartmentBudget * 0.9 THEN 'Warning: Exceeds 90% of Budget'
			WHEN @ProposedTotalSalary > @DepartmentBudget * 0.8 THEN 'Caution: Exceeds 80% of Budget'
			ELSE 'Within Safe Limits'
	   END AS BudgetStatus,
	   CASE 
	        WHEN @ProposedTotalSalary > @DepartmentBudget THEN 0
			ELSE 1 
       END AS IsWithinBudget;
END;

/* 10. Performance-Based Bonus Calculation */

--Procedure to calculate performance bonuses with tired logic
CREATE PROCEDURE sp_CalculatePerformanceBonus
       @EmployeeID INT,
	   @PerformanceRating INT,  -- Scale of 1-5
	   @BaseBonusPercentage DECIMAL(5,2) = 5.0
AS
BEGIN
      DECLARE @BonusAmount DECIMAL(18,2);
	  DECLARE @CurrentSalary DECIMAL(18,2);
	  DECLARE @TenureYears INT;

	  SELECT @CurrentSalary = Salary,
	         @TenureYears = DATEDIFF(YEAR, HireDate, GETDATE())
	  FROM Employees
	  WHERE EmployeeID = @EmployeeID;

-- Tiered bonus calculation based on performance and tenure
SET @BonusAmount = 
    CASE
	    WHEN @PerformanceRating = 5 THEN @CurrentSalary * (@BaseBonusPercentage + 5.0)/100
		WHEN @PerformanceRating = 4 THEN @CurrentSalary * (@BaseBonusPercentage + 2.5)/100
		WHEN @PerformanceRating = 3 THEN @CurrentSalary * @BaseBonusPercentage /100
		WHEN @PerformanceRating = 2 THEN @CurrentSalary * (@BaseBonusPercentage - 2)/100
		ELSE 0
END;

-- Add Tenure Multiplier
SET @BonusAmount = @BonusAmount *
    CASE
	     WHEN @TenureYears >= 10 THEN 1.2
		 WHEN @TenureYears >= 5 THEN 1.1
		 WHEN @TenureYears >= 2 THEN 1.05
		 ELSE 1.0
END;

-- Cap Bonus at 20% of Salary
IF @BonusAmount > @CurrentSalary * 0.2
   SET @BonusAmount = @CurrentSalary * 0.2;

   SELECT
         @EmployeeID AS EmployeeID,
		 @CurrentSalary AS CurrentSalary,
		 @PerformanceRating AS PerformanceRating,
		 @TenureYears AS TenureYears,
		 @BonusAmount AS CalculatedBonus,

   CASE
       WHEN @BonusAmount = 0 THEN 'No bonus - Poor Performance'
	   WHEN @BonusAmount = @CurrentSalary * 0.2 THEN 'Maximum Bonus Reached'
       ELSE 'Standard Bonus Calculation'
   END AS BonusStatus;
END;

/* 11. HEAD COUNT PLANNING LOGIC */

-- Procedure to determine optimal headcount based on workload and budget
CREATE PROCEDURE sp_CalculateOptimalHeadCount
       @DepartmentID INT
AS
BEGIN
     DECLARE @CurrentHeadCount INT;
	 DECLARE @AvgSalary DECIMAL(18,2);
	 DECLARE @TotalBudget DECIMAL(18,2);
	 DECLARE @WorkloadScore INT;
	 DECLARE @RecommendedHeadCount INT;

SELECT
      @CurrentHeadCount = Count(e.EmployeeID),
	  @AvgSalary = AVG(e.Salary),
	  @TotalBudget = d.Budget,
	  @WorkloadScore =
	       CASE
		       WHEN COUNT(e.EmployeeID) = 0 THEN 100 --If no employees; max workload
			   ELSE (SELECT COUNT(*) FROM Projects WHERE @DepartmentID = @DepartmentID AND Status = 'Active') * 10 / Count(e.EmployeeID)
			   END
			   FROM Employees e
			   INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID
			   WHERE e.DepartmentID = @DepartmentID AND e.IsActive = 1
			   GROUP BY d.Budget;
 
 -- Calculate recommended headcount based on workload and budget
 SET @RecommendedHeadCount = 
      CASE
	       WHEN @WorkloadScore > 150 THEN
		        LEAST(@CurrentHeadCount + 2, FLOOR(@TotalBudget / (@AvgSalary * 1.1)))
           WHEN @WorkloadScore > 120 THEN 
		        LEAST(@CurrentHeadCount + 1, FLOOR(@TotalBudget / (@AvgSalary * 1.1)))
		   WHEN @WorkloadScore < 80 THEN
		        GREATEST(@CurrentHeadCount -1, 1)
           WHEN @WorkloadScore < 50 THEN
		        GREATEST(@CurrentHeadCount -2, 1)
		   ELSE @CurrentHeadCount
	  END;

SELECT
         @DepartmentID AS DepartmentID,
		 @CurrentHeadCount AS CurrentHeadCount,
		 @AvgSalary AS AvgSalary,
		 @TotalBudget AS TotalBudget, 
		 @WorkloadScore AS WorkloadSource,
		 @RecommendedHeadCount AS RecommendedHeadCount,

CASE 
         WHEN @RecommendedHeadCount > @CurrentHeadCount THEN 'Recommend Hiring'
		 WHEN @RecommendedHeadCount < @CurrentHeadCount THEN 'Recommend Reducing Staff'
		 ELSE 'HeadCount appears optimal'
END AS Recommendation;
END;

/* 12. EMPLOYEE RETENTION RISK ANALYSIS */

-- VIEW to identify employees at risk of leaving
CREATE VIEW vw_EmployeeRetentionRisk AS
WITH SalaryAnalysis AS (
    SELECT 
        e.EmployeeID,
        e.Salary,
        e.DepartmentID,
        AVG(e2.Salary) AS DeptAvgSalary,
        PERCENT_RANK() OVER (PARTITION BY e.DepartmentID ORDER BY e.Salary) AS SalaryPercentile
    FROM Employees e
    JOIN Employees e2 ON e.DepartmentID = e2.DepartmentID AND e2.IsActive = 1
    WHERE e.IsActive = 1
    GROUP BY e.EmployeeID, e.Salary, e.DepartmentID
),
TenureAnalysis AS (
    SELECT 
        EmployeeID,
        DATEDIFF(MONTH, HireDate, GETDATE()) AS TenureMonths,
        CASE 
            WHEN DATEDIFF(MONTH, HireDate, GETDATE()) BETWEEN 12 AND 24 THEN 1
            WHEN DATEDIFF(MONTH, HireDate, GETDATE()) BETWEEN 36 AND 48 THEN 1
            ELSE 0
        END AS InCommonTransitionPeriod
    FROM Employees
    WHERE IsActive = 1
)
SELECT 
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName AS EmployeeName,
    d.DepartmentName,
    e.HireDate,
    e.Salary,
    sa.DeptAvgSalary,
    sa.SalaryPercentile,
    ta.TenureMonths,
    ta.InCommonTransitionPeriod,
    CASE 
        WHEN sa.SalaryPercentile < 0.3 AND ta.InCommonTransitionPeriod = 1 THEN 'High Risk'
        WHEN sa.SalaryPercentile < 0.5 AND ta.InCommonTransitionPeriod = 1 THEN 'Medium Risk'
        WHEN sa.SalaryPercentile < 0.3 THEN 'Potential Risk'
        ELSE 'Low Risk'
    END AS RetentionRisk
FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID
JOIN SalaryAnalysis sa ON e.EmployeeID = sa.EmployeeID
JOIN TenureAnalysis ta ON e.EmployeeID = ta.EmployeeID
WHERE e.IsActive = 1;




