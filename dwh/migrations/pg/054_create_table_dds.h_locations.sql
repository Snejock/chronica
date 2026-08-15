CREATE TABLE IF NOT EXISTS dds.h_locations (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    _source_system  text,
    location_id     text NOT NULL,
    location_type   text NOT NULL,

    CONSTRAINT h_locations__location_id_pk PRIMARY KEY (location_id)
);