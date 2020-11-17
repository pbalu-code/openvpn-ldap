# openvpn-ldap
Improved LDAP client authentication for OpenVPN  
Origin version: https://github.com/waldner/openvpn-ldap     

Tested under Centos8

The script needs the **Net::LDAP** module to run (under Debian, it's called **libnet-ldap-perl**).
What it does is bind against the LDAP server using the given search username and password from config file, 
(this fails if the password or the username is not correct), and then performs an LDAP search for the auth user's DN and bind with it.
Verify that the user is a member of the specified group (that is, that the query returns one element as the result).

**Required rpms:**
- perl-LDAP
- perl-Sys-Syslog
- perl-Config-Tiny


If you're lazy or don't want to mess around with Perl, [ldap_auth.sh](https://github.com/waldner/openvpn-ldap/blob/master/ldap_auth.sh) is the very basic bash version of the perl script with basic bind auth (Without search).

This version, of course, needs the ldapsearch tool (under Debian, part of the **ldap-utils** package).

In both cases, the OpenVPN server needs to be told about the script and to use it with the option

```
auth-user-pass-verify /etc/openvpn/ldap_auth.pl via-env
```
You have to set LDAP's parameters in the perl-auth-ldap.conf file what should be in the same diretory as the perl script.

The **via-env** bit is what tells OpenVPN to pass the user credentials to the script via environment variables; another possibility is to use **via-file**, which instead puts them into a file, whose name is communicated to the script. All the details are in the man page for OpenVPN. An important detail is that if using **via-env**, we need to set **script-security 3** in the server configuration file, whereas with **via-file**, **script-security 2** is enough. It's trivial to modify the scripts to read from the file if using the via-file method.

The good thing about using the scripts is that the user-supplied credentials are used to perform the operations, so no sensitive password has to be stored in the script. On the other hand, the plugin-based solutions use a predefined user (well, distinguished name) and password, whose values need to be put in the plugin configuration file.

Some final notes: the scripts use syslog to log their progress (using the "auth" facility), and it's easy to extend them to check for membership of any group from a list (they can be ORed together in the query), or membership of more than one group (they can be ANDed); if doing so, the test that checks whether the LDAP query returned exactly one entry has to be adjusting accordingly, of course.
