FROM debian:stretch
LABEL maintainer="e-COSI <odoo@e-cosi.com>"

# db_filter is added to odoo.conf
ARG ODOO_DB_FILTER
# Image is built from Odoo branch given by VERSION AND WITH EXACT COMMIT HASH
# IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 10.0
ARG ODOO_VERSION
ARG ODOO_COMMIT_HASH
# VERSION_DATE is used as meta info in version.txt file generated at /odoo
#  and to limit cloning depth via shallow-since
#  VERSION_DATE must be equal to commit selected date
ARG VERSION_DATE
# PostgreSQL Version used for bakcup/restore operations
ARG POSTGRES_VERSION
# Choosing default conf file, eg. to create dev container
ARG DEFAULT_CONF_FILE=odoo_default.conf

ENV ODOO_VERSION=${ODOO_VERSION}
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive


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
        apt-get update && apt-get install -y git apt-utils; \
        if [ ${ODOO_COMMIT_HASH} ]; \
        then git clone --shallow-since=${VERSION_DATE} --branch ${ODOO_VERSION} https://github.com/odoo/odoo.git /odoo/odoo-server; \
        else git clone --depth 1 --branch ${ODOO_VERSION} https://github.com/odoo/odoo.git /odoo/odoo-server; \
        fi; \
        cd /odoo/odoo-server \
        if [ ${ODOO_COMMIT_HASH} ]; then git reset --hard ${ODOO_COMMIT_HASH}; fi \
        rm -rf /odoo/odoo-server/.git; \
        # Setting permissions on home folder
        chown -R odoo:odoo /odoo/*

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------

# Install some deps, lessc and less-plugin-clean-css, wkhtmltopdf
#  and pgclient
RUN set -x; \
        apt-get update && apt-get install -y wget gnupg \
        && echo "deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main" >> /etc/apt/sources.list.d/pgdg.list \
        && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
        && apt-get update \
        && apt-get install -y --no-install-recommends --allow-unauthenticated \
        # Utils
        curl \
        vim \
        gcc \
        patch \
        ca-certificates \
        # Python 3 env
        python \
        python-pip \
        python-setuptools \
        python-wheel \
        python-dev \
        # Dev stuff for building python requirements
        cython \
        zlib1g-dev \
        libxml2-dev \
        libxslt-dev \
        libsasl2-dev \
        libldap2-dev \
        libssl1.0-dev \
        # PostgreSQL client (for DB backup/restore)
        postgresql-client-${POSTGRES_VERSION} \
        # Requierd from Odoo Deb package
        #node-clean-css \
        adduser \
        lsb-base \
        node-less \
        postgresql-client \
        python-vobject \
        python-babel \
        python-dateutil \
        python-decorator \
        python-docutils \
        python-feedparser \
        python-html2text \
        python-pil \
        python-jinja2 \
        python-lxml \
        python-mako \
        python-mock \
        python-openid \
        python-passlib \
        python-psutil \
        python-psycopg2 \
        python-pydot \
        python-pyparsing \
        python-pypdf2 \
        python-reportlab \
        python-requests \
        python-renderpm \
        python-suds \
        python-tz \
        python-vatnumber \
        python-werkzeug \
        python-xlsxwriter \
        python-yaml \
        # Recommended from Odoo Deb Package
        python-gevent \
        python-renderpm \
        python-watchdog \
        # Python requirements
        && pip install -r /odoo/odoo-server/requirements.txt \
        # Install extra stuff
        && pip install wdb pudb newrelic psycogreen==1.0 pysftp \
        # WKMHTLTOPDF
        && curl -o wkhtmltox.deb -SL http://nightly.odoo.com/extra/wkhtmltox-0.12.1.2_linux-jessie-amd64.deb \
        && echo '40e8b906de658a2221b15e4e8cd82565a47d7ee8 wkhtmltox.deb' | sha1sum -c - \
        && dpkg --force-depends -i wkhtmltox.deb \
        && apt-get -y install -f --no-install-recommends \
        # Cleaning layer
	&& apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false \
        && rm -rf /var/lib/apt/lists/* wkhtmltox.deb


# Writing meta infos file
RUN echo "Version : ${ODOO_VERSION}\n" > /odoo/version.txt \
        && echo "Date from : ${VERSION_DATE}\n" >> /odoo/version.txt \
        && echo "Commit : ${ODOO_COMMIT_HASH}\n" >> /odoo/version.txt \
        && echo "Built on :" >> /odoo/version.txt \
        && date +"%Y-%m-%d" >> /odoo/version.txt && echo "\n"

COPY ./files/patch_release.sh /tmp
RUN chmod +x /tmp/patch_release.sh 
RUN /tmp/patch_release.sh ${VERSION_DATE} ${ODOO_COMMIT_HASH} && \
    rm /tmp/patch_release.sh

RUN mkdir -p /etc/odoo

COPY ./files/${DEFAULT_CONF_FILE} /etc/odoo/odoo.conf

RUN chown odoo /etc/odoo/odoo.conf \
        && chmod 0640 /etc/odoo/odoo.conf \
        && echo "dbfilter=${DB_FILTER}" >> /etc/odoo/odoo.conf

# Copy entrypoint script
COPY ./files/entrypoint.sh /odoo/
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
EXPOSE 8069 8072

# Set the default config file
ENV ODOO_RC /etc/odoo/odoo.conf

# Set default user when running the container
USER odoo

ENTRYPOINT ["/odoo/entrypoint.sh"]

CMD ["/odoo/odoo-server/odoo-bin", "-c", "/etc/odoo/odoo.conf"]
