-- =====================================================
-- Olympics Advanced SQL Analysis
-- Dataset: 120 Years of Olympic History
-- Author: Prince Pandey
-- =====================================================



		---20 ADVANCED LEVEL QUESTIONS

--Q1 Find Top 3 Athletes Who Won Most Gold Medals
--	=====================================================

SELECT *
FROM (
        SELECT 
            Name,
            COUNT(*) AS total_gold,
            DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS rnk
        FROM olympics
        WHERE Medal = 'Gold'
        GROUP BY Name
     ) t
WHERE rnk <= 3;


--Q2 Find Country With Maximum Medals in Each Year
--	=====================================================

SELECT *
FROM (
        SELECT 
            Year,
            Team,
            COUNT(*) AS total_medals,
            DENSE_RANK() OVER (
                PARTITION BY Year 
                ORDER BY COUNT(*) DESC
            ) AS rnk
        FROM olympics
        WHERE Medal IS NOT NULL
        GROUP BY Year, Team
     ) t
WHERE rnk = 1
ORDER BY Year;



--Q3 For Each Sport, Find the Athlete With Highest Total Medals
--	=====================================================
SELECT *
FROM (
        SELECT 
            Sport,
            Name,
            COUNT(*) AS total_medals,
            DENSE_RANK() OVER (
                PARTITION BY Sport
                ORDER BY COUNT(*) DESC
            ) AS rnk
        FROM olympics
        WHERE Medal IS NOT NULL
        GROUP BY Sport, Name
     ) t
WHERE rnk = 1
ORDER BY Sport;

--Q 4 Find Countries That Never Won a Gold Medal but Won Silver or Bronze
--	=====================================================

SELECT 
    Team
FROM olympics
GROUP BY Team
HAVING 
    SUM(CASE WHEN Medal = 'Gold' THEN 1 ELSE 0 END) = 0
    AND
    SUM(CASE WHEN Medal IN ('Silver', 'Bronze') THEN 1 ELSE 0 END) > 0;


--Q5 Find the Youngest Gold Medal Winner in Each Sport
--	=====================================================


WITH youngest AS (
    SELECT Sport,
           MIN(Age) AS min_age
    FROM olympics
    WHERE Medal = 'Gold'
      AND Age IS NOT NULL
    GROUP BY Sport
 )

	SELECT o.Sport, o.Name, o.Age
	FROM olympics as o
	JOIN youngest as y
	  ON o.Sport = y.Sport
	 AND o.Age = y.min_age
	WHERE o.Medal = 'Gold';

--Q6  Find the Percentage of Medal Winners Per Country
--	=====================================================

WITH total_athletes AS (
    SELECT Team,
           COUNT(DISTINCT Name) AS total_players
    FROM olympics
    GROUP BY Team
),

medal_winners AS (
    SELECT Team,
           COUNT(DISTINCT Name) AS medal_players
    FROM olympics
    WHERE Medal IN ('Gold','Silver','Bronze')
    GROUP BY Team
)

SELECT t.Team,
       ROUND(
           (COALESCE(m.medal_players,0) * 100.0) / t.total_players,
           2
       ) AS medal_percentage
FROM total_athletes t
LEFT JOIN medal_winners m
ON t.Team = m.Team;


--  Q7 Find Athletes Who Won Medals in More Than One Sport
--	=====================================================

SELECT  Name
		FROM olympics
	WHERE Medal IN ('Gold','Silver','Bronze')
GROUP BY Name
HAVING COUNT(DISTINCT Sport) > 1;

--Q8 Year With Highest Number of Distinct Sports
--	=====================================================

SELECT Year,
       COUNT(DISTINCT Sport) AS total_sports
FROM olympics
GROUP BY Year
ORDER BY 2 DESC


--Q9 Athletes With 3+ Consecutive Olympic Participation
--	=====================================================

WITH participation AS (
    SELECT DISTINCT Name, Year
    FROM olympics
),
lagged AS (
    SELECT Name,
           Year,
           Year - LAG(Year) OVER (PARTITION BY Name ORDER BY Year) AS diff
    FROM participation
),
grouped AS (
    SELECT *,
           SUM(CASE WHEN diff != 4 OR diff IS NULL THEN 1 ELSE 0 END)
           OVER (PARTITION BY Name ORDER BY Year) AS grp
    FROM lagged
)
SELECT Name
FROM grouped
GROUP BY Name, grp
HAVING COUNT(*) >= 3;


--Q 10  Rank Sports Based on Growth in Participation
--	=====================================================


WITH participation AS (
    SELECT Sport,
           Year,
           COUNT(DISTINCT Name) AS players
    FROM olympics
    GROUP BY Sport, Year
),
first_last AS (
    SELECT Sport,
           MIN(Year) AS first_year,
           MAX(Year) AS last_year
    FROM participation
    GROUP BY Sport
),
growth AS (
    SELECT f.Sport,
           p1.players AS first_year_players,
           p2.players AS last_year_players,
           (p2.players - p1.players) AS growth
    FROM first_last f
    JOIN participation p1
      ON f.Sport = p1.Sport AND f.first_year = p1.Year
    JOIN participation p2
      ON f.Sport = p2.Sport AND f.last_year = p2.Year
)
SELECT *,
       RANK() OVER (ORDER BY growth DESC) AS growth_rank
FROM growth;

-- Q 11Find the Athlete Who Won the Most Medals Without Winning Gold 
--	=====================================================


