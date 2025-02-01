#!/bin/bash

############################### Disable services #############################
systemctl disable cups.path
systemctl disable abrt-ccpp.service
systemctl disable abrt-oops.service
systemctl disable abrt-vmcore.service
systemctl disable abrt-xorg.service
systemctl disable abrtd.service
systemctl disable accounts-daemon.service
systemctl disable atd.service
systemctl disable auditd.service
systemctl disable avahi-daemon.service
systemctl disable bluetooth.service
systemctl disable cups.service
systemctl disable dbus-org.bluez.service
systemctl disable dbus-org.fedoraproject.FirewallD1.service
systemctl disable dbus-org.freedesktop.Avahi.service
systemctl disable dbus-org.freedesktop.ModemManager1.service
systemctl disable dbus-org.freedesktop.NetworkManager.service
systemctl disable dbus-org.freedesktop.nm-dispatcher.service
systemctl disable display-manager.service
systemctl disable dmraid-activation.service
systemctl disable firewalld.service
systemctl disable initial-setup-reconfiguration.service
systemctl disable iscsi.service
errorsystemctl disable ksm.service
systemctl disable ksmtuned.service
systemctl disable libstoragemgmt.service
systemctl disable libvirtd.service
systemctl disable lvm2-monitor.service
systemctl disable mcelog.service
systemctl disable mdmonitor.service
systemctl disable microcode.service
systemctl disable ModemManager.service
systemctl disable multipathd.service
systemctl disable NetworkManager-dispatcher.service
systemctl disable NetworkManager-wait-online.service
systemctl disable postfix.service
systemctl disable qemu-guest-agent.service
systemctl disable rngd.service
systemctl disable smartd.service
systemctl disable tuned.service
systemctl disable udisks2.service
systemctl disable vdo.service
systemctl disable vgauthd.service
systemctl disable vmtoolsd.service
# Disable sockets
systemctl disable avahi-daemon.socket
systemctl disable cups.socket
systemctl disable dm-event.socket
systemctl disable iscsid.socket
systemctl disable iscsiuio.socket
systemctl disable lvm2-lvmetad.socket
systemctl disable lvm2-lvmpolld.socket
systemctl disable spice-vdagentd.socket
systemctl disable virtlockd.socket
systemctl disable virtlogd.socket

# Disable timers
systemctl disable unbound-anchor.timer

echo "All specified services, sockets, and timers have been disabled."


############################# stop firewalld ##########################
systemctl stop firewalld
systemctl disable firewalld
echo "the firewalld is stopped"



############################# SELINUX 비활성화 ##########################
# SELinux 설정 파일 경로
SELINUX_CONFIG="/etc/selinux/config"

# SELINUX=enforcing 또는 SELINUX=permissive을 SELINUX=disabled로 변경
if grep -q "^SELINUX=" "$SELINUX_CONFIG"; then
    sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' "$SELINUX_CONFIG"
    echo "SELINUX 설정을 disabled로 변경했습니다."
else
    echo "SELINUX 설정이 이미 disabled로 되어 있거나 찾을 수 없습니다."
fi


# /etc/sysctl.conf 파일 경로
SYSCTL_CONFIG="/etc/sysctl.conf"

##################### 필요한 커널 및 네트워크 설정을 추가하거나 수정I ######################
declare -A sysctl_settings=(
    ["kernel.sysrq"]="1"
    ["kernel.unknown_nmi_panic"]="1"
    ["kernel.panic_on_unrecovered_nmi"]="1"
    ["kernel.panic_on_io_nmi"]="1"
    ["net.ipv4.tcp_max_syn_backlog"]="2048"
    ["net.core.somaxconn"]="2048"
    ["net.core.netdev_max_backlog"]="2048"
)

for setting in "${!sysctl_settings[@]}"; do
    if grep -q "^$setting" $SYSCTL_CONFIG; then
        sed -i "s/^$setting.*/$setting = ${sysctl_settings[$setting]}/" $SYSCTL_CONFIG
        echo "$setting 값을 ${sysctl_settings[$setting]}로 수정했습니다."
    else
        echo "$setting = ${sysctl_settings[$setting]}" >> $SYSCTL_CONFIG
        echo "$setting 설정을 추가했습니다."
    fi
