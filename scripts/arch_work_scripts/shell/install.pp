# vim: ts=4 sw=4 et

class php::install ($ensure) {
    if is_hash($ensure) {
        $version = $ensure[$lsbdistcodename]
    } else {
        $version = $ensure
    }

    File{
        ensure  => present,
        owner   => root,
        group   => root,
    }

    package { [
        'php5-common',
    ]: ensure => $version }


    if $env == 'dev' or tagged('role_staging') or $fqdn == 'ci01.svc.core.prod.vit.e-merchant.net' or $fqdn == 'ci02.svc.core.prod.dc3.e-merchant.net' {
        package { 'php5-xdebug':
            ensure =>  $php::params::version['xdebug']
        }
        file {'/etc/php5/mods-available/xdebug.ini':
            source => 'puppet:///modules/php/default/mods-available/extensions/xdebug.ini'
        }
    } else {
        package { 'php5-xdebug':
            ensure => 'purged',
        }
        file { '/etc/php5/mods-available/xdebug.ini':
            ensure => absent,
        }
    
    }


    if $env != 'dev' and $fonction == 'web' {
        # Needed for APC statistic purpose via FastCGI
        package { 'python-flup':
            ensure => 'latest',
        }
    }
    # 
    define install_extension ($ensure = present) {

        if is_hash($ensure) {
            $version = $ensure[$lsbdistcodename]
        } else {
            $version = $ensure
        }

        File {
            ensure  => present,
            owner   => root,
            group   => root,
            mode    => 0644,
        }

#        # doing some nasty if/else due to package name
        if $title == 'sqlrelay'  {
       	    package { [
                'php5-sqlrelay',
                'libsqlrelay-0.41',
                ]:
                ensure  => $php::params::version["sqlrelay"],
               require => Package['librudiments0.32'],
            }
            file { '/etc/php5/mods-available/sql_relay.ini':
                source => 'puppet:///modules/php/default/mods-available/extensions/sql_relay.ini'
            }
            exec { "load sqlrelay" :
                command => "/usr/sbin/php5enmod sql_relay",
                # Only if module is enabled for all SAPI installed on server (fpm,cgi,cli)
                unless  => "/bin/sh -c 'for sapi in \$(php5query -S); do php5query -q -s \$sapi -m sql_relay || exit 1; done; exit 0'",
            }

            package { 'librudiments0.32': ensure => $php::params::version["rudiments"]}

        } elsif $title == 'apc' {
            package { 'php-apc':
                ensure  => $php::params::version["apc"],
            }
        } elsif $title == 'libssh2' {
            package { 'libssh2-php':
                ensure => $php::params::version["libssh2"],
            }   
        } elsif $title == 'seeker' {
            # none
        } else {
            if $title in $php::params::version {
                 $value= $php::params::version[$title]
            }
            else { $value= $version }

            package { "php5-$title":
                ensure => $value,
            }
            # Module activation
            exec { "load $title" :
                command => "/usr/sbin/php5enmod $title",
                # Only if module is enabled for all SAPI installed on server (fpm,cgi,cli)
                unless  => "/bin/sh -c 'for sapi in \$(php5query -S); do php5query -q -s \$sapi -m $title || exit 1; done; exit 0'",
            }
        }

        # Supplementary ini files
        if $title == 'sybase' {
            file { '/etc/php5/mods-available/pdo_dblib.ini':
                source => 'puppet:///modules/php/default/mods-available/extensions/pdo_dblib.ini'
            }
            file { '/etc/php5/mods-available/mssql.ini':
                source => 'puppet:///modules/php/default/mods-available/extensions/mssql.ini'
            }
        }
        if $title == 'mysql' {
            file { '/etc/php5/mods-available/pdo_mysql.ini':
                source => 'puppet:///modules/php/default/mods-available/extensions/pdo_mysql.ini'
            }
            file { '/etc/php5/mods-available/mysqli.ini':
                source => 'puppet:///modules/php/default/mods-available/extensions/mysqli.ini'
            }
        }

        # Default ini files
        if ($title == 'apc') {
            file { "/etc/php5/mods-available/$title.ini":
                content => template("php/conf.d/$title.ini.erb"),
            }
		} elsif ($title == 'sqlrelay') {
			file { "/etc/php5/mods-available/$title.ini":
				ensure => absent,
			}
        }
        ## exception shit for INFTSK-4840
        # elsif ! ($title == 'oci8' and $fonction == 'web') {
        #    file { "/etc/php5/mods-available/$title.ini":
        #        source => "puppet:///modules/php/default/mods-available/extensions/$title.ini"
        #    }
        #}
    }
}
