# openvpn-ldap
Simple LDAP client authentication for OpenVPN

Task: make sure that users connecting to the VPN server are authorized, that is, belong to a certain group in the LDAP database (say, "vpnauth"), which will be assumed to be a Windows AD controller here, although the idea should be applicable to other directory servers.

From a quick search, it seems that the most common way to authenticate OpenVPN users against LDAP is the [openvpn-auth-ldap] (https://github.com/threerings/openvpn-auth-ldap) module. It does work, however it's a bit clumsy to set up. There seems to be another LDAP authentication plugin floating around ([here](http://redmine.debuntu.org/projects/openvpn-ldap-auth/wiki) - broken link), which looks a bit better, but on the downside it looks like there are no binary packages available. In any case, I have not tried it.

But here we're going to make things simpler and use a simple script to do the authentication. The original source of inspiration was [here](http://dclavijo.blogspot.com.es/2010/01/openvpn-auth-con-ldap-y-perl.html) (spanish), which in turn got it from [here](https://github.com/threerings/openvpn-auth-ldap/issues/7#c8). In all cases, the idea is, as said, to check that the user is member of a specific group (and while doing so, also confirm that the username and password that the user supplied are correct).

For all these examples to work, the client configuration file needs to include the auth-user-pass option so the user is prompted for username and password when starting the connection (graphical tools like the windows GUI or NetworkManager also have ways to prompt the user for the same information).

Another thing to note is that, in addition to the classical distinguished name (DN) traditionally used to bind against LDAP, Microsoft LDAP also allows binding using the UPN (user@example.com) and the older EXAMPLE\user format (source: [this excellent post](http://blog.joeware.net/2008/05/03/1226/)). The two alternate forms are useful because they don't depend on where in the LDAP tree the user is, an information that instead is embedded in the DN and would make programmatic DN construction a bit difficult if connecting users belong to different OUs: it wouldn't be possible to just concatenate the username with some other fixed part. In these examples, we're going to use the user@example.com form (the UPN).

So [ldap_auth.pl](https://github.com/waldner/openvpn-ldap/blob/master/ldap_auth.pl) is a slightly refactored Perl script that can be used to check that the connecting user is authorized.

The script needs the **Net::LDAP** module to run (under Debian, it's called **libnet-ldap-perl**).
What it does is bind against the LDAP server using the given username and password (this fails if the password or the username is not correct), and then performs an LDAP query to verify that the user is active and is a member of the specified group (that is, that the query returns one element as the result).

Required rpms:
perl-LDAP
perl-Sys-Syslog
perl-Config-IniFiles (PowerTools module)


If you're lazy or don't want to mess around with Perl, [ldap_auth.sh](https://github.com/waldner/openvpn-ldap/blob/master/ldap_auth.sh) is the bash version of the same logic.

This version, of course, needs the ldapsearch tool (under Debian, part of the **ldap-utils** package).

In both cases, the OpenVPN server needs to be told about the script and to use it with the option

```
auth-user-pass-verify /etc/openvpn/ldap_auth.pl via-env
```
You have to set LDAP's parameters in the perl-auth-ldap.conf file what should be in the same diretory as the perl script.

The **via-env** bit is what tells OpenVPN to pass the user credentials to the script via environment variables; another possibility is to use **via-file**, which instead puts them into a file, whose name is communicated to the script. All the details are in the man page for OpenVPN. An important detail is that if using **via-env**, we need to set **script-security 3** in the server configuration file, whereas with **via-file**, **script-security 2** is enough. It's trivial to modify the scripts to read from the file if using the via-file method.

The good thing about using the scripts is that the user-supplied credentials are used to perform the operations, so no sensitive password has to be stored in the script. On the other hand, the plugin-based solutions use a predefined user (well, distinguished name) and password, whose values need to be put in the plugin configuration file.

Some final notes: the scripts use syslog to log their progress (using the "auth" facility), and it's easy to extend them to check for membership of any group from a list (they can be ORed together in the query), or membership of more than one group (they can be ANDed); if doing so, the test that checks whether the LDAP query returned exactly one entry has to be adjusting accordingly, of course.
