# Global Layoffs Data Cleaning and Analysis

## Project Overview

This project focuses on cleaning and analyzing a dataset containing global company layoffs between 2020 and 2023.

I completed the project in MySQL, beginning with 2,361 raw records. I created staging tables to preserve the original data, removed exact duplicates, standardized inconsistent values, handled missing information, converted data types, and validated the final result.

After cleaning, the dataset contained 1,995 analysis-ready records.

## Project Goals

The main goals of this project were to:

- Preserve the original dataset before making changes
- Identify and remove exact duplicate records
- Standardize company, industry, and country values
- Handle blank and missing values appropriately
- Convert dates and numeric fields into usable data types
- Remove records that could not support meaningful analysis
- Prepare the dataset for exploratory analysis

## Tools Used

- MySQL
- MySQL Workbench
- SQL
- Git and GitHub

## Dataset

The dataset includes information about:

- Companies
- Company locations
- Industries
- Total employees laid off
- Percentage of employees laid off
- Layoff dates
- Company funding stages
- Countries
- Funds raised

The raw dataset contained 2,361 records.

## Data Cleaning Process

### 1. Preserved the raw data

I kept the imported `layoffs_raw` table unchanged and created staging tables for all cleaning work. This allowed me to compare the cleaned results with the original data and avoid permanently changing the source.

### 2. Removed duplicates

I used `ROW_NUMBER()` with `PARTITION BY` across all dataset columns to identify exact duplicate records. Five duplicate records were removed.

### 3. Standardized text values

I removed unnecessary spaces from company names and standardized inconsistent industry and country values. For example, different Crypto industry labels were combined into one category, and `United States.` was changed to `United States`.

### 4. Handled missing values

Blank industry values were converted into proper SQL `NULL` values. Where possible, missing industries were populated using other records belonging to the same company.

### 5. Converted data types

The date field was converted from text into the MySQL `DATE` type. Layoff counts, percentages, and funding values were also stored using appropriate numeric data types.

### 6. Removed unusable records

I removed 361 records where both `total_laid_off` and `percentage_laid_off` were missing because those records could not contribute meaningful information to the layoffs analysis.

## Cleaning Results

| Cleaning stage | Records |
|---|---:|
| Original imported data | 2,361 |
| Duplicate records removed | 5 |
| Records without layoff information removed | 361 |
| Final cleaned dataset | 1,995 |

## SQL Skills Demonstrated

- Staging tables
- Common Table Expressions
- Window functions
- `ROW_NUMBER()`
- Duplicate detection
- Self joins
- String standardization
- Missing-value handling
- Date conversion
- Data-type modification
- Data-quality validation

## Repository Structure

```text
global-layoffs-sql-analysis/
├── data/
│   ├── raw/
│   │   └── layoffs_raw.csv
│   └── cleaned/
│       └── layoffs_cleaned.csv
├── sql/
│   ├── 01_data_cleaning.sql
│   └── 02_exploratory_analysis.sql
├── images/
└── README.md
```
## Next Step

The cleaned dataset will be used for exploratory SQL analysis to identify layoffs trends across companies, industries, countries, funding stages, and time periods.

## Data Source

Dataset originally published in the Alex The Analyst MySQL YouTube Series repository:

https://github.com/AlexTheAnalyst/MySQL-YouTube-Series

This project was completed for learning and portfolio purposes. The SQL cleaning process, validation, analysis, documentation, and project presentation are included in this repository.
