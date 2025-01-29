#!/bin/bash
#this is script for os install on KMA


################## network setting #################
# IP 주소와 연결 이름(con-name) 입력 받기
read -p "변경할 IP 주소를 입력하세요(default subnet 24): " IP_ADDRESS
read -p "변경할 GATEWAY 주소를 입력하세요: " GATEWAY
read -p "bonding 에 사용할 첫번째 연결 이름(con-name)을 입력하세요: " CON_NAME_1
read -p "bonding 에 사용할 두번째 연결 이름(con-name)을 입력하세요: " CON_NAME_2


#bonding 생성
echo "bond0 이름의 bonding 을 생성합니다."
sleep 2
nmcli connection add type bond con-name bond0 ifname bond0 bond.options "mode=active-backup"
nmcli connection modify $CON_NAME_1 master bond0 autoconnect yes
nmcli connection modify $CON_NAME_2 master bond0 autoconnect yes
nmcli connection up $CON_NAME_1
nmcli connection up $CON_NAME_2

nmcli con mod bond0 ipv4.addresses "$IP_ADDRESS/24" ipv4.gateway "$GATEWAY" ipv4.method manual autoconnect yes
nmcli con down bond0
nmcli con up bond0


################## write hostanme and ip in /etc/hosts ################
read -p "변경할 hostname 을 입력하세요 : " HOST_NAME
hostnamectl set-hostname $HOST_NAME
echo "$IP_ADDRESS  $HOST_NAME" >> /etc/hosts
echo "HOSTNAME 설정을 변경후 IP주소와 /etc/hosts에 기록하였습니다. HOSTNAME: $HOST_NAME"


################## selinux  #################
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
setenforce 0
echo "SELINUX 설정을 변경하였습니다. SELINUX: disabled"

## firewall off ##
systemctl stop firewalld
systemctl disable firewalld
echo "firewalld 설정을 변경하였습니다. firewalld: disabled"

################# local repo setting ##################
#mount /dev/sr0 /mnt
mkdir /root/RHEL8.10
echo "repo 복사를 시작합니다 잠시만 기다려 주세요"

rsync -ravhP /run/media/admin/RHEL-8-10-0/* /root/RHEL8.10/
#cp -rf /mnt/* /root/RHEL8.10

cat <<EOF | sudo tee /etc/yum.repos.d/local.repo
[local-BaseOS]
name=Local BaseOS
baseurl=file:///root/RHEL8.10/BaseOS
enabled=1
gpgcheck=0

[local-AppStream]
name=Local AppStream
baseurl=file:///root/RHEL8.10/AppStream
enabled=1
gpgcheck=0
EOF

dnf clean all
dnf repolist all
dnf list
echo "repo 설정을 완료하였습니다."

#################### sysstat rpm install && change log recording time ######################
SYSSTAT_CONF="/etc/sysconfig/sysstat"
NEW_HISTORY=2

sudo cp $SYSSTAT_CONF $SYSSTAT_CONF.bak
sudo sed -i "s/^HISTORY=.*/HISTORY=$NEW_HISTORY/" $SYSSTAT_CONF

sudo systemctl restart sysstat
echo "sar log 기록 주기를 default:10분 -> 2분으로 변경하였습니다."

################# ssh setting / default port 22->20022 , apply both ssh_config and sshd_config #############
SSHD_CONFIG="/etc/ssh/sshd_config"
SSH_CONFIG="/etc/ssh/ssh_config"

sudo cp $SSHD_CONFIG $SSHD_CONFIG.bak
sudo cp $SSH_CONFIG $SSH_CONFIG.bak

sudo sed -i '/^#Port/c\Port 20022' $SSHD_CONFIG
sudo sed -i '/^#   Port/c\Port 20022' $SSH_CONFIG

sudo systemctl restart sshd

echo "ssh 기본 포트를 22에서 20022로 변경하였습니다"

################## setting chrony ################################

