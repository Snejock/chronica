CREATE TABLE IF NOT EXISTS dds.s_location_geo (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    location_id     text NOT NULL,
    geo_lat         numeric(9, 6),
    geo_lon         numeric(9, 6),
    continent_code  text,
    country_code    text,
    country_nm      text,
    region_nm       text,
    feature_code    text,

    CONSTRAINT s_location_geo__location_id_pk PRIMARY KEY (location_id),

    CONSTRAINT s_location_geo__location_id_fk
        FOREIGN KEY (location_id) REFERENCES dds.h_locations(location_id)
);