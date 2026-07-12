CREATE TABLE IF NOT EXISTS dds.s_subscriber_details (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    subscriber_id   integer NOT NULL REFERENCES dds.h_subscribers(subscriber_id),
    language_code   text    NOT NULL DEFAULT 'ru',

    CONSTRAINT s_subscriber_details_pkey
        PRIMARY KEY (subscriber_id)
);
