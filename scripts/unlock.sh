#!/usr/bin/env bash

export LANG=en_US.UTF-8

# 当前脚本版本号和新增功能
VERSION='1.22'

# 支持的流媒体和 ChatGPT
STREAM=("Netflix" "Disney+" "ChatGPT")

# 选择 IP API 服务商
IP_API=https://api.ip.sb/geoip; ISP=isp

E[0]="Language:\n  1.English (default) \n  2.简体中文"
C[0]="${E[0]}"
E[1]="1. Add Alpine Linux support; 2. Rebuilt account registration: removed python/jq dependency (pure-awk json_pretty); 3. Improved log alignment (printf) & auto IP width for IPv4/IPv6"
C[1]="1. 新增 Alpine Linux 支持; 2. 重构注册逻辑：去除 python/jq 依赖，改用纯 awk 的 json_pretty; 3. 优化日志对齐（printf），IP 列宽按 IPv4/IPv6 自动调整"
E[2]="If you have a WARP+ License, please input it:"
C[2]="如果您有 WARP+ License，请输入:"
E[3]="Choose:"
C[3]="请选择:"
E[4]="Neither the WARP network interface nor Socks5 are installed, please select the installation script:\n 1. fscarmen's warp (Default)\n 2. fscarmen's warp-go\n 0. Exit"
C[4]="WARP 网络接口和 Socks5 都没有安装，请选择安装脚本:\n 1. fscarmen's warp (默认)\n 2. fscarmen's warp-go\n 0. 退出"
E[5]="The script supports Debian, Ubuntu, CentOS or Alpine systems only. Feedback: [https://github.com/fscarmen/unlock_warp/issues]"
C[5]="本脚本只支持 Debian、Ubuntu、CentOS 或 Alpine 系统,问题反馈:[https://github.com/fscarmen/unlock_warp/issues]"
E[6]="Please choose to brush WARP IP:\n 1. WARP Socks5 Proxy\n 2. WARP IPv6 Interface"
C[6]="请选择刷 WARP IP 方式:\n 1. WARP Socks5 代理\n 2. WARP IPv6 网络接口"
E[7]="Installing \$c..."
C[7]="安装 \$c 中……"
E[8]="It is necessary to upgrade the latest package library before install \$c.It will take a little time,please be patiently..."
C[8]="先升级软件库才能继续安装 \$c，时间较长，请耐心等待……"
E[9]="Failed to install \$c. The script is aborted. Feedback: [https://github.com/fscarmen/unlock_warp/issues]"
C[9]="安装 \$c 失败，脚本中止，问题反馈:[https://github.com/fscarmen/unlock_warp/issues]"
E[10]="Media unlock daemon installed successfully. The running log of the scheduled task will be saved in /root/result.log"
C[10]="媒体解锁守护进程已安装成功。定时任务运行日志将保存在 /root/result.log"
E[11]="The media unlock daemon is completely uninstalled."
C[11]="媒体解锁守护进程已彻底卸载"
E[12]="\n 1. Mode 1: Check it every 5 minutes.\n 2. Mode 2: Create a jobs with \$SVC_TYPE service. The process runs in the background. When the unlock is all successful, it will be checked every 1 hour.\n 3. Mode 3: Create a jobs with nohup to run. The process runs in the background. When the unlock is all successful, it will be checked every 1 hour.\n 4. Mode 4: Create a screen named [u] and run. The process runs in the background. When the unlock is all successful, it will be checked every 1 hour.\n 5. Mode 5: Install pm2 daemon. The process runs in the background. When the unlock is all successful, it will be checked every 1 hour.\n 6. Uninstall\n 0. Exit\n"
C[12]="\n 1. 模式1: 定时5分钟检查一次,遇到不解锁时更换 WARP IP，直至刷成功\n 2. 模式2: 创建 \$SVC_TYPE 服务。进程一直在后台，当刷成功后，每隔1小时检查一次\n 3. 模式3: 用 nohup 创建一个 jobs。进程一直在后台，当刷成功后，每隔1小时检查一次\n 4. 模式4: 创建一个名为 [u] 的 Screen 会话。进程一直在后台，当刷成功后，每隔1小时检查一次\n 5. 模式5: 安装 pm2 守护进程，安装依赖需较长时间。进程一直在后台，当刷成功后，每隔1小时检查一次\n 6. 卸载\n 0. 退出\n"
E[13]="The current region is \$REGION. Confirm press [y] . If you want another regions, please enter the two-digit region abbreviation. (such as hk,sg. Default is \$REGION):"
C[13]="当前地区是:\$REGION，需要解锁当前地区请按 y , 如需其他地址请输入两位地区简写 (如 hk,sg，默认:\$REGION):"
E[14]="Wrong input."
C[14]="输入错误"
E[15]="Note: Detection methods are replicated from 1-stream's RegionRestrictionCheck. If there are any issues, please report them at https://github.com/1-stream/RegionRestrictionCheck/issues\n\n Select the stream media you wanna unlock (Multiple selections are possible, such as 123. The default is select all)\n 1. Netflix\n 2. Disney+\n 3. ChatGPT"
C[15]="注意：检测方法复刻自 1-stream 的 RegionRestrictionCheck 项目，如有问题请到 https://github.com/1-stream/RegionRestrictionCheck/issues 反馈\n\n 选择你期望解锁的流媒体 (可多选，如 123，默认为全选)\n 1. Netflix\n 2. Disney+\n 3. ChatGPT"
E[16]="The script Born to make stream media unlock by WARP. Detail:[https://github.com/fscarmen/unlock_warp]\n Features:\n\t • Support a variety of main stream streaming media detection.\n\t • Multiple ways to unlock.\n\t • Support WARP Socks5 Proxy to detect and replace IP.\n\t • log output"
C[16]="本项目专为 WARP 解锁流媒体而生。详细说明：[https://github.com/fscarmen/unlock_warp]\n 脚本特点:\n\t • 支持多种主流串流影视检测\n\t • 多种方式解锁\n\t • 支持 WARP Socks5 Proxy 检测和更换 IP\n\t • 日志输出"
E[17]="Version"
C[17]="脚本版本"
E[18]="New features"
C[18]="功能新增"
E[19]="\\\n Stream media unlock daemon is running in mode: \$UNLOCK_MODE_NOW.\\\n"
C[19]="\\\n 流媒体解锁守护正在以模式: \$UNLOCK_MODE_NOW 运行中\\\n"
E[20]="Media unlock daemon installed successfully. A session window u has been created, enter [screen -Udr u] and close [screen -SX u quit]. The VPS restart will still take effect. The running log of the scheduled task will be saved in /root/result.log"
C[20]="媒体解锁守护进程已安装成功，已创建一个会话窗口 u ，进入 [screen -Udr u]，关闭 [screen -SX u quit]，VPS 重启仍生效。进入任务运行日志将保存在 /root/result.log"
E[21]="Media unlock daemon installed successfully. A jobs has been created, check [pgrep -laf warp_unlock] and close [kill -9 \$(pgrep -f warp_unlock)]. The VPS restart will still take effect. The running log of the scheduled task will be saved in /root/result.log"
C[21]="媒体解锁守护进程已安装成功，已创建一个jobs，查看 [pgrep -laf warp_unlock]，关闭 [kill -9 \$(pgrep -f warp_unlock)]，VPS 重启仍生效。进入任务运行日志将保存在 /root/result.log"
E[22]="The script runs on today: \$TODAY. Total:\$TOTAL"
C[22]="脚本当天运行次数:\$TODAY，累计运行次数：\$TOTAL"
E[23]="Please choose to brush WARP IP:\n 1. WARP - IPv4\n 2. WARP - IPv6"
C[23]="请选择刷 WARP IP 方式:\n 1. WARP - IPv4\n 2. WARP - IPv6"
E[24]="No option. The script is aborted. Feedback: [https://github.com/fscarmen/unlock_warp/issues]"
C[24]="没有该选项，脚本退出，问题反馈:[https://github.com/fscarmen/unlock_warp/issues]"
E[25]="No unlock method specified."
C[25]="没有指定的解锁模式"
E[26]="Expected region abbreviation should be two digits (eg hk,sg)."
C[26]="期望地区简码应该为两位 (如 hk,sg)"
E[27]="No unlock script is installed."
C[27]="解锁脚本还没有安装"
E[28]="Unlock script is installed."
C[28]="解锁脚本已安装"
E[29]="Please enter Bot Token if you need push the logs to Telegram. Leave blank to skip:"
C[29]="如需要把日志推送到 Telegram 机器人，请输入 Bot Token，不需要直接回车:"
E[30]="Enter Telegram USERID:"
C[30]="输入 Telegram USERID:"
E[31]="Enter custom name:"
C[31]="自定义名称:"
E[32]="The account type is Teams and does not support changing IP\n  1. Change to free (default)\n  2. Change to plus\n  3. Quit"
C[32]="账户类型为 Teams，不支持更换 IP\n  1. 更换为 free (默认)\n  2. 更换为 plus\n  3. 退出"
E[33]="Input errors up to 5 times.The script is aborted."
C[33]="输入错误达5次，脚本退出"
E[34]="License should be 26 characters, please re-enter WARP+ License. Otherwise press Enter to continue. (\${i} times remaining): "
C[34]="License 应为26位字符,请重新输入 WARP+ License (剩余\${i}次): "
E[35]="Please customize the WARP+ device name (Default is [warp] if left blank):"
C[35]="请自定义 WARP+ 设备名 (如果不输入，默认为 [warp]):"
E[36]="Press [y] to confirm whether to uninstall dependencies: nodejs and npm. Other keys do not uninstall by default:"
C[36]="是否卸载依赖 nodejs 和 npm，确认请按 [y] ，其他键默认不卸载:"
E[37]="Please choose to brush WARP IP:\n 1. Client - IPv4\n 2. Client - IPv6"
C[37]="请选择刷 WARP IP 方式:\n 1. Client - IPv4\n 2. Client - IPv6"
E[38]="Please choose to brush WARP IP:\n 1. WireProxy - IPv4\n 2. WireProxy - IPv6"
C[38]="请选择刷 WARP IP 方式:\n 1. WireProxy - IPv4\n 2. WireProxy - IPv6"
E[39]="Media unlock daemon installed successfully. A systemd service has been created, check [journalctl -fu warp_unlock] and close [systemctl disable --now warp_unlock]. The VPS restart will still take effect. The running log of the scheduled task will be saved in /root/result.log"
C[39]="媒体解锁守护进程已安装成功，已创建一个 systemd 服务，查看 [journalctl -fu warp_unlock]，关闭 [systemctl disable --now warp_unlock]，VPS 重启仍生效。进入任务运行日志将保存在 /root/result.log"
E[40]="Media unlock daemon installed successfully. pm2 daemon is running, check pm2 [list] and close [pm2 delete warp_unlock; pm2 unstartup systemd;]. The VPS restart will still take effect. The running log of the scheduled task will be saved in /root/result.log"
C[40]="媒体解锁守护进程已安装成功，pm2 守护进程正在工作中，查看 [pm2 list]，关闭 [pm2 delete warp_unlock; pm2 unstartup systemd; ]，VPS 重启仍生效。进入任务运行日志将保存在 /root/result.log"
E[41]="Please choose to brush WARP IP:\n 1. WireProxy - IPv4\n 2. WireProxy - IPv6\n 3. Client - IPv4\n 4. Client - IPv6"
C[41]="请选择刷 WARP IP 方式:\n 1. WireProxy - IPv4\n 2. WireProxy - IPv6\n 3. Client - IPv4\n 4. Client - IPv6"
E[42]="Please choose to brush WARP IP:\n 1. WireProxy - IPv4\n 2. WireProxy - IPv6\n 3. WARP - IPv6"
C[42]="请选择刷 WARP IP 方式:\n 1. WireProxy - IPv4\n 2. WireProxy - IPv6\n 3. WARP - IPv6"
E[43]="Please choose to brush WARP IP:\n 1. WireProxy - IPv4\n 2. WireProxy - IPv6\n 3. Client - IPv4\n 4. Client - IPv6\n 5. WARP - IPv6"
C[43]="请选择刷 WARP IP 方式:\n 1. WireProxy - IPv4\n 2. WireProxy - IPv6\n 3. Client - IPv4\n 4. Client - IPv6\n 5. WARP - IPv6"
E[44]="Please choose to brush WARP IP:\n 1. WireProxy - IPv4\n 2. WireProxy - IPv6\n 3. WARP - IPv4"
C[44]="请选择刷 WARP IP 方式:\n 1. WireProxy - IPv4\n 2. WireProxy - IPv6\n 3. WARP - IPv4"
E[45]="Please choose to brush WARP IP:\n 1. WARP Socks5 Proxy\n 2. WARP IPv4 Interface"
C[45]="请选择刷 WARP IP 方式:\n 1. WARP Socks5 代理\n 2. WARP IPv4 网络接口\n"
E[46]="Please choose to brush WARP IP:\n 1. WireProxy - IPv4\n 2. WireProxy - IPv6\n 3. Client - IPv4\n 4. Client - IPv6\n 5. WARP - IPv4"
C[46]="请选择刷 WARP IP 方式:\n 1. WireProxy - IPv4\n 2. WireProxy - IPv6\n 3. Client - IPv4\n 4. Client - IPv6\n 5. WARP - IPv4"
E[47]="Please choose to brush WARP IP:\n 1. WireProxy - IPv4\n 2. WireProxy - IPv6\n 3. WARP - IPv4\n 4. WARP - IPv6"
C[47]="请选择刷 WARP IP 方式:\n 1. WireProxy - IPv4\n 2. WireProxy - IPv6\n 3. WARP - IPv4\n 4. WARP - IPv6"
E[48]="Please choose to brush WARP IP:\n 1. Client - IPv4\n 2. Client - IPv6\n 3. WARP - IPv4\n 4. WARP - IPv6"
C[48]="请选择刷 WARP IP 方式:\n 1. Client - IPv4\n 2. Client - IPv6\n 3. WARP - IPv4\n 4. WARP - IPv6"
E[49]="Please choose to brush WARP IP:\n 1. WireProxy - IPv4\n 2. WireProxy - IPv6\n 3. Client - IPv4\n 4. Client - IPv6\n 5. WARP - IPv4\n 6. WARP - IPv6"
C[49]="请选择刷 WARP IP 方式:\n 1. WireProxy - IPv4\n 2. WireProxy - IPv6\n 3. Client - IPv4\n 4. Client - IPv6\n 5. WARP - IPv4\n 6. WARP - IPv6"
E[50]="Media unlock daemon installed successfully. An openrc service has been created, check [rc-service warp_unlock status] and close [rc-update del warp_unlock]. The VPS restart will still take effect. The running log of the scheduled task will be saved in /root/result.log"
C[50]="媒体解锁守护进程已安装成功，已创建一个 openrc 服务，查看 [rc-service warp_unlock status]，关闭 [rc-update del warp_unlock]，VPS 重启仍生效。进入任务运行日志将保存在 /root/result.log"

