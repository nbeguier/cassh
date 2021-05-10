CHANGELOG
=========

CASSH Web Client
-----

1.3.0
-----

2021/05/10

### New Features
  - `LISTEN` parameter in configuration for the WEB UI (@fedegiova)

1.2.0
-----

2020/05/05

### New Features
  - Allow env variables to be set instead (or in complement) of the `settings.txt` configuration file.

### Changes
  - VERSION is not necessary anymore in configuration file, hard-coded.

1.1.1
-----

2020/01/24

### Fix
  - Untrack settings.txt
  - Remove unused werkzeug


1.1.0
-----

2019/07/29

### New Features
  - Upgrade python libraries


1.0.1
-----

2019/05/22


### New Features

  - Add a User-Agent `HTTP_USER_AGENT : CASSH-WEB-CLIENT v1.0.1`
  - Add the client version in header `HTTP_CLIENT_VERSION : 1.0.1`
  - Add DEBUG, PORT and VERSION variables in settings.txt

### Bug Fixes

  - fix encoding/decoding functions
  - Disable debug by default