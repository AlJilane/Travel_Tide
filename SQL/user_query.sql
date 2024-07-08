-- Filter session data to include only sessions starting after '2023-01-04' (Elena's cohort)

WITH FilteredSessions AS (
  SELECT 
    user_id, 
    session_id, 
    session_start, 
    session_end, 
    page_clicks,
    flight_discount, 
    hotel_discount, 
    flight_booked, 
    hotel_booked, 
    cancellation,
    trip_id
  FROM sessions
  WHERE session_start >= '2023-01-04'
),

-- Aggregate session data to compute various session-related metrics.

AggregatedSessions AS (
  SELECT 
    user_id,
    COUNT(DISTINCT session_id) AS num_sessions,
    SUM(page_clicks) AS total_page_clicks,
    COUNT(CASE WHEN flight_discount = TRUE THEN 1 END) AS total_flight_discount,
    COUNT(CASE WHEN hotel_discount = TRUE THEN 1 END) AS total_hotel_discount,
    COUNT(CASE WHEN flight_booked = TRUE THEN 1 END) AS total_flights_booked,
    COUNT(CASE WHEN hotel_booked = TRUE THEN 1 END) AS total_hotels_booked,
    COUNT(CASE WHEN cancellation = TRUE THEN 1 END) AS total_cancellations
  FROM FilteredSessions
  GROUP BY user_id
  HAVING COUNT(DISTINCT session_id) > 7
),

-- Fetch flight information for each user.

FlightsData AS (
  SELECT 
    fs.user_id, 
    SUM(f.checked_bags) AS total_checked_bags,
    MAX(f.destination_airport_lat) AS destination_airport_lat,
    MAX(f.destination_airport_lon) AS destination_airport_lon,
    MAX(f.departure_time) AS departure_time, 
    MAX(f.return_time) AS return_time
  FROM FilteredSessions fs
  JOIN flights f ON fs.trip_id = f.trip_id
  GROUP BY fs.user_id
)

-- Merge user, session, flight, seat, and room data to create a comprehensive dataset.

SELECT 
  u.user_id, 
  u.birthdate, 
  u.gender, 
  u.married, 
  u.has_children, 
  u.home_country, 
  u.home_city,
  u.home_airport, 
  u.sign_up_date,
  a.num_sessions, 
  a.total_page_clicks, 
  a.total_flight_discount, 
  a.total_hotel_discount,
  a.total_flights_booked, 
  a.total_hotels_booked, 
  a.total_cancellations,
  fd.total_checked_bags,
  fd.destination_airport_lat, 
  fd.destination_airport_lon,
  u.home_airport_lat, 
  u.home_airport_lon,
  fl.seats, 
  h.rooms,
  fd.departure_time, 
  fd.return_time,
  fs.session_start, 
  fs.session_end, 
  fs.trip_id
FROM users u
INNER JOIN AggregatedSessions a ON u.user_id = a.user_id
LEFT JOIN FlightsData fd ON u.user_id = fd.user_id
LEFT JOIN (
  
 -- Retrieve the most recent session start, end, and trip_id for each user.
  
  SELECT 
    fs.user_id, 
    MAX(fs.session_start) AS session_start, 
    MAX(fs.session_end) AS session_end, 
    MAX(fs.trip_id) AS trip_id
  FROM FilteredSessions fs
  GROUP BY fs.user_id
) fs ON u.user_id = fs.user_id
LEFT JOIN (
  
 -- Calculate the total number of seats booked by each user.
  
  SELECT 
    fs.user_id, 
    SUM(f.seats) AS seats
  FROM FilteredSessions fs
  JOIN flights f ON fs.trip_id = f.trip_id
  GROUP BY fs.user_id
) fl ON u.user_id = fl.user_id
LEFT JOIN (
  
-- Calculate the total number of hotel rooms booked by each user.
  
  SELECT 
    fs.user_id, 
    SUM(h.rooms) AS rooms
  FROM FilteredSessions fs
  JOIN hotels h ON fs.trip_id = h.trip_id
  GROUP BY fs.user_id
) h ON u.user_id = h.user_id;