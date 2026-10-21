-- OBJECTIVE 1: ENCOUNTERS OVERVIEW

-- a. How many total encounters occurred each year?

-- b. For each year, what percentage of all encounters belonged to each encounter class
-- (ambulatory, outpatient, wellness, urgent care, emergency, and inpatient)?

-- c. What percentage of encounters were over 24 hours versus under 24 hours?

-- OBJECTIVE 2: COST & COVERAGE INSIGHTS

-- a. How many encounters had zero payer coverage, and what percentage of total encounters does this represent?

-- b. What are the top 10 most frequent procedures performed and the average base cost for each?

-- c. What are the top 10 procedures with the highest average base cost and the number of times they were performed?

-- d. What is the average total claim cost for encounters, broken down by payer?

-- OBJECTIVE 3: PATIENT BEHAVIOR ANALYSIS

-- a. How many unique patients were admitted each quarter over time?

-- b. How many patients were readmitted within 30 days of a previous encounter?

-- c. Which patients had the most readmissions?


-- OBJECTIVE 1: ENCOUNTERS OVERVIEW 
-- a. How many total encounters occurred each year?
SELECT strftime('%Y',START) as year, COUNT(Id) as encounter_count
FROM encounters
GROUP BY strftime('%Y',START)

-- b. For each year, what percentage of all encounters belonged to each encounter class
(ambulatory, outpatient, wellness, urgent care, emergency, and inpatient)?
SELECT strftime('%Y',START) as year, ENCOUNTERCLASS, count(Id) as encounters_per_class,
ROUND(CAST(count(Id) AS FLOAT) / CAST(SUM(COUNT(Id)) OVER(PARTITION by strftime('%Y',START)) AS FLOAT),3) AS encounter_percentage
FROM encounters
GROUP BY year, ENCOUNTERCLASS

-- c. What percentage of encounters were over 24 hours versus under 24 hours?
WITH under_over_24h AS
(
SELECT COUNT(Id) AS count_encounters, 
(SELECT COUNT(Id)
FROM encounters
WHERE(strftime('%s',STOP) - strftime('%s',START)) / 3600 < 24)
AS under_24_hours,
(SELECT COUNT(Id)
FROM encounters
WHERE(strftime('%s',STOP) - strftime('%s',START)) / 3600 >= 24)
AS over_24_hours
FROM encounters
)

SELECT ROUND((CAST(under_24_hours AS FLOAT) / CAST(count_encounters AS FLOAT)),3) as under_24_hours,
ROUND((CAST(over_24_hours AS FLOAT) /CAST(count_encounters AS FLOAT)),3) as over_24_hours
FROM under_over_24h


-- OBJECTIVE 2: COST & COVERAGE INSIGHTS
-- a. How many encounters had zero payer coverage, and what percentage of total encounters does this represent?
SELECT COUNT(CASE WHEN PAYER_COVERAGE = 0 THEN 1 ELSE NULL END) as no_payer_coverage, ROUND((CAST(COUNT(CASE WHEN PAYER_COVERAGE = 0 THEN 1 ELSE NULL END) AS FLOAT) / CAST(COUNT(Id) AS FLOAT)),3) as no_coverage_percentage
FROM encounters

-- b. What are the top 10 most frequent procedures performed and the average base cost for each?
SELECT CODE, DESCRIPTION, ROUND(AVG(BASE_COST),1) as average_base_cost, RANK() OVER(ORDER BY COUNT(ENCOUNTER) DESC) as rank, COUNT(ENCOUNTER) as procedure_count
FROM procedures
GROUP BY CODE
LIMIT 10

-- c. What are the top 10 procedures with the highest average base cost and the number of times they were performed?
SELECT CODE, DESCRIPTION, ROUND(AVG(BASE_COST),1) as average_base_cost, RANK() OVER(ORDER BY ROUND(AVG(BASE_COST),1)  DESC) as rank, COUNT(ENCOUNTER) as procedure_count
FROM procedures
GROUP BY CODE
LIMIT 10


-- d. What is the average total claim cost for encounters, broken down by payer?
SELECT payers.NAME, ROUND(AVG(TOTAL_CLAIM_COST),1) as average_total_claim 
FROM payers
LEFT JOIN encounters
ON payers.Id = encounters.PAYER
GROUP BY payers.NAME


-- OBJECTIVE 3: PATIENT BEHAVIOR ANALYSIS 
-- a. How many unique patients were admitted each quarter over time?
SELECT strftime('%Y',START) as year, 
CASE 
WHEN strftime('%m',START) IN ('01','02','03') THEN 'Q1' 
WHEN strftime('%m',START) IN ('04','05','06') THEN 'Q2'
WHEN strftime('%m',START) IN ('07','08','09') THEN 'Q3'
WHEN strftime('%m',START) IN ('10','11','12') THEN 'Q4'
END AS quarter, 
COUNT(DISTINCT((PATIENT))) as quartely_unique_patients
FROM encounters
GROUP BY year, quarter

-- b. How many patients were readmitted within 30 days of a previous encounter?
WITH read AS
(
SELECT PATIENT, START, STOP AS initial_visit_end_date, LEAD(START,1) OVER(PARTITION BY PATIENT) as read_visit_date
FROM encounters
)

SELECT COUNT(DISTINCT PATIENT) as read_within_30
FROM read
WHERE CAST(julianday(read_visit_date) AS INT) - CAST(julianday(initial_visit_end_date)AS INT) <30

-- c. Which patients had the most readmissions?
WITH read AS
(
SELECT PATIENT, ORGANIZATION, START, STOP AS initial_visit_end_date, LEAD(START,1) OVER(PARTITION BY PATIENT) as read_visit_date
FROM encounters
)

SELECT patients.Id, PREFIX, FIRST, LAST, LAT, LON, ORGANIZATION, COUNT(read_visit_date) as read_count 
FROM read
LEFT JOIN patients
ON read.PATIENT = patients.Id
WHERE CAST(julianday(read_visit_date) AS INT) - CAST(julianday(initial_visit_end_date)AS INT) <30
GROUP BY PATIENT
ORDER BY read_count DESC















