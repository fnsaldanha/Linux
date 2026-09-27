#!/usr/bin/env bash

# ============================================================
#                 CORPORATE LINUX MOTD
# ============================================================
#
# System Health
# Security
# Services
# Crypto Market
#
# Compatível principalmente com Debian / Ubuntu
# ============================================================

# ------------------------------------------------------------
# GARANTIR BASH
# ------------------------------------------------------------

if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi

# Locale numérico da API / cálculos
export LC_NUMERIC=C

# ------------------------------------------------------------
# CONFIGURAÇÕES
# ------------------------------------------------------------

API="https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=usd,brl&include_24hr_change=true"

CPU_WARN=80
MEM_WARN=80
DISK_WARN=80


# Serviços críticos
CRITICAL_SERVICES="ssh sshd"

# ------------------------------------------------------------
# CORES
# ------------------------------------------------------------

RESET="\033[0m"
BOLD="\033[1m"

CYAN="\033[1;36m"
BLUE="\033[1;34m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
WHITE="\033[1;37m"
GRAY="\033[0;37m"
MAGENTA="\033[1;35m"

# ------------------------------------------------------------
# FUNÇÕES
# ------------------------------------------------------------

print_title()
{
    echo -e "${1}${BOLD}  ${2}${RESET}"
}

# ------------------------------------------------------------
# HOST / SISTEMA
# ------------------------------------------------------------

HOSTNAME=$(hostname 2>/dev/null || echo "unknown")

IP_ADDRESS=$(hostname -I 2>/dev/null | awk '{print $1}')

[ -z "$IP_ADDRESS" ] && IP_ADDRESS="N/A"

KERNEL=$(uname -r 2>/dev/null)

ARCH=$(uname -m 2>/dev/null)

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO="${PRETTY_NAME:-$NAME}"
else
    DISTRO="Linux"
fi

UPTIME=$(uptime -p 2>/dev/null | sed 's/^up //')

[ -z "$UPTIME" ] && UPTIME="N/A"

# ------------------------------------------------------------
# CPU
# ------------------------------------------------------------
# ------------------------------------------------------------
# CPU
# ------------------------------------------------------------

CPU_MODEL=$(lscpu 2>/dev/null |
    awk -F: '/Model name/ {
        gsub(/^[ \t]+/, "", $2);
        print $2;
        exit
    }')

[ -z "$CPU_MODEL" ] && CPU_MODEL=$(uname -p 2>/dev/null)

CPU_CORES=$(nproc 2>/dev/null)

[ -z "$CPU_CORES" ] && CPU_CORES="?"

# ------------------------------------------------------------
# USO DA CPU
# Calculado diretamente através de /proc/stat
# ------------------------------------------------------------

read_cpu_usage()
{
    awk '/^cpu / {
        idle=$5;
        total=0;

        for (i=2; i<=NF; i++)
            total += $i;

        print total, idle;
        exit
    }' /proc/stat
}

CPU1=$(read_cpu_usage)

sleep 0.3

CPU2=$(read_cpu_usage)

CPU_USAGE=$(awk \
    -v cpu1="$CPU1" \
    -v cpu2="$CPU2" \
'
BEGIN {

    split(cpu1, a, " ")
    split(cpu2, b, " ")

    total1=a[1]
    idle1=a[2]

    total2=b[1]
    idle2=b[2]

    total_diff=total2-total1
    idle_diff=idle2-idle1

    if (total_diff > 0)
        usage=(1-(idle_diff/total_diff))*100
    else
        usage=0

    printf "%.1f", usage
}
')

[ -z "$CPU_USAGE" ] && CPU_USAGE="0"

# ------------------------------------------------------------
# MEMÓRIA
# Calculada diretamente através de /proc/meminfo
# ------------------------------------------------------------

MEM_TOTAL_KB=$(awk '/^MemTotal:/ {
    print $2;
    exit
}' /proc/meminfo)

MEM_AVAILABLE_KB=$(awk '/^MemAvailable:/ {
    print $2;
    exit
}' /proc/meminfo)

[ -z "$MEM_TOTAL_KB" ] && MEM_TOTAL_KB=0
[ -z "$MEM_AVAILABLE_KB" ] && MEM_AVAILABLE_KB=0

MEM_USED_KB=$((MEM_TOTAL_KB - MEM_AVAILABLE_KB))

if [ "$MEM_TOTAL_KB" -gt 0 ]; then

    MEM_PERCENT=$(awk \
        -v used="$MEM_USED_KB" \
        -v total="$MEM_TOTAL_KB" \
        'BEGIN {
            printf "%.0f", (used/total)*100
        }')

else

    MEM_PERCENT=0

fi

# ------------------------------------------------------------
# FORMATAÇÃO DA MEMÓRIA
# ------------------------------------------------------------

format_memory()
{
    local KB="$1"

    if [ "$KB" -ge 1048576 ]; then

        awk -v value="$KB" \
            'BEGIN {
                printf "%.1fG", value/1048576
            }'

    elif [ "$KB" -ge 1024 ]; then

        awk -v value="$KB" \
            'BEGIN {
                printf "%.1fM", value/1024
            }'

    else

        printf "%sK" "$KB"

    fi
}

