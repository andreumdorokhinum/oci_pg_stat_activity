#!/bin/bash

set_notification_threshold_timestamp(){
    printf "notification_threshold_timestamp=\"${1} ${2}\"\n" >> /etc/environment
}

get_vars(){
    source /etc/environment
}

flu_vars(){
    tmp=$(sed -e '/notification_threshold_timestamp=.*/d' /etc/environment)
    echo "${tmp}" > /etc/environment
    unset tmp notification_threshold_timestamp
}

start(){
    get_vars

    if [[ -z $notification_threshold_timestamp ]]; then
        set_notification_threshold_timestamp $(date '+%Y-%m-%d %H:%M:%S.%6N%:::z')
        get_vars
    fi

    notification_condition_and_timestamp=$(PGPASSWORD="${pwd}" psql --host "${host}" --port 5432 --dbname "${db}" --username "${uname}" <<< "\
            SELECT MAX(query_start)
              FROM pg_stat_activity
             WHERE query_start > '$notification_threshold_timestamp'
               AND query ILIKE 'INSERT INTO%'
             LIMIT 1;
             " | grep -E '\b[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{6}\+[0-9]{2}\b')

    if [[ -n $notification_condition_and_timestamp ]]; then
        oci ons message publish --title "Alert" --body "An insert query is running in your db" --topic-id ocid1.onstopic.oc1.aa-bbbbbbbbb-1.cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
        flu_vars
        set_notification_threshold_timestamp $notification_condition_and_timestamp
        unset notification_condition_and_timestamp
    fi
}

stop(){
    flu_vars
}

case $1 in
  start|stop) "$1" ;;
esac