done

# 설정 적용
sysctl -p

echo "sysctl 설정이 완료되었습니다."


################################ /etc/hosts 파일추가#################################
HOSTS_CONTENT=$(cat << 'EOF'

#######################################

####### make ip table on this ########

#######################################
EOF
)

# /etc/hosts 파일에 내용 추가
if ! grep -q "###  Internal IP ###" /etc/hosts; then
    echo "$HOSTS_CONTENT" | sudo tee -a /etc/hosts > /dev/null
    echo "Added new entries to /etc/hosts"
else
    echo "Entries already exist in /etc/hosts"
fi





##################################### repo 설정#################################
# 저장할 리포지토리 내용
REPO_CONTENT=$(cat << 'EOF'
[rhel8-AppStream]
name=rhel8-AppStream
baseurl=file:///ISO/AppStream
enabled=1
gpgcheck=0

[rhel8-BaseOS]
name=rhel8-BaseOS
baseurl=file:///ISO/BaseOS
enabled=1
gpgcheck=0
EOF
)

######################### 이부분 수정 필요 ###########################
# /dev/sr0 를 /mnt에 mount 후 /ISO 폴더로 복사
# mount /dev/sr0 /mnt
mount --bind /run/media/root/RHEL-8-9-0- /mnt
mkdir /ISO
cp -a /mnt/* /ISO/

sleep 3 
#repo 정상 동작 확인
yum clean all
yum repolist
yum list


#rngd 실행
yum install -y  rng-tools.x86_64
systemctl start rngd
systemctl enable rngd



# /etc/yum.repos.d/rhel8.repo 파일에 내용 추가
if [ -f /etc/yum.repos.d/rhel8.repo ]; then
    echo "File /etc/yum.repos.d/rhel8.repo already exists. Overwriting..."
fi

echo "$REPO_CONTENT" | sudo tee /etc/yum.repos.d/rhel8.repo > /dev/null
echo "Saved repository configuration to /etc/yum.repos.d/rhel8.repo"

############################ chrony.conf에 추가할 내용######################
CHRONY_CONTENT=$(cat << 'EOF'
# FOR INTERNAL
#server [time server ip] iburst


# FOR EXTERNAL
#server [time server ip] iburst

EOF
)

# /etc/chrony.conf 파일에 내용 추가
CONF_FILE="/etc/chrony.conf"

if [ -f "$CONF_FILE" ]; then
    echo "Inserting content into $CONF_FILE..."

    # 파일을 3번째 줄에 추가
    {
        head -n 2 "$CONF_FILE"    # 첫 두 줄 출력
        echo "$CHRONY_CONTENT"     # 추가할 내용 출력
        tail -n +3 "$CONF_FILE"    # 나머지 줄 출력
    } | sudo tee "$CONF_FILE" > /dev/null

    echo "Saved configuration to $CONF_FILE"
else
    echo "$CONF_FILE does not exist."
fi


############################ PermitRootLogin No 설정########################
# sshd_config 파일 경로#
SSHD_CONFIG="/etc/ssh/sshd_config"

# PermitRootLogin을 no로 변경
if [ -f "$SSHD_CONFIG" ]; then
    echo "Modifying PermitRootLogin in $SSHD_CONFIG..."

    # PermitRootLogin 항목을 no로 변경
    if grep -q "^PermitRootLogin" "$SSHD_CONFIG"; then
        # 항목이 존재하는 경우 수정
        sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
        echo "Existing PermitRootLogin entry has been set to no."
    else
        # 항목이 존재하지 않는 경우, 적절한 위치에 추가
        echo "PermitRootLogin no" | sudo tee -a "$SSHD_CONFIG" > /dev/null
        echo "PermitRootLogin entry added with value no."
    fi

    # 설정 변경 후 SSH 데몬 재시작
    sudo systemctl restart sshd
    echo "sshd service has been restarted."
else
    echo "$SSHD_CONFIG does not exist."
fi


############################## pwquality.conf 설정######################################
# pwquality.conf 파일 경로
PWQUALITY_CONFIG="/etc/security/pwquality.conf"

# pwquality.conf 파일 수정
if [ -f "$PWQUALITY_CONFIG" ]; then
    echo "Modifying $PWQUALITY_CONFIG..."

    # minlen을 9로 변경 (주석 처리된 경우도 처리)
    sudo sed -i 's/^#*\s*minlen\s*=\s*[0-9]\+/minlen = 9/' "$PWQUALITY_CONFIG"

    # dcredit을 -1로 변경
    sudo sed -i 's/^#*\s*dcredit\s*=\s*-*[0-9]\+/dcredit = -1/' "$PWQUALITY_CONFIG"

    # ucredit을 -1로 변경
    sudo sed -i 's/^#*\s*ucredit\s*=\s*-*[0-9]\+/ucredit = -1/' "$PWQUALITY_CONFIG"

    # lcredit을 -1로 변경
    sudo sed -i 's/^#*\s*lcredit\s*=\s*-*[0-9]\+/lcredit = -1/' "$PWQUALITY_CONFIG"

    # ocredit을 -1로 변경
    sudo sed -i 's/^#*\s*ocredit\s*=\s*-*[0-9]\+/ocredit = -1/' "$PWQUALITY_CONFIG"

    echo "Updated pwquality settings in $PWQUALITY_CONFIG."
else
    echo "$PWQUALITY_CONFIG does not exist."
fi


################################## failock.conf 파일 경로 설정 #############################
# faillock.conf 파일 경로
FAILLOCK_CONFIG="/etc/security/faillock.conf"

# faillock.conf 파일 수정
if [ -f "$FAILLOCK_CONFIG" ]; then
    echo "Modifying $FAILLOCK_CONFIG..."

    # audit 항목 주석 해제
    sudo sed -i 's/^#\s*audit/audit/' "$FAILLOCK_CONFIG"
    
    # silent 항목 주석 해제
    sudo sed -i 's/^#\s*silent/silent/' "$FAILLOCK_CONFIG"

    # deny 항목을 5로 변경 (주석 해제)
    sudo sed -i 's/^#\s*deny\s*=\s*[0-9]\+/deny = 5/' "$FAILLOCK_CONFIG"

    # unlock_time 항목을 120으로 변경 (주석 해제)
    sudo sed -i 's/^#\s*unlock_time\s*=\s*[0-9]\+/unlock_time = 120/' "$FAILLOCK_CONFIG"

    echo "Updated faillock settings in $FAILLOCK_CONFIG."
else
    echo "$FAILLOCK_CONFIG does not exist."
fi

################################## system-auth 파일 설정 ###############################
# system-auth 파일 경로
SYSTEM_AUTH_CONFIG="/etc/pam.d/system-auth"

# system-auth 파일 수정
if [ -f "$SYSTEM_AUTH_CONFIG" ]; then
    echo "Modifying $SYSTEM_AUTH_CONFIG..."

    # 정확한 공백을 고려하여 'remember=5' 추가
    sudo sed -i 's/password\s\{1,\}sufficient\s\{1,\}pam_unix.so\s\{1,\}sha512\s\{1,\}shadow\s\{1,\}nullok\s\{1,\}use_authtok/password    sufficient                                   pam_unix.so sha512 shadow nullok use_authtok remember=5/' "$SYSTEM_AUTH_CONFIG"

    echo "Updated password settings in $SYSTEM_AUTH_CONFIG."
else
    echo "$SYSTEM_AUTH_CONFIG does not exist."
fi


#################################### su 파일 설정 #######################################
# su 파일 경로
SU_CONFIG="/etc/pam.d/su"

# su 파일 수정
if [ -f "$SU_CONFIG" ]; then
    echo "Modifying $SU_CONFIG..."

    # 'auth required pam_wheel.so use_uid' 라인의 주석을 해제
    sudo sed -i 's/^#\s*\(auth\s\+required\s\+pam_wheel.so\s\+use_uid\)/\1/' "$SU_CONFIG"

    echo "Uncommented 'auth required pam_wheel.so use_uid' in $SU_CONFIG."
else
    echo "$SU_CONFIG does not exist."
fi


#################################### login.defs 설정 #######################################
# login.defs 파일 경로
LOGIN_DEFS="/etc/login.defs"

# profile 파일 경로
PROFILE_CONFIG="/etc/profile"

# /etc/login.defs 파일 수정 (패스워드 정책 설정)
if [ -f "$LOGIN_DEFS" ]; then
    echo "Modifying $LOGIN_DEFS for password policy..."

    # PASS_MAX_DAYS, PASS_MIN_DAYS, PASS_MIN_LEN, PASS_WARN_AGE 설정
    sudo sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' "$LOGIN_DEFS"
    sudo sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/' "$LOGIN_DEFS"
    sudo sed -i 's/^PASS_MIN_LEN.*/PASS_MIN_LEN   9/' "$LOGIN_DEFS"
    sudo sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   7/' "$LOGIN_DEFS"

    echo "Password policy updated in $LOGIN_DEFS."
