# vim: ts=4 sw=4 et

class role_webserver (
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
            class { 'apache2': ensure => $version }
            # Apache modules enabled
            apache2::config::module { [
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
                'proxy',
                'rewrite',
                'setenvif',
                'status',
                'suexec',
            ]: }
            if $platform == 'pix' {
                apache2::config::module { [
                    'reqtimeout',
                    'deflate',
                ]: }
            }
            if $fqdn == 'web62.front.mutu.uat.vit.e-merchant.net' {
                apache2::config::module { [
                    'shib2',
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
            class { 'php':
                ensure        => $php,
                extensions    => $php_extensions,
                memcache_list => $cache_list,
                modes         => $php_modes,
                relative_path => $php_relative_path,
            }
            if $platform == 'common' or $platform =='office' {
                php::config::fpm::user_php5fpm { 'www-data': template  => 'common_fpm_pool.conf' }
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
            class { 'php::memcache': memcache_list => $cache_list }
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

        # We need netapp mount points
        case $env {
            'prod': {
                case $platform {
                    'core': {
                        $mountpoints = [
                            '/mnt/share/automailer',
                            '/mnt/share/em_feeds_files',
                            '/mnt/share/em_fraudbuster',
                            '/mnt/share/em_log_logistique',
                            '/mnt/share/em_log_ws-int-client',
                            '/mnt/share/em_log_ws_sav/',
                            '/mnt/share/em_pdf_factures',
                            '/mnt/share/em_pdf_retours',
                            '/mnt/share/ftp_exchange',
                            '/mnt/share/pixplace',
                            '/mnt/share/pixplace/temp',
                            '/mnt/share/pixplace/temp/files',
                            '/mnt/share/taskmanager',
                            '/mnt/share/em_traces_wsint',
                            '/mnt/share/pixmania_salesterms',
                            '/mnt/share/crfplace',
                        ]
                    }
                    'corepub': {
                        $mountpoints = [
                            '/mnt/share/bo-escalation-cfour',
                            '/mnt/share/em_fraudbuster',
                            '/mnt/share/em_csv_bosav',
                            '/mnt/share/bo-retail',
                            '/mnt/share/testintool',
                            '/mnt/share/em_traces_bo',
                            '/mnt/share/em_csv_trad',
                            '/mnt/share/em_csv_shopbot',
                            '/mnt/share/em_pdf_retours',
                            '/mnt/share/em_bo-client',
                            '/mnt/share/automailer',
                            '/mnt/share/em_pdf_factures',
                            '/mnt/share/em_bretimages_img',
                            '/mnt/share/em_log_logistique',
                            '/mnt/share/em_editransfert_edi',
                            '/mnt/share/ftp_exchange',
                            '/mnt/share/bo-pixcm',
                            '/mnt/share/fo-pixpro-cm',
                            '/mnt/share/brain-static',
                            '/mnt/share/brain-static/export',
                            '/mnt/share/brain-static/0',
                            '/mnt/share/brain-static/1',
                            '/mnt/share/brain-static/2',
                            '/mnt/share/brain-static/3',
                            '/mnt/share/brain-static/4',
                            '/mnt/share/brain-static/5',
                            '/mnt/share/brain-static/6',
                            '/mnt/share/brain-static/7',
                            '/mnt/share/brain-static/8',
                            '/mnt/share/brain-static/9',
                            '/mnt/share/brain-static/A',
                            '/mnt/share/brain-static/B',
                            '/mnt/share/brain-static/C',
                            '/mnt/share/brain-static/D',
                            '/mnt/share/brain-static/E',
                            '/mnt/share/brain-static/F',
                            '/mnt/share/brain-pdf',
                            '/mnt/share/eptica-gem',
                            '/mnt/share/sniper',
                            '/mnt/share/fep',
                            '/mnt/share/taskmanager',
                            '/mnt/share/talend',
                            '/mnt/share/warning',
                            '/mnt/share/em_bo-product',
                            '/mnt/share/bo-seo',
                            '/mnt/share/brain-shared',
                            '/mnt/share/pixplace',
                            '/mnt/share/pixplace/temp',
                            '/mnt/share/pixplace/temp/files',
                            '/mnt/share/client',
                            '/mnt/share/pixmania_salesterms',
                            '/mnt/share/crfplace',
                        ]
                    }
                    'cfour': {
                        $mountpoints = [
                            '/mnt/share/em_pdf_factures',
                            '/mnt/share/em_pdf_retours',
                            '/mnt/share/em_traces_front',
                            '/mnt/share/fo-carrefour',
                            '/mnt/share/crfplace',
                        ]
                    }
                    'gen': {
                        $mountpoints = [
                            '/mnt/share/webagency',

                        ]
                    }
                    'mutu': {
                        $mountpoints = [
                            '/mnt/share/em_pdf_factures',
                            '/mnt/share/em_pdf_retours',
                            '/mnt/share/em_traces_front',
                            '/mnt/share/em_bo_affiliation_datafeeds',
                            '/mnt/share/em_bo_affiliation_externe',
                            '/mnt/share/em_bo_affiliation_factures',
                            '/mnt/share/em_feeds_pixpro',
                            '/mnt/share/em_pdf_eproofs',
                            '/mnt/share/em_tpl_mailing',
                            '/mnt/share/em_xml_bocm',
                            '/mnt/share/fo-pixpro-cm',
                            '/mnt/share/zendesk',
                        ]
                    }
                    'pix': {
                        $mountpoints = [
                            '/mnt/share/bo-pixcm',
                            '/mnt/share/em_pdf_factures',
                            '/mnt/share/em_pdf_retours',
                            '/mnt/share/zendesk',
                            '/mnt/share/pixplace/temp/files',
                            '/mnt/share/crfplace',
                        ]
                    }

                    default : { $mountpoints = undef }
                }
            }
            default : { $mountpoints = undef }
        }
        include mounts
        mounts::mkdir { $mountpoints: }

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
