#!/bin/bash

# passed by openvpn (in the environment):
#
# $username
# $password

ourname=ldap_auth.sh
facility=auth

ldapserver=windowsdc
domain=example.com

vpngroup=vpnauth
basedn='ou=Users,dc=example,dc=com'

bindname=${username}@${domain}

declare -a query

# writing the query this way is useful because it's easier to
# include it in the log; using an array instead of a string is
# safer, see http://mywiki.wooledge.org/BashFAQ/050

query[0]='-L'
query[1]='-s'
query[2]='sub'
query[3]='-x'
query[4]='-w'
query[5]="${password}"
query[6]='-D'
query[7]="${bindname}"
query[8]='-b'
query[9]="${basedn}"
query[10]='-H'
query[11]="ldap://${ldapserver}.${domain}"

# query can/should be customized
query[12]="(&(sAMAccountName=${username})(memberOf=cn=${vpngroup},${basedn})(accountStatus=active))"
# using userAccountControl seems to work better at detecting active users
# see https://github.com/waldner/openvpn-ldap/commit/9f2d0e835514f0aecc6cbb31a7dabe6367d410bf#comments
# query[12]="(&(sAMAccountName=${username})(memberOf=cn=${vpngroup},${basedn})(!(userAccountControl:1.2.840.113556.1.4.803:=2))    )"

query[13]='dn'

output=$(mktemp)
error=$(mktemp)

# clean temp files when we terminate
trap "rm -f ${output} ${error}" EXIT

logger -p "${facility}.info" -t "$ourname" "Trying to authenticate user ${bindname} against AD"

ldapsearch "${query[@]}" 1>"${output}" 2>"${error}"

# save exist status here, otherwise the following assignment resets $?
status=$?

query[5]='xxxxxxxxx'   # obfuscate password to put query in the logs

if [ $status -ne 0 ]; then
  logger -p "${facility}.err" -t "${ourname}" "There was an error authenticating user ${username} (${bindname}) against AD."
  logger -p "${facility}.err" -t "${ourname}" "The query was: ldapsearch ${query[*]}"
  logger -p "${facility}.err" -t "${ourname}" "The error was: $(tr '\n' ' ' < "${error}" )"  # turn multiline into single line
  exit 1
fi

# look for the "numEntries" line in the output of ldapsearch
numentries=$(awk '/numEntries:/{ne = $3} END{print ne + 0}' "$output")

if [ $numentries -eq 1 ]; then
  logger -p "${facility}.info" -t "{$ourname}" "User ${username} authenticated successfully"
  exit 0
else
  logger -p "${facility}.err" -t "${ourname}" "User ${username} NOT authenticated (user not in group?)"
  logger -p "${facility}.err" -t "${ourname}" "The query was: ldapsearch ${query[*]}"
  exit 1
fi

