CHANGELOG
=========

CASSH Client
-----

1.5.2
-----

2018/08/10

### Bug Fixes

Use quote_plus on client side to allow complex password

1.5.1
-----

2018/08/09

### Bug Fixes

public key upload error in python 3

1.5.0
-----

2018/08/09

### Changes

  - Every GET routes are DEPRECATED.
  - Authentication is in the payload now
  - Update tests


1.4.5
-----

2017/12/07

### Bug Fixes

urlencode import error in python 3

1.4.4
-----

2017/11/29

### Bug Fixes

Clean admin request.


1.4.3
-----

2017/11/28

### Bug Fixes

Fix non-RSA key issue (v1.4.1). Catch an error when signature begin with 'ssh-'.


1.4.2
-----

2017/11/24

### Bug Fixes

Encoding url params. This change the structure of auth_url function.


1.4.1
-----

2017/11/23

### Bug Fixes

Catch an error when signature begin with 'ssh-rsa-cert'.



1.4.0
-----

2017/11/21

### New Features

Admin can force the signature when database is unavailable.

### Changes

- Put version into a global variable.
- Correct usage.


1.3.0
-----

2017/11/20

### Changes

Username is provided when you sign a certificate. This is a patch for CASSH Server v1.3.0.


1.2.0
-----

2017/11/17

### New Features

Admin can set parameters like 'expiry' or 'principals'.


1.1.0
-----

2017/10/05

### New Features

Admin can status every user with : cassh admin all status

### Changes

Add 'print_result' function for cassh client


1.0.1
-----

2017/10/04

### Bug Fixes

Fix config file conflict with version



1.0.0
-----

2017/10/04

### Changes

First stable version
