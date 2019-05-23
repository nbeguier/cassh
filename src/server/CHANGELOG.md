CHANGELOG
=========

CASSH Server
-----

1.7.0
-----

2019/05/22

### New Features
  - Add multi-instance (cluster mode), especially to update the KRL
    - ClusterStatus (/cluster/status) : Get the status of the clusted (without auth)
    - ClusterUpdateKRL (/cluster/updatekrl) : Update the current KRL to revoke a user, or get the last version of the KRL inside the cluster
  - Add a User-Agent `HTTP_USER_AGENT : CASSH-SERVER v1.7.0`
  - Add the client version in header `HTTP_SERVER_VERSION : 1.7.0`
  - Add cluster and clustersecret parameters in configuration

### Changes
  - The KRL update is in a separated function
  - HTTP code are not always 200

### Bug Fixes
  - Disable Debug mode (#shame)

### Other
  - More tests, with random ssh-key and username
  - More documentation