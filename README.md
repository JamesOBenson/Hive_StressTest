# Hive_StressTest
This is designed to stress test a Hadoop Hive system by flooding it with query's and look at the response time.  This has been verified to work on HortonWorks Sandbox HDP 2.5 and an HDP 2.5 cluster, with LDAP as the authentication method.

**Note**: Stressing both users and groups creates N number of users.  The stress users test, looks at how the system will respond when they are given permission individually as users.  The stress groups test looks at how the system will respond when the users are given permission as a whole in a group.  All queries are conducted approximately at the same time.  The queries are executed in subshells so verify that your system ulimit is high, resources are adequate, etc. 

## This script has the following flow:
- Create a group: Group1 (locally)
- Create N number of users & join them to Group1 (locally)
- Grant users or groups access to Beeline
- Conduct a simple Query
- Conduct a Cleanup 
    - Deny Users & Groups from Beeline,
    - Delete users from unix system, 
    - Delete Group1 from unix system.

- Post processing will examine the results and return the: number of samples, min, max, and average time it took to conduct the query.

## Files created:
This script will create 4 files:
- users.txt (output of terminal while running user stress script)
- users.txt.bak (once post processing is complete)
- groups.txt (output of terminal while running group stress script)
- groups.txt.bak (once post processing is complete)
- user_results.txt (all user results get appended to this file)
- group_results.txt (all group results get appended to this file)

## How to run?
- Download script.
- Open script and:
  - Verify IP address in script matches the address needed to access beeline.
  - Verify Beeline admin user are correct.
  - Verify Beeline admin password are correct.
- Make script executable: chmod +x stress.sh
- For a list of options run: ./stress.sh
````
Welcome to Stress Test Script


Missing paramter. Please Enter one of the following options

Usage: ./stress.sh {Any of the options below}

N represents number of users to create and test

  create_users N
  grant_users N
  deny_users N

  allow_groups
  deny_groups

  query N

Auto create users/groups and conduct tests:

  Stress_users N
  Stress_groups N # users created with only 1 group
  Stress N

  cleanup N
  post_processing
````

- To execute a user stress test:
````
    ./stress.sh Stress_users 5
````

- To execute a group stress test:
````
    ./stress.sh Stress_groups 5
````

- To execute both a user and group stress test and conduct post processing:
````
    ./stress.sh Stress 5
````

- To execute the post processing:
````
   ./stress.sh post_processing
````


##How is this playbook licensed?

It's licensed under the Apache License 2.0. The quick summary is:

> A license that allows you much freedom with the software, including an explicit right to a patent. State changes means that you have to include a notice in each file you modified. 

[Pull requests](https://github.com/JamesOBenson/Hive_StressTest/pulls) and [Github issues](https://github.com/JamesOBenson/Hive_StressTest/issues) are welcome!

-- James
