#!/bin/bash

GROUP_NAME=GROUP1
SLEEP=30
IPADDR="10.245.123.233"
BeelineUser=raj_ops
BeelinePass=raj_ops

function create_users () {
    echo ""
    echo "Creating <$1> users ..."
    echo ""
    groupadd $GROUP_NAME
    echo "[INFO]: <$GROUP_NAME> CREATED"
    CMD=$1
    for i in `seq 1 $CMD`; do
        username=user$i
        adduser $username
        usermod -aG $GROUP_NAME $username
        echo "[INFO]: <$username> CREATED AND ADDED TO <$GROUP_NAME>"
    done
}

function grant_users () {
    echo ""
    echo "Granting access to <$1> users in beeline..."
    echo ""
    CMD=$1
    for i in `seq 1 $CMD`; do
        username=user$i
        beeline -u jdbc:hive2://$IPADDR:10000 -n $BeelineUser -p $BeelinePass --silent=true -e "grant select on table foodmart.customer to user $username"
        echo "[INFO]: ACCESS GRANTED TO <$username> IN BEELINE"
    done
    sleep 10
}

function deny_users () {
    echo ""
    echo "Denying <$1> users access to beeline..."
    echo ""
    CMD=$1
    for i in `seq 1 $CMD`; do
        username=user$i
        beeline -u jdbc:hive2://$IPADDR:10000 -n $BeelineUser -p $BeelinePass --silent=true -e "revoke select on table foodmart.customer from user $username;"
        echo "[INFO]: ACCESS REVOKED TO <$username> IN BEELINE"
    done
}

function allow_groups () {
    echo ""
    echo "Allow $GROUP_NAME access to beeline..."
    echo ""
    beeline -u jdbc:hive2://$IPADDR:10000 -n $BeelineUser -p $BeelinePass --silent=true -e "grant select on table foodmart.customer to group $GROUP_NAME;";
    echo "[INFO]: ACCESS GRANTED TO <$GROUP_NAME> IN BEELINE"
}

function deny_groups () {
    echo ""
    echo "Denying $GROUP_NAME access to beeline..."
    echo ""
    beeline -u jdbc:hive2://$IPADDR:10000 -n $BeelineUser -p $BeelinePass --silent=true -e "revoke select on table foodmart.customer from group $GROUP_NAME;";
    echo "[INFO]: ACCESS REVOKED TO <$GROUP_NAME> IN BEELINE"
}

function query () {
    echo ""
    echo "Execute beeline query for <$1> users"
    echo ""
    CMD=$1
    for i in `seq 1 $CMD`; do
        username=user$i
        beeline -u jdbc:hive2://$IPADDR:10000 -n $username -p $username --fastConnect=true -e "select * from foodmart.customer;" > out.txt &
        echo "[INFO]: QUERRY SUBMITTED FOR $username"
    done
}

function post_processing () {
    if [ -f ./users.txt ]; then
        echo "[INFO]: POST PROCESSING FOR users.txt"
        RESULTS=`cat users.txt | grep "seconds)" | awk '{print$4}' | cut -c 2- | \
            awk 'NR == 1 { max=$1; min=$1; sum=0 } \
                { if ($1>max) max=$1; if ($1<min) min=$1; sum+=$1;} \
                    END {printf "Min: %f\tMax: %f\tAverage: %f\tNo. of Samples:%d\n", min, max, sum/NR, NR}'`
        echo $RESULTS
        echo $RESULTS  >> user_results.txt
        echo "Results appended to user_results.txt"
#        cat users.txt | grep "seconds)" | awk '{print$4}' | cut -c 2-
        mv users.txt users.txt.bak
    else
        echo "[WARNING]: Post processing of users file was not conducted.  File does not exist."
    fi

    if [ -f ./groups.txt ] ; then
        echo "[INFO]: POST PROCESSING FOR groups.txt"
        RESULTS=`cat groups.txt | grep "seconds)" | awk '{print$4}' | cut -c 2- | \
            awk 'NR == 1 { max=$1; min=$1; sum=0 } \
                { if ($1>max) max=$1; if ($1<min) min=$1; sum+=$1;} \
                    END {printf "Min: %f\tMax: %f\tAverage: %f\tNo. of Samples:%d\n", min, max, sum/NR, NR}'`
        echo $RESULTS
        echo $RESULTS  >> group_results.txt
        echo "Results appended to group_results.txt"
#        cat groups.txt | grep "seconds)" | awk '{print$4}' | cut -c 2-
        mv groups.txt groups.txt.bak
    else
        echo "[WARNING]: Post processing of groups file was not conducted.  File does not exist."
    fi
}

function cleanup () {
    echo ""
    echo "Cleaning up."
    echo ""
    CMD=$1
    deny_groups
    deny_users "$CMD"
    for i in `seq 1 $CMD`; do
        echo "DELETING USER$i"
        username=user$i
        userdel -r -f $username
    done
    groupdel $GROUP_NAME
    rm -rf out.txt
}

function usage () {
    echo ""
    echo "Missing paramter. Please Enter one of the following options"
    echo ""
    echo "Usage: $0 {Any of the options below}"
    echo ""
    echo "N represents number of users to create and test"
    echo ""
    echo "  create_users N"
    echo "  grant_users N"
    echo "  deny_users N"
    echo ""
    echo "  allow_groups"
    echo "  deny_groups"
    echo ""
    echo "  query N"
    echo ""
    echo "Auto create users/groups and conduct tests:"
    echo ""
    echo "  Stress_users N"
    echo "  Stress_groups N # users created with only 1 group"
    echo ""
    echo "  cleanup N"
    echo "  post_processing"
}



function main () {
    echo ""
    echo "Welcome to Stress Test Script"
    echo ""

    if [ -z $1 ]; then
        usage
        exit 1
    fi

    if [ $1 == "Stress_users" ]; then
        result=`ps aux | grep -i "script users.txt" | grep -v "grep" | wc -l`
        if [ $result -ge 1 ]
        then
            create_users "$2"
            grant_users "$2"
            query "$2"
            echo "Sleeping $SLEEP seconds... please wait..."
            sleep $SLEEP
            cleanup "$2"
            echo ""
            echo "Please type 'exit' now and run post processing..."
            echo "        ./stress.sh post_processing"
            echo ""
        else
            echo "######################################"
            echo "# script is not running, please type: "
            echo "#           script users.txt"
            echo "# and try again"
            echo "######################################"
            exit 1
        fi
    fi

    if [ $1 == "Stress_groups" ]; then
        result=`ps aux | grep -i "script groups.txt" | grep -v "grep" | wc -l`
        if [ $result -ge 1 ]
        then
            create_users "$2"
            allow_groups
            echo "Sleeping $SLEEP seconds... please wait..."
            sleep $SLEEP
            query "$2"
            sleep $SLEEP
            cleanup "$2"
            echo ""
            echo "Please type 'exit' now and run post processing..."
            echo "        ./stress.sh post_processing"
            echo ""
        else
            echo "######################################"
            echo "# script is not running, please type: "
            echo "#           script groups.txt         "
            echo "# and try again"
            echo "######################################"
        fi
    fi

    if [ $1 == "cleanup" ]; then
        cleanup "$2"
    fi
    if [ $1 == "query" ]; then
        query "$2"
    fi
    if [ $1 == "create_users" ]; then
        create_users "$2"
    fi
    if [ $1 == "post_processing" ]; then
        post_processing
    fi
}

main "$1" "$2"
