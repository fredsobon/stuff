# vim: ts=4 sw=4 et

class role_99 (
    $type = undef,
    $version = present,
    $php = undef,
    $php_modes = undef,
    $cache_type = undef,
    $ora_version = undef,
    $php_extensions = undef,
    $php_relative_path = undef,
    $python = undef,
    ) {

    case $type {
        'apache2': {
            # Apache install/config
            class { 'apache2_99': ensure => $version }
            # Apache modules enabled
            apache2_99::config::module { [
                'actions',
                'alias',
                'auth_basic',
                'authn_file',
                'authz_host',
                'authz_user',
                'cgid',
                'dir',
                'env',
                'fastcgi',
                'headers',
                'info',
                'mime',
                'proxy_http',
                'proxy_ftp',
                'proxy',
                'rewrite',
                'setenvif',
                'status',
                'suexec',
            ]: }
            if $platform == 'pix' {
                apache2_99::config::module { [
                    'reqtimeout',
                    'deflate',
                ]: }
            }
        }
        'apache2_standalone': {
            class { 'apache2_standalone': ensure => $version }
            user::exists::create_user {'www-data': }
        }
        default: { notify { 'No webserver type was provided !': } }
    }

    # If we have php defined, load the class
    if $php != undef {
        if $php_modes != undef {
            class { 'php99':
                ensure        => $php,
                extensions    => $php_extensions,
                memcache_list => $cache_list,
                modes         => $php_modes,
                relative_path => $php_relative_path,
            }
            if $platform == 'common' or $platform =='office' {
                php99::config::fpm::user_php5fpm { 'www-data': template  => 'common_fpm_pool.conf' }
            }
            if $env == 'uat' or $env == 'prod' {
                include phpslowlogs
            }
        } else {
            notify { 'php: modes not defined in yaml conf ! Please provide a list : fpm,cli,etc': }
        }
    }

    # Install oracle client if needed
    if $ora_version != undef {
        class { 'oracle::client': version => $ora_version }
    }

    # Do we need a cache server ?
    case $cache_type {
        'memcache': {
            class { 'php99::memcache': memcache_list => $cache_list }
            class { 'memcache::client': memcache_list => $cache_list }
        }
        default: {}
    }

    if $gearman_list != undef {
        class { 'gearman::client': gen_gearman_list => $gearman_list }
    }

    # Or if we are using python with apache (aka elvis style)
    if $python != undef {
        class { 'python': ensure => $python }
    }

    if $platform != 'common' and $platform != 'office' {
        # Include users related to the applis/services
        include accountmanagement

        include sudo

        # fpm_watchdog
        include fpm_watchdog

        # Rsyncd for gettext
        include rsyncd

#    # We need netapp mount points
#        case $fqdn { 
#            'web99.front.mutu.prod.dc3.e-merchant.net' : {
#                        $mountpoints = [
#                            '/mnt/share/em_pdf_factures',
#                            '/mnt/share/em_pdf_retours',
#                            '/mnt/share/em_traces_front',
#                            '/mnt/share/em_bo_affiliation_datafeeds',
#                            '/mnt/share/em_bo_affiliation_externe',
#                            '/mnt/share/em_bo_affiliation_factures',
#                            '/mnt/share/em_feeds_pixpro',
#                            '/mnt/share/em_pdf_eproofs',
#                            '/mnt/share/em_tpl_mailing',
#                            '/mnt/share/em_xml_bocm',
#                            '/mnt/share/fo-pixpro-cm',
#                            '/mnt/share/zendesk',
#                        ]
#                    }
#        }
#        include mounts
#        mounts::mkdir { $mountpoints: }

        # We need localisation for all of our countries
        include locales

        # Logrotate
        include logrotate

        # Limits
        include limits

    }

    if $env == 'dev' {
        apache2::config::module { [ 'vhost_alias' ]: }

        include user::do_remote
        include riak

        if $service == 'front' {
            # Include SIPS certificates binaries
            class { 'certificates': need_binaries => true }
            certificates::config::devcertificates {"fo-carrefour": }
            certificates::config::devcertificates {"fo-pixpro": }
        } elsif $service == 'svc' and $platform == 'core' {
            # Import PSP certs
            certificates::config::usepspcertificates {'dev': }
        }

    }

    if $env == 'uat' {
        include riak
    }

    if $platform == 'gen' {
        # Synchronization between servers
        include lsyncd
    }
}
