CREATE TABLE IF NOT EXISTS dds.s_location_aliases (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    alias_nm        text NOT NULL,
    location_id     text NOT NULL,

    CONSTRAINT s_location_aliases__alias_nm_pk PRIMARY KEY (alias_nm),

    CONSTRAINT s_location_aliases__location_id_fk
        FOREIGN KEY (location_id) REFERENCES dds.h_locations(location_id)
);

CREATE INDEX s_location_aliases__location_id_idx ON dds.s_location_aliases (location_id);