#!/usr/bin/perl
## OpenVPN LDAP Auth script with search user
## Refactored and improved by Balazs Petik
use warnings;
use strict;

use Sys::Syslog qw(:standard :macros);
use Net::LDAP;

use Config::Tiny;
use File::Basename;

my $facility = LOG_AUTH;
my $ourname = $ARGV[0];

my $path = dirname(__FILE__);


my $cfg = Config::Tiny->new;
$cfg = Config::Tiny->read( "${path}/perl-auth-ldap.conf" );


my $domain = $cfg->{LDAP}->{DOMAIN};
my $vpngroup = $cfg->{LDAP}->{VPNGROUP};


# base DN for the search; adjust the code if the vpn group isn't directly in here.
my $basedn = $cfg->{LDAP}->{BASEDN};

my $ldap_uri = $cfg->{LDAP}->{LDAPSERVER};

# these are passed by OpenVPN
my $username = $ENV{'username'};
my $password = $ENV{'password'};


openlog($ourname, 'nofatal,pid', $facility);

my @filter;

if ($cfg->{LDAP}->{LDAPTYPE} eq "LDAP") {
# filter
	@filter = ( "(uid=${username})",
               "(memberOf=${vpngroup})",
              );
} else {
	@filter = ( "(sAMAccountName=${username})",
               "(memberOf=${vpngroup})",
               '(accountStatus=active)',
             );
}

# using userAccountControl seems to work better at detecting active users
# see https://github.com/waldner/openvpn-ldap/commit/9f2d0e835514f0aecc6cbb31a7dabe6367d410bf#comments
# Thanks to https://github.com/smanross
# my @filter = ( "(sAMAccountName=${username})",
#               "(memberOf=cn=${vpngroup},${basedn})",
#               '(!(userAccountControl:1.2.840.113556.1.4.803:=2))',
#             );



my $bindname = $cfg->{LDAP}->{BINDUSER};
my $bindpassword = $cfg->{LDAP}->{BINDPASSWD};

syslog(LOG_INFO, "Attempting to authenticate bind user");

my $ldap;

if (not ($ldap = Net::LDAP->new($ldap_uri))) {
  syslog(LOG_ERR, "Connect to $ldap_uri failed, error: %m");
  closelog();
  exit 1;
}

my $result = $ldap->bind($bindname, password => $bindpassword);

if ($result->code()) {
  syslog(LOG_ERR, "LDAP binding failed (wrong user/password?), error: " . $result->error);
  closelog();
  exit 1;
}

$result =  $ldap->search( base => $basedn, filter => "(uid=${username})", attrs => ['entrydn'] );

my @entries = $result->entries;
my $dn = $entries[0]->get_value('entryDN');
#print $dn,"\n";

$ldap->unbind( );

syslog(LOG_INFO, "Attempting to authenticate $dn user");

if (not ($ldap = Net::LDAP->new($ldap_uri))) {
  syslog(LOG_ERR, "Connect to $ldap_uri failed, error: %m");
  closelog();
  exit 1;
}

$result = $ldap->bind($dn, password => $password);

if ($result->code()) {
  syslog(LOG_ERR, "LDAP User auth failed (wrong user/password?), error: " . $result->error);
  closelog();
  exit 1;
}

$result = $ldap->search( base => $basedn, filter => "(&" . join("", @filter) . ")" );

if ($result->code()) {
  syslog(LOG_ERR, "LDAP search failed, error: " . $result->error);
  closelog();
  exit 1;
}

my $count = $result->count();

if ($count == 1) {
  syslog(LOG_INFO, "User $username authenticated successfully");
} else {
  syslog(LOG_ERR, "User $username not authenticated (user not in group?)");
}

$ldap->unbind( );
closelog();

exit ($count == 1 ? 0 : 1);

