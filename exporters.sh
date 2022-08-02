#!/bin/bash

FULLPATH="$(realpath "$0")"
DIRPATH="$(dirname "$FULLPATH")"

exporters_list() {
    echo "
        1 - node_exporter
        2 - postgres_exporter
        3 - elasticsearch_exporter"
}

exporters_setup() {
    exp_num=$1
    case $exp_num in
    1)
        exporter="node_exporter"
        exporters_config "$exporter" "$exp_num"
        ;;
    2)
        exporter="postgres_exporter"
        exporters_config "$exporter" "$exp_num"
        ;;
    3)
        exporter="elasticsearch_exporter"
        exporters_config "$exporter" "$exp_num"
        ;;
    *) echo "Wrong number!!!" ;;
    esac
}

exporters_config() {
    echo "$1 installation..."
    user_check=$(grep "$1" /etc/passwd | cut -d ":" -f 1)
    if [[ $user_check == "$1" ]]; then
        echo "User already exist...Skip this step"
    else
        useradd --no-create-home --shell /bin/false "$1"
        echo "Create user - [DONE]"
    fi
    echo "Download $1 package ..."
    architecture=$(dpkg --print-architecture)
    cd /opt || exit
    case $2 in
    1)
        if curl https://api.github.com/repos/prometheus/"$1"/releases/latest |
            grep -E "browser_download_url" |
            grep linux-"$architecture" |
            cut -d '"' -f 4 |
            wget -qi -; then
            echo "Package installation - [DONE]"
        else
            echo "Package installation - [FAILED]" && exit 1
        fi
        ;;
    [2-3])
        if curl https://api.github.com/repos/prometheus-community/"$1"/releases/latest |
            grep -E "browser_download_url" |
            grep linux-"$architecture" |
            cut -d '"' -f 4 |
            wget -qi -; then
            echo "Package installation - [DONE]"
        else
            echo "Package installation - [FAILED]" && exit 1
        fi
        ;;
    *) echo "I cant find this exporter... Try again" ;;
    esac
    if tar -xvf "$1"*.gz &&
        mv "$1"*64 "$1" &&
        rm "$1"*.gz &&
        cd "$1" || exit &&
        cp "$1" /usr/local/bin &&
        chown "$1":"$1" /usr/local/bin/"$1"; then
        echo "Preparing files - [DONE]"
    else
        echo "Preparing file - [FAILED]" && exit 1
    fi
    echo "Setup systemd unit file..."

    case $2 in
    1)
        cp "$DIRPATH"/services/"$1".service /etc/systemd/system/
        echo "Setup systemd - [DONE]"
        ;;
    2)
        read -p "Creating postgres exporter user... Enter password:" -r -s pg_pass
        if sudo -u postgres psql -c "create user $1 with password '$pg_pass';" &&
            sudo -u postgres psql -c "GRANT pg_monitor to $1;"; then
            echo "Setup user for postgres - [DONE]"
        else
            echo "Setup user for postgres - [FAILED]" && exit 1
        fi
        echo "Creating env file ..."
        cat <<  EOT >>"$1".env
#DATA_SOURCE_NAME="postgresql://username:password@localhost:5432/database-name?sslmode=disable"
DATA_SOURCE_NAME="postgresql://$1:$pg_pass@localhost:5432/postgres?sslmode=disable"
EOT
        chown "$1":"$1" /opt/"$1"/"$1".env &&
            cp "$DIRPATH"/services/"$1".service /etc/systemd/system/
        echo "Setup systemd - [DONE]"
        ;;
    3)
        ip=$(ip -4 addr show ens5 | grep -oP "(?<=inet ).*(?=/)")
        cp "$DIRPATH"/services/"$1".service /etc/systemd/system &&
            sed -i "s/ip/$ip/" /etc/systemd/system/"$1".service &&
            sed -i "s/exporter_name/$1/" /etc/systemd/system/"$1".service
        echo "Setup systemd - [DONE]"
        ;;
    *) echo "Wrong number!!!" ;;
    esac
    systemctl daemon-reload
    systemctl enable "$1".service
    systemctl start "$1".service
    systemctl status "$1"
}


[[ $EUID -ne 0 ]] && echo "This script must be run as root." && exit 1

read -p "Do you want to install exporters? [yes/no]:" -r trigger
while [ "$trigger" != 'no' ]; do
    exporters_list
    read -p "Enter exporter num:" -r num
    exporters_setup "$num"
    read -p "Continue installation [yes/no]:" -r trigger
done