# 预处理：扫描 E/C 数组，把含 $ 的条目下标记录到关联数组，避免 text() 每次调用都启动 grep 子进程
declare -A TEXT_NEEDS_EVAL
for _text_i in "${!E[@]}"; do
  [[ "${E[${_text_i}]}" == *'$'* || "${C[${_text_i}]}" == *'$'* ]] && TEXT_NEEDS_EVAL[${_text_i}]=1
done

# 自定义字体彩色，read 函数
red() { echo -e "\033[31m\033[01m$*\033[0m"; }
error() { echo -e "\033[31m\033[01m$*\033[0m" && exit 1; }
info() { echo -e "\033[32m\033[01m$*\033[0m"; }
hint() { echo -e "\033[33m\033[01m$*\033[0m"; }
reading() { read -rp "$(info "$1")" "$2"; }

# text <index>：输出当前语言对应的字符串，含 $ 变量的条目用 eval 展开，其余直接 printf
text() {
  local -n _text_arr="${L}"
  local _text_val="${_text_arr[$*]}"
  if [[ -n "${TEXT_NEEDS_EVAL[$*]}" ]]; then
    eval "printf '%s' \"${_text_val}\""
  else
    printf '%s' "${_text_val}"
  fi
}

# 自定义谷歌翻译函数，使用两个翻译 api，如均不能翻译，则返回原英文
translate() {
  [ -n "$@" ] && local EN="$@"
  [ -z "$ZH" ] && local ZH=$(curl -km8 -sSL "https://translate.google.com/translate_a/t?client=any_client_id_works&sl=en&tl=zh&q=${EN//[[:space:]]/%20}" 2>/dev/null | awk -F '"' '{print $2}')
  [ -z "$ZH" ] && local ZH=$(curl -km8 -sSL "https://lingva.ml/api/v1/en/zh/${EN//[[:space:]]/%20}" 2>/dev/null | awk -F '"' '{print $4}')
  [ -z "$ZH" ] && echo "$EN" || echo "$ZH"
}

check_dependencies() {
  for c in $*; do
    type -p $c >/dev/null 2>&1 || (hint " $(text 7) " && ${PACKAGE_INSTALL[b]} $c 2>/dev/null) || (hint " $(text 8) " && ${PACKAGE_UPDATE[b]} && ${PACKAGE_INSTALL[b]} $c 2>/dev/null)
    ! type -p $c >/dev/null 2>&1 && error " $(text 9) " && exit 1
  done
}

# 脚本当天及累计运行次数统计
statistics_of_run-times() {
  local COUNT=$(curl --retry 2 -ksm2 "https://stat.cloudflare.now.cc/updateStats?script=unlock.sh" 2>&1) &&
  [[ "$COUNT" =~ \"todayCount\":([0-9]+),\"totalCount\":([0-9]+) ]] &&
  TODAY="${BASH_REMATCH[1]}" &&
  TOTAL="${BASH_REMATCH[2]}"
}

# 选择语言，先判断 warp 脚本里的语言选择，没有的话再让用户选择，默认英语
select_laguage() {
  if [ -z "$L" ]; then
    if [ -e /opt/warp-go/language ]; then
	    L=$(cat /opt/warp-go/language 2>&1)
	  elif [ -e /etc/wireguard/language ]; then
	    L=$(cat /etc/wireguard/language 2>&1)
	  else
      case $(cat /etc/wireguard/language 2>&1) in
        E ) L=E;;
        C ) L=C;;
        * ) L=E && hint "\n $(text 0) \n" && reading " $(text 3) " LANGUAGE
		[ "$LANGUAGE" = 2 ] && L=C;;
      esac
	  fi
  fi
}

check_system_info() {
  # 多方式判断操作系统，试到有值为止。只支持 Debian 10/11/12、Ubuntu 18.04/20.04/22.04 或 CentOS 7/8/9 ,如非上述操作系统，退出脚本
  if [ -s /etc/os-release ]; then
    SYS="$(grep -i pretty_name /etc/os-release | cut -d \" -f2)"
  elif [ $(type -p hostnamectl) ]; then
    SYS="$(hostnamectl | grep -i system | cut -d : -f2)"
  elif [ $(type -p lsb_release) ]; then
    SYS="$(lsb_release -sd)"
  elif [ -s /etc/lsb-release ]; then
    SYS="$(grep -i description /etc/lsb-release | cut -d \" -f2)"
  elif [ -s /etc/redhat-release ]; then
    SYS="$(grep . /etc/redhat-release)"
  elif [ -s /etc/issue ]; then
    SYS="$(grep . /etc/issue | cut -d '\' -f1 | sed '/^[ ]*$/d')"
  fi

  REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|amazon linux|alma|rocky" "alpine")
  RELEASE=("Debian" "Ubuntu" "CentOS" "Alpine")
  PACKAGE_UPDATE=("apt -y update" "apt -y update" "yum -y update" "apk update -f")
  PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "apk add -f")
  PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "apk del -f")

  for b in ${!REGEX[@]}; do
    [[ "${SYS,,}" =~ ${REGEX[b]} ]] && SYSTEM="${RELEASE[b]}" && break
  done

  # 针对各厂运的订制系统
  if [ -z "$SYSTEM" ]; then
    [ $(type -p yum) ] && int=2 && SYSTEM='CentOS' || error " $(text 5) "
  fi
  # 模式2 服务 init 类型：Alpine=openrc，其余=systemd（供 text 12 根据系统显示）
  SVC_TYPE='systemd'
  [ "$SYSTEM" = Alpine ] && SVC_TYPE='openrc'
}

