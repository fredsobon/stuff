class composer::service (
  $composer_script_path,
  $composer_install_path,
  $cleanup_cron,
  $cleanup_cron_user
) {
  # composer global exec
  exec { "composer global":
    command =>"/bin/sh $composer_script_path/composer global update",
    path =>"/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    timeout     => 1800,
    subscribe   => File["$composer_install_path/composer.json"],
    refreshonly => true
  }
  
  if (true == $cleanup_cron) {
	  cron { composer:
	    name    => "composer",
	    command => "/bin/sh $composer_script_path/composer clear-cache",
	    ensure  => present,
	    user    => $cleanup_cron_user,
	    hour    => "0",
	    minute  => "15",
	    month   => "*",
	    monthday => "*",
	    weekday => "*"
	  }
  }
}