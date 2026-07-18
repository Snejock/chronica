CREATE TABLE IF NOT EXISTS dds.h_subscribers (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    subscriber_id   integer GENERATED ALWAYS AS IDENTITY CONSTRAINT h_subscribers__subscriber_id_pk PRIMARY KEY
);