# 检查解锁是否已运行，如果是则判断模式，以前给更换模式赋值
check_unlock_running() {
  # 只读盘一次：把 timedatectl 之前的头部变量定义读到内存变量 UNLOCK_CFG，供下面统一取值
  [ -e /usr/bin/warp_unlock.sh ] &&
  local UNLOCK_CFG=$(awk '/timedatectl/{exit} {print}' /usr/bin/warp_unlock.sh)
  UNLOCK_MODE_NOW=$(awk -F '"' '/^MODE=/{print $2}' <<< "$UNLOCK_CFG")
  EXPECT=$(awk -F '"' '/^EXPECT=/{print $2}' <<< "$UNLOCK_CFG")
  MACHINE=$(awk -F '"' '/^MACHINE=/{print $2}' <<< "$UNLOCK_CFG")
  TG_BOT_TOKEN=$(awk -F '"' '/^TG_BOT_TOKEN=/{print $2}' <<< "$UNLOCK_CFG")
  TG_USERID=$(awk -F '"' '/^TG_USERID=/{print $2}' <<< "$UNLOCK_CFG")
  NIC=$(awk -F '"' '/^NIC=/{print $2}' <<< "$UNLOCK_CFG")
  RESTART=$(awk -F '"' '/^RESTART=/{print $2}' <<< "$UNLOCK_CFG")
}

