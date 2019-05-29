-------------------------
-- CASSH Revocation table
-------------------------
CREATE TABLE REVOCATION
(
    SSH_KEY            TEXT  PRIMARY KEY  NOT NULL,
    REVOCATION_DATE    INT                NOT NULL,
    NAME               TEXT
)
