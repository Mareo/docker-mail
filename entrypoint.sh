#!/bin/sh

toupper() {
    printf '%s' "$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
}

exec_dovecot() {
    for f in /etc/dovecot/args/*.yaml; do
        name="$(basename "$f" .yaml)"
        /envconf.py "$f" "DOVECOT_$(toupper "$name")" = > \
          "/etc/dovecot/args/${name}.conf"
    done

    for feature in ${DOVECOT_FEATURES:-}; do
        if [ -f "/etc/dovecot/features/${feature}.yaml" ]; then
            /envconf.py "/etc/dovecot/features/${feature}.yaml" \
              "DOVECOT_$(toupper "$feature")" = >> \
              "/etc/dovecot/features/${feature}.conf"
        fi
        echo "!include features/${feature}.conf" >> /etc/dovecot/local.conf
    done

    exec dovecot -F -c /etc/dovecot/dovecot.conf
}

exec_opendkim() {
    if [ -n "$OPENDKIM_KEYFILE" ]; then
        cp "$OPENDKIM_KEYFILE" /etc/opendkim/key.pem
        chmod 0440 /etc/opendkim/key.pem
        export OPENDKIM_KEYFILE="/etc/opendkim/key.pem"
    fi
    /envconf.py /etc/opendkim/defs.yaml OPENDKIM "" >> /etc/opendkim/opendkim.conf
    mkdir -p /var/spool/postfix/opendkim
    chown opendkim:postfix /var/spool/postfix/opendkim
    exec opendkim -f \
      -p local:/var/spool/postfix/opendkim/opendkim.sock \
      -u opendkim:postfix \
      -x /etc/opendkim/opendkim.conf
}

prepare_postfix_chroot() {
    for d in dev etc usr; do
        mkdir -p "/var/spool/postfix/$d"
    done
    cp -a /usr/lib /var/spool/postfix/usr/
    ln -sf /usr/lib /var/spool/postfix/lib
    cp -a /dev/stdout /dev/random /dev/urandom /var/spool/postfix/dev/
    cp -a /etc/ssl /var/spool/postfix/etc/
    for f in host.conf hosts localtime nsswitch.conf resolv.conf services; do
        cp -a "/etc/$f" "/var/spool/postfix/etc/$f"
    done
}

exec_postfix() {
    if [ -d "/config/postfix" ]; then
        cp -rL /config/postfix /etc/
    fi
    /envconf.py /etc/postfix/defs.yaml POSTFIX = >> /etc/postfix/main.cf
    find "/etc/postfix/" -name '*.hash' -exec \
      sh -c 'postmap "$1"; chmod 0400 "$1"' sh {} \;
    find "/etc/postfix/" -name '*.ldap' -exec \
      sh -c '/envconf.py /etc/postfix/ldap.yaml LDAP = >> "$1; chmod 0400 "$1"' sh {} \;
    prepare_postfix_chroot
    postfix set-permissions
    exec postfix start-fg
}

exec_postsrsd() {
    if [ -z "${POSTSRSD_DOMAIN}" ]; then
        echo "POSTSRSD_DOMAIN mus be set" >&2
        exit 1
    fi
    if [ -z "${POSTSRSD_SECRET_FILE}" ]; then
        if [ -z "${POSTSRSD_SECRET}" ]; then
            echo "Either POSTSRSD_SECRET or POSTSRSD_SECRET_FILE must be set" >&2
            exit 1
        fi
       export POSTSRSD_SECRET_FILE="/etc/postsrsd.secret"
       echo "${POSTSRSD_SECRET}" > "${POSTSRSD_SECRET_FILE}"
    fi
    if [ -n "${POSTSRSD_EXCLUDE_DOMAINS}" ]; then
        _POSTSRSD_EXCLUDE_DOMAINS="-X${POSTSRSD_EXCLUDE_DOMAINS} "
    fi
    exec postsrsd \
      -f"${POSTSRSD_FORWARD_PORT:-10001}" \
      -r"${POSTSRSD_REVERSE_PORT:-10002}" \
      -d"${POSTSRSD_DOMAIN}" \
      -s"${POSTSRSD_SECRET_FILE}" \
      -a"${POSTSRSD_SEPARATOR:-=}" \
      -n"${POSTSRSD_HASHLENGTH:-4}" \
      -N"${POSTSRSD_HASHMIN:-4}" \
      -l"${POSTSRSD_LISTEN_ADDR:-127.0.0.1}" \
      "${_POSTSRSD_EXCLUDE_DOMAINS}"-upostsrsd \
      -c/var/lib/postsrsd
}

case "$1" in
  dovecot)
    exec_dovecot
    ;;

  opendkim)
    exec_opendkim
    ;;

  postfix)
    exec_postfix
    ;;

  postsrsd)
    exec_postsrsd
    ;;

  *)
    exec "$@"
    ;;
esac
