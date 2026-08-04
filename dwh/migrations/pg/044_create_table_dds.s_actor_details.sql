CREATE TABLE IF NOT EXISTS dds.s_actor_details (
    _loaded_dttm     timestamp(0) with time zone DEFAULT now(),
    actor_id         text NOT NULL,
    language_code    text NOT NULL,
    canonical_nm     text,
    description_txt  text,
    source_link      text,

    CONSTRAINT s_actor_details__actor_id_language_code_pk
        PRIMARY KEY (actor_id, language_code),

    CONSTRAINT s_actor_details__actor_id_fk
        FOREIGN KEY (actor_id) REFERENCES dds.h_actors(actor_id)
);
