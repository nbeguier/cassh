FROM debian:latest

RUN apt-get update; \
    apt-get install -y git python-psycopg2 python-webpy python-ldap python-configparser python-requests python-openssl; \ 
    git clone https://github.com/Petlefeu/cassh.git /opt/cassh; \
    cd /opt/cassh; \
    mkdir test-keys; \
    ssh-keygen -t rsa -b 4096 -o -a 100 -N "" -f test-keys/id_rsa_ca; \
    ssh-keygen -k -f test-keys/revoked-keys; \
    sed -i 's/host = localhost/host = 172.17.0.1/g' /opt/cassh/demo/cassh_dummy.conf; \
    sed -i "s#__CASSH_PATH__#${PWD}#g" demo/cassh_dummy.conf

ENTRYPOINT ["/opt/cassh/server/server.py"]

CMD ["--config", "/opt/cassh/demo/cassh_dummy.conf"] 

