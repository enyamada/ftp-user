#!/bin/bash

function create_extra_dirs {
  
   BASE_DIR=$1
   MY_UID=$2

   LIST_SUBDIRS='OCOREN CTE log NOTFIS'
  
   for sd in $LIST_SUBDIRS; do
      mkdir $BASE_DIR/$sd
      chown $MY_UID:$MY_UID $BASE_DIR/$sd
   done
 
   # Log directory should be read-only
   chmod a-w $BASE_DIR/log
 
   # Create NOTFIS/Backup, read-only too
   mkdir $BASE_DIR/NOTFIS/Backup
   chown $MY_UID:$MY_UID $BASE_DIR/NOTFIS/Backup
   chmod a-w $BASE_DIR/NOTFIS/Backup
   
   
}



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

# Make sure bc and pwgen are installed.
test -n "$NEW_PASS" || type pwgen >/dev/null 2>&1 || echo "please install packet pwgen first"
type bc >/dev/null 2>&1 || echo "please install packet bc first"
test -n "$NEW_PASS" || type pwgen >/dev/null 2>&1 || exit 1
type bc >/dev/null 2>&1 || exit 1

# -u option is mandatory
test -z "$NEW_USER" && echo "please give username to create"
test -z "$NEW_USER" && exit 1

# Get the new user uid 
# If if it's the first initialize the ftpd passwd and group files and 
# set the uid to 20001. Otherwise, the new uid should be the latest+1.
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
        mkdir -p /etc/proftpd
        touch /etc/proftpd/ftpd.passwd
        touch /etc/proftpd/ftpd.group
        chmod +r /etc/proftpd/ftpd.passwd /etc/proftpd/ftpd.group
        NEW_UID=20001
fi



#NEW_USER=$1
#NEW_PASS=$2
#NEW_HOME=$3
#BATCHRUN=$4

# If we should create a new user and both provider and user were given
if test -n "$LOGISTIC_PROVIDER" && test -n  "$CREATE_USER" && test -n "$NEW_USER"
then

        # Initialize the password and/or homedir name if none were given
        test -z "$NEW_PASS" && NEW_PASS=`pwgen -1`
        test -z "$NEW_HOME" && NEW_HOME=$NEW_USER

        # Create new user home dir with proper ownership/permissions
        mkdir -p $FTP_ROOT/$NEW_HOME
        chown $NEW_UID:$NEW_UID $FTP_ROOT/$NEW_HOME
        chmod a+rw $FTP_ROOT/$NEW_HOME

        # Create the new user using ftpasswd
        output=`echo $NEW_PASS | ftpasswd --file=/etc/proftpd/ftpd.passwd --passwd --stdin  --name $NEW_USER --uid $NEW_UID --gid $NEW_UID --home $FTP_ROOT/$NEW_HOME --shell /bin/false 2| grep -v -e false -e PAM -e adjusted -e ^$`
        output_err=$?
        echo $output

        # If user created successfully
        if test $output_err -eq 0
        then
                # Say the user and password created
                echo you can change later password with e.g.:
                echo "echo $NEW_PASS | ftpasswd --file=/etc/proftpd/ftpd.passwd --passwd --stdin --change-password --name $NEW_USER"
                echo
                echo User: "$NEW_USER"
                echo Password: "$NEW_PASS"
                echo

                # And for each provider...
                for PROVIDER in $LOGISTIC_PROVIDER
                do

                        # Create a new user using the user-provider format.
                        # Uid/password should be generated as usual.
                        MAX_UID=`cut -d : -f 3 /etc/proftpd/ftpd.passwd | sort -n | tail -1`
                        NEW_UID=`echo $MAX_UID+1 | bc`
                        NEW_PASS=`pwgen -1`

                        # Create home dir under user homedir with proper ownership
                        mkdir -p $FTP_ROOT/$NEW_HOME/$PROVIDER
                        chown $NEW_UID:$NEW_UID $FTP_ROOT/$NEW_HOME/$PROVIDER
                        chmod a+rw $FTP_ROOT/$NEW_HOME/$PROVIDER

                        # Create extra dirs as asked by SR
                        create_extra_dirs  $FTP_ROOT/$NEW_HOME/$PROVIDER $NEW_UID
 
                        # Create new user-provider login using ftpasswd and 
                        # display data
                        echo $NEW_PASS | ftpasswd --file=/etc/proftpd/ftpd.passwd --passwd --stdin  --name ` echo "$NEW_USER-$PROVIDER" | tr '[:upper:]' '[:lower:]'` --uid $NEW_UID --gid $NEW_UID --home $FTP_ROOT/$NEW_HOME/$PROVIDER --shell /bin/false 2| grep -v -e false -e PAM -e adjusted -e ^$ -e "using alternate file" -e entry
                        echo User: `echo "$NEW_USER-$PROVIDER" | tr '[:upper:]' '[:lower:]'`
                        echo Password: "$NEW_PASS"
                        echo
                done
        else
                echo problem by creating user "$NEW_USER" with pass "$NEW_PASS".
                exit $output_err;
        fi

# If provider and user were passed in, but not -c, then the providers should
# be added to an existing user.
elif  test -n "$LOGISTIC_PROVIDER" && test -z "$CREATE_USER" && test -n "$NEW_USER"
then
echo "Adding "$LOGISTIC_PROVIDER" to "$NEW_USER
echo
test -z "$NEW_HOME" && NEW_HOME=$NEW_USER

        # For each provider specified...
        for PROVIDER in $LOGISTIC_PROVIDER
                do

                        # Create a new user using user-provider format.
                        # Uid and password should be generated as usual.
                        MAX_UID=`cut -d : -f 3 /etc/proftpd/ftpd.passwd | sort -n | tail -1`
                        NEW_UID=`echo $MAX_UID+1 | bc`
                        NEW_PASS=`pwgen -1`
                        mkdir -p $FTP_ROOT/$NEW_HOME/$PROVIDER
                        chown $NEW_UID:$NEW_UID $FTP_ROOT/$NEW_HOME/$PROVIDER
                        chmod a+rw $FTP_ROOT/$NEW_HOME/$PROVIDER

                        # Create extra dirs as asked by SR
                        create_extra_dirs  $FTP_ROOT/$NEW_HOME/$PROVIDER $NEW_UID

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