WITH medal_count AS (
    SELECT Name,
           COUNT(*) AS total_medals
    FROM olympics
    WHERE Medal IN ('Silver', 'Bronze')
    GROUP BY Name
),
no_gold AS (
    SELECT Name
    FROM olympics
    GROUP BY Name
    HAVING SUM(CASE WHEN Medal = 'Gold' THEN 1 ELSE 0 END) = 0
),
filtered AS (
    SELECT m.Name,
           m.total_medals
    FROM medal_count m
    JOIN no_gold g
      ON m.Name = g.Name
),
ranked AS (
    SELECT *,
           DENSE_RANK() OVER (ORDER BY total_medals DESC) AS rnk
    FROM filtered
)
SELECT Name, total_medals
FROM ranked
WHERE rnk = 1;


-- Q 12 Top 10 Athlete With Most Total Medals Overall
--	=====================================================

SELECT Name,
		city ,
       COUNT(*) AS total_medals
FROM olympics
WHERE Medal IN ('Gold','Silver','Bronze')
GROUP BY 1,2
ORDER BY total_medals DESC
LIMIT 10;


-- Q 13 Country With Highest Gold Medal Conversion Rate
--	=====================================================

WITH gold_medals AS (
    SELECT City,
           COUNT(*) AS total_gold_medals
    FROM olympics
    WHERE Medal = 'Gold'
    GROUP BY City
),

total_medals AS (
    SELECT City,
           COUNT(*) AS total_medal
    FROM olympics
    WHERE Medal IS NOT NULL
    GROUP BY City
)

SELECT gs.City,
       ROUND(
           (gs.total_gold_medals::numeric /
            ts.total_medal::numeric) * 100,
       2) AS gold_conversion_rate
FROM gold_medals gs
JOIN total_medals ts
  ON gs.City = ts.City
ORDER BY gold_conversion_rate DESC;


--Q 14 Find the Most Successful Country in Each Olympic Season (Summer/Winter)
--	=====================================================


SELECT * FROM (
		SELECT season ,
		       team,
		COUNT(*) AS total_medals,
		DENSE_RANK() OVER(PARTITION BY season ORDER BY COUNT(*) DESC ) AS rnk
		FROM olympics
		WHERE medal IS NOT NULL 
		GROUP BY 1,2
	) t

	WHERE rnk =1;

--Q15 Find Athletes Who Won Medals in Both Summer and Winter Olympics 
--	=====================================================
	
SELECT 
    Name,
    COUNT(DISTINCT Season) AS seasons_played
FROM olympics
WHERE Medal IS NOT NULL
GROUP BY Name
HAVING COUNT(DISTINCT Season) = 2;

--Q16  Find the Most Dominant Country in Each Sport 

SELECT *
FROM (
        SELECT 
            Sport,
            Team,
            SUM(CASE WHEN Medal = 'Gold' THEN 1 ELSE 0 END) AS gold_medals,
            DENSE_RANK() OVER (
                PARTITION BY Sport
                ORDER BY SUM(CASE WHEN Medal = 'Gold' THEN 1 ELSE 0 END) DESC
            ) AS rnk
        FROM olympics
        GROUP BY Sport, Team
     ) t
WHERE rnk = 1;

--Q17 Find Sports Where Only One Country Ever Won Gold 
--	=====================================================

SELECT 
    Sport,
    MIN(Team) AS dominant_country
FROM olympics
WHERE Medal = 'Gold'
GROUP BY 1
HAVING COUNT(DISTINCT Team) = 1;

--Q 18 Find the City That Hosted Olympics Most Times 
--	=====================================================

	SELECT *
	FROM (
 			SELECT 
			 city,
			 COUNT(DISTINCT year) AS hosted,
			 DENSE_RANK() OVER(
			 ORDER BY COUNT(DISTINCT Year)DESC
			 )AS rnk 
			 FROM olympics
			 GROUP BY 1
			 ) t 
		WHERE rnk = 1;


		
select 
		*
		from olympics
limit 10

--Q 19 Find Top 5 Growing Sports Based on Participation Increase 
--	=====================================================

WITH sport_year_participation AS (
    SELECT 
        Sport,
        Year,
        COUNT(DISTINCT Name) AS total_athletes
    FROM olympics
    GROUP BY Sport, Year
),
ranked_years AS (
    SELECT 
        Sport,
        Year,
        total_athletes,
        FIRST_VALUE(total_athletes) OVER (
            PARTITION BY Sport 
            ORDER BY Year
        ) AS first_participation,
        LAST_VALUE(total_athletes) OVER (
            PARTITION BY Sport 
            ORDER BY Year
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS last_participation
    FROM sport_year_participation
)
SELECT DISTINCT
    Sport,
    last_participation - first_participation AS growth
FROM ranked_years
ORDER BY growth DESC
LIMIT 5;



--Q20 Find the  TOP 5 Athlete With Longest Gap Between Two Gold Medals 
--	=====================================================


WITH gold_medals AS (
    SELECT Name, Year
    FROM olympics
    WHERE Medal = 'Gold'
),
gold_gaps AS (
       SELECT 
        Name,
        Year,
        Year - LAG(Year) OVER ( PARTITION BY Name ORDER BY Year ) AS gap_years
        FROM gold_medals
)
SELECT *
FROM (
        SELECT *,
        DENSE_RANK() OVER (ORDER BY gap_years DESC) AS rnk
        FROM gold_gaps
        WHERE gap_years IS NOT NULL
     ) t
WHERE rnk <5
LIMIT 5;



--	=====================================================
-- 				 END OF THE PROJECT
--	=====================================================