# 判断是否已经安装 WARP 网络接口或者 Socks5 代理,如已经安装组件尝试启动，再分情况作相应处理。STATUS[0]: warp/warp-go IPv4; STATUS[1]: warp/warp-go IPv6; STATUS[2]: client proxy / client warp; STATUS[3]: wireproxy
check_warp() {
  # 检查 STATUS[0]: warp/warp-go IPv4; STATUS[1]: warp/warp-go IPv6
  if [ -z "${STATUS[*]}" ]; then
    IP_ADDRESS=$(ip a)
    if [[ "$IP_ADDRESS" =~ ": wgcf:"|": warp:" ]]; then
      [[ "$IP_ADDRESS" =~ ": wgcf:" ]] && WARP="--interface wgcf" || WARP="--interface warp"
      # 检测账户类型为 Team 的不能更换
      if [ -s /etc/wireguard/info.log ] && ! grep -q 'Device name' /etc/wireguard/info.log; then
        hint "\n $(text 32) \n" && reading " $(text 3) " CHANGE_ACCOUNT
        case "$CHANGE_ACCOUNT" in
          2 )
            [ -z "$LICENSE" ] && reading " $(text 2) " LICENSE
            local i=5
            until [[ "$LICENSE" =~ ^[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}$ ]]; do
              (( i-- )) || true
              [ "$i" = 0 ] && error " $(text 33) " && exit 1 || reading " $(text 34) " LICENSE
            done
            [[ -n "$LICENSE" && -z "$NAME" ]] && reading " $(text 35) " NAME
            [ -n "$NAME" ] && NAME="${NAME//[[:space:]]/_}" || NAME=${NAME:-'warp'}
            echo "$LICENSE" > /opt/wireguard/License
            echo -e "Device name   : $NAME\nAccount type  : limited" > /etc/wireguard/info.log
            ;;
          3 )
            exit 0
        esac
      fi
      TRACE4=$(curl -ks4m8 $WARP https://www.cloudflare.com/cdn-cgi/trace | awk -F= '/^warp/{print $2}')
      TRACE6=$(curl -ks6m8 $WARP https://www.cloudflare.com/cdn-cgi/trace | awk -F= '/^warp/{print $2}')
      [[ "$TRACE4" =~ on|plus ]] && STATUS[0]=1 || STATUS[0]=0
      [[ "$TRACE6" =~ on|plus ]] && STATUS[1]=1 || STATUS[1]=0
    elif [[ "$IP_ADDRESS" =~ ": WARP:" ]]; then
      WARP="--interface WARP"
      # 检测账户类型为 Team 的不能更换
      if grep -qE 'Type[ ]+=[ ]+team' /opt/warp-go/warp.conf; then
        hint "\n $(text 32) \n" && reading " $(text 3) " CHANGE_ACCOUNT
        case "$CHANGE_ACCOUNT" in
          2 )
            [ -z "$LICENSE" ] && reading " $(text 2) " LICENSE
            local i=5
            until [[ "$LICENSE" =~ ^[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}$ ]]; do
              (( i-- )) || true
              [ "$i" = 0 ] && error " $(text 33) " && exit 1 || reading " $(text 34) " LICENSE
            done
            [[ -n "$LICENSE" && -z "$NAME" ]] && reading " $(text 35) " NAME
            [ -n "$NAME" ] && NAME="${NAME//[[:space:]]/_}" || NAME=${NAME:-'warp'}
            echo "$LICENSE" > /opt/warp-go/License
            echo "$NAME" > /opt/warp-go/Device_Name
            ;;
          3 )
            exit 0
        esac
      fi
      TRACE4=$(curl -ks4m8 $WARP https://www.cloudflare.com/cdn-cgi/trace | awk -F= '/^warp/{print $2}')
      TRACE6=$(curl -ks6m8 $WARP https://www.cloudflare.com/cdn-cgi/trace | awk -F= '/^warp/{print $2}')
      [[ "$TRACE4" =~ on|plus ]] && STATUS[0]=1 || STATUS[0]=0
      [[ "$TRACE6" =~ on|plus ]] && STATUS[1]=1 || STATUS[1]=0
    else
      STATUS[0]=0; STATUS[1]=0
    fi

    # 检查 STATUS[2]: client proxy / client warp, 在已安装 Client 的前提下，区分模式 Mode
    if [ "$(type -p warp-cli)" ]; then
      [ "$(systemctl is-active warp-svc)" != 'active' ] && systemctl start warp-svc && sleep 5
      CLIENT_MODE=$(warp-cli --accept-tos settings | grep 'Mode')
      [[ "$CLIENT_MODE" =~ 'Warp' ]] && STATUS[2]=1 && [[ "$CLIENT_MODE" =~ 'WarpProxy' ]] && CLIENT_PORT=$(awk '{print $NF}' <<< "$CLIENT_MODE")
    else
      STATUS[2]=0
    fi

    # 检查 STATUS[3]: wireproxy
    if [ "$(type -p wireproxy)" ]; then
      # Alpine(openrc) 下用 rc-service，其余 systemd；未启动才重启
      [[ ! "$(ss -nltp | awk -F\" '{print $2}' | sed '/^$/d')" =~ 'wireproxy' ]] && { [ "$SYSTEM" = Alpine ] && rc-service wireproxy restart >/dev/null 2>&1 || systemctl restart wireproxy >/dev/null 2>&1; }
      [[ "$(ss -nltp | awk -F\" '{print $2}' | sed '/^$/d')" =~ 'wireproxy' ]] && WIREPROXY_PORT=$(ss -nltp | awk '/"wireproxy"/{print $4}' | awk -F: '{print $2}') && STATUS[3]=1
    else
      STATUS[3]=0
    fi
  fi

  warp() { wget -N --no-check-certificate https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh; exit; }
  warp-go() { wget -N --no-check-certificate https://gitlab.com/fscarmen/warp/-/raw/main/warp-go.sh && bash warp-go.sh; exit; }

  CASE_WARP4() { NIC="-ks4m8 $WARP"; RESTART="warp_restart"; }
  CASE_WARP6() { NIC="-ks6m8 $WARP"; RESTART="warp_restart"; }
  CASE_CLIENT4() { NIC='-ks4m8 --interface CloudflareWARP' && RESTART="client_restart" && [ "$(warp-cli --accept-tos settings | awk '/Mode:/{for (i=0; i<NF; i++) if ($i=="Mode:") {print $(i+1)}}')" = WarpProxy ] && NIC="-4 -sx socks5://127.0.0.1:$CLIENT_PORT"; }
  CASE_CLIENT6() { NIC='-ks6m8 --interface CloudflareWARP' && RESTART="client_restart" && [ "$(warp-cli --accept-tos settings | awk '/Mode:/{for (i=0; i<NF; i++) if ($i=="Mode:") {print $(i+1)}}')" = WarpProxy ] && NIC="-6 -sx socks5://127.0.0.1:$CLIENT_PORT"; }
  CASE_WIREPROXY4() { NIC="-ks4m8 -x socks5://127.0.0.1:$WIREPROXY_PORT"; RESTART="wireproxy_restart"; }
  CASE_WIREPROXY6() { NIC="-ks6m8 -x socks5://127.0.0.1:$WIREPROXY_PORT"; RESTART="wireproxy_restart"; }

  INSTALL_CHECK=("0 0 0 0" "1 1 1 1" "0 1 1 1" "1 0 1 1" "1 1 1 0" "1 1 0 1" "0 0 1 1" "0 1 1 0" "1 0 1 0" "0 1 0 1" "1 0 0 1" "1 1 0 0" "0 0 1 0" "0 0 0 1" "0 1 0 0" "1 0 0 0")
  SHOW=("\n $(text 4) \n" "\n $(text 49) \n" "\n $(text 43) \n" "\n $(text 46) \n" "\n $(text 48) \n" "\n $(text 47) \n" "\n $(text 41) \n" "\n $(text 6) \n" "\n $(text 45) \n" "\n $(text 42) \n" "\n $(text 44) \n" "\n $(text 23) \n" "\n $(text 37) \n" "\n $(text 38) \n")
  NUM=("0|1|2" "1|2|3|4|5|6" "1|2|3|4|5" "1|2|3|4|5" "1|2|3|4" "1|2|3|4" "1|2|3|4" "1|2|3" "1|2|3" "1|2|3" "1|2|3" "1|2" "1|2" "1|2")
  DO1=("warp" "CASE_WIREPROXY4" "CASE_WIREPROXY4" "CASE_WIREPROXY4" "CASE_CLIENT4" "CASE_WIREPROXY4" "CASE_WIREPROXY4" "CASE_CLIENT4" "CASE_CLIENT4" "CASE_WIREPROXY4" "CASE_WIREPROXY4" "CASE_WARP4" "CASE_CLIENT4" "CASE_WIREPROXY4" "CASE_WARP6" "CASE_WARP4")
  DO2=("warp-go" "CASE_WIREPROXY6" "CASE_WIREPROXY6" "CASE_WIREPROXY6" "CASE_CLIENT6" "CASE_WIREPROXY6" "CASE_WIREPROXY6" "CASE_CLIENT6" "CASE_CLIENT6" "CASE_WIREPROXY6" "CASE_WIREPROXY6" "CASE_WARP6" "CASE_CLIENT6" "CASE_WIREPROXY6")
  DO3=("" "CASE_CLIENT4" "CASE_CLIENT4" "CASE_CLIENT4" "CASE_WARP4" "CASE_WARP4" "CASE_CLIENT4" "CASE_WARP6" "CASE_WARP4" "CASE_CLIENT6" "CASE_WARP4")
  DO4=("" "CASE_CLIENT6" "CASE_CLIENT6" "CASE_CLIENT6" "CASE_WARP6" "CASE_WARP6" "CASE_CLIENT6")
  DO5=("" "CASE_WARP4" "CASE_WARP6" "CASE_WARP4")
  DO6=(" "  "CASE_WARP6")
  DO0=("exit")

  for f in ${!INSTALL_CHECK[@]}; do
    [[ "${STATUS[*]}" = "${INSTALL_CHECK[f]}" ]] && break
  done

  # 默认只安装一种 WARP 形式时，不用选择。如两种或以上则让用户选择哪个方式的解锁
  CHOOSE2=1
  if grep -qvwE "14|15" <<< "$f"; then
    hint "${SHOW[f]}" && reading " $(text 3) " CHOOSE2
    [[ "$f" = 0 && "$CHOOSE2" != [0-2] ]] && CHOOSE2=1
    grep -qvwE "${NUM[f]}" <<< "$CHOOSE2" && error " $(text 24) "
  fi
  $(eval echo \${DO$CHOOSE2[f]})
}

# 期望解锁流媒体, 解锁项目数组 STREAM 的元素个数，限制选项枚举的次数，不填默认全选, 解锁状态保存在 /usr/bin/status.log
input_streammedia_unlock() {
  if [ -z "${STREAM_UNLOCK[@]}" ]; then
    hint "\n $(text 15) \n" && reading " $(text 3) " CHOOSE4
    for d in "${!STREAM[@]}"; do
      ( [ -z "$CHOOSE4" ] || echo "$CHOOSE4" | grep -q "$((d+1))" ) && STREAM_UNLOCK[d]='1' || STREAM_UNLOCK[d]='0'
      [ "$d" = 0 ] && echo "${STREAM[d]}: null" > /usr/bin/status.log || echo "${STREAM[d]}: null" >> /usr/bin/status.log
    done
  fi
  for ((e=0; e<"${#STREAM[*]}"; e++)); do
    [ "${STREAM_UNLOCK[e]}" = 1 ] && UNLOCK_SELECT+="
[[ ! \${R[*]} =~ 'No' ]] && check$e;" ||
    UNLOCK_SELECT+="
#[[ ! \${R[*]} =~ 'No' ]] && check$e;"
  done
}

# 期望解锁地区
input_region() {
  if [ -z "$EXPECT" ]; then
  REGION=$(curl -ksm8 -A Mozilla $IP_API | grep -E "country_iso|country_code" | sed 's/.*country_[a-z]\+\":[ ]*\"\([^"]*\).*/\1/g' 2>/dev/null)
  reading "\n $(text 13) " EXPECT
  until [[ -z "$EXPECT" || "${EXPECT,,}" = 'y' || "$EXPECT" =~ ^[A-Za-z]{2}$ ]]; do
    reading "\n $(text 13) " EXPECT
  done
  [[ -z "$EXPECT" || "${EXPECT,,}" = 'y' ]] && EXPECT="$REGION"
  fi
}

# Telegram Bot 日志推送
input_tg() {
  [ -z "$MACHINE" ] && reading "\n $(text 29) " TG_BOT_TOKEN
  [[ -n "$TG_BOT_TOKEN" && -z "$TG_USERID" ]] && reading "\n $(text 30) " TG_USERID
  [[ -n "$TG_BOT_TOKEN" && -z "$MACHINE" ]] && reading "\n $(text 31) " MACHINE
}

# 根据用户选择在线生成解锁程序，放在 /etc/wireguard/unlock.sh
export_unlock_file() {
  input_streammedia_unlock

  input_region

  input_tg

  # 根据解锁模式写入定时任务或systemd
  sh -c "$TASK"

  # 生成 warp_unlock.sh 文件，判断当前流媒体解锁状态，遇到不解锁时更换 WARP IP，直至刷成功。5分钟后还没有刷成功，将不会重复该进程而浪费系统资源

  # 生成 warp_unlock.sh 文件：内容累积到 WARP_UNLOCK_SRC（+=），最后一次性写盘，不用 heredoc。
  # 后台常驻（模式2/3/4/5，CHOOSE1≠1）用 while true:do 包裹并整体缩进2空格；crontab 定时（模式1）不包裹。
  local WARP_UNLOCK_SRC="" I="  "
  [ -n "$CHOOSE1" ] && [ "$CHOOSE1" != 1 ] && I="    "

  # 分段 A：头部变量（按实际值替换）
  WARP_UNLOCK_SRC+='#!/usr/bin/env bash
'
  WARP_UNLOCK_SRC+="MODE=\"$CHOOSE1\"
EXPECT=\"$EXPECT\"
MACHINE=\"$MACHINE\"
SYSTEM=\"$SYSTEM\"
TG_BOT_TOKEN=\"$TG_BOT_TOKEN\"
TG_USERID=\"$TG_USERID\"

NIC=\"$NIC\"
RESTART=\"$RESTART\"
WARP=\"$WARP\"
IP_API=\"$IP_API\"
ISP=\"$ISP\"
"
  # 分段 B：固定逻辑（heredoc 读入追加到变量，内容零转义、可读）
  WARP_UNLOCK_SRC+="$(cat <<'EOF'
LOG_LIMIT="1000"
UNLOCK_STATUS='Yes 🎉'
NOT_UNLOCK_STATUS='No 😰'

# 设时区：Alpine(openrc) 无 timedatectl，写入 /etc/timezone 并软链 localtime；其余系统用 timedatectl
if [ "$SYSTEM" = Alpine ]; then
  echo 'Asia/Shanghai' > /etc/timezone
  ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
else
  timedatectl set-timezone Asia/Shanghai
fi

if [[ $(pgrep -laf $0 | wc -l) < 4 ]]; then
  # 日志：IP 列宽 IPW 按 IPv4/IPv6 动态取（IPv6=46、IPv4=30，用 %-*s），Country 定宽 COW=18，使 Country 对齐且 IPv4 不多空格。
  log_message() {
    local _ip _co IPW
    # IPv6 地址含冒号、比 IPv4 长；按 IP 类型决定 IP 列宽，既让 Country 对齐又不至于 IPv4 空格过多。
    [[ "$WAN" == *:* ]] && IPW=46 || IPW=30
    printf -v _ip '%-*s' "$IPW" "IP: $WAN"
    printf -v _co '%-18s' "Country: $COUNTRY"
    printf '%s. %s%s %s\n' "$(date +'%F %T')" "$_ip" "$_co" "$CONTENT" | tee -a /root/result.log
    [[ $(wc -l < /root/result.log) -gt $LOG_LIMIT ]] && sed -i "1,10d" /root/result.log
  }

  # Telegram 消息推送函数：向指定的 Telegram 用户发送消息通知
  tg_message() {
    curl -s -X POST "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" \
      -d chat_id=$TG_USERID \
      -d text="💻 $MACHINE. ⏰ $(date +'%F %T'). 🛰 $WAN  🌏 $COUNTRY. $CONTENT" \
      -d parse_mode="HTML" >/dev/null 2>&1
  }

  # 纯 awk JSON 美化器（0 依赖，替代旧的 $JSON_TOOL）
  json_pretty() {
    awk 'BEGIN{in_str=0;depth=0;ind="  "}
      {
        len=length($0);
        for(i=1;i<=len;i++){
          c=substr($0,i,1);
          if(in_str){
            printf "%s", c;
            if(c=="\\"){ i++; printf "%s", substr($0,i,1) }
            else if(c=="\""){ in_str=0 }
            continue
          }
          if(c=="\"" ){ in_str=1; printf "%s", c; continue }
          if(c==" " || c=="\t" || c=="\r"){ continue }
          if(c=="{" || c=="["){
            printf "%s\n", c;
            depth++;
            for(d=0;d<depth;d++) printf "%s", ind;
            continue
          }
          if(c=="}" || c=="]"){
            printf "\n";
            depth--; if(depth<0) depth=0;
            for(d=0;d<depth;d++) printf "%s", ind;
            printf "%s", c;
            continue
          }
          if(c==","){
            printf "%s\n", c;
            for(d=0;d<depth;d++) printf "%s", ind;
            continue
          }
          if(c==":"){
            printf ": ";
            continue
          }
          printf "%s", c
        }
        print ""
      }' | sed '/^[[:space:]]*$/d'
  }

  fetch_account_information() {
    local REGISTER_PATH="$1"
    if grep -q 'xml version' $REGISTER_PATH; then
      WARP_DEVICE_ID=$(grep 'correlation_id' $REGISTER_PATH | sed "s#.*>\(.*\)<.*#\1#")
      WARP_TOKEN=$(grep 'warp_token' $REGISTER_PATH | sed "s#.*>\(.*\)<.*#\1#")
      CLIENT_ID=$(grep 'client_id' $REGISTER_PATH | sed "s#.*client_id&quot;:&quot;\([^&]\{4\}\)&.*#\1#")

    # 官方 api 文件
    elif grep -q 'client_id' $REGISTER_PATH; then
      WARP_DEVICE_ID=$(grep -m1 '"id' "$REGISTER_PATH" | cut -d\" -f4)
      WARP_TOKEN=$(grep '"token' "$REGISTER_PATH" | cut -d\" -f4)
      CLIENT_ID=$(grep 'client_id' "$REGISTER_PATH" | cut -d\" -f4)

    # client 文件，默认存放路径为 /var/lib/cloudflare-warp/reg.json
    elif grep -q 'registration_id' $REGISTER_PATH; then
      WARP_DEVICE_ID=$(cut -d\" -f4 "$REGISTER_PATH")
      WARP_TOKEN=$(cut -d\" -f8 "$REGISTER_PATH")

    # wgcf 文件，默认存放路径为 /etc/wireguard/wgcf-account.toml
    elif grep -q 'access_token' $REGISTER_PATH; then
      WARP_DEVICE_ID=$(grep 'device_id' "$REGISTER_PATH" | cut -d\' -f2)
      WARP_TOKEN=$(grep 'access_token' "$REGISTER_PATH" | cut -d\' -f2)

    # warp-go 文件，默认存放路径为 /opt/warp-go/warp.conf
    elif grep -q 'PrivateKey' $REGISTER_PATH; then
      WARP_DEVICE_ID=$(awk -F' *= *' '/^Device/{print $2}' "$REGISTER_PATH")
      WARP_TOKEN=$(awk -F' *= *' '/^Token/{print $2}' "$REGISTER_PATH")

    else
      echo " There is no registered account information, please check the content. " && exit 1
    fi
  }

  check_ip() {
    unset IP_INFO WAN COUNTRY ASNORG
    IP_INFO="$(curl $NIC -A Mozilla $IP_API)"
    read -r WAN COUNTRY ASNORG <<< "$(awk -F'"' -v ispk="$ISP" '{ if ($2=="ip") ip=$4; else if ($2=="country") co=$4; else if ($2==ispk) asn=$4 } END { printf "%s %s %s", ip, co, asn }' <<< "$(json_pretty 2>&1 <<< "$IP_INFO")")"
  }

  # api 注册账户
  registe_api() {
    local REGISTE_FILE_PATH="$1"
    local LICENSE="$2"
    local NAME="$3"
    local i=0; local j=5
    until [ -s $REGISTE_FILE_PATH ]; do
      ((i++)) || true
      [ "$i" -gt "$j" ] && rm -f $REGISTE_FILE_PATH && echo -e " Failed to register warp account. Script aborted. " && exit 1
      if ! grep -sq 'PrivateKey' $REGISTE_FILE_PATH; then
        unset CF_API_REGISTE API_DEVICE_ID API_ACCESS_TOKEN API_PRIVATEKEY API_TYPE
        rm -f $REGISTE_FILE_PATH

        if [ -x "$(type -p wg)" ]; then
          local PRIVATE_KEY=$(wg genkey)
          local PUBLIC_KEY=$(wg pubkey <<<"$PRIVATE_KEY")
        elif [[ -x "$(type -p openssl)" && -x "$(type -p base64)" ]]; then
          local KEY_DER=$(openssl genpkey -algorithm X25519 -outform DER | base64 | tr -d '\n')
          local PRIVATE_KEY=$(echo -n "$KEY_DER" | base64 -d | tail -c 32 | base64 | tr -d '\n')
          local PUBLIC_KEY=$(echo -n "$KEY_DER" | base64 -d | openssl pkey -inform DER -pubout -outform DER | tail -c 32 | base64 | tr -d '\n')
        elif [[ -x "$(type -p openssl)" && -x "$(type -p xxd)" && -x "$(type -p base64)" ]]; then
          # 兜底：保留旧 openssl+xxd 路径（非主路径）
          local KEY_PAIR=$(openssl genpkey -algorithm X25519 | openssl pkey -text -noout)
          local PRIVATE_KEY=$(echo $KEY_PAIR | sed 's/.*priv:\(.*\)pub.*/\1/; s/ //g' | xxd -r -p | base64)
          local PUBLIC_KEY=$(echo $KEY_PAIR | sed 's/.*pub://; s/ //g'| xxd -r -p | base64)
        else
          local WG_API=$(curl -m5 -sSL "https://warp.cloudflare.nyc.mn/?run=key&format=yaml")
          local PRIVATE_KEY=$(awk '/PrivateKey/{print $NF}' <<< "$WG_API")
          local PUBLIC_KEY=$(awk '/PublicKey/{print $NF}' <<< "$WG_API")
        fi

        if grep -q '.' <<< "$PRIVATE_KEY" && grep -q '.' <<< "$PUBLIC_KEY"; then
          local INSTALL_ID=$(tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 22)
          local FCM_TOKEN="${INSTALL_ID}:APA91b$(tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 134)"

          grep -q '.' <<< "$WARP_TEAM_TOKEN" && local TEAM_HEADER="--header \"Cf-Access-Jwt-Assertion: $(sed 's/.*?token=//' <<< "$WARP_TEAM_TOKEN")\""
          until grep -q 'account' <<< "$ACCOUNT"; do
            # error code 1015 为限流，等待后重试
            [ "$ACCOUNT" = 'error code: 1015' ] && sleep 10
            ((REGISTER_ERROR_TIME++))
            if [ "$REGISTER_ERROR_TIME" -gt 30 ]; then
              break
            elif [ "$REGISTER_ERROR_TIME" -gt 1 ]; then
              sleep 5
            fi
            local ACCOUNT=$(curl --request POST 'https://api.cloudflareclient.com/v0a2158/reg' \
              --silent \
              --location \
              --tlsv1.3 \
              --header 'User-Agent: okhttp/3.12.1' \
              --header 'CF-Client-Version: a-6.10-2158' \
              --header 'Content-Type: application/json' \
              $TEAM_HEADER \
              --data '{"key":"'${PUBLIC_KEY}'","install_id":"'${INSTALL_ID}'","fcm_token":"'${FCM_TOKEN}'","tos":"'$(date +"%Y-%m-%dT%H:%M:%S.000Z")'","model":"PC","serial_number":"'${INSTALL_ID}'","locale":"zh_CN"}')
          done

          if grep -q 'account' <<< "$ACCOUNT"; then
            local CLIENT_ID=$(sed 's/.*"client_id":"\([^\"]\+\)\".*/\1/' <<<"$ACCOUNT")
            local RESERVED=$(printf '[%s]' "$(printf '%s' "$CLIENT_ID" | base64 -d | while LC_ALL=C read -rn1 c; do printf "%d, " "'$c"; done | sed 's/, $//')")

            # 1. 压成单行（去 \r\n），便于 sed 单遍插入
            ACCOUNT=$(tr -d '\r\n' <<<"$ACCOUNT")

            # 2. 插入 private_key；若 API 已含 reserved 则仅插 private_key，否则同时插 reserved
            if grep -q '"reserved"' <<<"$ACCOUNT"; then
              ACCOUNT=$(sed "s|\"key\":\"[^\"]*\"|&,\"private_key\":\"$PRIVATE_KEY\"|" <<<"$ACCOUNT")
            else
              ACCOUNT=$(sed -E \
                -e "s|\"key\":\"[^\"]*\"|&,\"private_key\":\"$PRIVATE_KEY\"|" \
                -e "s|\"client_id\":\"[^\"]*\"|&,\"reserved\":$RESERVED|" \
                <<<"$ACCOUNT")
            fi

            # 3. 纯 awk 美化回多行（0 依赖，替代旧的 $JSON_TOOL）
            CF_API_REGISTE=$(json_pretty 2>&1 <<<"$ACCOUNT")
          fi
        fi

        if grep -q 'private_key' <<< "$CF_API_REGISTE"; then
          local API_DEVICE_ID API_ACCESS_TOKEN API_PRIVATEKEY API_TYPE
          read -r API_DEVICE_ID API_ACCESS_TOKEN API_PRIVATEKEY API_TYPE <<< "$(awk '/"id"|"token"|"private_key"|"account_type"/ { k=$1; gsub(/[":]/, "", k); gsub(/[" ,]/, "", $2); if (!(k in v)) v[k]=$2 } END { printf "%s %s %s %s", v["id"], v["token"], v["private_key"], v["account_type"] }' <<< "$CF_API_REGISTE")"
          if [[ "$REGISTE_FILE_PATH" =~ '/opt/warp-go' ]]; then
            cat > $REGISTE_FILE_PATH << ABC
[Account]
Device = $API_DEVICE_ID
PrivateKey = $API_PRIVATEKEY
Token = $API_ACCESS_TOKEN
Type = $API_TYPE

[Device]
Name = WARP
MTU  = 1280

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
Endpoint = 162.159.193.10:1701
KeepAlive = 30
# AllowedIPs = 0.0.0.0/0
# AllowedIPs = ::/0

ABC

          elif [[ "$REGISTE_FILE_PATH" =~ '/etc/wireguard' ]]; then
            printf '%s\n' "$CF_API_REGISTE" > "$REGISTE_FILE_PATH"
          fi

          # 如果文件有问题，则删除该注册文件
          if grep -sqE 'Account|account_type' $REGISTE_FILE_PATH; then
            grep -sq Account $REGISTE_FILE_PATH && echo -e "\n[Script]\nPostUp =\nPostDown =" >> $REGISTE_FILE_PATH && sed -i 's/\r//' $REGISTE_FILE_PATH
          else
            rm -f $REGISTE_FILE_PATH
          fi

          # 如是 plus 账户，升级账户
          if [[ -n "$LICENSE" && -n "$NAME" ]]; then
            fetch_account_information $REGISTE_FILE_PATH

            curl --request PUT "https://api.cloudflareclient.com/v0a2158/reg/${WARP_DEVICE_ID}/account" \
              --silent \
              --location \
              --header 'User-Agent: okhttp/3.12.1' \
              --header 'CF-Client-Version: a-6.10-2158' \
              --header 'Content-Type: application/json' \
              --header "Authorization: Bearer ${WARP_TOKEN}" \
              --data '{"license": "'$LICENSE'"}'

            curl --request PATCH "https://api.cloudflareclient.com/v0a2158/reg/${WARP_DEVICE_ID}" \
              --silent \
              --location \
              --header 'User-Agent: okhttp/3.12.1' \
              --header 'CF-Client-Version: a-6.10-2158' \
              --header 'Content-Type: application/json' \
              --header "Authorization: Bearer ${WARP_TOKEN}" \
              --data '{"name":"'$NAME'"}' >/dev/null 2>&1
          fi
        fi
      fi

    done
  }

  # 注销 warp 账户
  delete_warp_account() {
    curl --request DELETE "https://api.cloudflareclient.com/v0a2158/reg/${WARP_DEVICE_ID}" \
        --silent \
        --location \
        --header 'User-Agent: okhttp/3.12.1' \
        --header 'CF-Client-Version: a-6.10-2158' \
        --header 'Content-Type: application/json' \
        --header "Authorization: Bearer ${WARP_TOKEN}"
  }

  warp_restart() {
    INTERFACE=$(cut -d ' ' -f2 <<< "$WARP")
    case "$INTERFACE" in
      # warp-go 处理方案
      WARP )
        [ -s /opt/warp-go/License ] && local LICENSE=$(cat /opt/warp-go/License)
        [[ -n "$LICENSE" && -s /opt/warp-go/Device_Name ]] && local NAME=$(cat /opt/warp-go/Device_Name)
        cp -f /opt/warp-go/warp.conf{,.tmp1}
        registe_api /opt/warp-go/warp.conf.tmp2 $LICENSE $NAME
        sed -i '1,6!d' /opt/warp-go/warp.conf.tmp2
        tail -n +7 /opt/warp-go/warp.conf.tmp1 >> /opt/warp-go/warp.conf.tmp2
        mv /opt/warp-go/warp.conf.tmp2 /opt/warp-go/warp.conf
        fetch_account_information /opt/warp-go/warp.conf.tmp1
        delete_warp_account >/dev/null 2>&1
        rm -f /opt/warp-go/warp.conf.tmp*
        # Alpine(openrc) 无 systemd：pkill + 后台重启 warp-go（对齐 warp-go.sh 的 alpine_warp_restart）；其余系统走 systemctl
        [ "$SYSTEM" = Alpine ] && { pkill -f warp-go 2>/dev/null; /opt/warp-go/warp-go --config=/opt/warp-go/warp.conf >/dev/null 2>&1 & } || systemctl restart warp-go
        sleep 10
        ;;

      # warp 处理方案
      warp )
        [ -s /etc/wireguard/license ] && local LICENSE=$(cat /etc/wireguard/license)
        [ -n "$LICENSE" ] && grep -sq 'Device name' /etc/wireguard/info.log && local NAME=$(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }')
        [ -e /etc/wireguard/warp-account.conf ] && mv -f /etc/wireguard/warp-account.conf{,.tmp}
        wg-quick down warp >/dev/null 2>&1
        registe_api /etc/wireguard/warp-account.conf $LICENSE $NAME
        local PRIVATEKEY="$(grep 'private_key' /etc/wireguard/warp-account.conf | cut -d\" -f4)"
        local ADDRESS6="$(grep '"v6.*"$' /etc/wireguard/warp-account.conf | cut -d\" -f4)"
        local RESERVED="$(printf '[%s]' "$(grep 'client_id' /etc/wireguard/warp-account.conf | cut -d\" -f4 | base64 -d | while LC_ALL=C read -rn1 c; do printf '%d, ' "'$c"; done | sed 's/, $//')")"
        sed -i "s#\(PrivateKey[ ]\+=[ ]\+\).*#\1$PRIVATEKEY#g; s#\(Address[ ]\+=[ ]\+\).*\(/128\)#\1$ADDRESS6\2#g; s#\(.*Reserved[ ]\+=[ ]\+\).*#\1$RESERVED#g" /etc/wireguard/warp.conf
        fetch_account_information /etc/wireguard/warp-account.conf.tmp
        delete_warp_account >/dev/null 2>&1
        rm -f /etc/wireguard/warp-account.conf.tmp
        wg-quick up warp >/dev/null 2>&1
        sleep 10
        [[ "$(ss -nltp | awk -F\" '{print $2}' | sed '/^$/d')" =~ 'dnsmasq' ]] && { [ "$SYSTEM" = Alpine ] && rc-service dnsmasq restart >/dev/null 2>&1 || systemctl restart dnsmasq >/dev/null 2>&1; sleep 2; }
        ;;

      # wgcf 处理方案
      wgcf )
        # Alpine(openrc)：openrc 无 systemd @模板，直接 wg-quick down/up（对齐 alpine_warp_restart）
        [ "$SYSTEM" = Alpine ] && { wg-quick down wgcf >/dev/null 2>&1; wg-quick up wgcf >/dev/null 2>&1; } || systemctl restart wg-quick@wgcf
        sleep 2
        [[ "$(ss -nltp | awk -F\" '{print $2}' | sed '/^$/d')" =~ 'dnsmasq' ]] && { [ "$SYSTEM" = Alpine ] && rc-service dnsmasq restart >/dev/null 2>&1 || systemctl restart dnsmasq >/dev/null 2>&1; }
        sleep 2
    esac
    check_ip
  }

  client_restart() {
    local CLIENT_MODE=$(warp-cli --accept-tos settings | awk '/Mode:/{for (i=0; i<NF; i++) if ($i=="Mode:") {print $(i+1)}}')
    if [ "$CLIENT_MODE" = 'Warp' ]; then
      [ "$NIC" = '-ks4m8 --interface CloudflareWARP' ] && IP_RULE='-4' || IP_RULE='-6'
      warp-cli --accept-tos delete >/dev/null 2>&1
      ip $IP_RULE rule delete from 172.16.0.2/32 lookup 51820
      ip $IP_RULE rule delete table main suppress_prefixlength 0
      warp-cli --accept-tos register >/dev/null 2>&1 &&
      [ -s /etc/wireguard/license ] && warp-cli --accept-tos set-license $(cat /etc/wireguard/license) >/dev/null 2>&1
      sleep 10
      ip $IP_RULE rule add from 172.16.0.2 lookup 51820
      ip $IP_RULE route add default dev CloudflareWARP table 51820
      ip $IP_RULE rule add table main suppress_prefixlength 0
    elif [ "$CLIENT_MODE" = 'WarpProxy' ]; then
      warp-cli --accept-tos delete >/dev/null 2>&1
      warp-cli --accept-tos register >/dev/null 2>&1 &&
      [ -s /etc/wireguard/license ] && warp-cli --accept-tos set-license $(cat /etc/wireguard/license) >/dev/null 2>&1
      sleep 10
    fi
    check_ip
  }

  wireproxy_restart() { [ "$SYSTEM" = Alpine ] && rc-service wireproxy restart >/dev/null 2>&1 || systemctl restart wireproxy >/dev/null 2>&1; sleep 5; check_ip; }

  check0() {
    unset R[0] REGION[0]

    # Netflix 检测函数
    MediaUnlockTest_Netflix() {
      local RESULT=$( { curl ${NIC} --user-agent "${UA_BROWSER}" -SsL --max-time 10 --tlsv1.3 "https://www.netflix.com/title/81280792"; \
                         curl ${NIC} --user-agent "${UA_BROWSER}" -SsL --max-time 10 --tlsv1.3 "https://www.netflix.com/title/70143836"; } 2>&1 | \
        awk '
        NR==1{u=1}
        /curl:/{print "error"; exit}
        /og:video/{v=1}
        {
          if(!r && match($0,/"requestCountry":\{"supportedLocales":\[[^]]+\],"id":"[^"]+"/)){
            s=substr($0,RSTART,RLENGTH);
            sub(/.*"id":"*/,"",s);
            sub(/".*/,"",s);
            r=s
          }
        }
        END {
          if(!u || r=="") {print "error"}
          else { print (v?"full":"orig") ":" r }
        }')

      # 解析 JSON 结果
      [[ "$RESULT" == "error" || -z "$RESULT" ]] && return 2

      local STATUS=$(echo $RESULT | cut -d':' -f1)
      REGION[0]=$(echo $RESULT | cut -d':' -f2)

      if [[ "$STATUS" == "full" ]]; then
          echo "${REGION[0]}" | grep -qi "$EXPECT" && return 0 || return 1
      else
          return 1
      fi
    }

    # 执行检测
    MediaUnlockTest_Netflix

    # Netflix 返回码说明:
    # 0: 成功解锁
    # 1: 仅支持原创内容
    # 2: 网络连接错误

    case "$?" in
      0 )
        R[0]="$UNLOCK_STATUS"
        CONTENT="Netflix: ${R[0]}${REGION[0]:+ (Region: ${REGION[0]^^})}."
        ;;
      1 )
        R[0]="$NOT_UNLOCK_STATUS"
        CONTENT="Netflix: ${R[0]} Originals Only${REGION[0]:+ (Region: ${REGION[0]^^})}."
        ;;
      * )
        R[0]="$NOT_UNLOCK_STATUS"
        CONTENT="Netflix: ${R[0]} (Network Error)."
        ;;
    esac

    log_message
    grep -q '.' <<< "$MACHINE" && [[ ${R[0]} != $(sed -n '1s/.*: \(.*\)/\1/p' /usr/bin/status.log) ]] && tg_message
    sed -i "1s/Netflix: .*/Netflix: ${R[0]}/" /usr/bin/status.log
  }

  check1() {
    unset R[1] REGION[1]

    # Disney+ 检测函数
    MediaUnlockTest_DisneyPlus() {
      # ========== 1. 向Disney+设备注册接口发送请求，获取设备注册的assertion ==========
      local ASSERTION=$(curl ${NIC} --user-agent "${UA_BROWSER}" -s --max-time 10 -X POST "https://disney.api.edge.bamgrid.com/devices" -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -H "content-type: application/json; charset=UTF-8" -d '{"deviceFamily":"browser","applicationRuntime":"chrome","deviceProfile":"windows","attributes":{}}' 2>&1 | sed 's/.*assertion":"\([^"]\+\)".*/\1/')

      grep -q 'curl:' <<< "$ASSERTION" && return 1

      # ========== 2. 构造获取token所需的参数内容 ==========
      local DISNEYCOOKIE=$(sed "s/DISNEYASSERTION/${ASSERTION}/g" <<< 'grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Atoken-exchange&latitude=0&longitude=0&platform=browser&subject_token=DISNEYASSERTION&subject_token_type=urn%3Abamtech%3Aparams%3Aoauth%3Atoken-type%3Adevice')

      # ========== 3. 使用构造好的参数向token接口发送请求，获取访问令牌 ==========
      local TOKEN_CONTENT=$(curl ${NIC} --user-agent "${UA_BROWSER}" -s --max-time 10 -X POST "https://disney.api.edge.bamgrid.com/token" -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -d "$DISNEYCOOKIE" 2>&1)

      grep -qE 'forbidden-location|403 ERROR' <<< "$TOKEN_CONTENT" && return 1

      # ========== 4. 从返回结果中提取refreshToken ==========
      local REFRESH_TOKEN=$(sed 's/.*"refresh_token":[ ]*"\([^"]\+\)".*/\1/' <<< "$TOKEN_CONTENT")

      # ========== 5. 构造GraphQL查询参数 ==========
      local DISNEY_CONTENT='{"query":"mutation refreshToken($input: RefreshTokenInput!) {\n            refreshToken(refreshToken: $input) {\n                activeSession {\n                    sessionId\n                }\n            }\n        }","variables":{"input":{"refreshToken":"'${REFRESH_TOKEN}'"}}}'

      # ========== 6. 发送GraphQL查询请求，获取用户会话及区域信息 ==========
      local TMP_RESULT=$(curl ${NIC} --user-agent "${UA_BROWSER}" -X POST -sSL --max-time 10 "https://disney.api.edge.bamgrid.com/graph/v1/device/graphql" -H "authorization: ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -d "$DISNEY_CONTENT" 2>&1)

      grep -q 'curl:' <<< "$TMP_RESULT" && return 1

      # ========== 7. 访问Disney+主页，检查页面跳转情况 ==========
      local PREVIEW_CHECK_TMP=$(curl ${NIC} -s -o /dev/null -L --max-time 10 -w '%{url_effective}\n' "https://www.disneyplus.com")

      grep -q 'curl:' <<< "$PREVIEW_CHECK_TMP" && return 1

      # ========== 8. 解析返回数据，提取区域信息和可用性状态 ==========
      local IS_UNAVAILABLE=$(grep -E 'preview.*unavailable' <<< "$PREVIEW_CHECK_TMP")

      local REGION=$(sed -n 's/.*"countryCode":[ ]*"\([^"]\+\)".*/\1/p' <<< "$TMP_RESULT")

      local IN_SUPPORTED_LOCATION=$(sed -n 's/.*"inSupportedLocation":[ ]*\([^,]\+\),.*/\1/p' <<< "$TMP_RESULT")

      if [ -z "$REGION" ]; then
          return 2
      elif [[ "$REGION" == "JP" ]]; then
          # Japan region
          REGION[1]="JP"
          return 0
      elif [ -n "$IS_UNAVAILABLE" ]; then
          # Unavailable
          return 3
      elif [[ "$IN_SUPPORTED_LOCATION" == "true" ]]; then
          # Supported location
          REGION[1]="$REGION"
          return 0
      elif [[ "$IN_SUPPORTED_LOCATION" == "false" ]]; then
          # Will be available soon
          REGION[1]="$REGION"
          return 4
      else
          # Failed
          return 5
      fi

    }

    # 执行检测
    MediaUnlockTest_DisneyPlus

    # Disney+ 返回码说明:
    # 0: 成功解锁(包括日本地区)
    # 1: 网络连接错误
    # 2: 未知区域
    # 3: 不可用
    # 4: 即将支持该区域
    # 5: 检测失败
    case "$?" in
      0 )
        R[1]="$UNLOCK_STATUS"
        CONTENT="Disney+: ${R[1]}${REGION[1]:+ (Region: ${REGION[1]^^})}."
        ;;
      1 )
        R[1]="$NOT_UNLOCK_STATUS"
        CONTENT="Disney+: ${R[1]} (Network Error)."
        ;;
      2 )
        R[1]="$NOT_UNLOCK_STATUS"
        CONTENT="Disney+: ${R[1]} (Unknown)."
        ;;
      3 )
        R[1]="$NOT_UNLOCK_STATUS"
        CONTENT="Disney+: ${R[1]} (Unavailable)."
        ;;
      4 )
        R[1]="$NOT_UNLOCK_STATUS"
        CONTENT="Disney+: Available For [Disney+ ${REGION[1]:-(Unknown)}] Soon."
        ;;
      5 )
        R[1]="$NOT_UNLOCK_STATUS"
        CONTENT="Disney+: ${R[1]} (Failed)."
        ;;
      * )
        R[1]="$NOT_UNLOCK_STATUS"
        CONTENT="Disney+: ${R[1]}."
        ;;
    esac

    log_message
    grep -q '.' <<< "$MACHINE" && [[ ${R[1]} != $(sed -n '2s/.*: \(.*\)/\1/p' /usr/bin/status.log) ]] && tg_message
    sed -i "2s/Disney+: .*/Disney+: ${R[1]}/" /usr/bin/status.log
  }

  check2() {
    unset R[2] REGION[2]

    # ChatGPT 检测函数
    MediaUnlockTest_ChatGPT() {
      # ========== 1. 访问 ChatGPT 主页，检查响应 ==========
      local RESULT_WEB=$(curl ${NIC} --user-agent "${UA_BROWSER}" -SsLI --max-time 10 "https://chatgpt.com" 2>&1 | grep -E 'curl:|location')

      grep -q 'curl:' <<< "$RESULT_WEB" && return 1

      # ========== 2. 访问 iOS 版本页面，检查限制信息 ==========
      local RESULT_ISO=$(curl ${NIC} --user-agent "${UA_BROWSER}" -SsL --max-time 10 "https://ios.chat.openai.com" 2>&1)

      # ========== 3. 判断结果，返回结果码 ==========
      if grep -q '^$' <<< "$RESULT_WEB"; then
        if grep -q 'blocked_why_headline' <<< "$RESULT_ISO"; then
          return 2
        elif grep -q 'unsupported_country_region_territory' <<< "$RESULT_ISO"; then
          return 3
        elif grep -q '(1)' <<< "$RESULT_ISO"; then
          return 4
        elif grep -q '(2)' <<< "$RESULT_ISO"; then
          return 5
        else
          return 6
        fi
      else
        REGION=$(curl ${NIC} --user-agent "${UA_BROWSER}" -SsL --max-time 10 "https://chatgpt.com/cdn-cgi/trace" 2>&1 | awk -F '=' '/^loc=/{print $2}')
        if grep -q '(1)' <<< "$RESULT_ISO"; then
          return 7
        elif grep -q '(2)' <<< "$RESULT_ISO"; then
          return 8
        else
          return 0
        fi
      fi
    }

    # 执行检测
    MediaUnlockTest_ChatGPT

    # ChatGPT 返回码说明:
    # 0: 成功解锁
    # 1: 网络连接错误
    # 2: 被阻止访问
    # 3: 不支持的地区
    # 4: 不允许的ISP(1)
    # 5: 不允许的ISP(2)
    # 6: 无法解锁
    # 7: 仅网页版可用(不允许的ISP[1])
    # 8: 仅网页版可用(不允许的ISP[2])

    case "$?" in
      0 )
        R[2]="$UNLOCK_STATUS"
        CONTENT="ChatGPT: ${R[2]}${REGION[2]:+ (Region: ${REGION[2]^^})}."
        ;;
      1 )
        R[2]="$NOT_UNLOCK_STATUS"
        CONTENT="ChatGPT: ${R[2]} (Network Error)."
        ;;
      2 )
        R[2]="$NOT_UNLOCK_STATUS"
        CONTENT="ChatGPT: ${R[2]} (Blocked)."
        ;;
      3 )
        R[2]="$NOT_UNLOCK_STATUS"
        CONTENT="ChatGPT: ${R[2]} (Unsupported Region)."
        ;;
      4 )
        R[2]="$NOT_UNLOCK_STATUS"
        CONTENT="ChatGPT: ${R[2]} (Disallowed ISP[1])."
        ;;
      5 )
        R[2]="$NOT_UNLOCK_STATUS"
        CONTENT="ChatGPT: ${R[2]} (Disallowed ISP[2])."
        ;;
      6 )
        R[2]="$NOT_UNLOCK_STATUS"
        CONTENT="ChatGPT: ${R[2]}."
        ;;
      7 )
        R[2]="$UNLOCK_STATUS"
        CONTENT="ChatGPT: ${R[2]} (Web Only, Disallowed ISP[1], Region: ${REGION[2]^^})."
        ;;
      8 )
        R[2]="$UNLOCK_STATUS"
        CONTENT="ChatGPT: ${R[2]} (Web Only, Disallowed ISP[2], Region: ${REGION[2]^^})."
        ;;
      * )
        R[2]="$NOT_UNLOCK_STATUS"
        CONTENT="ChatGPT: ${R[2]}."
        ;;
    esac

    log_message
    grep -q '.' <<< "$MACHINE" && [[ ${R[2]} != $(sed -n '3s/.*: \(.*\)/\1/p' /usr/bin/status.log) ]] && tg_message
    sed -i "3s/ChatGPT: .*/ChatGPT: ${R[2]}/" /usr/bin/status.log
  }
