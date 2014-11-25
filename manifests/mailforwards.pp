define mailserver::mailforwards($dbname,$destination){
  $email=$name
  if is_array($destination){
    $joined_destination=join($destination, ",")
  } else {
    $joined_destination=$destination
  }
  postgresql_psql { "public.forwardings-${email}":
    db      => $dbname,
    command => "UPDATE public.forwardings SET destination='${joined_destination}' where source LIKE '${email}'; INSERT INTO public.forwardings (source,destination) SELECT '${email}', '${joined_destination}' WHERE NOT EXISTS (SELECT 1 FROM public.forwardings WHERE source LIKE '${email}');",
    unless  => "SELECT source FROM public.forwardings WHERE source LIKE '${email}'",
    require => Postgresql_psql["${dbname}-init-database"]
  }
}
