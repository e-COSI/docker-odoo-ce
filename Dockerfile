FROM debian:jessie:
MAINTAINER e-COSI <odoo@e-cosi.com>

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
#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------

# Install some deps, lessc and less-plugin-clean-css, wkhtmltopdf
#  and pgclient
RUN set -x; \
        apt-get update \
        && apt-get install -y --no-install-recommends wget \
        echo "deb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
        && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
        apt-get update \
        && apt-get upgrade -y \
        && apt-get install -y --no-install-recommends \
            ca-certificates \
            curl \
      	    git \
      	    npm \
      	    build-essential \
      	    python-dev \
      	    python-pip \
            node-less \
            node-clean-css \
         	  nodejs \
      	    nodejs-legacy \
      	    cython \
      	    libldap2-dev \
      	    libsasl2-dev \
      	    libxml2-dev \
      	    zlib1g-dev \
      	    libxslt1-dev \
            libjpeg-dev \
      	    libpq-dev \
        && curl -o wkhtmltox.deb -SL http://nightly.odoo.com/extra/$WKHTMLTOPDF_DEB \
        && echo '$WKHTMLTOPDF_SHA wkhtmltox.deb' | sha1sum -c - \
        && dpkg --force-depends -i wkhtmltox.deb \
        && apt-get -y install -f --no-install-recommends
        && apt-get install -y postgresql-$POSTGRES_VERSION

#--------------------------------------------------
# Prepare Env
#--------------------------------------------------

# Create Odoo system user
RUN adduser --system --home /odoo --quiet --group odoo

# Log
RUN mkdir -p /var/log/odoo \
	&& chown odoo:odoo /var/log/odoo \
	&& chmod 0750 /var/log/odoo

# Data dir
RUN mkdir -p /var/lib/odoo \
	&& chown odoo:odoo /var/lib/odoo \
	&& chmod 0750 /var/lib/odoo

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------

# Clone git repo
RUN git clone --shallow-since $VERSION_DATE --branch $ODOO_VERSION https://www.github.com/odoo/odoo /odoo/odoo-server \
    && git reset --hard $ODOO_COMMIT_HASH
# && rm -rf /odoo/odoo-server/.git

# Writing metainfo file
RUN echo "Version : ${ODOO_VERSION}\n" > /odoo/version.txt \
    && echo "Date from : ${VERSION_DATE}\n" > /odoo/version.txt \
    && echo "Commit : ${ODOO_COMMIT_HASH}\n" > /odoo/version.txt \
    && echo "Built on :" > /odoo/version.txt \
    && date +"%Y-%m-%d" > /odoo/version.txt && echo "\n"


# Installing community edition requirements
RUN pip install -r /odoo/odoo-server/requirements.txt \
  # FIXME: repair pip !!!
  #&& apt-get remove -y python-pip \
  #&& easy_install pip \
  # needed by auto-backup module
  && /usr/local/bin/pip install pysftp


#echo -e "\n---- Setting permissions on home folder ----"
RUN chown -R odoo:odoo /odoo/*

# Odoo configuration file
RUN mkdir -p /etc/odoo
COPY ./odoo_default.conf /etc/odoo/odoo.conf

RUN chown odoo /etc/odoo/odoo.conf \
	&& chmod 0640 /etc/odoo/odoo.conf \
  && echo "dbfilter=${DB_FILTER}" >> /etc/odoo/odoo.conf

# Copy entrypoint script
COPY ./entrypoint.sh /odoo/
RUN chmod +x /odoo/entrypoint.sh

# Mount /var/lib/odoo to allow restoring filestore 
# and /mnt/extra-addons for users addons
RUN mkdir -p /mnt/extra-addons \
        && chown -R odoo /mnt/extra-addons \
        && mkdir -p /mnt/sas \
        && chown -R odoo /mnt/sas \
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
