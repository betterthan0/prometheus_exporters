#!/bin/bash
# Exporters cleaner

# Default paths to clean
binary_file="/usr/local/bin/"
data_dir="/opt/"
systemd_unit="/etc/systemd/system/"


exporters_list () {
        echo "
        1 - node_exporter
        2 - postgres_exporter
        3 - elasticsearch_exporter"
}


exporters_cleaner () {
    exp_num=$1
    case $exp_num in
        1) 
            exporter="node_exporter" 
            exporters_config "$exporter"
            ;;
        2) 
            exporter="postgres_exporter" 
            exporters_config "$exporter"
            ;;
        3) 
            exporter="elasticsearch_exporter" 
            exporters_config "$exporter"
            ;;
        *) echo "Wrong number!!!";;
    esac
}


exporters_config () {
    echo "Clean $1 ..."
        if rm "$binary_file""$1" \
            && rm -r "$data_dir""$1" \
            && rm "$systemd_unit""$1".service;
        then echo "Clean - [DONE]"; exit 0
        else echo "Clean - [FAILED]"; exit 1
        fi

        echo "Clean deletes unit file ..."
        if systemctl reset-failed \
            && systemctl daemon-reload;
        then echo "Clean - [DONE]"; exit 0
        else echo "Clean - [FAILED]" exit 1
        fi

}


exporters_cleaner "$1"
