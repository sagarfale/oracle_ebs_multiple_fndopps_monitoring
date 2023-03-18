#!/bin/bash
########################################################################################################
# Name          : oraebs-checks-fndopp-ora.sh
# Author        : Sagar Fale
# Date          : 29/12/2022
#
# Description:  - This script will check if DB is up and running
#
# Usage         : oraebs-checks-fndopp-ora.sh - v2
#
#
# Modifications :
#
# When         Who               What
# ==========   ===========    ================================================================
# 29/12/2022   Sagar Fale     Initial draft version
# 31/12/2022   Sagar Fale     adding db down logic
# 12/01/2022   Sagar Fale     addition of multiple FNDOPP logic
########################################################################################################

script_base=/home/oracle/scripts_itc
HOSTNAME=`hostname`
mkdir -p /home/oracle/scripts_itc/log
HOST=`hostname | awk -F\. '{print $1}'`
tlog=`date "+ora_fndopp_check-%d%b%Y_%H%M".log`
script_base=/home/oracle/scripts_itc
logfile=`echo /home/oracle/scripts_itc/log/${tlog}`

OPP_HOSTNAME=$(echo ${HOSTNAME} | sed 's/\..*//g' | tr '[:lower:]' '[:upper:]')

apps_pass=`cat ${script_base}/.appspass`
. /u01/install/APPS/EBSapps.env run

MAIL_LIST=sagar.fale@gmail.com

sendemail_notify()
   {
      (
         echo "Subject: ${tempvalue}"
         echo "TO: $MAIL_LIST"
         echo "FROM: test@test.com"
         echo "MIME-Version: 1.0"
         echo "Content-Type: text/html"
         echo "Content-Disposition: inline"
      )  | /usr/sbin/sendmail $MAIL_LIST
}

sendemail_notify_t()
   {
      (
         echo "Subject: ${tempvalue}"
         echo "TO: $MAIL_LIST"
         echo "FROM: test@test.com"
         echo "MIME-Version: 1.0"
         echo "Content-Type: text/html"
         echo "Content-Disposition: inline"
         cat ${attachement_name}
      )  | /usr/sbin/sendmail $MAIL_LIST -t
}


