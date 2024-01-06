-- 1) Show the PlaceID along with the corresponding counts of cuisines for the top 5 places serving the highest number of cuisines.

SELECT PlaceID,cuisine_count
FROM (
  SELECT PlaceID, COUNT(*) AS cuisine_count
  FROM chefmozcuisine
  GROUP BY PlaceID
) AS cuisines_per_place
ORDER BY cuisine_count DESC
LIMIT 5;

-- 2) Display the top 10 cuisines having the highest rating.
SELECT
  c.Rcuisine,
  AVG(r.rating) AS average_cuisine_rating
FROM
  chefmozcuisine c
JOIN
  Rating_final r ON c.PlaceID = r.placeID
GROUP BY
  c.Rcuisine
ORDER BY
  average_cuisine_rating DESC
LIMIT 10;

-- 3)  What is/are the most popular cuisines at the highest rated place?
WITH AverageRatings AS (
  SELECT
    r.placeID,
    AVG(r.rating) AS average_rating
  FROM
    rating_final r
  GROUP BY
    r.placeID
),
RankedPlaces AS (
  SELECT
    ar.placeID,
    ar.average_rating,
    RANK() OVER (ORDER BY ar.average_rating DESC) AS Ranking
  FROM
    AverageRatings ar
)
SELECT
  c.Rcuisine
FROM
  chefmozcuisine c
JOIN
  RankedPlaces rp ON c.PlaceID = rp.placeID
WHERE
  rp.Ranking = 1;
  
-- 4) What are the opening hours for the place with the most reviews?
SELECT 
  h.PlaceID, 
  h.hours, 
  h.days,
  review_count
FROM chefmozhours4 h
INNER JOIN (
  SELECT 
    placeID, 
    COUNT(*) AS review_count 
  FROM rating_final 
  GROUP BY placeID 
  ORDER BY COUNT(*) DESC 
  LIMIT 1
) AS most_reviewed ON h.PlaceID = most_reviewed.PlaceID;

-- 5) Which payment methods are most commonly used at the highest-rated places for each cuisine type?

WITH CuisineRatings AS (
  SELECT
    c.Rcuisine,
    c.PlaceID,
    AVG(r.rating) AS avg_rating,
    ROW_NUMBER() OVER (PARTITION BY c.Rcuisine ORDER BY AVG(r.rating) DESC) AS rating_rank
  FROM chefmozcuisine c
  JOIN rating_final r ON c.PlaceID = r.placeID
  GROUP BY c.Rcuisine, c.PlaceID
),
HighestRatedPlaces AS (
  SELECT
    PlaceID
  FROM CuisineRatings
  WHERE rating_rank = 1
)

SELECT
  cr.Rcuisine,
  a.Rpayment,
  COUNT(*) AS payment_count
FROM CuisineRatings cr
JOIN chefmozaccepts a ON cr.PlaceID = a.PlaceID
JOIN HighestRatedPlaces hrp ON cr.PlaceID = hrp.PlaceID
GROUP BY cr.Rcuisine, a.Rpayment
ORDER BY payment_count DESC;


-- 6) What is the average service rating for the top three most popular cuisines, and how many unique users have rated these cuisines?


WITH CuisinePopularity AS (
  SELECT
    c.Rcuisine,
    COUNT(DISTINCT r.userID) AS total_users,
    RANK() OVER (ORDER BY AVG(r.food_rating) DESC) AS popularity_rank
  FROM chefmozcuisine c
  INNER JOIN rating_final r ON c.PlaceID = r.placeID
  GROUP BY c.Rcuisine
),
TopCuisines AS (
  SELECT
    RCuisine
  FROM CuisinePopularity
  WHERE popularity_rank <= 3
)

SELECT
  tc.Rcuisine,
  AVG(r.service_rating) AS avg_service_rating,
  cp.total_users
FROM TopCuisines tc
JOIN chefmozcuisine c ON tc.Rcuisine = c.Rcuisine
JOIN rating_final r ON c.PlaceID = r.placeID
JOIN CuisinePopularity cp ON tc.Rcuisine = cp.Rcuisine
GROUP BY tc.Rcuisine, cp.total_users;

-- 7) What are the average ratings for places that have both parking and at least two different types of payment methods, compared to those that don't meet these criteria?
WITH PlacePaymentCount AS (
  SELECT
    PlaceID,
    COUNT(DISTINCT Rpayment) AS payment_types_count
  FROM chefmozaccepts
  GROUP BY PlaceID
),
PlaceWithParking AS (
  SELECT
    PlaceID
  FROM chefmozparking
),
PlaceCriteria AS (
  SELECT
    p.PlaceID,
    CASE
      WHEN p.payment_types_count >= 2 AND pk.PlaceID IS NOT NULL THEN 'With Parking & Multiple Payments'
      ELSE 'Without Criteria'
    END AS criteria
  FROM PlacePaymentCount p
  LEFT JOIN PlaceWithParking pk ON p.PlaceID = pk.PlaceID
),
AverageRatings AS (
  SELECT
    pc.criteria,
    AVG(r.rating) AS average_rating
  FROM PlaceCriteria pc
  JOIN rating_final r ON pc.PlaceID = r.placeID
  GROUP BY pc.criteria
)

SELECT
  criteria,
  average_rating
FROM AverageRatings;


-- 8) What are the top 3 most popular cuisines based on the average overall rating, and within those cuisines, identify the place that has the highest average food rating, along with its most preferred payment method and whether it has a parking lot?

WITH CuisineRatings AS (
  SELECT
    c.Rcuisine,
    AVG(r.rating) AS avg_cuisine_rating
  FROM chefmozcuisine c
  JOIN rating_final r ON c.PlaceID = r.placeID
  GROUP BY c.Rcuisine
),
TopCuisines AS (
  SELECT
    Rcuisine,
    avg_cuisine_rating,
    RANK() OVER (ORDER BY avg_cuisine_rating DESC) AS cuisine_rank
  FROM CuisineRatings
),
BestFoodPlace AS (
  SELECT
    tc.Rcuisine,
    r.PlaceID,
    AVG(r.food_rating) AS avg_food_rating,
    ROW_NUMBER() OVER (PARTITION BY tc.Rcuisine ORDER BY AVG(r.food_rating) DESC) AS food_rank
  FROM TopCuisines tc
  JOIN rating_final r ON tc.Rcuisine IN (SELECT c2.Rcuisine FROM chefmozcuisine c2 WHERE c2.PlaceID = r.placeID)
  WHERE tc.cuisine_rank <= 3
  GROUP BY tc.Rcuisine, r.PlaceID
),
PaymentAndParking AS (
  SELECT
    bfp.Rcuisine,
    bfp.PlaceID,
    a.Rpayment,
    p.parking_lot
  FROM BestFoodPlace bfp
  JOIN chefmozaccepts a ON bfp.PlaceID = a.PlaceID
  LEFT JOIN chefmozparking p ON bfp.PlaceID = p.PlaceID
  WHERE bfp.food_rank = 1
)

SELECT
  p.Rcuisine,
  p.PlaceID,
  p.Rpayment,
  p.parking_lot
FROM PaymentAndParking p
WHERE p.Rcuisine IN (SELECT Rcuisine FROM TopCuisines WHERE cuisine_rank <= 3)
ORDER BY p.Rcuisine, p.PlaceID;

  

