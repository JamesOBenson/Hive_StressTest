[centos@client3 ~]$ cat stress.sh
#!/bin/bash

ulimit -u 20000

GROUP_NAME=group1
SLEEP=10
IPADDR="192.170.0.34"
BeelineUser=raj_ops
BeelinePass=raj_ops
RUNTIMES=5
TABLE="default.users"
PASSWORD=passworduser

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

function create_users_ipa () {
    for ii in {00..199}; do
        echo testpw | ipa user-add user$ii --first=Test --last="Test$ii" --password --shell=/bin/bash
        echo "testpw
        passworduser
        passworduser" | kinit user$ii
    done
}

function grant_users () {
    echo ""
    echo "Granting access to users in beeline..."
    echo ""
    for ii in {00..99}; do
        username="user$ii"
        beeline -u jdbc:hive2://$IPADDR:10000 -n $BeelineUser -p $BeelinePass --silent=true -e "grant select on table $TABLE to user $username"
        echo "[INFO]: ACCESS GRANTED TO <$username> IN BEELINE"
        wait
    done
}

function deny_users () {
    echo ""
    echo "Denying <$1> users access to beeline..."
    echo ""
    CMD=$1
    for i in `seq 1 $CMD`; do
        username=user$i
        beeline -u jdbc:hive2://$IPADDR:10000 -n $BeelineUser -p $BeelinePass --silent=true -e "revoke select on table $TABLE from user $username;"
        echo "[INFO]: ACCESS REVOKED TO <$username> IN BEELINE"
    done
}

function allow_groups () {
    echo ""
    echo "Allow $GROUP_NAME access to beeline..."
    echo ""
    beeline -u jdbc:hive2://$IPADDR:10000 -n $BeelineUser -p $BeelinePass --silent=true -e "grant select on table $TABLE to group $GROUP_NAME;";
    echo "[INFO]: ACCESS GRANTED TO <$GROUP_NAME> IN BEELINE"
}

function deny_groups () {
    echo ""
    echo "Denying $GROUP_NAME access to beeline..."
    echo ""
    beeline -u jdbc:hive2://$IPADDR:10000 -n $BeelineUser -p $BeelinePass --silent=true -e "revoke select on table $TABLE from group $GROUP_NAME;";
    echo "[INFO]: ACCESS REVOKED TO <$GROUP_NAME> IN BEELINE"
}

function query_users () {
    echo "[INFO] TESTING USER POLICIES"
    echo "Execute beeline query for <$(($2-$1))> users"
    echo ""
    FIRST=$1
    LAST=$2
    for i in `seq -f "%02g" $FIRST $LAST`; do
        username=user$i
        ( beeline -u jdbc:hive2://$IPADDR:10000 -n $username -p $PASSWORD --fastConnect=true -e "select * from $TABLE;" 1>/dev/null 2>>users.txt ) &
        echo "[INFO]: QUERRY SUBMITTED FOR $username"
    done
    wait
    reset
}

function query_groups () {
    echo "[INFO] TESTING GROUP POLICIES"
    echo "[INFO] Execute beeline query for <$(($2-$1))> users"
    echo ""
    FIRST=$1
    LAST=$2
    for i in `seq $FIRST $LAST`; do
        username=user$i
        ( beeline -u jdbc:hive2://$IPADDR:10000 -n $username -p $PASSWORD --fastConnect=true -e "select * from $TABLE;" 1>/dev/null 2>>groups.txt ) &
        echo "[INFO]: QUERRY SUBMITTED FOR $username"
    done
    wait
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
    echo "  query_users / query_groups"
    echo ""
    echo "Auto create users/groups and conduct tests:"
    echo ""
    echo "  Stress_users <FIRST USER> <LAST USER>"
    echo "  Stress_groups <FIRST USER> <LAST USER>"
    echo "      i.e. Stress_groups 100 120"
    echo "         this will execute the query for user100 -> user120"
    echo ""
    echo "  Stress N"
    echo "     This test includes post_processing"
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
        echo "Going to run this test $RUNTIMES."
        for i in `seq -f "%02g" $RUNTIMES`; do
            echo ""
            echo "[INFO] Test $i"
            echo ""
            query_users "$2" "$3"
            echo ""
            echo "[INFO] Stabilizing the system, sleeping $SLEEP seconds... please wait..."
            sleep $SLEEP
            post_processing
            echo ""
        done
        echo ""
    fi


    if [ $1 == "Stress_groups" ]; then
        echo "Going to run this test $RUNTIMES."
        for i in `seq -f "%02g" $RUNTIMES`; do
            echo ""
            echo "[INFO] Test $i"
            echo ""
            query_groups "$2" "$3"
            echo ""
            echo "[INFO] Stabilizing the system, sleeping $SLEEP seconds... please wait..."
            sleep $SLEEP
            post_processing
            echo ""
        done
        echo ""
        echo "        ./stress.sh post_processing"
    fi

    if [ $1 == "Stress" ]; then
        echo "Going to run this test $RUNTIMES."
        for i in `seq -f "%02g" $RUNTIMES`; do
            echo ""
            echo "[INFO] Test $i"
            echo ""
            query_users "0" "$2"
            echo ""
            echo "[INFO] Stabilizing the system, sleeping $SLEEP seconds... please wait..."
            sleep $SLEEP
            echo ""
            query_groups "100" "$((99+$2))"
            echo ""
            echo "[INFO] Stabilizing the system, sleeping $SLEEP seconds... please wait..."
            sleep $SLEEP
            post_processing
            echo ""
        done
    fi

    if [ $1 == "cleanup" ]; then
        cleanup "$2"
    fi
    if [ $1 == "query_users" ]; then
        query_users "$2" "$3"
    fi
    if [ $1 == "create_users" ]; then
        create_users "$2"
    fi
    if [ $1 == "allow_groups" ]; then
        allow_groups
    fi
    if [ $1 == "grant_users" ]; then
        grant_users
    fi
    if [ $1 == "post_processing" ]; then
        post_processing
    fi

}

main "$1" "$2" "$3"
