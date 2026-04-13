#!/bin/bash

# ============================================
# LOGIN & LOGOUT TRACKER - MAIN CODE
# Features: Login tracking, alerts, IP blocking
# ============================================

LOG_FILE="/var/log/auth.log"
BLOCK_FILE="/etc/hosts.deny"

# Function to get total logins
get_total_logins() {
    grep -c "session opened for user" "$LOG_FILE" 2>/dev/null || echo "0"
}

# Function to get total logouts
get_total_logouts() {
    grep -c "session closed for user" "$LOG_FILE" 2>/dev/null || echo "0"
}

# Function to get total failed attempts
get_total_failed() {
    grep -c "Failed password" "$LOG_FILE" 2>/dev/null || echo "0"
}

# Function to get recent logins (for web display)
get_recent_logins() {
    grep "session opened for user" "$LOG_FILE" 2>/dev/null | tail -20
}

# Function to get recent logouts
get_recent_logouts() {
    grep "session closed for user" "$LOG_FILE" 2>/dev/null | tail -20
}

# Function to get recent failed attempts
get_recent_failed() {
    grep "Failed password" "$LOG_FILE" 2>/dev/null | tail -20
}

# Function to get suspicious IPs (>=3 failures)
get_suspicious_ips() {
    grep "Failed password" "$LOG_FILE" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | awk '$1>=3'
}

# Function to get top attacking IPs
get_top_ips() {
    grep "Failed password" "$LOG_FILE" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | sort -rn | head -10
}

# Function to block an IP
block_ip() {
    ip=$1
    if ! grep -q "$ip" "$BLOCK_FILE" 2>/dev/null; then
        echo "sshd: $ip" >> "$BLOCK_FILE"
        echo "SUCCESS"
    else
        echo "ALREADY_BLOCKED"
    fi
}

# Function to check and block suspicious IPs
block_suspicious_ips() {
    suspicious=$(get_suspicious_ips)
    if [ -n "$suspicious" ]; then
        echo "$suspicious" | while read count ip; do
            block_ip "$ip"
        done
    fi
}

# Generate JSON data for web interface
generate_json() {
    echo "{"
    echo "  \"total_login\": $(get_total_logins),"
    echo "  \"total_logout\": $(get_total_logouts),"
    echo "  \"total_failed\": $(get_total_failed),"
    echo "  \"timestamp\": \"$(date)\","
    echo "  \"hostname\": \"$(hostname)\""
    echo "}"
}

# Generate complete data file for web
generate_data_file() {
    DATA_FILE="/tmp/login_data.txt"
    
    echo "TOTAL_LOGIN=$(get_total_logins)" > "$DATA_FILE"
    echo "TOTAL_LOGOUT=$(get_total_logouts)" >> "$DATA_FILE"
    echo "TOTAL_FAILED=$(get_total_failed)" >> "$DATA_FILE"
    echo "TIMESTAMP=$(date)" >> "$DATA_FILE"
    echo "HOSTNAME=$(hostname)" >> "$DATA_FILE"
    
    echo "RECENT_LOGINS:" >> "$DATA_FILE"
    get_recent_logins >> "$DATA_FILE"
    
    echo "RECENT_LOGOUTS:" >> "$DATA_FILE"
    get_recent_logouts >> "$DATA_FILE"
    
    echo "RECENT_FAILED:" >> "$DATA_FILE"
    get_recent_failed >> "$DATA_FILE"
    
    echo "SUSPICIOUS_IPS:" >> "$DATA_FILE"
    get_suspicious_ips >> "$DATA_FILE"
    
    echo "TOP_IPS:" >> "$DATA_FILE"
    get_top_ips >> "$DATA_FILE"
}

# Menu interface (for terminal)
show_menu() {
    clear
    echo "==============================="
    echo " LOGIN & LOGOUT TRACKER"
    echo "==============================="
    echo "1. Show All Login"
    echo "2. Show All Logout"
    echo "3. Show Successful Login"
    echo "4. Show Failed Login"
    echo "5. Block Suspicious IPs"
    echo "6. Search by Username"
    echo "7. Generate Report"
    echo "8. Generate Data for Web"
    echo "9. Exit"
    echo "==============================="
}

# Show all logins
show_all_login() {
    echo ""
    echo "=== ALL LOGIN ATTEMPTS ==="
    get_recent_logins
    echo ""
    echo "Total login records: $(get_total_logins)"
}

# Show all logouts
show_all_logout() {
    echo ""
    echo "=== ALL LOGOUT ATTEMPTS ==="
    get_recent_logouts
    echo ""
    echo "Total logout records: $(get_total_logouts)"
}

# Show successful logins
show_successful() {
    echo ""
    echo "=== SUCCESSFUL LOGINS ==="
    get_recent_logins
    echo ""
    echo "Total logins: $(get_total_logins)"
}

# Show failed logins
show_failed() {
    echo ""
    echo "=== FAILED LOGIN ATTEMPTS ==="
    get_recent_failed
    echo ""
    echo "Total failed attempts: $(get_total_failed)"
    echo ""
    echo "Top 5 IPs with failures:"
    get_top_ips | head -5
}

# Block suspicious IPs
block_suspicious() {
    echo ""
    echo "=== BLOCKING SUSPICIOUS IPs ==="
    block_suspicious_ips
}

# Search by username
search_user() {
    echo ""
    echo "=== SEARCH BY USERNAME ==="
    echo -n "Enter username: "
    read username
    if [ -z "$username" ]; then
        echo "No username entered"
        return
    fi
    echo ""
    echo "Records for user: $username"
    echo "---------------------------"
    grep -E "session opened for user|session closed for user|Failed password" "$LOG_FILE" 2>/dev/null | grep "$username" | tail -20
}

# Generate report
generate_report() {
    REPORT_FILE="login_report_$(date +%Y%m%d_%H%M%S).txt"
    echo "Generating report..."
    echo "LOGIN & LOGOUT REPORT" > "$REPORT_FILE"
    echo "Generated: $(date)" >> "$REPORT_FILE"
    echo "---------------------------" >> "$REPORT_FILE"
    echo "Total logins: $(get_total_logins)" >> "$REPORT_FILE"
    echo "Total logouts: $(get_total_logouts)" >> "$REPORT_FILE"
    echo "Total failed: $(get_total_failed)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Suspicious IPs:" >> "$REPORT_FILE"
    get_suspicious_ips >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Report saved: $REPORT_FILE"
}

# Main function
main() {
    if [ "$EUID" -ne 0 ]; then
        echo "⚠️ Run with sudo: sudo $0"
        exit 1
    fi

    if [ "$1" == "--web-data" ]; then
        generate_data_file
        exit 0
    fi

    choice=0
    while [ $choice -ne 9 ]; do
        show_menu
        echo -n "Enter choice (1-9): "
        read choice
        case $choice in
            1) show_all_login ;;
            2) show_all_logout ;;
            3) show_successful ;;
            4) show_failed ;;
            5) block_suspicious ;;
            6) search_user ;;
            7) generate_report ;;
            8) generate_data_file; echo "Data generated for web interface" ;;
            9) echo "Exiting..."; exit 0 ;;
            *) echo "Invalid choice" ;;
        esac
        echo ""
        echo "Press Enter to continue..."
        read dummy
    done
}

# Run main function with arguments
main "$@"