else
    echo "$LOGIN_DEFS does not exist."
fi

# /etc/profile 파일 수정 (Session Timeout 설정)
if [ -f "$PROFILE_CONFIG" ]; then
    echo "Modifying $PROFILE_CONFIG for session timeout..."

    # TMOUT 설정이 이미 존재하는지 확인하고 수정 또는 추가
    if grep -q "^export TMOUT=" "$PROFILE_CONFIG"; then
        sudo sed -i 's/^export TMOUT=.*/export TMOUT=300/' "$PROFILE_CONFIG"
    else
        echo "export TMOUT=300" | sudo tee -a "$PROFILE_CONFIG" > /dev/null
    fi

    echo "Session timeout set to 300 seconds in $PROFILE_CONFIG."
else
    echo "$PROFILE_CONFIG does not exist."
fi



################################# at.deny, crontab 권한 설정 ############################
#allow at.deny, crontab file authority
chmod 640 /etc/at.deny
chmod 640 /etc/crontab



################################# rc.loacl 파일 설정  ###############################
# rc.local 파일 경로
RC_LOCAL="/etc/rc.d/rc.local"

# 네트워크 및 chronyd 재시작 명령 추가
if [ -f "$RC_LOCAL" ]; then
    echo "Adding network and chronyd restart commands to $RC_LOCAL..."

    # 명령을 추가
    echo -e "\nsystemctl restart network" | sudo tee -a "$RC_LOCAL" > /dev/null
    echo "Added 'systemctl restart network'."

    echo "systemctl restart chronyd" | sudo tee -a "$RC_LOCAL" > /dev/null
    echo "Added 'systemctl restart chronyd'."

    # rc.local 파일 실행 가능 권한 부여
    sudo chmod +x "$RC_LOCAL"
    echo "Made $RC_LOCAL executable."
