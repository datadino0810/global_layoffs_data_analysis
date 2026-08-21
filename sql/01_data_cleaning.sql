/* ============================================================
   PROJECT: Global Layoffs Data Cleaning

   In this project, I cleaned a global layoffs dataset in MySQL.

   Main steps:
   1. Preserve the original raw data
   2. Remove duplicate records
   3. Standardize inconsistent values
   4. Handle blank and missing values
   5. Convert columns into appropriate data types
   6. Remove records that cannot support the analysis
   7. Validate the final cleaned dataset
   ============================================================ */
   
   -- Select the database containing the imported dataset.
USE world_job_layoffs;

/* ============================================================
   1. UNDERSTAND AND VALIDATE THE RAW DATA
   ============================================================ */

-- Check the imported data before making any changes.
SELECT *
FROM layoffs_raw;

-- Confirm that the complete CSV was imported.
SELECT COUNT(*) AS raw_row_count
FROM layoffs_raw;

-- Expected result: 2361

-- Review the structure and current column data types.
DESCRIBE layoffs_raw;

-- Check the overall date range stored in the raw file.
SELECT
    MIN(STR_TO_DATE(`date`, '%m/%d/%Y')) AS earliest_date,
    MAX(STR_TO_DATE(`date`, '%m/%d/%Y')) AS latest_date
FROM layoffs_raw;

/* ============================================================
   2. CREATE A WORKING COPY
   ============================================================ */

-- Best practice is to keep layoffs_raw unchanged so I always have the original copy
-- This makes the imported data available for comparison or recovery.

DROP TABLE IF EXISTS layoffs_staging;

CREATE TABLE layoffs_staging
LIKE layoffs_raw;

-- Copy every raw record into the staging table.
INSERT INTO layoffs_staging
SELECT *
FROM layoffs_raw;

-- Making sure the staging copy has the same number of records as the original file
SELECT
    (SELECT COUNT(*) FROM layoffs_raw) AS raw_rows,
    (SELECT COUNT(*) FROM layoffs_staging) AS staging_rows;

-- Both values should be 2361. 

/* ============================================================
   3. IDENTIFY EXACT DUPLICATES
   ============================================================ */

-- NOTE: A record should only be considered a duplicate when all relevant columns contain the same values.

-- ROW_NUMBER assigns a number to every record within each identical group. The first record receives 1, 
-- while additional copies receive 2, 3, and so on.

SELECT *,
       ROW_NUMBER() OVER (
           PARTITION BY
               company,
               location,
               industry,
               total_laid_off,
               percentage_laid_off,
               `date`,
               stage,
               country,
               funds_raised_millions
       ) AS row_num
FROM layoffs_staging;

-- Display only the extra duplicate records.
WITH duplicate_check AS
(
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY
                   company,
                   location,
                   industry,
                   total_laid_off,
                   percentage_laid_off,
                   `date`,
                   stage,
                   country,
                   funds_raised_millions
           ) AS row_num
    FROM layoffs_staging
)
SELECT *
FROM duplicate_check
WHERE row_num > 1;

-- Result: 5 extra duplicate records.

/* ============================================================
   4. CREATE A SECOND STAGING TABLE
   ============================================================ */

-- The second staging table includes row_num so that duplicate records can be removed safely.

-- Numeric columns are also assigned proper numeric data types.
-- The date remains TEXT temporarily because it still needs to
-- be converted from month/day/year format.

DROP TABLE IF EXISTS layoffs_staging2;

CREATE TABLE layoffs_staging2
(
    company TEXT,
    location TEXT,
    industry TEXT,
    total_laid_off INT,
    percentage_laid_off DECIMAL(10,4),
    `date` TEXT,
    stage TEXT,
    country TEXT,
    funds_raised_millions INT,
    row_num INT
);

-- Insert the records and calculate their duplicate row numbers.
INSERT INTO layoffs_staging2
SELECT
    company,
    location,
    industry,
    total_laid_off,
    percentage_laid_off,
    `date`,
    stage,
    country,
    funds_raised_millions,

    ROW_NUMBER() OVER (
        PARTITION BY
            company,
            location,
            industry,
            total_laid_off,
            percentage_laid_off,
            `date`,
            stage,
            country,
            funds_raised_millions
    ) AS row_num

FROM layoffs_staging;

/* ============================================================
   5. REMOVE DUPLICATES
   ============================================================ */

-- Always inspect records before deleting them.

SELECT *
FROM layoffs_staging2
WHERE row_num > 1;

-- Safe Updates can block this because row_num is not a key.
-- This changes Safe Updates only for the current SQL session.
SET SQL_SAFE_UPDATES = 0;

-- Keep the first occurrence and remove only additional copies.
DELETE FROM layoffs_staging2
WHERE row_num > 1;

-- Confirm the table now contains 2356 records.
SELECT COUNT(*) AS rows_after_duplicate_removal
FROM layoffs_staging2;

-- Expected result: 2356

-- Confirm that no row_num values above 1 remain.
SELECT COUNT(*) AS remaining_duplicate_records
FROM layoffs_staging2
WHERE row_num > 1;

-- Expected result: 0

/* ============================================================
   6. STANDARDIZE COMPANY NAMES
   ============================================================ */

-- Check whether company names contain unnecessary spaces.
SELECT
    company,
    TRIM(company) AS trimmed_company
FROM layoffs_staging2
WHERE company <> TRIM(company);

-- Remove leading and trailing spaces.
UPDATE layoffs_staging2
SET company = TRIM(company);

-- Confirm that the spaces were removed.
SELECT
    company,
    TRIM(company) AS trimmed_company
