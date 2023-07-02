#!/bin/bash

# 设置相关变量
config_file="/etc/AdGuardHome.yaml"  # AdGuardHome配置文件路径
primary_dns="192.168.10.254:7874"  # 主DNS服务器地址
backup_dns="119.29.29.29"  # 备用DNS服务器地址
LOG_FILE="/tmp/log/777/check_adg_dns.log"

# 创建日志
check_log() {
    if [ ! -f "$LOG_FILE" ]; then
        mkdir -p "$(dirname "$LOG_FILE")"
        touch "$LOG_FILE"
    fi
}

# 捕获终止信号
trap on_exit SIGINT SIGTERM SIGHUP
# 终止信号处理函数
on_exit() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [ERROR] check_adg_dns脚本进程被关闭" | tee -a "$LOG_FILE"
    exit 1
}

# 获取当前网络DNS地址
get_dns_server() {
  awk '/upstream_dns:/ {getline; gsub(/[- ]/, ""); print}' "$config_file"  # 使用awk命令获取配置文件中的DNS服务器地址
}

# 检查DNS服务器状态函数
check_dns_status() {
  nslookup qq.com "$primary_dns" >/dev/null  # 使用nslookup命令检查主DNS服务器状态，抛弃输出
  if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [ERROR] 主DNS服务器异常，重试中..." | tee -a "$LOG_FILE"
    return 1
  fi
}

# 修改配置文件为备用DNS函数
modify_config_file() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] 检测到上游为主DNS，当前网络不正常" | tee -a "$LOG_FILE"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] 准备将AdGuardHome上游修改为备用DNS..." | tee -a "$LOG_FILE"
  sed '/^  upstream_dns:$/,/^  upstream_dns_file: ""$/ {/^\(  upstream_dns:\|  upstream_dns_file: ""\)$/! s/.*/    - '"$backup_dns"'/}' $config_file > tmpfile && mv tmpfile $config_file
  # 使用sed命令将配置文件中的DNS服务器地址修改为备用DNS
}

# 修改配置文件为主DNS函数
modify_config_file_1() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] 检测到主DNS正常，上游不为主DNS" | tee -a "$LOG_FILE"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] 准备将AdGuardHome上游修改为主DNS..." | tee -a "$LOG_FILE"
  sed '/^  upstream_dns:$/,/^  upstream_dns_file: ""$/ {/^\(  upstream_dns:\|  upstream_dns_file: ""\)$/! s/.*/    - '"$primary_dns"'/}' $config_file > tmpfile && mv tmpfile $config_file
  # 使用sed命令将配置文件中的DNS服务器地址修改为主DNS
}

# 重启AdGuardHome服务函数
restart_adguard_service() {
  /etc/init.d/AdGuardHome restart >/dev/null 2>&1  # 重启AdGuardHome服务
}

# 主函数
main() {
  consecutive_normal=0  # 记录连续正常的次数
  consecutive_abnormal=0  # 记录连续异常的次数
  while true; do
    if check_dns_status; then  # 检查DNS服务器状态
      ((consecutive_normal++))
      consecutive_abnormal=0

  if ((consecutive_normal == 3)); then
    # 连续正常次数达到3次，切换到主DNS
    current_dns_server=$(get_dns_server)
      if [[ "$current_dns_server" != "$primary_dns" ]]; then
        modify_config_file_1
        restart_adguard_service
            echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] 网络恢复正常，AdGuardHome当前上游为$(get_dns_server)" | tee -a "$LOG_FILE"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] 主DNS切换完毕，持续检测主DNS..." | tee -a "$LOG_FILE"
      fi
  consecutive_normal=0  # 重置连续正常次数
  consecutive_abnormal=0  # 重置连续异常的次数
  fi
else
  # DNS服务器异常
  ((consecutive_abnormal++))
  consecutive_normal=0

  if ((consecutive_abnormal == 2)); then
    # 连续异常次数达到2次，切换到备用DNS
    current_dns_server=$(get_dns_server)
      if [[ $current_dns_server == "$primary_dns" ]]; then
        modify_config_file
        restart_adguard_service
            echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] 网络恢复正常，AdGuardHome当前上游为$(get_dns_server)" | tee -a "$LOG_FILE"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] 持续检测主DNS中...当主DNS恢复正常则切换回来" | tee -a "$LOG_FILE"
      fi
  consecutive_normal=0  # 重置连续正常次数
  consecutive_abnormal=0  # 重置连续异常的次数
  fi
fi
    sleep 60  # 间隔60秒钟继续监测DNS服务器状态
  done
}

# 调用主函数
check_log
if pgrep -f "$(basename "$0")" | grep -vw "$$" > /dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] 启动失败，check_adg_dns脚本已经在运行" | tee -a "$LOG_FILE"
    exit 1  # 终止脚本的执行
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] 启动check_adg_dns脚本..." | tee -a "$LOG_FILE"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] AdGuardHome当前上游为$(get_dns_server)" | tee -a "$LOG_FILE"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] 脚本每隔60秒钟监测主DNS服务器状态" | tee -a "$LOG_FILE"
  main
  fi