EOF
)"
  # $(cat) 命令替换会去掉尾部换行，这里补回一个，避免与分段 C 首行粘连
  WARP_UNLOCK_SRC+=$'\n'

  # 分段 C：动态主流程。按用户选择（CHOOSE1）判断是否用 while true 包裹：
  # 后台常驻（2/3/4/5）→ 包裹 while true; do ... sleep 1h; done，中间整体再缩进 2 空格；
  # crontab 定时（1）→ 不包裹，维持当前缩进。I 为每行基础缩进。
  [ -n "$CHOOSE1" ] && [ "$CHOOSE1" != 1 ] && WARP_UNLOCK_SRC+='  while true; do
'
  WARP_UNLOCK_SRC+="${I}check_ip
${I}CONTENT='Script runs.'
${I}log_message
${I}UA_BROWSER=\"Mozilla/5.0 (Windows NT 10.0; Win64; x6*4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36\"
"
  WARP_UNLOCK_SRC+="$(sed "s/^/${I}/" <<< "$UNLOCK_SELECT")
"
  WARP_UNLOCK_SRC+="${I}
${I}until [[ ! \${R[*]}  =~ \"\$NOT_UNLOCK_STATUS\" ]]; do
${I}  unset R
${I}  \$RESTART
"
  WARP_UNLOCK_SRC+="$(sed "s/^/${I}  /" <<< "$UNLOCK_SELECT")
"
  WARP_UNLOCK_SRC+="${I}done
"
  [ -n "$CHOOSE1" ] && [ "$CHOOSE1" != 1 ] && WARP_UNLOCK_SRC+="${I}sleep 1h
  done
"
  WARP_UNLOCK_SRC+='fi
'

  # 最后一次写盘
  printf '%s' "$WARP_UNLOCK_SRC" > /usr/bin/warp_unlock.sh
  chmod +x /usr/bin/warp_unlock.sh
}

# 写入 warp_unlock 的 cron 条目。Alpine 用 busybox crond 文件(/var/spool/cron/crontabs/root)并确保 crond 启用；其余系统写 /etc/crontab
set_cron_one() {
  local CRON_LINE="$1"
  if [ "$SYSTEM" = Alpine ]; then
    local CF=/var/spool/cron/crontabs/root
    # Alpine busybox crond 的 crontab 为 5 字段格式（不含用户字段），去掉用户 token:root
    CRON_LINE="$(awk '{ out=""; for(i=1;i<=NF;i++){ if($i!="root") out=out (out!=""?FS:"") $i } print out }' <<<"$CRON_LINE")"
    mkdir -p "$(dirname "$CF")"
    sed -i '/warp_unlock.sh/d' "$CF" 2>/dev/null || true
    printf '%s\n' "$CRON_LINE" >> "$CF"
    chmod 600 "$CF"
    # 确保 busybox crond 运行并开机自启
    rc-update add crond >/dev/null 2>&1
    rc-service crond status >/dev/null 2>&1 | grep -q started || rc-service crond start >/dev/null 2>&1
  else
    # 部分精简系统可能无 /etc/crontab，先确保存在再写，避免 sed 报错
    [ -f /etc/crontab ] || touch /etc/crontab 2>/dev/null
    sed -i '/warp_unlock.sh/d' /etc/crontab 2>/dev/null || true
    printf '%s\n' "$CRON_LINE" >> /etc/crontab
  fi
}

# 删除 warp_unlock 的 cron 条目（按系统选文件）
del_cron_one() {
  # 卸载(-U)路径在 check_system_info 之前，SYSTEM 未必已赋值；
  # 统一清理两个候选 crontab 文件中 warp_unlock.sh 的行，不依赖 SYSTEM 判断
  [ -f /var/spool/cron/crontabs/root ] && sed -i '/warp_unlock.sh/d' /var/spool/cron/crontabs/root
  [ -f /etc/crontab ] && sed -i '/warp_unlock.sh/d' /etc/crontab
}

# 输出执行结果
result_output() {
  info " $RESULT_OUTPUT "
  info " $(text 22) \n"
}

# 卸载
uninstall() {
  if command -v pm2 >/dev/null 2>&1 && pm2 list | grep -q 'warp_unlock'; then
    reading " $(text 36) " REMOVE_DEPS
    if pm2 list | grep -q 'warp_unlock'; then
      pm2 delete warp_unlock >/dev/null 2>&1
      pm2 unstartup systemd >/dev/null 2>&1
    fi
    if [ "${REMOVE_DEPS,,}" = 'y' ]; then
      npm uninstall -g pm2 >/dev/null 2>&1
      ${PACKAGE_UNINSTALL[b]} nodejs npm
    fi
  fi

  type -p screen >/dev/null 2>&1 && screen -ls | grep -q 'u' && screen -QX u quit >/dev/null 2>&1 && screen -wipe >/dev/null 2>&1
  type -p wg-quick >/dev/null 2>&1 && { [ "$SYSTEM" = Alpine ] && wg-quick up wgcf >/dev/null 2>&1 || systemctl restart wgcf >/dev/null 2>&1; }
  type -p warp-cli >/dev/null 2>&1 && ( warp-cli --accept-tos delete >/dev/null 2>&1; sleep 1; warp-cli --accept-tos register >/dev/null 2>&1 )
  del_cron_one
  rm -f /usr/bin/warp_unlock.sh /root/result.log /usr/bin/status.log /etc/systemd/system/warp_unlock.service /etc/init.d/warp_unlock /run/warp_unlock.pid
  # Alpine(openrc) 卸载守护：rc-service stop + rc-update del；其余系统走 systemctl disable --now
  if [ "$SYSTEM" = Alpine ]; then
    type -p rc-service >/dev/null 2>&1 && rc-service warp_unlock stop >/dev/null 2>&1
    type -p rc-update  >/dev/null 2>&1 && rc-update del warp_unlock >/dev/null 2>&1
  else
    type -p systemctl >/dev/null 2>&1 && systemctl list-unit-files | grep -q 'warp_unlock' && systemctl disable --now warp_unlock >/dev/null 2>&1
  fi

  # 输出执行结果，如是切换模式则不显示
  [ "$UN" = 1 ] && info "\n $(text 11) \n"

  # 杀死所有的程序，如果提前执行这步，会导致脚本整体退出
  kill -9 $(pgrep -f warp_unlock.sh) >/dev/null 2>&1
}

# 传参 1/2
[[ "$*" =~ -[Ee] ]] && L=E
[[ "$*" =~ -[Cc] ]] && L=C

# 主程序运行 1/2
statistics_of_run-times
select_laguage

# 传参 2/2
while getopts ":UuM:m:A:a:N:n:T:t:" OPTNAME; do
  case "$OPTNAME" in
    'U'|'u' )
      if [ ! -e /usr/bin/warp_unlock.sh ]; then
        error " $(text 27) "
    	else
			  UN=1; uninstall; exit 0
      fi
      ;;
    'M'|'m' )
      [ -z "$UNLOCK_MODE_NOW" ] && check_unlock_running
      if [ -n "$UNLOCK_MODE_NOW" ]; then
        error " $(text 28) "
      else
			  [[ $OPTARG != [1-5] ]] && error " $(text 25) " || CHOOSE1=$OPTARG
      fi
      ;;
    'A'|'a' )
      [[ ! "$OPTARG" =~ ^[A-Za-z]{2}$ ]] && error " $(text 26) " || EXPECT="$OPTARG"
      ;;
    'N'|'n' )
      for d in "${!STREAM[@]}"; do
        [ "$d" = 0 ] && echo "${STREAM[d]}: null" > /usr/bin/status.log || echo "${STREAM[d]}: null" >> /usr/bin/status.log
      done
      echo "$OPTARG" | grep -qi 'n' && STREAM_UNLOCK[0]='1' || STREAM_UNLOCK[0]='0'
      echo "$OPTARG" | grep -qi 'd' && STREAM_UNLOCK[1]='1' || STREAM_UNLOCK[1]='0'
      echo "$OPTARG" | grep -qi 'c' && STREAM_UNLOCK[2]='1' || STREAM_UNLOCK[2]='0'
      ;;
    'T'|'t' )
      TG_BOT_TOKEN="$(echo $OPTARG | cut -d'@' -f1)"
      TG_USERID="$(echo $OPTARG | cut -d'@' -f2)"
      MACHINE="$(echo $OPTARG | cut -d'@' -f3)"
      MACHINE="${MACHINE:-'Stream Media Unlock'}"
  esac
