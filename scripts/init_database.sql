/*
=============================================================
Create Database and Schemas
=============================================================
Script Purpose:
    This script creates a database named 'DataWarehouse'. It first checks whether the database already
    exists. If it does, the script deletes it and creates a fresh copy. After that, it creates three
    schemas inside the database: 'bronze', 'silver', and 'gold'.

WARNING:
    Running this script will permanently delete the existing 'DataWarehouse' database (if present),
    including all tables and data. Use with caution and confirm you have a backup before executing.
*/

USE master;
GO

-- Drop and recreate the 'DataWarehouse' database
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouse')
BEGIN
    ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouse;
END;
GO

-- Create the 'DataWarehouse' database
CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

-- Create Schemas
CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
GO
