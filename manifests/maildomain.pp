define mailserver::maildomain($dbname){

  postgresql_psql { "${dbname}-domains-${name}":
    db      => $dbname,
    command => "INSERT INTO domains (domain) VALUES ('${name}');",
    unless  => "SELECT domain FROM domains WHERE domain LIKE '${name}'",
    require => Postgresql_psql["${dbname}-init-database"]
  }
}