MEM_TOTAL=$(format_memory "$MEM_TOTAL_KB")
MEM_USED=$(format_memory "$MEM_USED_KB")
MEM_AVAILABLE=$(format_memory "$MEM_AVAILABLE_KB")

# ------------------------------------------------------------
# DISCO
# ------------------------------------------------------------

DISK_INFO=$(df -h / 2>/dev/null | awk 'NR==2')

DISK_USED=$(echo "$DISK_INFO" | awk '{print $3}')

DISK_TOTAL=$(echo "$DISK_INFO" | awk '{print $2}')

DISK_PERCENT=$(echo "$DISK_INFO" |
    awk '{gsub("%","",$5); print $5}')

[ -z "$DISK_USED" ] && DISK_USED="N/A"
[ -z "$DISK_TOTAL" ] && DISK_TOTAL="N/A"
[ -z "$DISK_PERCENT" ] && DISK_PERCENT="0"

# ------------------------------------------------------------
# PROCESSOS
# ------------------------------------------------------------

PROCESS_COUNT=$(ps -e --no-headers 2>/dev/null | wc -l)

# ------------------------------------------------------------
# LOAD
# ------------------------------------------------------------

LOAD=$(awk '{print $1 "  " $2 "  " $3}' /proc/loadavg 2>/dev/null)

[ -z "$LOAD" ] && LOAD="N/A"

# ------------------------------------------------------------
# TEMPERATURA
# ------------------------------------------------------------

CPU_TEMP="N/A"

if command -v sensors >/dev/null 2>&1; then

    CPU_TEMP=$(
        sensors 2>/dev/null |
        awk '/Package id 0:/ {
            gsub(/[+°C]/,"",$4)
            print $4 "°C"
            exit
        }'
    )

    if [ -z "$CPU_TEMP" ]; then
        CPU_TEMP=$(
            sensors 2>/dev/null |
            awk '/Tctl:/ {
                gsub(/[+°C]/,"",$2)
                print $2 "°C"
                exit
            }'
        )
    fi

fi

# Fallback para thermal zones

if [ -z "$CPU_TEMP" ]; then

    TEMP_FILE=$(find /sys/class/thermal \
        -name 'temp*_input' 2>/dev/null | head -1)

    if [ -n "$TEMP_FILE" ] && [ -r "$TEMP_FILE" ]; then

        TEMP=$(cat "$TEMP_FILE" 2>/dev/null)

        if [[ "$TEMP" =~ ^[0-9]+$ ]]; then
            CPU_TEMP=$(awk \
                -v temp="$TEMP" \
                'BEGIN {printf "%.1f°C", temp/1000}')
        fi

    fi

fi

[ -z "$CPU_TEMP" ] && CPU_TEMP="N/A"

# ------------------------------------------------------------
# USUÁRIOS
# ------------------------------------------------------------

LOGGED_USERS=$(who 2>/dev/null | wc -l)

# ------------------------------------------------------------
# ÚLTIMO LOGIN
# ------------------------------------------------------------

LAST_LOGIN=$(
    last -n 1 -w 2>/dev/null |
    grep -v "^wtmp" |
    head -1 |
    awk '{$1=$1; print}' |
    cut -c1-55
)

[ -z "$LAST_LOGIN" ] && LAST_LOGIN="N/A"

# ------------------------------------------------------------
# FIREWALL
# ------------------------------------------------------------

FIREWALL_STATUS="N/A"

if command -v ufw >/dev/null 2>&1; then

    if ufw status 2>/dev/null |
        grep -q "Status: active"; then

        FIREWALL_STATUS="ATIVO"

    else

        FIREWALL_STATUS="INATIVO"

    fi

elif command -v firewall-cmd >/dev/null 2>&1; then

    if firewall-cmd --state 2>/dev/null |
        grep -q "running"; then

        FIREWALL_STATUS="ATIVO"

    else

        FIREWALL_STATUS="INATIVO"

    fi

elif command -v nft >/dev/null 2>&1; then

    if nft list ruleset 2>/dev/null |
        grep -q "chain"; then

        FIREWALL_STATUS="ATIVO"

    else

        FIREWALL_STATUS="SEM REGRAS"

    fi

fi

# ------------------------------------------------------------
# SSH
# ------------------------------------------------------------

SSH_STATUS="INATIVO"

