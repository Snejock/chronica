CREATE TABLE IF NOT EXISTS dds.s_subscriber_channels (
    _loaded_dttm      timestamp(0) with time zone DEFAULT now(),
    subscriber_id     integer NOT NULL REFERENCES dds.h_subscribers(subscriber_id),
    channel_nm        text    NOT NULL,
    channel_addr_txt  text    NOT NULL,

    CONSTRAINT s_subscriber_channels_pkey
        PRIMARY KEY (subscriber_id, channel_nm)
);