else
    echo "$RC_LOCAL does not exist."
fi



############################  경고문구 관련 설정 #############################
# motd 및 issue.net 파일 경로
MOTD_FILE="/etc/motd"
ISSUE_NET_FILE="/etc/issue.net"

# 경고 메시지 내용
WARNING_MESSAGE="Authorized users only"

# /etc/motd 파일에 경고 메시지 설정
if [ -f "$MOTD_FILE" ]; then
    echo "Setting warning message in $MOTD_FILE..."
    echo "$WARNING_MESSAGE" | sudo tee "$MOTD_FILE" > /dev/null
    echo "Updated $MOTD_FILE with warning message."
else
    echo "$MOTD_FILE does not exist. Creating and adding warning message..."
    echo "$WARNING_MESSAGE" | sudo tee "$MOTD_FILE" > /dev/null
    echo "Created $MOTD_FILE and added warning message."
fi

# /etc/issue.net 파일에 경고 메시지 설정
if [ -f "$ISSUE_NET_FILE" ]; then
    echo "Setting warning message in $ISSUE_NET_FILE..."
    echo "$WARNING_MESSAGE" | sudo tee "$ISSUE_NET_FILE" > /dev/null
    echo "Updated $ISSUE_NET_FILE with warning message."
else
    echo "$ISSUE_NET_FILE does not exist. Creating and adding warning message..."
    echo "$WARNING_MESSAGE" | sudo tee "$ISSUE_NET_FILE" > /dev/null
    echo "Created $ISSUE_NET_FILE and added warning message."
fi



############################ rngd daemon 설치 후 실행 #############################
#rngd 실행
yum install -y  rng-tools.x86_64
systemctl start rngd
systemctl enable rngd
