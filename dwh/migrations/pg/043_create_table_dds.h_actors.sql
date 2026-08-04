CREATE TABLE IF NOT EXISTS dds.h_actors (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    _source_system  text,
    actor_id        text NOT NULL,
    actor_type      text NOT NULL,

    CONSTRAINT h_actors__actor_id_pk PRIMARY KEY (actor_id)
);
