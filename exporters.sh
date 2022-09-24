#!/bin/bash

FULLPATH="$(realpath "$0")"
DIRPATH="$(dirname "$FULLPATH")"

exporters_list() {
    echo "
    1 - node_exporter
    2 - postgres_exporter
    3 - elasticsearch_exporter
    4 - redis_exporter"
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
    4)
        exporter="redis_exporter"
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
    4)
        if curl https://api.github.com/repos/oliver006/"$1"/releases/latest |
            grep -E "browser_download_url" |
            grep linux-"$architecture" |
            cut -d '"' -f 4 |
            wget -qi -; then
            echo "Package installation - [DONE]"
        else
            echo "Package installation - [FAILED]" && exit 1
        fi
        ;;
    *) echo "I cant find this exporter... try again" ;;
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
        cp "$DIRPATH"/systemd/"$1".service /etc/systemd/system/
        echo "Setup systemd - [DONE]"
        ;;
    2)
        read -p "Enter password for psql $1 user:" -r -s pg_pass
        if sudo -u postgres psql -c "create user $1 with password '$pg_pass';" &&
            sudo -u postgres psql -c "GRANT pg_monitor to $1;"; then
            echo "Setup user for postgres - [DONE]"
        else
            echo "Setup user for postgres - [FAILED]" && exit 1
        fi
        echo "Creating env file ..."
        cat < "$DIRPATH"/options/"$1".env > /opt/"$1"/.env &&
            chown -R "$1":"$1" /opt/"$1" &&
            sed -i "s/pg_user/$1/g" /opt/"$1"/.env &&
            sed -i "s/pg_pass/$pg_pass/g" /opt/"$1"/.env
        echo "Creating env file - [DONE]"
        echo "Setup systemd..."
        cp "$DIRPATH"/systemd/"$1".service /etc/systemd/system
        echo "Setup systemd - [DONE]"
        ;;
    3)
        ip_addr_to_bind
        cp "$DIRPATH"/systemd/"$1".service /etc/systemd/system &&
            sed -i "s/\/ip/\/$ip/" /etc/systemd/system/"$1".service
        echo "Setup systemd - [DONE]"
        ;;
    4)
        echo "Setup redis env..."
        ip_addr_to_bind
        read -p "Enter redis password: " -r -s redis_pass
        echo ""
        read -p "Enter redis port: " -r -s redis_port
        cat < "$DIRPATH"/options/"$1".env > /opt/"$1"/.env &&
            chown -R "$1":"$1" /opt/"$1" &&
            sed -i "s/redis_ip/$ip/g" /opt/"$1"/.env &&
            sed -i "s/redis_pass/$redis_pass/g" /opt/"$1"/.env &&
            sed -i "s/redis_port/$redis_port/g" /opt/"$1"/.env
        echo "Redis env - [DONE]"
        echo "Setup systemd..."
        cp "$DIRPATH"/systemd/"$1".service /etc/systemd/system
        echo "Setup systemd - [DONE]"
        ;;

    *) echo "Wrong number!!!" ;;
    esac
    systemctl daemon-reload
    systemctl enable "$1".service
    systemctl start "$1".service
    systemctl status "$1"
}       

ip_addr_to_bind() {
    ip -4 -j -br a | jq -r '.[] | select(.addr_info[0].local) | .ifname +" "+ .addr_info[0].local' | column -t
    read -p "Enter the network interface so that the exporter can connect to the service: " -r network_int
    ip=$(ip -4 addr show "$network_int" | grep -oP "(?<=inet ).*(?=/)")
    echo "IP that will bee used: $ip"
}


[[ $EUID -ne 0 ]] && echo "This script must be run as root." && exit 1

read -p "Do you want to install exporters? [yes/no]:" -r trigger
while [ "$trigger" != 'no' ]; do
    exporters_list
    read -p "Enter exporter num:" -r num
    exporters_setup "$num"
    read -p "Continue installation [yes/no]:" -r trigger
done
