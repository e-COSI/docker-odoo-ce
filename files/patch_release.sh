#!/bin/bash
cp /odoo/odoo-server/odoo/release.py /odoo/odoo-server/odoo/release_py.backup
sed -i "s/%%CONTAINER_DATE%%/${1//-/}/g" /tmp/release.diff
sed -i "s/%%COMMIT_HASH%%/${2:0:7}/g" /tmp/release.diff
patch -i /tmp/release.diff /odoo/odoo-server/odoo/release.py
