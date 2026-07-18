CREATE TABLE IF NOT EXISTS dds.s_subscriber_channels (
    _loaded_dttm      timestamp(0) with time zone DEFAULT now(),
    subscriber_id     integer NOT NULL CONSTRAINT s_subscriber_channels__subscriber_id_fk REFERENCES dds.h_subscribers(subscriber_id),
    channel_nm        text    NOT NULL,
    channel_link      text    NOT NULL,

    CONSTRAINT s_subscriber_channels__subscriber_id_channel_nm_pk
        PRIMARY KEY (subscriber_id, channel_nm)
);
