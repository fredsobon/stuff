# vim: ts=4 sw=4 et

class xen::params {
    case $operatingsystem {
        Ubuntu: {
            $xen_server_pkg_name  = [
                'xen-hypervisor-4.1-amd64',
                'xen-utils-4.1',
                'bridge-utils',
                'vlan',
                'qemu-keymaps',
                'qemu-utils',
                'python-xenapi',
            ]
            $xen_server_service_name     = 'xend'
        }
    }
}
