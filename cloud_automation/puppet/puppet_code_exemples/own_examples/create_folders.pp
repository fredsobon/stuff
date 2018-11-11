$dirs = ["bb", "bib", "bob"]
$dirs.each | $dir |{
  file { "/tmp/${dir}":
    ensure => file,
    owner  => 'root',
    mode   => '0600',
   }
}
