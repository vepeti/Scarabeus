#!/bin/bash

# push or pull
METHOD=push

SSH_HOST=0.0.0.0
SSH_USER=root
SSH_PORT=22
SSH_KEY=

LOCAL_DB_USER=root
LOCAL_DB_PASS=

REMOTE_DB_USER=root
REMOTE_DB_PASS=

DBS=(db1 db2 db3)

SSHCON=0

if [ -z $SSH_KEY ]
then
    ssh-keygen -q -t rsa -b 2048 -N '' -f tempkey
    ssh-copy-id -i tempkey "$SSH_USER@$SSH_HOST -p $SSH_PORT" 1>/dev/null
    SSH_KEY=tempkey
    SSHCON="ssh -p $SSH_PORT -i $SSH_KEY $SSH_USER@$SSH_HOST"
fi

SSHOK=$($SSHCON echo 1 2>&1)

if [ ! -z $SSHOK ] && [ $SSHOK -ne 0 ]
then
    if [ -z $LOCAL_DB_PASS ]
    then
	LOCAL_DB_PASS=$(cat ~/.my.cnf | grep password | sed -r 's/^.*="?(.+)"?/\1/g')
    fi

    if [ -z $REMOTE_DB_PASS ]
    then
	REMOTE_DB_PASS=$($SSHCON "cat ~/.my.cnf | grep password | sed -r 's/^.*=\"(.+)\"/\1/g'")
    fi

    if [ $METHOD == "push" ]
    then
	for element in ${DBS[@]}
	do
	    if mysql -u$LOCAL_DB_USER -p"$LOCAL_DB_PASS" -e "use $element" 2>/dev/null
	    then
		echo -n "Transferring database $element... "
		$SSHCON "mysql -u$REMOTE_DB_USER -p\"$REMOTE_DB_PASS\" -e 'CREATE DATABASE IF NOT EXISTS $element'"
		mysqldump --routines -u$LOCAL_DB_USER -p"$LOCAL_DB_PASS" $element | $SSHCON "mysql -u$REMOTE_DB_USER -p\"$REMOTE_DB_PASS\" $element"
		echo "Done!"
	    else
		echo "$element database doesn't exist! Ignoring..."
	    fi
	done
    elif [ $METHOD == "pull" ]
    then
	for element in ${DBS[@]}
	do
	    if $SSHCON "mysql -u$REMOTE_DB_USER -p\"$REMOTE_DB_PASS\" -e \"use $element\"" 2>/dev/null
	    then
		echo -n "Transferring database $element..."
		mysql -u$LOCAL_DB_USER -p"$LOCAL_DB_PASS" -e "CREATE DATABASE IF NOT EXISTS $element" 2>/dev/null
		$SSHCON "mysqldump --routines -u$REMOTE_DB_USER -p\"$REMOTE_DB_PASS\" $element 2>/dev/null" | mysql -u$LOCAL_DB_USER -p"$LOCAL_DB_PASS" $element 2>/dev/null
		echo "Done!"
	    else
		echo "$element database doesn't exist! Ignoring..."
	    fi
	done
    else
	echo "Invalid method! Exiting..."
    fi
else
    echo "Can't connect to $SSH_HOST"
fi

if [ -f tempkey ]
then
    TEMPKEYPUB=$(cat tempkey.pub)
    $SSHCON "grep -v -P '\Q$TEMPKEYPUB\E' ~/.ssh/authorized_keys > ~/.ssh/authorized_keys_temp"
    $SSHCON "cat ~/.ssh/authorized_keys_temp > ~/.ssh/authorized_keys && rm ~/.ssh/authorized_keys_temp"
    rm tempkey tempkey.pub
fi
exit 0
