#!/usr/bin/python
# -*- coding: utf-8 -*-
# vim: ft=python ts=4 sw=4 et
# Maxime Guillet - Mon, 19 Nov 2012 16:41:43 +0100

import sys
import yum
import yum.update_md

if __name__ == '__main__':
    ybase = yum.YumBase()

    yum.update_md.UpdateMetadata()

    ybase.localPackages = []
    ybase.updates = []

    # Lock for yum
    ybase.doLock()

    ybase.doConfigSetup(init_plugins=False)

    # Remove metadata
    ybase.cleanMetadata()

    # Get upgradable packages
    try:
        ygh = ybase.doPackageLists('updates')
    except yum.Errors.RepoError:
        ybase.doUnlock()
        sys.exit(1)

    # Unlock yum
    ybase.doUnlock()

    pkg_fhandle = open('/var/cache/yum/upgradable.list', 'w')

    for pkg in ygh.updates:
        pkg_fhandle.write('%s\n' % pkg.name)

    pkg_fhandle.close()

    sys.exit(0)
