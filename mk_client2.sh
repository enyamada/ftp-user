#!/bin/bash


FTP_ROOT=/home/ftp
while getopts u:p:h:l:c: opts; do
   case $opts in
      u) NEW_USER=$OPTARG ;;
      p) NEW_PASS=$OPTARG ;;
      h) NEW_HOME=$OPTARG ;;
      l) LOGISTIC_PROVIDER=$OPTARG ;;
      c) CREATE_USER=$OPTARG ;;
   esac
done


test -n "$NEW_PASS" || type pwgen >/dev/null 2>&1 || echo "please install packet pwgen first"
type bc >/dev/null 2>&1 || echo "please install packet bc first"
test -n "$NEW_PASS" || type pwgen >/dev/null 2>&1 || exit 1
type bc >/dev/null 2>&1 || exit 1

test -z "$NEW_USER" && echo "please give username to create"
test -z "$NEW_USER" && exit 1

if test -f "/etc/proftpd/ftpd.passwd"
then
        MAX_UID=`cut -d : -f 3 /etc/proftpd/ftpd.passwd | sort -n | tail -1`
        if test -n "$MAX_UID"
        then
                NEW_UID=`echo $MAX_UID+1 | bc`
        else
                NEW_UID=20001
        fi
else
        touch /etc/proftpd/ftpd.passwd
        touch /etc/proftpd/ftpd.group
        NEW_UID=20001
fi



#NEW_USER=$1
#NEW_PASS=$2
#NEW_HOME=$3
#BATCHRUN=$4


if test -n "$LOGISTIC_PROVIDER" && test -n  "$CREATE_USER" && test -n "$NEW_USER"
then

        test -z "$NEW_PASS" && NEW_PASS=`pwgen -1`
        test -z "$NEW_HOME" && NEW_HOME=$NEW_USER

        mkdir -p $FTP_ROOT/$NEW_HOME
        chown $NEW_UID:$NEW_UID $FTP_ROOT/$NEW_HOME
        chmod a+rw $FTP_ROOT/$NEW_HOME
        output=`echo $NEW_PASS | ftpasswd --file=/etc/proftpd/ftpd.passwd --passwd --stdin  --name $NEW_USER --uid $NEW_UID --gid $NEW_UID --home $FTP_ROOT/$NEW_HOME --shell /bin/false 2| grep -v -e false -e PAM -e adjusted -e ^$`
        output_err=$?
        echo $output
        if test $output_err -eq 0
        then

                echo you can change later password with e.g.:
                echo "echo $NEW_PASS | ftpasswd --file=/etc/proftpd/ftpd.passwd --passwd --stdin --change-password --name $NEW_USER"
                echo
                echo User: "$NEW_USER"
                echo Password: "$NEW_PASS"
                echo
                for PROVIDER in $LOGISTIC_PROVIDER
                do
                        MAX_UID=`cut -d : -f 3 /etc/proftpd/ftpd.passwd | sort -n | tail -1`
                        NEW_UID=`echo $MAX_UID+1 | bc`
                        NEW_PASS=`pwgen -1`
                        mkdir -p $FTP_ROOT/$NEW_HOME/$PROVIDER
                        chown $NEW_UID:$NEW_UID $FTP_ROOT/$NEW_HOME/$PROVIDER
                        chmod a+rw $FTP_ROOT/$NEW_HOME/$PROVIDER
                        echo $NEW_PASS | ftpasswd --file=/etc/proftpd/ftpd.passwd --passwd --stdin  --name ` echo "$NEW_USER-$PROVIDER" | tr '[:upper:]' '[:lower:]'` --uid $NEW_UID --gid $NEW_UID --home $FTP_ROOT/$NEW_HOME/$PROVIDER --shell /bin/false 2| grep -v -e false -e PAM -e adjusted -e ^$ -e "using alternate file" -e entry
                        echo User: `echo "$NEW_USER-$PROVIDER" | tr '[:upper:]' '[:lower:]'`
                        echo Password: "$NEW_PASS"
                        echo
                done
        else
                echo problem by creating user "$NEW_USER" with pass "$NEW_PASS".
                exit $output_err;
        fi

elif  test -n "$LOGISTIC_PROVIDER" && test -z "$CREATE_USER" && test -n "$NEW_USER"
then
echo "Adding "$LOGISTIC_PROVIDER" to "$NEW_USER
echo
test -z "$NEW_HOME" && NEW_HOME=$NEW_USER
        for PROVIDER in $LOGISTIC_PROVIDER
                do
                        MAX_UID=`cut -d : -f 3 /etc/proftpd/ftpd.passwd | sort -n | tail -1`
                        NEW_UID=`echo $MAX_UID+1 | bc`
                        NEW_PASS=`pwgen -1`
                        mkdir -p $FTP_ROOT/$NEW_HOME/$PROVIDER
                        chown $NEW_UID:$NEW_UID $FTP_ROOT/$NEW_HOME/$PROVIDER
                        chmod a+rw $FTP_ROOT/$NEW_HOME/$PROVIDER
                        echo $NEW_PASS | ftpasswd --file=/etc/proftpd/ftpd.passwd --passwd --stdin  --name ` echo "$NEW_USER-$PROVIDER" | tr '[:upper:]' '[:lower:]'` --uid $NEW_UID --gid $NEW_UID --home $FTP_ROOT/$NEW_HOME/$PROVIDER --shell /bin/false 2| grep -v -e false -e PAM -e adjusted -e ^$ -e "using alternate file" -e entry
                        echo User: `echo "$NEW_USER-$PROVIDER" | tr '[:upper:]' '[:lower:]'`
                        echo Password: "$NEW_PASS"
                        echo
                done
else
       if test $? -eq 1
       then
              echo "Usage ./mk_client2.sh -u new_user -l "LP1 LP2" -c yes(to create the user) "

               exit 2;
       else
               if `echo $output | grep -q created`
               then
                       exit 0;
               else
                       echo "Usage ./mk_client2.sh -u new_user -l "LP1 LP2" -c yes(to create the user) "
                        exit 1;
               fi
       fi
fi