# chrony 설정 파일 경로
CHRONY_CONF="/etc/chrony.conf"

# 함수 정의: IP 대역에 따라 NTP 서버 설정
set_ntp_servers() {
    local IP=$1
    case $IP in
        172.*)
            NEW_NTP_SERVERS="server 190.1.5.46 iburst\nserver 190.1.5.47 iburst"
            ;;
        203.*)
            NEW_NTP_SERVERS="server 203.247.66.246 iburst"
            ;;
        *)
            echo "유효하지 않은 네트워크 주소입니다."
            exit 1
            ;;
    esac

    # chrony 설정 파일에서 기존 pool 라인을 찾아 대체하거나 추가
    sudo sed -i "/^pool/c\\$NEW_NTP_SERVERS" $CHRONY_CONF
}

# 입력받은 IP 주소 대역에 따라 NTP 서버 설정 호출
set_ntp_servers "$IP_ADDRESS"

# chrony 서비스 재시작
sudo systemctl restart chronyd

echo "네트워크 주소 $IP_ADDRESS 대역에 따른 NTP 서버 설정을 완료하였습니다."



################## make user ################
# Check if the user 'rt' exists
if id "rt" &>/dev/null; then
    echo "User 'rt' already exists. No action taken."
else
    groupadd -g 1002 rt
    useradd -u 1002 -g 1002 rt
    echo 'kma1357!@' | passwd --stdin rt
    echo "rt 유저 생성을 완료하였습니다."
    echo "User 'rt' has been added."
fi

## change root passwd ##


## pakage install about HW Magaraid Storage Manager,SSDCLI,lxce_onecli##
HERE=$(dirname $(realpath $0))

mkdir -p /root/gg_server_util/Lenovo/onecli
rsync -P $HERE/lnvgy_utl_lxce_onecli02a-4.4.1_linux_x86-64.tgz /root/gg_server_util/Lenovo/

tar -zxvf /root/gg_server_util/Lenovo/lnvgy_utl_lxce_onecli02a-4.4.1_linux_x86-64.tgz -C /root/gg_server_util/Lenovo/onecli

## MegaRaid GUI install ##
mkdir -p /root/gg_server_util/Lenovo/msm
rsync -P $HERE/lnvgy_utl_msm_17.05.02.01_linux_x86-64.tgz /root/gg_server_util/Lenovo/
tar -zxvf /root/gg_server_util/Lenovo/lnvgy_utl_msm_17.05.02.01_linux_x86-64.tgz -C /root/gg_server_util/Lenovo/msm

rpm -ivh /root/gg_server_util/Lenovo/msm/lnvgy_utl_msm_17.05.02.01_linux_x86-64/Lib_Utils2-1.00-10.noarch.rpm

rpm -ivh /root/gg_server_util/Lenovo/msm/lnvgy_utl_msm_17.05.02.01_linux_x86-64/MegaRAID_Storage_Manager-17.05.02-01.noarch.rpm

rpm -ivh /root/gg_server_util/Lenovo/msm/lnvgy_utl_msm_17.05.02.01_linux_x86-64/sas_ir_snmp-17.05-0003.x86_64.rpm

rpm -ivh /root/gg_server_util/Lenovo/msm/lnvgy_utl_msm_17.05.02.01_linux_x86-64/sas_snmp-17.05-0003.x86_64.rpm


## MegaRaid CLI install ##
rsync -p $HERE/MegaCli-8.07.14-1.noarch.rpm /root/gg_server_util/Lenovo/msm
rpm -ivh /root/gg_server_util/Lenovo/msm/MegaCli-8.07.14-1.noarch.rpm
dnf install -y ncurses-compat-libs

## SSDCli ##
mkdir -p /root/gg_server_util/Lenovo/ssdcli
rsync -rP $HERE/lnvgy_utl_drives_all.ss.wg-10.04-20.04.20-0_linux_x86-64.bin /root/gg_server_util/Lenovo/ssdcli