fndopp_check()
{

sqlplus -s apps/${apps_pass} <<EOF > /tmp/queue-fndopp.log
   set feedback off pause off pagesize 0 verify off linesize 500 term off
   set pages 80
   set head off
   set line 120
   set echo off
   select  TARGET_PROCESSES||':'||RUNNING_PROCESSES||':'|| NODE_NAME  from fnd_concurrent_queues  where node_name='${OPP_HOSTNAME}' and CONCURRENT_QUEUE_NAME like  '%FNDCPOPP%';
EOF

grep -v '^$' /tmp/queue-fndopp.log > /tmp/queue-fndopp.filtered.log


#!/bin/bash

# Read each line of the file
while read line; do
  # Skip blank lines
  if [[ -z "$line" ]]; then
    continue
  fi

  # Extract the actual processes, target processes, and node name
  actual_processes=$(echo "$line" | awk -F':' '{print $1}')
  target_processes=$(echo "$line" | awk -F':' '{print $2}')
  node_name=$(echo "$line" | awk -F':' '{print $3}')

  # Check if the node name is blank
  if [[ -z "$node_name" ]]; then
    echo "Error: Node name is blank in line: $line"
    NODE_NAME_NULL='Y'
    # Perform some action, such as sending an email or logging a message
    continue
  else 
    NODE_NAME_NULL='N'
  fi

  # Check if the actual and target processes are equal
  if [[ "$actual_processes" -eq "$target_processes" ]]; then
    echo "Actual and target processes are equal for node $node_name"
    # Perform some action, such as sending an email or logging a message
    ACTUAL_TARGET_PROCESSES='Y'
  else
    echo "Actual and target processes are not equal for node $node_name"
    ACTUAL_TARGET_PROCESSES='N'
    # Perform some action, such as sending an email or logging a message
  fi

done < /tmp/queue-fndopp.filtered.log



target_proc=`sqlplus -s apps/${apps_pass} <<EOF
   set feedback off pause off pagesize 0 verify off linesize 500 term off
   set pages 80
   set head off
   set line 120
   set echo off
   select TARGET_PROCESSES from fnd_concurrent_queues where node_name='${OPP_HOSTNAME}' and CONCURRENT_QUEUE_ID= (select CONCURRENT_QUEUE_ID from FND_CONCURRENT_QUEUES where node_name='${OPP_HOSTNAME}' and CONCURRENT_QUEUE_NAME like '%FNDCPOPP%'); 
EOF
` 

sqlplus -s apps/${apps_pass} <<EOF > ${script_base}/pid.data
   set feedback off pause off pagesize 0 verify off linesize 500 term off
   set pages 80
   set head off
   set line 120
   set echo off
   select OS_PROCESS_ID  from  fnd_concurrent_processes where node_name='${OPP_HOSTNAME}' and process_status_code='A' and  CONCURRENT_QUEUE_ID=(select CONCURRENT_QUEUE_ID from  FND_CONCURRENT_QUEUES where node_name='${OPP_HOSTNAME}' and CONCURRENT_QUEUE_NAME like '%FNDCPOPP%');
   exit
EOF

sed -i  '/\S/!d' ${script_base}/pid.data

count=0
for i in `cat ${script_base}/pid.data`
do
ps -ef |grep  DCLIENT_PROCESSID=$i | grep -v grep
if [ $? -eq 0 ] ; then 
echo "Process is running."
count=$((${count}+1)) 
else 
echo "invalid process"
fi 
echo "Count is $count"
done	
echo "main count is : $count"

ps -ef | grep FNDOPP | grep -v grep | awk '{sub("-Dlogfile=","",$23); print $2 ":" $23}' > /tmp/fndopp_pid_log_details.log 

rm -rf /tmp/log_file_updated.txt

while read -r line; do
    # Extract the PID, log file path, and log file name from the line
    pid=$(echo "$line" | awk -F':' '{print $1}')
    log_file=$(echo "$line" | awk -F':' '{print $2}')
    #log_file_name=$(echo "$log_file" | awk -F'/' '{print $NF}')
    log_file_name="$log_file"
    # Check if the process with the given PID is running
    if ps -p "$pid" > /dev/null; then
        # Get the last modification time of the log file in epoch format
        last_mod_time=$(date +%s -r "$log_file")

        # Calculate the difference between the current time and the last modification time
        time_diff=$((current_time - last_mod_time))

        # Check if the log file has been updated within the last 30 minutes
        if [ "$time_diff" -le 1800 ]; then
            #echo "<p>PID $pid is running and its logfile $log_file_name has been updated within the last 30 minutes.</p>"
            echo "<p><span style=\"color:green;\">PID $pid is running and its logfile $log_file has been updated within the last 30 minutes.</span></p>"
            LOG_FILE_UPDATION='Y'
        else
            #echo "<p>WARNING: PID $pid is running but its logfile $log_file_name has not been updated within the last 30 minutes.</p>"
            echo "<p><span style='color:red;'>WARNING: PID $pid is running but its logfile $log_file has not been updated within the last 30 minutes.</span></p>"
            LOG_FILE_UPDATION='N'
            if [ "$LOG_FILE_UPDATION" == 'N' ]; then
              echo "N" > /tmp/log_file_updated.txt
            fi
        fi
    else
        echo "<p>WARNING: PID $pid is not running.</p>"
    fi
done < /tmp/fndopp_pid_log_details.log > output.html

if [[ -f /tmp/log_file_updated.txt && $(cat /tmp/log_file_updated.txt) == "N" ]]; then
  LOG_FILE_UPDATION_VAR='NO'
else
  LOG_FILE_UPDATION_VAR='YES'
fi


## imp one 

echo "target_proc is $target_proc"
echo "count is $count"
echo "ACTUAL_TARGET_PROCESSES is $ACTUAL_TARGET_PROCESSES"
echo "NODE_NAME_NULL is $NODE_NAME_NULL"
echo "LOG_FILE_UPDATION is $LOG_FILE_UPDATION"
echo "LOG_FILE_UPDATION_VAR is $LOG_FILE_UPDATION_VAR"

#[ ${target_proc} -eq ${count} ] && echo "Target process and count is equal $target_proc:$count "
#[ "${ACTUAL_TARGET_PROCESSES}" == 'Y' ] && echo "ACTUAL_TARGET_PROCESSES are equal"
#[ "${NODE_NAME_NULL}" == 'N' ] && echo "Node_name is NOT NULL"
#[ "${LOG_FILE_UPDATION}" == 'Y' ] && echo "Logfile is getting updated"

if [ ${target_proc} -eq ${count} ]; then echo "Target process matching count"; else echo "Target process matching count"; fi
if [ "${ACTUAL_TARGET_PROCESSES}" == 'Y' ]; then echo "ACTUAL_TARGET_PROCESSES are equal"; else echo "ACTUAL_TARGET_PROCESSES NOT are equal"; fi
if [ "${NODE_NAME_NULL}" == 'N' ]; then echo "Node_name is not NULL"; else echo "Node_name is NULL"; fi
if [ "${LOG_FILE_UPDATION}" == 'Y' ]; then echo "Logfile is getting updated"; else echo "Logfile is NOT getting updated"; fi

if [ ${target_proc} -eq ${count} ] && [ "${ACTUAL_TARGET_PROCESSES}" == 'Y' ] && [ "${NODE_NAME_NULL}" == 'N' ] && [ "${LOG_FILE_UPDATION_VAR}" == 'YES' ]; then 
echo "Passed"
else 
echo "Failed"
   sqlplus -s apps/${apps_pass} <<EOF
               set feedback off pause off pagesize 0 verify off linesize 500 term off
               set pages 80
               set head on
               set line 120
               set echo off
               set pagesize 50000
               col CONCURRENT_QUEUE_NAME for a25
               col node_name for a20
               set markup html on
               spool fndopp.html
               select NODE_NAME,TARGET_PROCESSES,RUNNING_PROCESSES from fnd_concurrent_queues  where node_name='${OPP_HOSTNAME}' and CONCURRENT_QUEUE_NAME like  '%FNDCPOPP%';
               select  distinct  CONCURRENT_QUEUE_NAME , NODE_NAME  from  FND_CONCURRENT_QUEUES where CONCURRENT_QUEUE_NAME like '%OPP%';
               select to_char(PROCESS_START_DATE,'dd-mm-yy:hh24:mi:ss') START_DATE ,CONCURRENT_PROCESS_ID,  
              decode(PROCESS_STATUS_CODE, 
            'A','Active',
            'C','Connecting',
            'D','Deactiviating',
            'G','Awaiting Discovery',
            'K','Terminated',
            'M','Migrating',
            'P','Suspended',
            'R','Running',
            'S','Deactivated',
            'T','Terminating',
            'U','Unreachable',
            'Z' ,'Initializing') STATUS,gsm_internal_info from  fnd_concurrent_processes where node_name='${OPP_HOSTNAME}' and CONCURRENT_QUEUE_ID in (select  CONCURRENT_QUEUE_ID from  FND_CONCURRENT_QUEUES where node_name='${OPP_HOSTNAME}' and CONCURRENT_QUEUE_NAME like '%FNDCPOPP%') order by PROCESS_START_DATE  desc;
            set markup html off
            spool off
            exit
EOF
cat fndopp.html >> output.html 
tempvalue="DRY -RUN  WTW : Issues with FNDOPP on $TWO_TASK : $HOSTNAME"
attachement_name='output.html'
#attachement_name='fndopp.html'
sendemail_notify_t ${attachement_name}
fi
}


   output3=`sqlplus -s apps/${apps_pass} <<EOF
   set feedback off pause off pagesize 0 heading off verify off linesize 500 term off
   select open_mode  from v\\$DATABASE;
   exit
EOF
`
   if [ "$output3" = "READ WRITE" ] 
   then 
   date  >> ${logfile}
   echo "Calling function to check FNDOPP.." >> ${logfile}
   fndopp_check
   else
   date  >> ${logfile}
   echo "DB is not up and running" >> ${logfile}
   tempvalue="DB NOT RUNNING on $TWO_TASK : $HOSTNAME"
   sendemail_notify
   fi