if systemctl is-active --quiet ssh 2>/dev/null; then
    SSH_STATUS="ATIVO"
elif systemctl is-active --quiet sshd 2>/dev/null; then
    SSH_STATUS="ATIVO"
fi

# ------------------------------------------------------------
# SERVIÇOS CRÍTICOS
# ------------------------------------------------------------

SERVICE_OUTPUT=""

for SERVICE in $CRITICAL_SERVICES; do

    if systemctl list-unit-files 2>/dev/null |
        grep -q "^${SERVICE}\.service"; then

        if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then

            SERVICE_OUTPUT="${SERVICE_OUTPUT} ${GREEN}●${RESET} ${SERVICE}"

        else

            SERVICE_OUTPUT="${SERVICE_OUTPUT} ${RED}●${RESET} ${SERVICE}"

        fi

    fi

done

# ------------------------------------------------------------
# APT - ATUALIZAÇÃO DAS LISTAS
# ------------------------------------------------------------



# ------------------------------------------------------------
# STATUS DO SISTEMA
# ------------------------------------------------------------

if awk -v value="$CPU_USAGE" \
       -v limit="$CPU_WARN" \
       'BEGIN {exit !(value >= limit)}'; then

    CPU_COLOR="$RED"
    CPU_ICON="▲"

else

    CPU_COLOR="$GREEN"
    CPU_ICON="●"

fi

if [ "$MEM_PERCENT" -ge "$MEM_WARN" ] 2>/dev/null; then

    MEM_COLOR="$RED"
    MEM_ICON="▲"

else

    MEM_COLOR="$GREEN"
    MEM_ICON="●"

fi

if [ "$DISK_PERCENT" -ge "$DISK_WARN" ] 2>/dev/null; then

    DISK_COLOR="$RED"
    DISK_ICON="▲"

else

    DISK_COLOR="$GREEN"
    DISK_ICON="●"

fi

# ------------------------------------------------------------
# STATUS FIREWALL
# ------------------------------------------------------------

if [ "$FIREWALL_STATUS" = "ATIVO" ]; then

    FW_COLOR="$GREEN"
    FW_ICON="●"

else

    FW_COLOR="$RED"
    FW_ICON="●"

fi

# ------------------------------------------------------------
# CRYPTO
# ------------------------------------------------------------

DATA=$(
    curl -fsSL \
    --connect-timeout 3 \
    --max-time 5 \
    "$API" 2>/dev/null
)

CRYPTO_OK=false

if [ -n "$DATA" ] &&
   command -v jq >/dev/null 2>&1 &&
   echo "$DATA" |
   jq -e '.bitcoin and .ethereum' >/dev/null 2>&1; then

    CRYPTO_OK=true

    BTC_USD=$(echo "$DATA" |
        jq -r '.bitcoin.usd // 0')

    BTC_BRL=$(echo "$DATA" |
        jq -r '.bitcoin.brl // 0')

    BTC_CHANGE=$(echo "$DATA" |
        jq -r '.bitcoin.usd_24h_change // 0')

    ETH_USD=$(echo "$DATA" |
        jq -r '.ethereum.usd // 0')

    ETH_BRL=$(echo "$DATA" |
        jq -r '.ethereum.brl // 0')

    ETH_CHANGE=$(echo "$DATA" |
        jq -r '.ethereum.usd_24h_change // 0')

    # --------------------------------------------------------
    # FORMATAÇÃO DECIMAL
    # --------------------------------------------------------

    BTC_USD_FMT=$(printf "%.2f" "$BTC_USD")
    BTC_BRL_FMT=$(printf "%.2f" "$BTC_BRL")

    ETH_USD_FMT=$(printf "%.2f" "$ETH_USD")
    ETH_BRL_FMT=$(printf "%.2f" "$ETH_BRL")

    BTC_CHANGE_FMT=$(printf "%+.2f" "$BTC_CHANGE")
    ETH_CHANGE_FMT=$(printf "%+.2f" "$ETH_CHANGE")

    # --------------------------------------------------------
    # FORMATAÇÃO BRASILEIRA
    # --------------------------------------------------------

    format_br()
    {
        local VALUE="$1"

        printf "%s" "$VALUE" |
        sed \
            -e ':a' \
            -e 's/\([0-9]\)\([0-9]\{3\}\)\(\(\.[0-9]\{2\}\)\{0,1\}\)$/\1.\2\3/;ta' \
            -e 's/\./,/'
    }

    BTC_USD_FMT=$(format_br "$BTC_USD_FMT")
    BTC_BRL_FMT=$(format_br "$BTC_BRL_FMT")

    ETH_USD_FMT=$(format_br "$ETH_USD_FMT")
    ETH_BRL_FMT=$(format_br "$ETH_BRL_FMT")

    # --------------------------------------------------------
    # CORES DA VARIAÇÃO
    # --------------------------------------------------------

    if awk -v value="$BTC_CHANGE" \
           'BEGIN {exit !(value >= 0)}'; then

        BTC_COLOR="$GREEN"
        BTC_ICON="▲"

    else

        BTC_COLOR="$RED"
        BTC_ICON="▼"

    fi

    if awk -v value="$ETH_CHANGE" \
           'BEGIN {exit !(value >= 0)}'; then

        ETH_COLOR="$GREEN"
        ETH_ICON="▲"

    else

        ETH_COLOR="$RED"
        ETH_ICON="▼"

    fi

