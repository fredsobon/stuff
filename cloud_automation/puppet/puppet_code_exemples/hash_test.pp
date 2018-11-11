
  $names = {"bob" =>"cactus",
          "bab"=>  "yuka",
  }
  $names.each | $n, $value| {
    notice("name is ${n} and his value is  ${value}")
    
    file { "/tmp/${n}":
      ensure => directory,
    }
    file {"/tmp/${n}/${n}":
      content => "hey ${value}",
   }

}
  



