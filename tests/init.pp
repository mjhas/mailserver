package{'libaugeas-ruby':
  ensure => installed,
  before => Class['mailserver']
}
package{'augeas-lenses':
  ensure  => installed,
  before  => Class['mailserver']
}

class { 'mailserver':
  ssl_key_file  =>'/etc/ssl/private/ssl-cert-snakeoil.key',
  ssl_cert_file =>'/etc/ssl/certs/ssl-cert-snakeoil.pem',
  dbpassword    =>'password',
  dbuser        =>'username',
  domains	=> ["$::fqdn"],
  forwards      =>  { 
      "postmaster@${::fqdn}" => { destination => "root@${::fqdn}" },
      "admin@${::fqdn}"      => { destination => ["root@${::fqdn}","post@${::fqdn}"] }
  },
  users	        => { "root@${::fqdn}" => { 
  			password     => 'wt3T3FHETdggQ',
			quota => '100000'
                   }
  },
  default_quota => '10485760',
}
