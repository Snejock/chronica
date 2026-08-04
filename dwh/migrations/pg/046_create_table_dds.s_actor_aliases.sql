CREATE TABLE IF NOT EXISTS dds.s_actor_aliases (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    alias_nm        text NOT NULL,
    actor_id        text NOT NULL,

    CONSTRAINT s_actor_aliases__alias_nm_pk PRIMARY KEY (alias_nm),

    CONSTRAINT s_actor_aliases__actor_id_fk
        FOREIGN KEY (actor_id) REFERENCES dds.h_actors(actor_id)
);

CREATE INDEX s_actor_aliases__actor_id_idx ON dds.s_actor_aliases (actor_id);