FROM layoffs_staging2
WHERE company <> TRIM(company);

-- Expected result: no records.

/* ============================================================
   7. STANDARDIZE INDUSTRY VALUES
   ============================================================ */

-- Review the existing industry categories before changing them.
SELECT DISTINCT industry
FROM layoffs_staging2
ORDER BY 1;

-- Upon observation, I noticed that some Crypto records use slightly different labels.
SELECT DISTINCT industry
FROM layoffs_staging2
WHERE industry LIKE 'Crypto%';

-- Standardize all Crypto variations into one category.
UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- Convert blank strings into proper SQL NULL values.
-- NULL represents missing information, while 'NULL' would only be the literal word NULL stored as text.

UPDATE layoffs_staging2
SET industry = NULL
WHERE TRIM(industry) = '';

-- Review the remaining missing industries.
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL;

/* ============================================================
   8. POPULATE MISSING INDUSTRIES
   ============================================================ */

-- A company may appear multiple times in the dataset.
-- If one record is missing its industry but another record for the same company has it,
-- I can use the known value.

SELECT
    t1.company,
    t1.industry AS missing_industry,
    t2.industry AS available_industry
FROM layoffs_staging2 AS t1
JOIN layoffs_staging2 AS t2
    ON t1.company = t2.company
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;

-- Fill missing industries using another record from the same company.
UPDATE layoffs_staging2 AS t1
JOIN layoffs_staging2 AS t2
    ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;
  
  -- Check whether any industries are still missing.
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL;

/* ============================================================
   9. STANDARDIZE COUNTRY VALUES
   ============================================================ */

-- Review the country categories.
SELECT DISTINCT country
FROM layoffs_staging2
ORDER BY 1;

-- Upon observation, i noticed that some United States records have a period at the end.
SELECT DISTINCT country
FROM layoffs_staging2
WHERE country LIKE 'United States%';

-- Remove the trailing period to create one consistent value.
UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

-- Confirm that only one United States label remains.
SELECT DISTINCT country
FROM layoffs_staging2
WHERE country LIKE 'United States%';

/* ============================================================
   10. CONVERT THE DATE COLUMN
   ============================================================ */

-- The dates were imported as text in month/day/year format.
-- I first preview the conversion before updating the table.

SELECT
    `date` AS original_date,
    STR_TO_DATE(`date`, '%m/%d/%Y') AS converted_date
FROM layoffs_staging2;

-- Check whether any non-null dates cannot be converted.
SELECT *
FROM layoffs_staging2
WHERE `date` IS NOT NULL
  AND STR_TO_DATE(`date`, '%m/%d/%Y') IS NULL;

-- Expected result: no records.

-- Convert the text values into MySQL date values.
UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y')
WHERE `date` IS NOT NULL;

-- Change the column itself from TEXT to DATE.
ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

-- Confirm the updated data type.
DESCRIBE layoffs_staging2;

/* ============================================================
   11. REVIEW MISSING LAYOFF INFORMATION
   ============================================================ */

-- Some records have neither a layoff count nor a layoff percentage.
-- These records cannot contribute meaningful information to the
-- layoffs analysis, so I inspect them before removing them.

SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;

-- Count how many records meet this condition.
SELECT COUNT(*) AS records_without_layoff_information
FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;

-- Result: 361

-- Remove records where both important layoff measurements are missing.
DELETE FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;
  
  /* ============================================================
   12. REMOVE THE TEMPORARY HELPER COLUMN
   ============================================================ */

-- row_num was only required for duplicate detection.
-- It is no longer needed in the final dataset.

ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

/* ============================================================
   13. FINAL DATA-QUALITY CHECKS
   ============================================================ */

-- Confirm the final number of cleaned records.
SELECT COUNT(*) AS final_cleaned_row_count
FROM layoffs_staging2;

-- Expected result: 1995

-- Check that no exact duplicates remain.
SELECT
    company,
    location,
    industry,
    total_laid_off,
    percentage_laid_off,
    `date`,
    stage,
    country,
    funds_raised_millions,
    COUNT(*) AS duplicate_count
FROM layoffs_staging2
GROUP BY
    company,
    location,
    industry,
    total_laid_off,
    percentage_laid_off,
    `date`,
    stage,
    country,
    funds_raised_millions
HAVING COUNT(*) > 1;

-- Expected result: no records.

-- Confirm that company names no longer have outside spaces.
SELECT *
FROM layoffs_staging2
WHERE company <> TRIM(company);

-- Expected result: no records.

-- Confirm that Crypto values were standardized.
SELECT DISTINCT industry
FROM layoffs_staging2
WHERE industry LIKE 'Crypto%';

-- Expected result: Crypto

-- Confirm that country values were standardized.
SELECT DISTINCT country
FROM layoffs_staging2
WHERE country LIKE 'United States%';

-- Expected result: United States

-- Review the final date range.
SELECT
    MIN(`date`) AS earliest_date,
    MAX(`date`) AS latest_date
FROM layoffs_staging2;

-- Review the final cleaned data.
SELECT *
FROM layoffs_staging2
ORDER BY `date` DESC;

/* ============================================================
   14. FINAL CLEANING SUMMARY
   ============================================================ */

-- This summary makes the transformation easy to explain.
SELECT
    (SELECT COUNT(*) FROM layoffs_raw) AS original_rows,
    5 AS duplicate_records_removed,
    361 AS unusable_records_removed,
    (SELECT COUNT(*) FROM layoffs_staging2) AS final_rows;

/* ============================================================
   15. RESTORE SAFE UPDATES
   ============================================================ */

-- Turn Safe Updates back on for the current session.
SET SQL_SAFE_UPDATES = 1;
