fi

# ============================================================
#                      DISPLAY
# ============================================================

clear

echo

# ------------------------------------------------------------
# CABEÇALHO
# ------------------------------------------------------------

echo -e "${CYAN}${BOLD}  ◈ ${HOSTNAME}${RESET}"

echo -e "${GRAY}  ${DISTRO}  •  Kernel ${KERNEL}  •  ${ARCH}${RESET}"

echo -e "${GRAY}  IP ${WHITE}${IP_ADDRESS}${RESET}  •  Uptime ${WHITE}${UPTIME}${RESET}"

echo

# ------------------------------------------------------------
# SYSTEM
# ------------------------------------------------------------

print_title "$BLUE" "SYSTEM"

printf "  %-12s ${CPU_COLOR}%s %5s%%${RESET}  %s (%s cores)\n" \
    "CPU" \
    "$CPU_ICON" \
    "$CPU_USAGE" \
    "${CPU_MODEL:0:30}" \
    "$CPU_CORES"

printf "  %-12s ${MEM_COLOR}%s %5s%%${RESET}  %s / %s\n" \
    "MEMÓRIA" \
    "$MEM_ICON" \
    "$MEM_PERCENT" \
    "$MEM_USED" \
    "$MEM_TOTAL"

printf "  %-12s ${DISK_COLOR}%s %5s%%${RESET}  %s / %s\n" \
    "DISCO /" \
    "$DISK_ICON" \
    "$DISK_PERCENT" \
    "$DISK_USED" \
    "$DISK_TOTAL"

printf "  %-12s ${WHITE}%s${RESET}\n" \
    "TEMPERATURA" \
    "$CPU_TEMP"

printf "  %-12s ${WHITE}%s${RESET}  Load: ${WHITE}%s${RESET}\n" \
    "PROCESSOS" \
    "$PROCESS_COUNT" \
    "$LOAD"

echo

# ------------------------------------------------------------
# SECURITY
# ------------------------------------------------------------

print_title "$MAGENTA" "SECURITY"

printf "  Firewall     ${FW_COLOR}%s %s${RESET}\n" \
    "$FW_ICON" \
    "$FIREWALL_STATUS"

if [ "$SSH_STATUS" = "ATIVO" ]; then

    printf "  SSH          ${GREEN}● ATIVO${RESET}\n"

else

    printf "  SSH          ${RED}● INATIVO${RESET}\n"

fi


printf "  Usuários     ${WHITE}%s conectados${RESET}\n" \
    "$LOGGED_USERS"

if [ -n "$SERVICE_OUTPUT" ]; then

    echo -e "  Serviços    ${SERVICE_OUTPUT}"

fi

echo

# ------------------------------------------------------------
# ACCESS
# ------------------------------------------------------------

print_title "$YELLOW" "ACCESS"

printf "  Último login ${GRAY}%s${RESET}\n" \
    "${LAST_LOGIN:0:65}"

echo

# ------------------------------------------------------------
# CRYPTO MARKET
# ------------------------------------------------------------

print_title "$CYAN" "CRYPTO MARKET"

if [ "$CRYPTO_OK" = true ]; then

    printf "  ${YELLOW}₿ BTC${RESET}  \$%s  ${BTC_COLOR}%s %s%%${RESET}   R\$ %s\n" \
        "$BTC_USD_FMT" \
        "$BTC_ICON" \
        "$BTC_CHANGE_FMT" \
        "$BTC_BRL_FMT"

    printf "  ${MAGENTA}Ξ ETH${RESET}  \$%s  ${ETH_COLOR}%s %s%%${RESET}   R\$ %s\n" \
        "$ETH_USD_FMT" \
        "$ETH_ICON" \
        "$ETH_CHANGE_FMT" \
        "$ETH_BRL_FMT"

else

    echo -e "  ${YELLOW}● Mercado indisponível${RESET}"

fi

echo

# ------------------------------------------------------------
# RODAPÉ
# ------------------------------------------------------------

echo -e "${GRAY}  $(date '+%d/%m/%Y %H:%M:%S')${RESET}"

echo
