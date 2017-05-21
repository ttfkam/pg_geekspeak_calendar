-- ===========================================================================
-- geekspeak_schedule PostgreSQL extension
-- Miles Elam <miles@geekspeak.org>
--
-- Depends on geekspeak
-- ---------------------------------------------------------------------------

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION geekspeak_schedule" to load this file. \quit

CREATE TABLE recording_schedules (
    "start" timestamp(0) with time zone NOT NULL, -- Start of first instance
    "end" timestamp(0) with time zone NOT NULL, -- End of last instance
    location smallint,
    cancellations date[]
);

ALTER TABLE recording_schedules
    ADD CONSTRAINT sessions_similarity_gist EXCLUDE
        USING gist (tstzrange("start", "end") WITH &&,
                    EXTRACT(dow FROM "start") WITH =,
                    int4range(EXTRACT(epoch from "start"::time),
                              EXTRACT(epoch from "end"::time)) WITH &&);

COMMENT ON TABLE recording_schedules IS
'Seed info for episode recordings. The time difference between the start and
 the end mark duration.';

COMMENT ON COLUMN recording_schedules.start IS
'Start of recording for the first episode of the schedule.';

COMMENT ON COLUMN recording_schedules.end IS
'End of recording for the last episode of the schedule.';

COMMENT ON COLUMN recording_schedules.cancellations IS
'Dates excluded from the schedule range.';

COMMENT ON COLUMN recording_schedules.location IS
'Default location for episode recording.';

CREATE VIEW calendar AS
  WITH schedule AS (
    SELECT (now() + '-1 week' +
             (INTERVAL '1 day' * (EXTRACT(dow FROM rs.start) - EXTRACT(dow FROM now()))) +
             (INTERVAL '1 week' * i))::date AS record_date,
           now() + '-1 week' +
             (INTERVAL '1 day' * (EXTRACT(dow FROM rs.start) - EXTRACT(dow FROM now()))) +
             (rs.start::time - now()::time) +
             (INTERVAL '1 week' * i) AS "start",
           now() + '-1 week' +
             (interval '1 day' * (EXTRACT(dow FROM rs.start) - EXTRACT(dow FROM now()))) +
             (rs.end::time - now()::time) +
             (INTERVAL '1 week' * i) AS "end",
           COALESCE(cancellations, '{}') as cancellations,
           rs.location
    FROM gs.recording_schedules AS rs,
         generate_series(0, 50) AS i
    WHERE rs.end > now()
  ), pending AS (
    SELECT e.id, lower(e.recorded)::date AS record_date, e.title, e.promo, e.description,
           lower(e.recorded) as "start", upper(e.recorded) AS "end",
           e.location, e.modified,
           NULLIF(array_agg(u.display_name), '{NULL}') AS participants
    FROM episodes AS e
    LEFT JOIN participants AS p ON (e.id = p.episode)
    LEFT JOIN people AS u ON (p.person = u.id)
    WHERE upper(e.recorded) > now() + '-2 weeks'
    GROUP BY e.id, e.recorded, e.title, e.promo, e.description
  )
  SELECT p.id,
         COALESCE(p.title, 'No Topic Yet') AS title,
         COALESCE(p.description, p.promo) AS description,
         COALESCE(p.participants, '{}'),
         COALESCE(l2.summary, l.summary) as location,
         COALESCE(l2.geo, l.geo) as geo,
         COALESCE(p.modified,
                  now() + '-2 weeks' +
                  (INTERVAL '1 day' *
                      (EXTRACT(dow FROM schedule.start) - EXTRACT(dow FROM now()))) +
                  (schedule.start::time - now()::time)) as modified,
         schedule.start, schedule.end
  FROM schedule
  LEFT join pending AS p USING (record_date)
  LEFT JOIN locations as l on (l.id = schedule.location)
  LEFT JOIN locations as l2 on (l2.id = p.location)
  WHERE NOT ARRAY[schedule.record_date] <@ schedule.cancellations;

COMMENT ON VIEW calendar IS
'Pending episodes.';
