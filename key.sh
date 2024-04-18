#!/bin/bash

# 检测Linux系统类型
if [ -f /etc/os-release ]; then
    # 使用lsb_release命令来获取系统信息
    os=$(lsb_release -si)
elif [ -f /etc/redhat-release ]; then
    os="CentOS"
else
    os="Unknown"
fi

# 根据系统类型执行不同的操作
case "$os" in
    "Ubuntu" | "Debian")
        apt-get update -y
        apt-get install curl jq -y
        ;;
    "CentOS" | "Red Hat Enterprise Linux")
        yum clean all
        yum makecache
        yum install curl jq -y
        ;;
    *)
        echo "Unsupported or unknown Linux distribution."
        exit 1
        ;;
esac

echo '============================
      SSH Key Installer
     V1.0 Alpha
     Author: Kirito
============================'

# 创建.ssh目录并切换到该目录
mkdir -p ~/.ssh
cd ~/.ssh

# GitHub用户名
read -p "请输入 GitHub 用户名: " github_username

# GitHub API URL
url="https://api.github.com/users/$github_username/keys"

# 发送 GET 请求获取公钥列表，并使用 jq 从 JSON 响应中提取公钥信息
keys=$(curl -s "$url")

# 检查是否成功获取到公钥列表
if [ -z "$keys" ]; then
    echo "从GitHub获取SSH-KEY失败."
    exit 1
fi

# 计数器
count=1

# 显示公钥列表，并将 id 和 key 提取出来
echo "公钥列表："
echo "$keys" | jq -r '.[] | "\(.id)=\(.key)"' |
while IFS= read -r line; do
    echo "$count: $line"
    ((count++))
done

# 用户选择公钥
read -p "请选择你需要使用的SSH-KEY(输入编号): " choice

# 检查用户选择
if [[ "$choice" =~ ^[0-9]+$ ]]; then
    selected_key=$(echo "$keys" | jq -r ".[$choice - 1].key")
    if [ -n "$selected_key" ]; then
        echo "已选择SSH-KEY：$selected_key"
        echo "$selected_key" > authorized_keys
        echo "已将SSH-KEY写入 authorized_keys 文件."
    else
        echo "无效的选择."
        exit 1
    fi
else
    echo "无效的选择."
    exit 1
fi

# 返回用户主目录
cd ~

# 修改sshd_config文件并重启SSH服务
sed -i "/PasswordAuthentication no/c PasswordAuthentication no" /etc/ssh/sshd_config
sed -i "/RSAAuthentication no/c RSAAuthentication yes" /etc/ssh/sshd_config
sed -i "/PubkeyAuthentication no/c PubkeyAuthentication yes" /etc/ssh/sshd_config
sed -i "/PasswordAuthentication yes/c PasswordAuthentication no" /etc/ssh/sshd_config
sed -i "/RSAAuthentication yes/c RSAAuthentication yes" /etc/ssh/sshd_config
sed -i "/PubkeyAuthentication yes/c PubkeyAuthentication yes" /etc/ssh/sshd_config

# 根据不同系统重启SSH服务
if [ "$os" == "Ubuntu" ] || [ "$os" == "Debian" ]; then
    service ssh restart
elif [ "$os" == "CentOS" ] || [ "$os" == "Red Hat Enterprise Linux" ]; then
    systemctl restart sshd
fi
