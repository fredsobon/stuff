# vim: ts=4 sw=4 et

class apache2::config {
    # main apache2 config folder
    file { '/etc/apache2/':
        ensure  => directory,
        recurse => true,
        source  => [
            "puppet:///apache2/$env/$fonction/$service/$platform/apache2",
            "puppet:///apache2/$env/$fonction/$service/apache2",
            "puppet:///apache2/$env/$fonction/apache2",
            "puppet:///apache2/$env/apache2",
            "puppet:///apache2/fqdn/$fqdn/apache2",
            'puppet:///apache2/default/apache2',
        ],
        purge   => true,
        require => Package[apache2],
        notify  => Class['apache2::service'],
        mode    => '0644',
        ignore  => [
            '.svn',
            'mods-enabled',
            'apache2.conf',
            'conf/004-mpm_worker_module.conf',
        ],
        owner   => 'root',
        group   => 'www-data',
    }

    # apache2.conf is a template cause we need short hostname for varnish backend
    file { '/etc/apache2/apache2.conf':
        ensure  => present,
        content => template("apache2/conf/apache2.conf.erb"),
        require => File['/etc/apache2/'],
        notify  => Class['apache2::service'],
        mode    => '0644',
        owner   => 'root',
        group   => 'www-data',
    }

    # apache2.conf is a template cause we need short hostname for varnish backend
    file { '/etc/apache2/conf.d/004-mpm_worker_module.conf':
        ensure  => present,
        content => template("$apache2::params::apache_worker_template"),
        require => File['/etc/apache2/'],
        notify  => Class['apache2::service'],
        mode    => '0644',
        owner   => 'root',
        group   => 'www-data',
    }

    # common mods-available folder
    file { '/etc/apache2/mods-available':
        ensure  => directory,
        recurse => true,
        purge   => true,
        source  => 'puppet:///apache2/default/mods-available',
        require => Package[apache2],
        notify  => Class['apache2::service'],
        mode    => '0644',
        ignore  => '.svn',
        owner   => 'root',
        group   => 'www-data',
    }

### SHIBBOLETH 

    case $fqdn {
        'web61.front.mutu.uat.vit.e-merchant.net', 'web62.front.mutu.uat.vit.e-merchant.net': {
            file { '/etc/apache2/mods-available/shib2.conf':
                ensure  => present,
                source  => 'puppet:///shibboleth/uat/shib2.conf',
                mode    => '0644',
                owner   => 'root',
                group   => 'www-data',
            }
            file { '/etc/apache2/mods-available/shib2.load':
                ensure  => present,
                source  => 'puppet:///shibboleth/default/shib2.load',
                mode    => '0644',
                owner   => 'root',
                group   => 'www-data',
            }
            # manage  vhost Tablette
            file { '/etc/apache2/sites-available/tab-cfour':
                ensure  => present,
                source  => 'puppet:///shibboleth/uat/tab-cfour',
                require => Package[apache2],
                notify  => Class['apache2::service'],
                owner   => 'root',
                group   => 'www-data',
                mode    => '0644',
            }
            file { '/etc/apache2/sites-enabled/500-tab-cfour':
                ensure  => link,
                target  => '../sites-available/tab-cfour',
                require => Package[apache2],
                notify  => Class['apache2::service'],
                owner   => 'root',
                group   => 'www-data',
            }

            file { '/etc/apache2/includes/fo-carrefour-tablette-aliases':
                ensure  => present,
                source  => 'puppet:///shibboleth/uat/fo-carrefour-tablette-aliases',
                require => Package[apache2],
                notify  => Class['apache2::service'],
                owner   => 'root',
                group   => 'www-data',
                mode    => '0644',
            }
        }
        'web61.front.cfour.prod.vit.e-merchant.net', 'web62.front.cfour.prod.vit.e-merchant.net':{
            file { '/etc/apache2/mods-available/shib2.conf':
                ensure  => present,
                source  => 'puppet:///shibboleth/prod/shib2.conf',
                mode    => '0644',
                owner   => 'root',
                group   => 'www-data',
            }
            file { '/etc/apache2/mods-available/shib2.load':
                ensure  => present,
                source  => 'puppet:///shibboleth/default/shib2.load',
                mode    => '0644',
                owner   => 'root',
                group   => 'www-data',
            }
            # manage  vhost Tablette
            file { '/etc/apache2/sites-available/tab-cfour':
                ensure  => present,
                source  => 'puppet:///shibboleth/prod/tab-cfour',
                require => Package[apache2],
                notify  => Class['apache2::service'],
                owner   => 'root',
                group   => 'www-data',
                mode    => '0644',
            }
            file { '/etc/apache2/sites-enabled/500-tab-cfour':
                ensure  => link,
                target  => '../sites-available/tab-cfour',
                require => Package[apache2],
                notify  => Class['apache2::service'],
                owner   => 'root',
                group   => 'www-data',
            }

            file { '/etc/apache2/includes/fo-carrefour-tablette-aliases':
                ensure  => present,
                source  => 'puppet:///shibboleth/prod/fo-carrefour-tablette-aliases',
                require => Package[apache2],
                notify  => Class['apache2::service'],
                owner   => 'root',
                group   => 'www-data',
                mode    => '0644',
            }
        }
        
    } 
### FIN SHIBBOLETH 

