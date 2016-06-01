# vim: ts=4 sw=4 et

class collectd::install {
    if $lsbdistcodename  == 'lucid' {
        package { 'collectd5':
            ensure => '5.0.0-1~pix2',
        }

        package { [
            'rrdcached',
            'rrdtool',
            'librrd4',
            'librrds-perl',
            'python-rrdtool',
        ]:
            ensure => '1.4.3-3.1ubuntu2~pix2',
        }
    } else {
        package { 'collectd':
            ensure  => '5.4.0-3ubuntu1~em124',
            require => Class['collectd::preconfig'],
        }

        package { [
            'rrdcached',
            'rrdtool',
            'librrd4',
            'librrds-perl',
            'python-rrdtool',
        ]:
            ensure  => '1.4.7-1',
            require => Class['collectd::preconfig'],
        }

        package { [
            'libhtml-format-perl',
            'libhtml-parser-perl',
            'libhtml-tagset-perl',
            'libhtml-tree-perl',
            'libconfig-general-perl',
            'libregexp-common-perl',
            'libyajl1',
        ]:
            ensure  => 'latest',
            require => Class['collectd::preconfig'],
        }
    }
}
