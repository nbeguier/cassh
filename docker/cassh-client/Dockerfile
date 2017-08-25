FROM alpine:latest

RUN apk update; \
    apk add git py2-pip; \
    git clone https://github.com/nbeguier/cassh.git; \
    pip install -r cassh/requirements.txt

ENTRYPOINT ["/cassh/cassh"]

CMD ["--help"] 

