CREATE TABLE IF NOT EXISTS dds.s_location_details (
    _loaded_dttm     timestamp(0) with time zone DEFAULT now(),
    location_id      text NOT NULL,
    language_code    text NOT NULL,
    canonical_nm     text,
    description_txt  text,
    source_link      text,

    CONSTRAINT s_location_details__location_id_language_code_pk
        PRIMARY KEY (location_id, language_code),

    CONSTRAINT s_location_details__location_id_fk
        FOREIGN KEY (location_id) REFERENCES dds.h_locations(location_id)
);