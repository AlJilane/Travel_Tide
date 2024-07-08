-- First Week Query
-- The session-level dataset has 49,211 rows as per Elena's cohort definition.

WITH sessions_2023 AS (
  SELECT *
  FROM sessions s
  WHERE s.session_start > '2023-01-04'
),

filtered_users AS (
  SELECT user_id, COUNT(*) as session_count
  FROM sessions_2023 s
  GROUP BY user_id
  HAVING COUNT(*) > 7
),

results AS (
  SELECT 
    s.session_id, 
    s.user_id, 
    s.trip_id, 
    s.session_start, 
    s.session_end,
    s.flight_discount, 
    s.hotel_discount, 
    s.flight_discount_amount, 
    s.hotel_discount_amount, 
    s.flight_booked, 
    s.hotel_booked, 
    s.page_clicks,
    u.birthdate, 
    u.gender, 
    u.married, 
    u.has_children, 
    u.home_country, 
    u.home_city,
    f.origin_airport, 
    f.destination, 
    f.destination_airport, 
    f.seats, 
    f.return_flight_booked,
    h.hotel_name, 
    CASE WHEN h.nights < 0 THEN 1 ELSE h.nights END AS nights, 
    h.rooms
  FROM sessions_2023 s
  LEFT JOIN users u ON s.user_id = u.user_id
  LEFT JOIN flights f ON s.trip_id = f.trip_id
  LEFT JOIN hotels h ON s.trip_id = h.trip_id
  WHERE s.user_id IN (SELECT user_id FROM filtered_users)
)

SELECT *
FROM results