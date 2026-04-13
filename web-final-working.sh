#!/bin/bash

# WORKING WEB SERVER - SIMPLE VERSION

PORT=8080
LOG_FILE="/var/log/auth.log"

# Kill existing process
sudo fuser -k $PORT/tcp 2>/dev/null

echo "========================================="
echo "Login Monitor Web Server"
echo "========================================="
echo "Server starting on port $PORT..."
echo ""
echo "Open Firefox and go to: http://localhost:$PORT"
echo ""
echo "Press Ctrl+C to stop"
echo "========================================="

while true; do
    # Get data first
    total_login=$(grep -c "session opened for user" "$LOG_FILE" 2>/dev/null)
    total_logout=$(grep -c "session closed for user" "$LOG_FILE" 2>/dev/null)
    total_failed=$(grep -c "Failed password" "$LOG_FILE" 2>/dev/null)
    hostname_val=$(hostname)
    current_time=$(date)
    
    # Get recent alerts
    recent_alerts=$(grep "Failed password" "$LOG_FILE" 2>/dev/null | tail -3)
    
    # Build login history table
    login_table=""
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            time=$(echo "$line" | awk '{print $1, $2, $3}')
            user=$(echo "$line" | awk '{print $9}')
            login_table="${login_table}<tr><td>${time}</td><td>${user}</td></tr>"
        fi
    done <<< "$(grep "session opened for user" "$LOG_FILE" 2>/dev/null | tail -20)"
    
    # Build logout history table
    logout_table=""
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            time=$(echo "$line" | awk '{print $1, $2, $3}')
            user=$(echo "$line" | awk '{print $9}')
            logout_table="${logout_table}<tr><td>${time}</td><td>${user}</td></tr>"
        fi
    done <<< "$(grep "session closed for user" "$LOG_FILE" 2>/dev/null | tail -20)"
    
    # Build failed attempts table
    failed_table=""
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            time=$(echo "$line" | awk '{print $1, $2, $3}')
            user=$(echo "$line" | awk '{print $9}')
            ip=$(echo "$line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
            failed_table="${failed_table}<tr><td>${time}</td><td>${user}</td><td>${ip}</td></tr>"
        fi
    done <<< "$(grep "Failed password" "$LOG_FILE" 2>/dev/null | tail -20)"
    
    # Build suspicious IPs table
    suspicious_table=""
    while IFS= read -r count ip; do
        if [ -n "$ip" ]; then
            suspicious_table="${suspicious_table}<tr><td>${ip}</td><td>${count}</td></tr>"
        fi
    done <<< "$(grep "Failed password" "$LOG_FILE" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | awk '$1>=3')"
    
    # Send HTTP response
    {
        echo "HTTP/1.1 200 OK"
        echo "Content-Type: text/html; charset=UTF-8"
        echo "Connection: close"
        echo ""
        
        cat << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Login Monitor - IDS</title>
    <meta http-equiv="refresh" content="30">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: auto;
            background: white;
            border-radius: 15px;
            padding: 25px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.2);
        }
        h1 { text-align: center; color: #333; margin-bottom: 10px; }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        .stat {
            background: white;
            padding: 25px;
            text-align: center;
            border-radius: 10px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            transition: transform 0.3s;
            cursor: pointer;
        }
        .stat:hover { transform: translateY(-5px); }
        .stat h2 { font-size: 48px; margin: 10px 0; }
        .login h2 { color: #27ae60; }
        .logout h2 { color: #2980b9; }
        .failed h2 { color: #e74c3c; }
        .menu {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            margin: 20px 0;
            justify-content: center;
        }
        .menu button {
            background: #667eea;
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 8px;
            cursor: pointer;
            font-size: 14px;
            transition: all 0.3s;
        }
        .menu button:hover {
            background: #5a67d8;
            transform: scale(1.05);
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background: #2c3e50;
            color: white;
        }
        tr:hover {
            background: #f5f5f5;
        }
        .alert {
            background: #fff3cd;
            padding: 15px;
            border-radius: 8px;
            margin: 20px 0;
            border-left: 4px solid #ffc107;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            color: #666;
        }
        button {
            background: #3498db;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 8px;
            cursor: pointer;
            margin-top: 10px;
        }
        button:hover {
            background: #2980b9;
        }
        .page {
            display: none;
        }
        .page.active {
            display: block;
        }
        @media (max-width: 768px) {
            .menu button { padding: 8px 16px; font-size: 12px; }
            .stat h2 { font-size: 32px; }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔐 Login & Logout Monitor</h1>
        <p style="text-align:center">Intrusion Detection System - Operating System Lab</p>
        <p style="text-align:center"><small>Server: $hostname_val | Time: $current_time</small></p>
        
        <div class="stats">
            <div class="stat login" onclick="showPage('login')">
                <p>✅ Total Logins</p>
                <h2>$total_login</h2>
            </div>
            <div class="stat logout" onclick="showPage('logout')">
                <p>📤 Total Logouts</p>
                <h2>$total_logout</h2>
            </div>
            <div class="stat failed" onclick="showPage('failed')">
                <p>❌ Failed Attempts</p>
                <h2>$total_failed</h2>
            </div>
        </div>
        
        <div class="menu">
            <button onclick="showPage('home')">🏠 Home</button>
            <button onclick="showPage('login')">📋 Login History</button>
            <button onclick="showPage('logout')">📤 Logout History</button>
            <button onclick="showPage('success')">✅ Successful Logins</button>
            <button onclick="showPage('failed')">❌ Failed Logins</button>
            <button onclick="showPage('suspicious')">⚠️ Suspicious IPs</button>
        </div>
        
        <!-- Home Page -->
        <div id="home" class="page active">
            <h3>📊 System Status</h3>
            <p>Welcome to Login Monitor. Click on any menu above to view detailed information.</p>
            <div class="alert">
                <strong>⚠️ Recent Failed Attempts:</strong><br>
                <pre>$recent_alerts</pre>
            </div>
            <ul>
                <li>✅ Total Logins: $total_login</li>
                <li>📤 Total Logouts: $total_logout</li>
                <li>❌ Total Failed: $total_failed</li>
            </ul>
        </div>
        
        <!-- Login History Page -->
        <div id="login" class="page">
            <h3>📋 Login History</h3>
            <table>
                <thead><tr><th>Time</th><th>User</th></tr></thead>
                <tbody>$login_table</tbody>
            </table>
            <p><strong>Total: $total_login</strong></p>
        </div>
        
        <!-- Logout History Page -->
        <div id="logout" class="page">
            <h3>📤 Logout History</h3>
            <table>
                <thead><tr><th>Time</th><th>User</th></tr></thead>
                <tbody>$logout_table</tbody>
            </table>
            <p><strong>Total: $total_logout</strong></p>
        </div>
        
        <!-- Successful Logins Page -->
        <div id="success" class="page">
            <h3>✅ Successful Logins</h3>
            <table>
                <thead><tr><th>Time</th><th>User</th></tr></thead>
                <tbody>$login_table</tbody>
            </table>
        </div>
        
        <!-- Failed Logins Page -->
        <div id="failed" class="page">
            <h3>❌ Failed Login Attempts</h3>
            <table>
                <thead><tr><th>Time</th><th>User</th><th>IP Address</th></tr></thead>
                <tbody>$failed_table</tbody>
            </table>
            <p><strong>Total: $total_failed</strong></p>
        </div>
        
        <!-- Suspicious IPs Page -->
        <div id="suspicious" class="page">
            <h3>⚠️ Suspicious IPs (>=3 failures)</h3>
            <table>
                <thead><tr><th>IP Address</th><th>Attempts</th></tr></thead>
                <tbody>$suspicious_table</tbody>
            </table>
        </div>
        
        <div class="footer">
            <p>Page auto-refreshes every 30 seconds</p>
            <button onclick="location.reload()">🔄 Refresh Now</button>
        </div>
    </div>
    
    <script>
        function showPage(pageName) {
            var pages = document.querySelectorAll('.page');
            for(var i = 0; i < pages.length; i++) {
                pages[i].classList.remove('active');
            }
            document.getElementById(pageName).classList.add('active');
        }
    </script>
</body>
</html>
EOF
    } | nc -l $PORT
done