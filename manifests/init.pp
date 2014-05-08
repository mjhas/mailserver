class mailserver (
  $domains               = [],
  $users                 = {},
  $forwards              = {},
  $mydestination         = 'localhost, localhost.localdomain',
  $myhostname            = 'localhost',
  $mynetworks            = '127.0.0.0/8',
  $smtpd_banner_hostname = 'localhost',
  $ssl_key_file,
  $ssl_cert_file,
  $ssl_ca_file           = undef,
  $postmaster_address    = "root@${::fqdn}",
  $message_size_limit    = '60485760',
  $default_quota         = '10485760',
  $db                    = 'yes',
  $dbname                = 'mail',
  $dbuser                = undef,
  $dbpassword            = undef,
) {
  include clamav
  Class['amavis'] -> Class['clamav']
  include amavis

  class { 'amavis::config':
    bypass_virus_checks_maps => '(\%bypass_virus_checks, \@bypass_virus_checks_acl, \$bypass_virus_checks_re);',
    bypass_spam_checks_maps  => '(\%bypass_spam_checks, \@bypass_spam_checks_acl, \$bypass_spam_checks_re);',
    final_virus_destiny      => 'D_REJECT; # (defaults to D_BOUNCE)',
    final_banned_destiny     => 'D_REJECT;  # (defaults to D_BOUNCE)',
    final_spam_destiny       => 'D_PASS;  # (defaults to D_REJECT)',
    final_bad_header_destiny => 'D_PASS;  # (defaults to D_PASS), D_BOUNCE suggested',
  }
  if $db == 'yes' {
    if $dbuser == undef or $dbpassword ==undef {
      fail ('dbuser and dbpassword must be set for db to work')
    }
    $users_defaults = {
  	  'quota'      => $default_quota,
  	  'dbname'     => $dbname,
    }
    $forwards_defaults = {
  	  'dbname'     => $dbname,
    }
    create_resources(mailuser, $users, $users_defaults)
    create_resources(mailforwards, $forwards, $forwards_defaults)
    maildomain { $domains :
    	dbname=>$dbname,
    }

    include postgresql::server

    postgresql::db { $dbname:
      user     => $dbuser,
      password => $dbpassword
    }

    postgresql::validate_db_connection { "public.connection-validate":
      database_host     => 'localhost',
      database_username => $dbuser,
      database_password => $dbpassword,
      database_name     => $dbname,
      require           => Postgresql::Db[$dbname],
      before            => Postgresql_psql["${dbname}-init-database"],
    }

    postgresql_psql { "${dbname}-init-database":
      db      => $dbname,
      command => "
  CREATE TABLE domains (
      domain character varying(50) NOT NULL
  );
  ALTER TABLE public.domains OWNER TO ${dbuser};
  CREATE TABLE forwardings (
      source character varying(80) NOT NULL,
      destination text NOT NULL
  );
  ALTER TABLE public.forwardings OWNER TO ${dbuser};
  CREATE TABLE transport (
      domain character varying(128) DEFAULT ''::character varying NOT NULL,
      transport character varying(128) DEFAULT ''::character varying NOT NULL
  );
  ALTER TABLE public.transport OWNER TO ${dbuser};
  CREATE TABLE users (
      email character varying(80) NOT NULL,
      password character varying(20) NOT NULL,
      quota integer DEFAULT 10485760
  );
  ALTER TABLE public.users OWNER TO ${dbuser};
  ALTER TABLE ONLY transport
      ADD CONSTRAINT domain UNIQUE (domain); ",
      unless  => "SELECT table_name FROM information_schema.tables WHERE table_catalog LIKE '${dbname}' AND table_schema LIKE 'public' AND (table_name LIKE 'forwardings' or table_name LIKE 'domains' or table_name LIKE 'transport' or table_name LIKE 'users')",
    }

    Service['dovecot'] -> Package['postfix']
    Package['postfix-pgsql'] -> Service['postfix']

    Class['amavis::config'] -> Class['postfix']

    class { 'postfix': }

    class { 'postfix::postgres':
      dbname     => $dbname,
      dbpassword => $dbpassword,
      dbuser     => $dbuser,
    }



    class { 'postfix::config':
      alias_maps                           => 'hash:/etc/aliases',
      append_dot_mydomain                  => 'no',
      biff                                 => 'no',
      broken_sasl_auth_clients             => 'no',
      content_filter                       => 'amavis:[127.0.0.1]:10024',
      disable_vrfy_command                 => 'yes',
      import_environment                   => 'MAIL_CONFIG MAIL_DEBUG MAIL_LOGTAG TZ XAUTHORITY DISPLAY LANG=C RESOLV_MULTI=on',
      mail_spool_directory                 => '/var/mail',
      message_size_limit                   => $message_size_limit,
      mydestination                        => $mydestination,
      myhostname                           => $myhostname,
      mynetworks                           => $mynetworks,
      myorigin                             => '/etc/mailname',
      local_recipient_maps                 => 'proxy:unix:passwd.byname $alias_maps',
      proxy_read_maps                      => '$local_recipient_maps $mydestination $virtual_alias_maps $virtual_alias_domains $virtual_mailbox_maps $virtual_mailbox_domains $relay_recipient_maps $relay_domains $canonical_maps $sender_canonical_maps $recipient_canonical_maps $relocated_maps $transport_maps $mynetworks',
      receive_override_options             => 'no_address_mappings',
      show_user_unknown_table_name         => 'no',
      smtp_sasl_security_options           => 'yes',
      smtp_tls_CAfile                      => $ssl_ca_file,
      smtp_tls_note_starttls_offer         => 'yes',
      smtp_use_tls                         => 'yes',
      smtpd_banner                         => "${smtpd_banner_hostname} ESMTP ${smtpd_banner_hostname} (Debian/GNU)",
      smtpd_data_restrictions              => 'reject_unauth_pipelining,     permit',
      smtpd_delay_reject                   => 'yes',
      smtpd_helo_required                  => 'yes',
      smtpd_recipient_restrictions         => 'reject_invalid_hostname,     permit_sasl_authenticated,      reject_non_fqdn_hostname,     reject_non_fqdn_sender,     reject_non_fqdn_recipient,      reject_unknown_sender_domain,     reject_unknown_recipient_domain,            reject_unauth_pipelining,     permit_mynetworks,      reject_unauth_destination,      reject_rbl_client zen.spamhaus.org, reject_rbl_client bl.spamcop.net      permit',
      smtpd_sasl_auth_enable               => 'yes',
      smtpd_sasl_local_domain              => '$myhostname',
      smtpd_sasl_security_options          => 'noanonymous',
      smtpd_sender_restrictions            => 'permit_sasl_authenticated, permit_mynetworks',
      smtpd_tls_auth_only                  => 'no',
      smtpd_tls_cert_file                  => $ssl_cert_file,
      smtpd_tls_key_file                   => $ssl_key_file,
      smtpd_tls_loglevel                   => '1',
      smtpd_tls_received_header            => 'yes',
      smtpd_tls_session_cache_timeout      => '3600s',
      smtpd_use_tls                        => 'yes',
      tls_random_source                    => 'dev:/dev/urandom',
      transport_maps                       => 'proxy:pgsql:/etc/postfix/postgresql/virtual_transports.cf',
      virtual_alias_maps                   => 'proxy:pgsql:/etc/postfix/postgresql/virtual_forwardings.cf',
      virtual_gid_maps                     => 'static:5000',
      virtual_mailbox_base                 => '/srv/vmail',
      virtual_mailbox_domains              => 'proxy:pgsql:/etc/postfix/postgresql/virtual_domains.cf',
      virtual_mailbox_limit                => '100000000',
      virtual_mailbox_maps                 => 'proxy:pgsql:/etc/postfix/postgresql/virtual_mailboxes.cf',
      virtual_uid_maps                     => 'static:5000',
      smtpd_sasl_type                      => 'dovecot',
      smtpd_sasl_path                      => 'private/auth',
      virtual_transport                    => 'dovecot',
      dovecot_destination_recipient_limit  => '1',
      maildrop_destination_recipient_limit => '1',
      mailbox_size_limit                   => $default_quota,
    }

    postfix::config::mastercf { 'smtps':
      type    => 'inet',
      private => 'n',
      command => '"smtpd
      -o syslog_name=postfix/smtps
      -o smtpd_tls_wrappermode=yes
      -o smtpd_sasl_auth_enable=yes
      -o smtpd_client_restrictions=permit_sasl_authenticated,reject
      -o milter_macro_daemon_name=ORIGINATING"'
    }

    postfix::config::mastercf { 'amavis':
      type    => 'unix',
      limit   => '2',
      chroot  => 'y',
      command => '"smtp
          -o smtp_data_done_timeout=1200
          -o smtp_send_xforward_command=yes"'
    }

    postfix::config::mastercf { 'dovecot':
      type         => 'unix',
      unprivileged => 'n',
      chroot       => 'n',
      command      => '"pipe
      flags=DRhu user=vmail:vmail argv=/usr/lib/dovecot/deliver -f ${sender} -d ${recipient}"'
    }

    postfix::config::mastercf { 'maildrop':
      type         => 'unix',
      unprivileged => 'n',
      chroot       => 'n',
      command      => '"pipe
      flags=DRhu user=vmail:vmail argv=argv=/usr/bin/maildrop -d ${recipient}"'
    }

    postfix::config::mastercf { 'smtp':
      type         => 'inet',
      unprivileged => 'n',
      command      => '"smtpd"'
    }

    postfix::config::mastercf { '127.0.0.1:10025':
      type    => 'inet',
      private => 'n',
      command => '"smtpd
          -o content_filter=
          -o local_recipient_maps=
          -o relay_recipient_maps=
          -o smtpd_restriction_classes=
          -o smtpd_client_restrictions=
          -o smtpd_helo_restrictions=
          -o smtpd_sender_restrictions=
          -o smtpd_recipient_restrictions=permit_mynetworks,reject
          -o mynetworks=127.0.0.0/8
          -o strict_rfc821_envelopes=yes
          -o receive_override_options=no_unknown_recipient_checks,no_header_body_checks"'
    }
    class { dovecot:
    }

    class { 'dovecot::ssl':
      ssl          => 'yes',
      ssl_keyfile  => $ssl_key_file,
      ssl_certfile => $ssl_cert_file,
      ssl_ca       => $ssl_ca_file,
    }
    include dovecot::sieve

    class { 'dovecot::master': postfix => true, }


    include dovecot::mail

    class { 'dovecot::lda': postmaster_address => $postmaster_address }
    include dovecot::imap
    include dovecot::base
    include dovecot::auth
    class { dovecot::postgres:
      dbname     => $dbname,
      dbpassword => $dbpassword,
      dbusername => $dbuser,
    }
  } else {
    fail ('setup without db currently not supported')
  }
}
