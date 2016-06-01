# vim: ts=4 sw=4 et

define apache2_standalone::module ($ensure = 'present') {
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
