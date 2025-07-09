IF OBJECT_ID('dbo.DateDimension', 'U') IS NOT NULL
    DROP TABLE dbo.DateDimension;

-- Create DateDimension table
CREATE TABLE dbo.DateDimension (
    [Date] DATE PRIMARY KEY,
    [Day] INT,
    [Month] INT,
    [MonthName] VARCHAR(20),
    [Year] INT,
    [DayOfWeek] INT,
    [WeekdayName] VARCHAR(20),
    [IsWeekend] BIT,
    [Quarter] INT,
    [DayOfYear] INT,
    [WeekOfYear] INT
);
-- Drop procedure if it exists (optional)
IF OBJECT_ID('dbo.PopulateDateDimension', 'P') IS NOT NULL
    DROP PROCEDURE dbo.PopulateDateDimension;
GO

-- Create the stored procedure
CREATE PROCEDURE dbo.PopulateDateDimension
    @inputDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @startDate DATE = DATEFROMPARTS(YEAR(@inputDate), 1, 1);
    DECLARE @endDate DATE = DATEFROMPARTS(YEAR(@inputDate), 12, 31);

    -- Recursive CTE to generate all dates of the year
    WITH DateCTE AS (
        SELECT @startDate AS [Date]
        UNION ALL
        SELECT DATEADD(DAY, 1, [Date])
        FROM DateCTE
        WHERE [Date] < @endDate
    )

    -- Single INSERT statement to populate all columns
    INSERT INTO dbo.DateDimension (
        [Date], 
        [Day], 
        [Month], 
        [MonthName], 
        [Year], 
        [DayOfWeek], 
        [WeekdayName], 
        [IsWeekend],
        [Quarter],
        [DayOfYear],
        [WeekOfYear]
    )
    SELECT
        [Date],
        DAY([Date]) AS [Day],
        MONTH([Date]) AS [Month],
        DATENAME(MONTH, [Date]) AS [MonthName],
        YEAR([Date]) AS [Year],
        DATEPART(WEEKDAY, [Date]) AS [DayOfWeek],
        DATENAME(WEEKDAY, [Date]) AS [WeekdayName],
        CASE WHEN DATENAME(WEEKDAY, [Date]) IN ('Saturday', 'Sunday') THEN 1 ELSE 0 END AS [IsWeekend],
        DATEPART(QUARTER, [Date]) AS [Quarter],
        DATEPART(DAYOFYEAR, [Date]) AS [DayOfYear],
        DATEPART(WEEK, [Date]) AS [WeekOfYear]
    FROM DateCTE
    OPTION (MAXRECURSION 366);
END;
GO
EXEC dbo.PopulateDateDimension @inputDate = '2020-07-14';
