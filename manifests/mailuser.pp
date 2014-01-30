define mailuser($dbname,
		$password,
		$quota){
  $email=$name
  mailforwards { $email: 
     dbname  =>$dbname,
     destination =>$email
  }
  postgresql_psql { "public.users-${email}":
    db      => $dbname,
    command => "INSERT INTO public.users (email,password,quota) VALUES ('${email}','${password}','${quota}');",
    unless  => "SELECT email FROM public.users WHERE email LIKE '${email}'",
    require => Postgresql_psql["${dbname}-init-database"]
  }
}
