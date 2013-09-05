define mailuser($dbname,
		$password,
		$quota){
  $email=$name
    postgresql_psql { "public.forwardings-${email}":
    db      => $dbname,
    command => "INSERT INTO public.forwardings (source,destination) VALUES ('${email}','${email}');",
    unless  => "SELECT source FROM public.forwardings WHERE source LIKE '${email}'",
    require => Postgresql_psql["${dbname}-init-database"]
  }
  postgresql_psql { "public.users-${email}":
    db      => $dbname,
    command => "INSERT INTO public.users (email,password,quota) VALUES ('${email}','${password}','${quota}');",
    unless  => "SELECT email FROM public.users WHERE email LIKE '${email}'",
    require => Postgresql_psql["${dbname}-init-database"]
  }
}
