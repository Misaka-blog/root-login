#!/bin/bash

red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "alpine")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Alpine")
PACKAGE_UPDATE=("apt -y update" "apt -y update" "yum -y update" "yum -y update" "apk update -f")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "apk add -f")
CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
	SYS="$i" && [[ -n $SYS ]] && break
done

for ((int=0; int<${#REGEX[@]}; int++)); do
	[[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
done

[[ -z $SYSTEM ]] && red "脚本暂时不支持VPS的当前系统，请使用主流操作系统" && exit 1
[[ ! -f /etc/ssh/sshd_config ]] && sudo ${PACKAGE_UPDATE[int]} && sudo ${PACKAGE_INSTALL[int]} openssh-server
[[ -z $(type -P curl) ]] && sudo ${PACKAGE_UPDATE[int]} && sudo ${PACKAGE_INSTALL[int]} curl

WgcfIPv4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
WgcfIPv6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
if [[ $WgcfIPv4Status =~ "on"|"plus" ]] || [[ $WgcfIPv6Status =~ "on"|"plus" ]]; then
    wg-quick down wgcf >/dev/null 2>&1
    systemctl stop warp-go >/dev/null 2>&1
    v6=$(curl -s6m8 api64.ipify.org -k)
    v4=$(curl -s4m8 api64.ipify.org -k)
    wg-quick up wgcf >/dev/null 2>&1
    systemctl start warp-go >/dev/null 2>&1
else
    v6=$(curl -s6m8 api64.ipify.org -k)
    v4=$(curl -s4m8 api64.ipify.org -k)
fi

sudo lsattr /etc/passwd /etc/shadow >/dev/null 2>&1
sudo chattr -i /etc/passwd /etc/shadow >/dev/null 2>&1
sudo chattr -a /etc/passwd /etc/shadow >/dev/null 2>&1
sudo lsattr /etc/passwd /etc/shadow >/dev/null 2>&1

read -p "输入设置的SSH端口（默认22）：" sshport
[[ -z $sshport ]] && red "端口未设置，将使用默认22端口" && sshport=22
read -p "输入设置的root密码：" password
[[ -z $password ]] && red "密码未设置，将使用随机生成密码" && password=$(cat /proc/sys/kernel/random/uuid)
echo root:$password | sudo chpasswd root

sudo sed -i "s/^#\?Port.*/Port $sshport/g" /etc/ssh/sshd_config;
sudo sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config;
sudo sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config;

sudo service ssh restart >/dev/null 2>&1 # 某些VPS系统的ssh服务名称为ssh，以防无法重启服务导致无法立刻使用密码登录
sudo service sshd restart >/dev/null 2>&1

yellow "VPS root登录信息设置完成！"
if [[ -n $v4 && -z $v6 ]]; then
    green "VPS登录IP地址及端口为：$v4:$sshport"
fi
if [[ -z $v4 && -n $v6 ]]; then
    green "VPS登录IP地址及端口为：$v6:$sshport"
fi
if [[ -n $v4 && -n $v6 ]]; then
    green "VPS登录IP地址及端口为：$v4:$sshport 或 $v6:$sshport"
fi
green "用户名：root"
green "密码：$password"
yellow "请妥善保存好登录信息！然后重启VPS确保设置已保存！"
