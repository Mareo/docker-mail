FROM ubuntu:focal

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      dovecot-common \
      dovecot-gssapi \
      dovecot-ldap \
      opendkim \
      postfix \
      postfix-ldap \
      postsrsd \
      python3 \
      python3-yaml && \
    rm -rf /etc/dovecot

COPY ./postfix /etc/postfix
COPY ./dovecot /etc/dovecot
COPY ./opendkim /etc/opendkim

COPY ./entrypoint.sh /entrypoint.sh
COPY ./envconf.py /envconf.py

ENTRYPOINT ["/entrypoint.sh"]
