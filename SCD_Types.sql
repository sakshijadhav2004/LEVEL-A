-- Main dimension table for all types
CREATE TABLE dimension_table (
    CustomerID INT PRIMARY KEY,
    CustomerName VARCHAR(100),
    Address VARCHAR(200),
    PrevAddress VARCHAR(200),     -- For SCD 3 & 6
    StartDate DATE,               -- For SCD 2 & 6
    EndDate DATE,                 -- For SCD 2 & 6
    IsCurrent BIT                 -- For SCD 2 & 6
);

-- History table for SCD Type 4
CREATE TABLE dimension_table_history (
    CustomerID INT,
    CustomerName VARCHAR(100),
    Address VARCHAR(200),
    ArchivedOn DATE
);

-- Staging table
CREATE TABLE staging_table (
    CustomerID INT,
    CustomerName VARCHAR(100),
    Address VARCHAR(200)
);

CREATE PROCEDURE scd_type_0_load
AS
BEGIN
    INSERT INTO dimension_table (CustomerID, CustomerName, Address)
    SELECT s.CustomerID, s.CustomerName, s.Address
    FROM staging_table s
    WHERE NOT EXISTS (
        SELECT 1 FROM dimension_table d WHERE d.CustomerID = s.CustomerID
    );
END;

CREATE PROCEDURE scd_type_1_load
AS
BEGIN
    MERGE dimension_table AS target
    USING staging_table AS source
    ON target.CustomerID = source.CustomerID
    WHEN MATCHED THEN
        UPDATE SET
            target.CustomerName = source.CustomerName,
            target.Address = source.Address
    WHEN NOT MATCHED THEN
        INSERT (CustomerID, CustomerName, Address)
        VALUES (source.CustomerID, source.CustomerName, source.Address);
END;

CREATE PROCEDURE scd_type_2_load
AS
BEGIN
    DECLARE @today DATE = GETDATE();

    -- Mark old rows as not current
    UPDATE dimension_table
    SET EndDate = @today, IsCurrent = 0
    FROM dimension_table d
    JOIN staging_table s ON d.CustomerID = s.CustomerID
    WHERE d.IsCurrent = 1 AND (d.Address <> s.Address OR d.CustomerName <> s.CustomerName);

    -- Insert new rows
    INSERT INTO dimension_table (
        CustomerID, CustomerName, Address, StartDate, EndDate, IsCurrent
    )
    SELECT s.CustomerID, s.CustomerName, s.Address, @today, NULL, 1
    FROM staging_table s
    LEFT JOIN dimension_table d ON d.CustomerID = s.CustomerID AND d.IsCurrent = 1
    WHERE d.CustomerID IS NULL
          OR d.Address <> s.Address
          OR d.CustomerName <> s.CustomerName;
END;

CREATE PROCEDURE scd_type_3_load
AS
BEGIN
    MERGE dimension_table AS target
    USING staging_table AS source
    ON target.CustomerID = source.CustomerID
    WHEN MATCHED AND target.Address <> source.Address THEN
        UPDATE SET
            target.PrevAddress = target.Address,
            target.Address = source.Address,
            target.CustomerName = source.CustomerName
    WHEN NOT MATCHED THEN
        INSERT (CustomerID, CustomerName, Address, PrevAddress)
        VALUES (source.CustomerID, source.CustomerName, source.Address, NULL);
END;

CREATE PROCEDURE scd_type_4_load
AS
BEGIN
    DECLARE @now DATE = GETDATE();

    -- Archive current row before change
    INSERT INTO dimension_table_history (CustomerID, CustomerName, Address, ArchivedOn)
    SELECT d.CustomerID, d.CustomerName, d.Address, @now
    FROM dimension_table d
    JOIN staging_table s ON d.CustomerID = s.CustomerID
    WHERE d.Address <> s.Address OR d.CustomerName <> s.CustomerName;

    -- Update or Insert main table
    MERGE dimension_table AS target
    USING staging_table AS source
    ON target.CustomerID = source.CustomerID
    WHEN MATCHED THEN
        UPDATE SET
            target.CustomerName = source.CustomerName,
            target.Address = source.Address
    WHEN NOT MATCHED THEN
        INSERT (CustomerID, CustomerName, Address)
        VALUES (source.CustomerID, source.CustomerName, source.Address);
END;

CREATE PROCEDURE scd_type_6_load
AS
BEGIN
    DECLARE @today DATE = GETDATE();

    -- Expire old rows (SCD2)
    UPDATE dimension_table
    SET EndDate = @today, IsCurrent = 0
    FROM dimension_table d
    JOIN staging_table s ON d.CustomerID = s.CustomerID
    WHERE d.IsCurrent = 1 AND (d.Address <> s.Address OR d.CustomerName <> s.CustomerName);

    -- Insert new row with previous value (SCD3)
    INSERT INTO dimension_table (
        CustomerID, CustomerName, Address, PrevAddress, StartDate, EndDate, IsCurrent
    )
    SELECT
        s.CustomerID,
        s.CustomerName,
        s.Address,
        d.Address,
        @today,
        NULL,
        1
    FROM staging_table s
    JOIN dimension_table d ON d.CustomerID = s.CustomerID AND d.IsCurrent = 1
    WHERE d.Address <> s.Address OR d.CustomerName <> s.CustomerName

    UNION

    SELECT
        s.CustomerID,
        s.CustomerName,
        s.Address,
        NULL,
        @today,
        NULL,
        1
    FROM staging_table s
    WHERE NOT EXISTS (
        SELECT 1 FROM dimension_table d WHERE d.CustomerID = s.CustomerID
    );
END;

-- Load based on need
EXEC scd_type_1_load;

EXEC scd_type_2_load;



