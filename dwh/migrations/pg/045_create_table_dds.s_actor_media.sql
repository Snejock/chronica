CREATE TABLE IF NOT EXISTS dds.s_actor_media (
    _loaded_dttm        timestamp(0) with time zone DEFAULT now(),
    actor_id            text NOT NULL,
    source_link         text,
    photo_link          text,
    author_nm           text,
    license_nm          text,

    CONSTRAINT s_actor_media__actor_id_pk PRIMARY KEY (actor_id),

    CONSTRAINT s_actor_media__actor_id_fk
        FOREIGN KEY (actor_id) REFERENCES dds.h_actors(actor_id)
);
