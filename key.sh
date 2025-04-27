#!/bin/bash

# SSH 密钥自动配置脚本（专为 6shell 优化）
# 功能：从 GitHub 获取 6shell 的公钥并配置 SSH 密钥登录
# 支持系统：CentOS/RHEL, Debian, Ubuntu

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置参数
GITHUB_USER="6shell"  # 直接指定GitHub用户名
SSH_DIR="/root/.ssh"
AUTH_KEYS="${SSH_DIR}/authorized_keys"
SSHD_CONFIG="/etc/ssh/sshd_config"

# 初始化检查
init_check() {
    # 检查root权限
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误：此脚本需要root权限执行${NC}"
        exit 1
    fi

    # 检查网络连接
    if ! curl -Is https://github.com | head -n 1 | grep -q "200"; then
        echo -e "${RED}错误：无法连接到GitHub，请检查网络${NC}"
        exit 1
    fi
}

# 检测系统类型
detect_os() {
    if [ -f /etc/redhat-release ]; then
        echo "centos"
    elif grep -qi "debian" /etc/os-release; then
        echo "debian"
    elif grep -qi "ubuntu" /etc/os-release; then
        echo "ubuntu"
    else
        echo "unknown"
    fi
}

# 安装必要软件
install_deps() {
    local os_type=$1
    
    echo -e "${BLUE}正在安装必要软件...${NC}"
    
    case $os_type in
        centos)
            yum install -y curl openssh-server openssh-clients && \
            systemctl enable sshd && \
            systemctl start sshd
            ;;
        debian|ubuntu)
            apt-get update && \
            apt-get install -y curl openssh-server && \
            systemctl enable ssh && \
            systemctl start ssh
            ;;
        *)
            echo -e "${RED}不支持的Linux发行版${NC}"
            exit 1
            ;;
    esac

    if [ $? -ne 0 ]; then
        echo -e "${RED}软件安装失败${NC}"
        exit 1
    fi
}

# 获取GitHub公钥
get_github_key() {
    local temp_file=$(mktemp)
    
    echo -e "${BLUE}正在获取 ${GITHUB_USER} 的GitHub公钥...${NC}"
    
    if ! curl -s "https://github.com/${GITHUB_USER}.keys" -o "$temp_file"; then
        echo -e "${RED}错误：获取公钥失败${NC}"
        rm -f "$temp_file"
        exit 1
    fi

    # 验证公钥
    if [ ! -s "$temp_file" ] || ! grep -q "ssh-" "$temp_file"; then
        echo -e "${RED}错误：无效的公钥或账户未添加SSH密钥${NC}"
        rm -f "$temp_file"
        exit 1
    fi

    echo "$temp_file"
}

# 配置SSH
setup_ssh() {
    local key_file=$1
    
    echo -e "${BLUE}正在配置SSH...${NC}"

    # 创建.ssh目录
    mkdir -p "$SSH_DIR" && chmod 700 "$SSH_DIR"
    
    # 备份原有密钥
    if [ -f "$AUTH_KEYS" ]; then
        cp "$AUTH_KEYS" "${AUTH_KEYS}.bak-$(date +%Y%m%d%H%M%S)"
        echo -e "${YELLOW}已备份原有authorized_keys文件${NC}"
    fi

    # 添加新密钥
    {
        echo -e "\n# 来自 GitHub 用户 ${GITHUB_USER} 的公钥（自动添加于 $(date)）"
        cat "$key_file"
    } >> "$AUTH_KEYS"
    
    chmod 600 "$AUTH_KEYS"
    rm -f "$key_file"

    # 修改SSH配置
    cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
    sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONFIG"
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' "$SSHD_CONFIG"

    # 重启SSH服务
    if systemctl restart sshd || systemctl restart ssh; then
        echo -e "${GREEN}SSH服务重启成功${NC}"
    else
        echo -e "${RED}警告：SSH服务重启失败，请手动重启${NC}"
    fi
}

# 验证配置
verify_setup() {
    echo -e "\n${BLUE}验证配置...${NC}"
    echo -e "当前 authorized_keys 内容："
    grep -v "^#" "$AUTH_KEYS" | while read -r line; do
        echo -e "${GREEN}√ 已添加密钥: ${line:0:30}...${NC}"
    done

    echo -e "\n${YELLOW}请在新终端窗口中测试SSH连接："
    echo -e "  ssh root@您的服务器IP"
    echo -e "确认能正常登录后再关闭当前会话！${NC}"
}

# 主流程
main() {
    init_check
    
    local os_type=$(detect_os)
    echo -e "${GREEN}检测到系统: ${os_type}${NC}"
    
    install_deps "$os_type"
    local key_file=$(get_github_key)
    setup_ssh "$key_file"
    verify_setup
    
    echo -e "\n${GREEN}SSH密钥配置完成！${NC}"
}

# 执行主函数
main
