--------------------
-- CASSH Users table
--------------------
CREATE TABLE USERS
(
    NAME           TEXT  PRIMARY KEY  NOT NULL,
    REALNAME       TEXT               NOT NULL,
    STATE          INT                NOT NULL,
    EXPIRATION     INT                NOT NULL,
    SSH_KEY_HASH   TEXT,
    SSH_KEY        TEXT,
    EXPIRY         TEXT,
    PRINCIPALS     TEXT
)