done

# 主程序运行 2/2
check_system_info
check_unlock_running
check_dependencies curl
check_warp
[ -n "$UNLOCK_MODE_NOW" ] && MENU_SHOW="$(text 19)$(text 12)" || MENU_SHOW="$(text 12)"

action1() {
  [ -n "$UNLOCK_MODE_NOW" ] && uninstall
  TASK=""
  set_cron_one "*/5 * * * * root bash /usr/bin/warp_unlock.sh"
  RESULT_OUTPUT="\n $(text 10) \n"
  export_unlock_file
  result_output
}

action2() {
  [ -n "$UNLOCK_MODE_NOW" ] && uninstall
  if [ "$SYSTEM" = Alpine ]; then
    # Alpine(openrc)：生成 /etc/init.d/warp_unlock init 脚本（start-stop-daemon 拉起，日志仍写 /root/result.log）
    TASK="cat <<'EOF' > /etc/init.d/warp_unlock
#!/sbin/openrc-run

description=\"WARP stream media unlock daemon\"

depend() {
  need net
  after firewall
}

start() {
  ebegin \"Starting warp_unlock\"
  start-stop-daemon --start --background \\
    --make-pidfile --pidfile /run/warp_unlock.pid \\
    --exec /bin/bash -- /usr/bin/warp_unlock.sh
  eend \$?
}

stop() {
  ebegin \"Stopping warp_unlock\"
  start-stop-daemon --stop --pidfile /run/warp_unlock.pid
  eend \$?
}
EOF
chmod +x /etc/init.d/warp_unlock"
    RESULT_OUTPUT="\n $(text 50) \n"
    export_unlock_file
    rc-update add warp_unlock default >/dev/null 2>&1
    rc-service warp_unlock start >/dev/null 2>&1 &
    result_output
  else
    TASK="cat <<EOF > /etc/systemd/system/warp_unlock.service
[Unit]
Description = WARP unlock
After = network.target

[Service]
ExecStart = /usr/bin/warp_unlock.sh
Restart = always
Type = simple

[Install]
WantedBy = multi-user.target
EOF"
    RESULT_OUTPUT="\n $(text 39) \n"
    export_unlock_file
    systemctl enable --now warp_unlock >/dev/null 2>&1 &
    result_output
  fi
}