    # manage sites configuration folders
    file { [
        '/etc/apache2/sites-available',
        '/etc/apache2/sites-enabled',
    ]:
        ensure  => directory,
        owner   => 'root',
        group   => 'www-data',
        mode    => '0644',
        purge   => true,
        recurse => true,
    }

    # manage default vhost
    file { '/etc/apache2/sites-available/default':
        ensure  => present,
        source  => [
            "puppet:///apache2/$env/$fonction/$service/$platform/sites-available/default",
            "puppet:///apache2/$env/$fonction/$service/sites-available/default",
            "puppet:///apache2/$env/$fonction/sites-available/default",
            "puppet:///apache2/$env/sites-available/default",
            'puppet:///apache2/default/sites-available/default',
        ],
        require => Package[apache2],
        notify  => Class['apache2::service'],
        owner   => 'root',
        group   => 'www-data',
        mode    => '0644',
    }

    file { '/etc/apache2/sites-enabled/000-default':
        ensure  => link,
        target  => '../sites-available/default',
        require => Package[apache2],
        notify  => Class['apache2::service'],
        owner   => 'root',
        group   => 'www-data',
    }


    # define function to manage modules
    define module($ensure = 'present') {
        case $ensure {
            'present' : {
                exec { "/usr/sbin/a2enmod $name":
                    unless => "/bin/sh -c '[ -L /etc/apache2/mods-enabled/${name}.load ] \\
                        && [ /etc/apache2/mods-enabled/${name}.load -ef /etc/apache2/mods-available/${name}.load ]'",
                }
            }
            'absent': {
                exec { "/usr/sbin/a2dismod $name":
                    onlyif => "/bin/sh -c '[ -L /etc/apache2/mods-enabled/${name}.load ] \\
                        && [ /etc/apache2/mods-enabled/${name}.load -ef /etc/apache2/mods-available/${name}.load ]'",
                }
            }
            default: { err ( "Unknown ensure value: '$ensure'" ) }
        }
    }

    # define function to manage vhosts
    define vhost (
        $ensure = 'present',
        $home = "/home/$name",
        $template = 'vhost-generic',
        $order = '500',
        $idle_timeout = '32',
    ) {
        file { "/etc/apache2/sites-available/${name}":
            ensure  => $ensure,
            content => template("apache2/vhosts/$template.erb"),
            require => [
                Package[apache2],
                File['/etc/apache2/sites-available'],
                User[$name],
            ],
            notify  => Class['apache2::service'],
            mode    => '0644',
            owner   => root,
            group   => www-data,
        }

        case $ensure {
            'present' : {
                file { "/etc/apache2/sites-enabled/${order}-${name}":
                    ensure  => link,
                    target  => "../sites-available/${name}",
                    require => [
                        Package[apache2],
                        File['/etc/apache2/sites-enabled'],
                        File["/etc/apache2/sites-available/${name}"],
                    ],
                    notify  => Class['apache2::service'],
                    mode    => '0644',
                    owner   => root,
                    group   => www-data,
                }
            }
            'absent' : {
                file { "/etc/apache2/sites-enabled/${order}-${name}":
                    ensure  => absent,
                    notify  => Class['apache2::service'],
                }
            }
        }
    }

}
