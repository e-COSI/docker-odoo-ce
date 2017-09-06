FROM debian:stretch
MAINTAINER e-COSI <odoo@e-cosi.com>

# db_filter is added to odoo.conf
ARG ODOO_DB_FILTER=^%d_*
# Image is built from Odoo branch given by VERSION AND WITH EXACT COMMIT HASH
# IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 10.0
ARG ODOO_VERSION=10.0
ARG ODOO_COMMIT_HASH
# VERSION_DATE is used as meta info in version.txt file generated at /odoo
#  and to limit cloning depth via shallow-since
#  VERSION_DATE must be equal to commit selected date
ARG VERSION_DATE
# Odoo need specific extra version for wkhtmltopdf provided by Odoo from nightly builds server
ARG WKHTMLTOPDF_DEB=wkhtmltox-0.12.1.2_linux-jessie-amd64.deb
ARG WKHTMLTOPDF_SHA=40e8b906de658a2221b15e4e8cd82565a47d7ee8
# PostgreSQL Version used for bakcup/restore operations
ARG POSTGRES_VERSION=9.6
# Choosing default conf file, eg. to create dev container
ARG DEFAULT_CONF_FILE=odoo_default.conf

ENV ODOO_VERSION=${ODOO_VERSION}

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------

# Install some deps, lessc and less-plugin-clean-css, wkhtmltopdf
#  and pgclient
RUN set -x; \
        apt-get update \
        && apt-get install -y --no-install-recommends wget \
        && echo "deb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
        && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \

RUN set -x; \
        apt-get update \
        && apt-get install -y --no-install-recommends \
            apt-utils \
            git \
            ca-certificates \
            curl \
            node-less \
            python-gevent \
            python-pip \
            python-setuptools \
            python-wheel \
            python-renderpm \
            python-watchdog \
            # Utils
            vim 
            # Adding distro package to speedup container building preventing package building 
            # throw python requirements and lib-dev downloading
            # python-ldap \
            # python-psycogreen \
            # python-psycopg2 \
            # python-gevent \
            # python-psutil

 
RUN set -x; \
        curl -o wkhtmltox.deb -SL http://nightly.odoo.com/extra/${WKHTMLTOPDF_DEB} \
        && echo "${WKHTMLTOPDF_SHA} wkhtmltox.deb" | sha1sum -c - \
        && dpkg --force-depends -i wkhtmltox.deb \
        && apt-get -y install -f --no-install-recommends \
        && rm wkhtmltox.deb \
        # PostgreSQL client for backup and restore
        && apt-get install -y --force-yes postgresql-client-${POSTGRES_VERSION} \

#--------------------------------------------------
# Prepare Env
#--------------------------------------------------

# Create Odoo system user
RUN set -x; \
        adduser --system --home /odoo --quiet --group odoo \
# Log
        && mkdir -p /var/log/odoo \
	&& chown odoo:odoo /var/log/odoo \
	&& chmod 0750 /var/log/odoo \
# Data dir
        && mkdir -p /var/lib/odoo \
	&& chown odoo:odoo /var/lib/odoo \
	&& chmod 0750 /var/lib/odoo

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------

# Clone git repo, using commit hash if given
RUN set -x; \
        if [ ${ODOO_COMMIT_HASH} ]; \
          then git clone --shallow-since=${VERSION_DATE} --branch ${ODOO_VERSION} https://www.github.com/odoo/odoo /odoo/odoo-server; \
          else git clone --depth 1 --branch ${ODOO_VERSION} https://www.github.com/odoo/odoo /odoo/odoo-server; \
        fi; \
        cd /odoo/odoo-server \
        if [ ${ODOO_COMMIT_HASH} ]; then git reset --hard ${ODOO_COMMIT_HASH}; fi \
        rm -rf /odoo/odoo-server/.git

# Installing community edition requirements
RUN set -x; apt-get update && apt-get install -y \
        libldap2-dev \
      	libsasl2-dev \
      	libxml2-dev \
      	zlib1g-dev \
      	libxslt1-dev \
        libjpeg-dev \
        libpython2.7-dev \
        libffi-dev \
        libssl-dev \
        gcc

RUN set -x; \
        pip install -r /odoo/odoo-server/requirements.txt \ 
        # needed by auto-backup module
        && pip install pysftp

# Cleaning image
RUN set -x; \
        apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false \
        && rm -rf /var/lib/apt/lists/*

# Writing metainfo file
RUN echo "Version : ${ODOO_VERSION}\n" > /odoo/version.txt \
    && echo "Date from : ${VERSION_DATE}\n" >> /odoo/version.txt \
    && echo "Commit : ${ODOO_COMMIT_HASH}\n" >> /odoo/version.txt \
    && echo "Built on :" >> /odoo/version.txt \
    && date +"%Y-%m-%d" >> /odoo/version.txt && echo "\n"

#echo -e "\n---- Setting permissions on home folder ----"
RUN chown -R odoo:odoo /odoo/* \
    # Odoo configuration file
    && mkdir -p /etc/odoo

COPY ./${DEFAULT_CONF_FILE} /etc/odoo/odoo.conf

RUN chown odoo /etc/odoo/odoo.conf \ 
    && chmod 0640 /etc/odoo/odoo.conf \
    && echo "dbfilter=${DB_FILTER}" >> /etc/odoo/odoo.conf

# Copy entrypoint script
COPY ./entrypoint.sh /odoo/
RUN chmod +x /odoo/entrypoint.sh

# Mount /var/lib/odoo to allow restoring filestore 
# and /mnt/extra-addons for users addons
RUN set -x; \
        mkdir -p /mnt/extra-addons/{oca,community,commercial,specific} \
        && chown -R odoo /mnt/extra-addons \
        && mkdir -p /var/lib/odoo \
        && chown -R odoo /var/lib/odoo \
        && mkdir -p /var/log/odoo \
        && chown -R odoo /var/log/odoo

VOLUME ["/var/lib/odoo", "/mnt/extra-addons", "/var/log/odoo", "/etc/odoo"]

# Expose Odoo services
EXPOSE 8069 8071 8072

# Set default user when running the container
USER odoo

ENTRYPOINT ["/odoo/entrypoint.sh"]

CMD ["/odoo/odoo-server/odoo-bin", "-c", "/etc/odoo/odoo.conf"]
