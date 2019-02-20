#!/bin/bash
# Can't do inline editing work :-(
cp /odoo/odoo-server/odoo/release.py /odoo/odoo-server/odoo/release.py.orig
cat /odoo/odoo-server/odoo/release.py.orig | sed -r "s/(version_info = \([0-9]+, [0-9]+, [0-9]+, FINAL, [0-9]+, ')()('\))/\1${1//-/}\(${2:0:7}\)\3/g" /odoo/odoo-server/odoo/release.py.orig > /odoo/odoo-server/odoo/release.py

