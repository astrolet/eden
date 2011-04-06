#!/bin/sh

cat <<MESSAGE

Thanks for installing Eden.

Please make sure to git-clone git@github.com:astrolet/lin.git & npm-link it (not published yet).

Do npm-install for the rest of the node_modules (due to .gitignore).

For the time being, install pyswisseph <http://pypi.python.org/pypi/pyswisseph/> from source.

There is also a <http://pyyaml.org/wiki/PyYAML/> dependency (that should go away some day).

Put or link ephemeris files at mnt/sin/data (git clone git@github.com:astrolet/sin.git mnt/sin).

Read LICENSE (full copy found in swe/src) before use.

MESSAGE
