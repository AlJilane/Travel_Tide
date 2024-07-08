-- Calculate various perks-related metrics for each user and create a comprehensive dataset.

WITH cohort_flight AS (
  
    -- Calculate flight-related metrics for users with more than 7 sessions after 2023-01-04 (Elena's cohort)
  
    SELECT 
        s.user_id,
        SUM(f.checked_bags)::FLOAT / COUNT(*) AS average_bags,
        SUM(CASE WHEN s.flight_discount THEN 1 ELSE 0 END) :: FLOAT / COUNT(*) AS discount_flight_proportion,
        AVG(s.flight_discount_amount) AS average_flight_discount,
        SUM(s.flight_discount_amount * f.base_fare_usd) / 
        SUM(haversine_distance(geos.home_airport_lat, geos.home_airport_lon, f.destination_airport_lat, f.destination_airport_lon)) AS ADS
    FROM 
        flights AS f
        INNER JOIN (SELECT DISTINCT home_airport, home_airport_lat, home_airport_lon FROM users) AS geos ON f.origin_airport = geos.home_airport
        INNER JOIN sessions AS s ON f.trip_id = s.trip_id
    WHERE 
        s.session_start > '2023-01-04' 
        AND s.user_id IN (SELECT DISTINCT user_id FROM sessions WHERE session_start > '2023-01-04' AND cancellation = FALSE)
    GROUP BY 
        s.user_id
    HAVING 
        COUNT(*) > 7
),
flight_perk AS (
  
    -- Scale flight-related metrics to create a bargain hunter index (Elena's cohort)
  
    SELECT 
        user_id,
        (average_bags - MIN(average_bags) OVER()) / (MAX(average_bags) OVER() - MIN(average_bags) OVER()) AS average_bags_scaled,
        discount_flight_proportion * average_flight_discount * 
        ((ADS - MIN(ADS) OVER()) / (MAX(ADS) OVER() - MIN(ADS) OVER())) AS bargain_hunter_index
    FROM 
        cohort_flight
),
cohort_hotels AS (
  
    -- Calculate hotel-related metrics for users with more than 7 sessions after 2023-01-04 (Elena's cohort)
  
    SELECT 
        s.user_id,
        SUM(CASE WHEN s.hotel_discount THEN 1 ELSE 0 END) :: FLOAT / COUNT(*) AS discount_hotel_proportion,
        AVG(s.hotel_discount_amount) AS average_hotel_discount,
        CASE WHEN SUM(h.nights) > 0 THEN SUM(h.hotel_per_room_usd * h.rooms * s.hotel_discount_amount) / SUM(h.nights) ELSE NULL END AS ADS_night
    FROM 
        hotels AS h
        INNER JOIN sessions AS s ON h.trip_id = s.trip_id
    WHERE 
        s.session_start > '2023-01-04' 
        AND s.user_id IN (SELECT DISTINCT user_id FROM sessions WHERE session_start > '2023-01-04' AND cancellation = FALSE)
    GROUP BY 
        s.user_id
    HAVING 
        COUNT(*) > 7
),
hotel_perk AS (
  
    -- Scale hotel-related metrics to create a hotel hunter index (Elena's cohort)
  
    SELECT 
        user_id,
        discount_hotel_proportion * average_hotel_discount *
        (ADS_night - MIN(ADS_night) OVER()) / (MAX(ADS_night) OVER() - MIN(ADS_night) OVER()) AS hotel_hunter_index
    FROM 
        cohort_hotels
),
cancellation_perk AS (
  
    -- Calculate cancellation rates and combined booking rates for users (Elena's cohort)
  
    SELECT 
        user_id,
        SUM(CASE WHEN cancellation IS TRUE THEN 1 ELSE 0 END)::FLOAT / SUM(CASE WHEN flight_booked IS TRUE OR hotel_booked IS TRUE THEN 1 ELSE 0 END) AS cancellation_rate,
        SUM(CASE WHEN flight_booked IS TRUE AND hotel_booked IS TRUE THEN 1 ELSE 0 END)::FLOAT / SUM(CASE WHEN flight_booked IS TRUE OR hotel_booked IS TRUE THEN 1 ELSE 0 END) AS combined_booking
    FROM 
        sessions
    WHERE 
        session_start > '2023-01-04'
    GROUP BY 
        user_id
    HAVING 
        COUNT(*) > 7 AND COUNT(trip_id) > 0
),
session_activity AS (
  
    -- Calculate the number of sessions and average session duration for users
  
    SELECT 
        user_id,
        COUNT(session_id) AS session_number,
        AVG(DATE_PART('second', session_end - session_start)) AS average_session_sec
    FROM 
        sessions
    WHERE 
        session_start > '2023-01-04'
    GROUP BY 
        user_id
    HAVING 
        COUNT(*) > 7
)
SELECT 
    COALESCE(fp.user_id, hp.user_id, cp.user_id) AS user_id,
    hp.hotel_hunter_index,
    fp.average_bags_scaled,
    (cp.cancellation_rate - MIN(cp.cancellation_rate) OVER()) / (MAX(cp.cancellation_rate) OVER() - MIN(cp.cancellation_rate) OVER()) AS cancellation_rate_scaled,
    fp.bargain_hunter_index,
    (cp.combined_booking - MIN(cp.combined_booking) OVER()) / (MAX(cp.combined_booking) OVER() - MIN(cp.combined_booking) OVER()) AS combined_booking_scaled,
    (sa.session_number / MAX(sa.session_number) OVER())::FLOAT * (sa.average_session_sec / MAX(sa.average_session_sec) OVER()) AS session_intensity_index
FROM 
    flight_perk AS fp 
    FULL JOIN hotel_perk AS hp ON fp.user_id = hp.user_id
    FULL JOIN cancellation_perk AS cp ON cp.user_id = COALESCE(fp.user_id, hp.user_id)
    FULL JOIN session_activity AS sa ON sa.user_id = COALESCE(fp.user_id, hp.user_id, cp.user_id);
