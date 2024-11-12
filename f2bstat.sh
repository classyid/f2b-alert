#!/bin/bash

# Configuration file path
CONFIG_FILE="/etc/f2bstat/config.conf"
TEMP_DIR="/tmp/f2bstat"
LOG_FILE="/var/log/f2bstat.log"

# Function for logging
log_message() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1" >> "$LOG_FILE"
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    for cmd in whois curl iptables ifconfig; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_message "ERROR: Missing dependencies: ${missing_deps[*]}"
        echo "Missing required dependencies: ${missing_deps[*]}"
        echo "Please install them first."
        exit 1
    fi
}

# Function to get IP location using whois
get_ip_location() {
    local ip=$1
    local country
    
    # Try to get country from whois
    country=$(whois "$ip" 2>/dev/null | grep -i "country:" | head -n 1 | awk '{print $2}')
    
    # If country is empty, return Unknown
    if [ -z "$country" ]; then
        echo "Unknown"
    else
        case $country in
            "US") echo "United States";;
            "GB") echo "United Kingdom";;
            "DE") echo "Germany";;
            "FR") echo "France";;
            "JP") echo "Japan";;
            "CN") echo "China";;
            "RU") echo "Russia";;
            "ID") echo "Indonesia";;
            "SG") echo "Singapore";;
            "MY") echo "Malaysia";;
            *) echo "$country";;
        esac
    fi
}

# Create necessary directories
setup_environment() {
    # Create config directory if it doesn't exist
    if [ ! -d "/etc/f2bstat" ]; then
        mkdir -p /etc/f2bstat
    fi

    # Create temp directory if it doesn't exist
    if [ ! -d "$TEMP_DIR" ]; then
        mkdir -p "$TEMP_DIR"
    fi

    # Create config file if it doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        echo 'BOT_TOKEN="YOUR_BOT_TOKEN"' > "$CONFIG_FILE"
        echo 'CHAT_ID="YOUR_CHAT_ID"' >> "$CONFIG_FILE"
        echo "Please configure $CONFIG_FILE with your Telegram credentials"
        exit 1
    fi
}

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        log_message "ERROR: Configuration file not found"
        exit 1
    fi

    # Validate configuration
    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        log_message "ERROR: BOT_TOKEN or CHAT_ID not configured"
        echo "Please configure BOT_TOKEN and CHAT_ID in $CONFIG_FILE"
        exit 1
    fi
}

# Initialize files
TEMPFILE="$TEMP_DIR/f2bstat.tmp"
OUTPUTFILE="$TEMP_DIR/f2bstat_output.txt"
MESSAGEFILE="$TEMP_DIR/message_output.txt"

# Check root privileges
if [ "$(id -u)" != "0" ]; then
    log_message "ERROR: This script must be run as root"
    echo "This script must be run as root"
    exit 1
fi

# Main execution
check_dependencies
setup_environment
load_config

# Clean up old files
rm -f "$TEMPFILE" "$OUTPUTFILE" "$MESSAGEFILE"
touch "$TEMPFILE" "$OUTPUTFILE" "$MESSAGEFILE"

# Get system information
OS_INFO=$(cat /etc/os-release | grep -E '^NAME=|^VERSION=' | sed 's/NAME=//' | sed 's/VERSION=//' | tr '\n' ' ')
KERNEL_INFO=$(uname -r)
UPTIME_INFO=$(uptime -p)
IP_INFO=$(ifconfig | grep -E 'inet ' | awk '{print $2}' | tr '\n' ' ')
TIMESTAMP=$(date "+%d-%m-%Y - %T WIB")
HOSTNAME=$(hostname)

# Create message header with enhanced system information
cat << EOF > "$MESSAGEFILE"
🖥️ *System Information:*
━━━━━━━━━━━━━━━━━━━━━
🏷️ *Hostname:* \`$HOSTNAME\`
💻 *OS:* \`$OS_INFO\`
🛡️ *Kernel:* \`$KERNEL_INFO\`
⏱️ *Uptime:* \`$UPTIME_INFO\`
🌐 *Network IPs:* \`$IP_INFO\`

🔒 *Security Report - Fail2ban Status*
━━━━━━━━━━━━━━━━━━━━━
EOF

# Process blocked IPs
echo -e "📋 *Detailed IP Analysis:*\n" > "$OUTPUTFILE"
count=0
current_time=$(date +%s)

# Get fail2ban status
banned_ips=$(iptables -S | grep f2b | grep REJECT | awk '{print $4;}' | cut -d'/' -f1)

if [ -z "$banned_ips" ]; then
    echo "✅ *No IPs currently blocked by Fail2ban*" >> "$MESSAGEFILE"
else
    for ip in $banned_ips; do
        location=$(get_ip_location "$ip")
        echo "🌍 $ip - $location" >> "$OUTPUTFILE"
        echo "$location" >> "$TEMPFILE"
        ((count++))
    done

    # Generate statistics
    echo -e "\n📊 *Geographic Distribution of Blocked IPs:*" >> "$MESSAGEFILE"
    echo "━━━━━━━━━━━━━━━━━━━━━" >> "$MESSAGEFILE"
    cat "$TEMPFILE" | sort | uniq -c | sort -rn | while read -r line; do
        count_loc=$(echo "$line" | awk '{print $1}')
        location=$(echo "$line" | cut -d' ' -f2-)
        echo "🔹 \`$count_loc\` from $location" >> "$MESSAGEFILE"
    done
fi

# Add summary
echo -e "\n📌 *Summary:*" >> "$MESSAGEFILE"
echo "━━━━━━━━━━━━━━━━━━━━━" >> "$MESSAGEFILE"
echo "🚫 *Total Blocked IPs:* \`$count\`" >> "$MESSAGEFILE"
echo -e "🕒 *Report Generated:* \`$TIMESTAMP\`" >> "$MESSAGEFILE"

# Send message to Telegram
if ! curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
     -d chat_id="$CHAT_ID" \
     -d text="$(cat "$MESSAGEFILE")" \
     -d parse_mode="Markdown" > /dev/null; then
    log_message "ERROR: Failed to send message to Telegram"
fi

# Send detailed report if there are blocked IPs
if [ $count -gt 0 ]; then
    if ! curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" \
         -F chat_id="$CHAT_ID" \
         -F document=@"$OUTPUTFILE" \
         -F caption="📑 Detailed IP Report - Generated on $TIMESTAMP" > /dev/null; then
        log_message "ERROR: Failed to send document to Telegram"
    fi
fi

# Clean up
rm -f "$TEMPFILE" "$OUTPUTFILE" "$MESSAGEFILE"
log_message "Script executed successfully - $count IPs processed"
