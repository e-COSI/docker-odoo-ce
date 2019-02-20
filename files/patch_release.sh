#!/bin/bash
# Can't do inline editing work :-(
cp /odoo/odoo-server/openerp/release.py /odoo/odoo-server/openerp/release.py.orig
cat /odoo/odoo-server/openerp/release.py.orig | sed -r "s/(version_info = \([0-9]+, [0-9]+, [0-9]+, FINAL, [0-9]+, ')(.*)('\))/\1${1//-/}\(${2:0:7}\)\3/g" /odoo/odoo-server/openerp/release.py.orig > /odoo/odoo-server/openerp/release.py