action3() {
  [ -n "$UNLOCK_MODE_NOW" ] && uninstall
  TASK=""
  set_cron_one "@reboot root nohup bash /usr/bin/warp_unlock.sh &"
  RESULT_OUTPUT="\n $(text 21) \n"
  export_unlock_file
  nohup bash /usr/bin/warp_unlock.sh >/dev/null 2>&1 &
  result_output
}

action4() {
  [ -n "$UNLOCK_MODE_NOW" ] && uninstall
  TASK=""
  check_dependencies screen
  set_cron_one "@reboot root screen -USdm u bash /usr/bin/warp_unlock.sh"
  RESULT_OUTPUT="\n $(text 20) \n"
  export_unlock_file
  screen -USdm u bash /usr/bin/warp_unlock.sh
  result_output
}

action5() {
  [ -n "$UNLOCK_MODE_NOW" ] && uninstall
  TASK=""
  RESULT_OUTPUT="\n $(text 40) \n"
  node -v >/dev/null 2>&1 || DEPS+='nodejs'
  npm -v >/dev/null 2>&1 || DEPS+=' npm'
  [ -n "$DEPS" ] && ( ${PACKAGE_UPDATE[b]}; ${PACKAGE_INSTALL[b]} $DEPS 2>/dev/null )
  npm install -g pm2
  export_unlock_file
  pm2 start /usr/bin/warp_unlock.sh
  pm2 save; pm2 startup
  result_output
}

action6() { UN=1; uninstall; }

action0() { exit 0; }

# 菜单显示
menu() {
  clear
  hint " $(text 16) "
  red "======================================================================================================================\n"
  info " $(text 17): $VERSION  $(text 18): $(text 1)\n "
  red "======================================================================================================================\n"
  [ -z "$CHOOSE1" ] && hint " $MENU_SHOW " && reading " $(text 3) " CHOOSE1
  case "$CHOOSE1" in
    [0-6] )
      action$CHOOSE1
      ;;
    * )
      red " $(text 14) "; sleep 1; menu
  esac
}

menu