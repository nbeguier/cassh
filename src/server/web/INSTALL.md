# INSTALL - CASSH Server WebUI

## Docker

```bash
docker build . -t nbeguier/cassh-web

# Run an example web server
docker run -it --rm \
    -v $PWD/settings.txt.sample:/opt/cassh/settings.txt \
    -v /etc/ssl/certs/ssl-cert-snakeoil.pem:/etc/ssl/certs/ssl-cert-snakeoil.pem:ro \
    -v /etc/ssl/private/ssl-cert-snakeoil.key:/etc/ssl/private/ssl-cert-snakeoil.key:ro \
    -p 8443:8443 \
    nbeguier/cassh-web

# Go to https://0.0.0.0:8443/

```

## From scratch
```bash
pip install -U pip
pip install -r requirements.txt
cp settings.txt.sample settings.txt
# Edit this file
python cassh_web.py

# Go to https://0.0.0.0:8443/
```
