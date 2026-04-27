
#!/bin/bash

PORT=8080
LOG_FILE="/var/log/auth.log"

sudo fuser -k $PORT/tcp 2>/dev/null

echo "========================================="
echo "Login Monitor Web Server"
echo "========================================="
echo "Server running on http://localhost:$PORT"
echo "Press Ctrl+C to stop"
echo "========================================="

while true; do

total_login=$(grep -c "session opened for user" "$LOG_FILE" 2>/dev/null)
total_logout=$(grep -c "session closed for user" "$LOG_FILE" 2>/dev/null)
total_failed=$(grep -c "Failed password" "$LOG_FILE" 2>/dev/null)
hostname_val=$(hostname)
current_time=$(date)

recent_alerts=$(grep "Failed password" "$LOG_FILE" 2>/dev/null | tail -3)

# Login table - CLEAN
login_table=""
while IFS= read -r line; do
    time=$(echo "$line" | awk '{print $1, $2, $3}')
    user=$(echo "$line" | awk -F'for user ' '{print $2}' | awk '{print $1}' | cut -d'(' -f1)
    login_table="${login_table}<tr><td>${time}</td><td>${user}</td></tr>"
done <<< "$(grep "session opened for user" "$LOG_FILE" 2>/dev/null | tail -20)"

# Logout table - CLEAN
logout_table=""
while IFS= read -r line; do
    time=$(echo "$line" | awk '{print $1, $2, $3}')
    user=$(echo "$line" | awk -F'for user ' '{print $2}' | awk '{print $1}' | cut -d'(' -f1)
    logout_table="${logout_table}<tr><td>${time}</td><td>${user}</td></tr>"
done <<< "$(grep "session closed for user" "$LOG_FILE" 2>/dev/null | tail -20)"

# Failed table - CLEAN
failed_table=""
while IFS= read -r line; do
    time=$(echo "$line" | awk '{print $1, $2, $3}')
    user=$(echo "$line" | awk -F'for ' '{print $2}' | awk '{print $1}' | cut -d'(' -f1)
    ip=$(echo "$line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    failed_table="${failed_table}<tr><td>${time}</td><td>${user}</td><td>${ip}</td></tr>"
done <<< "$(grep "Failed password" "$LOG_FILE" 2>/dev/null | tail -20)"

# Suspicious IPs - CLEAN
suspicious_table=""
while read count ip; do
    suspicious_table="${suspicious_table}<tr><td>${ip}</td><td>${count}</td></tr>"
done <<< "$(grep 'Failed password' "$LOG_FILE" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | awk '$1>=3 {print $1, $2}')"

if [ -z "$suspicious_table" ]; then
    suspicious_table="<tr><td colspan='2' style='text-align:center; color:#999;'>No suspicious IPs detected</td></tr>"
fi

# Report data (last 10 logins) - CLEAN
report_login_table=""
while IFS= read -r line; do
    time=$(echo "$line" | awk '{print $1, $2, $3}')
    user=$(echo "$line" | awk -F'for user ' '{print $2}' | awk '{print $1}' | cut -d'(' -f1)
    report_login_table="${report_login_table}<tr><td>${time}</td><td>${user}</tr>"
done <<< "$(grep "session opened for user" "$LOG_FILE" 2>/dev/null | tail -10)"

{
echo "HTTP/1.1 200 OK"
echo "Content-Type: text/html"
echo ""

cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login Monitor IDS | Security Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 30px;
        }
        
        .main-container {
            max-width: 1600px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            overflow: hidden;
            box-shadow: 0 25px 50px rgba(0,0,0,0.2);
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 36px;
            margin-bottom: 10px;
        }
        
        .header p {
            font-size: 14px;
            opacity: 0.9;
        }
        
        .dashboard {
            display: flex;
            min-height: 600px;
        }
        
        .sidebar {
            width: 280px;
            background: #f8f9fa;
            border-right: 2px solid #e0e0e0;
            padding: 30px 20px;
        }
        
        .nav-buttons {
            display: flex;
            flex-direction: column;
            gap: 12px;
        }
        
        .nav-btn {
            padding: 14px 20px;
            border: none;
            border-radius: 10px;
            font-size: 15px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
            text-align: left;
            color: white;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }
        
        .nav-btn:hover {
            transform: translateX(5px);
            filter: brightness(1.05);
        }
        
        .nav-btn.active {
            filter: brightness(1.1);
            box-shadow: 0 4px 10px rgba(0,0,0,0.2);
        }
        
        /* Individual button colors */
        .btn-dashboard { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }
        .btn-login { background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); }
        .btn-logout { background: linear-gradient(135deg, #3494e6 0%, #ec6ead 100%); }
        .btn-failed { background: linear-gradient(135deg, #eb3349 0%, #f45c43 100%); }
        .btn-suspicious { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); }
        .btn-search { background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%); }
        .btn-report { background: linear-gradient(135deg, #fa709a 0%, #fee140 100%); }
        
        .content-area {
            flex: 1;
            padding: 30px;
            background: white;
            overflow-x: auto;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 20px;
            margin-bottom: 30px;
            align-items: stretch;
        }
        
        .stat-card {
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            padding: 25px;
            border-radius: 15px;
            text-align: center;
            color: white;
            cursor: pointer;
            transition: transform 0.3s;
            min-height: 140px;
        }
        
        .stat-card:hover {
            transform: translateY(-5px);
        }
        
        .stat-card .label {
            font-size: 14px;
            opacity: 0.9;
            margin-bottom: 10px;
            text-align: center;
        }
        
        .stat-card .number {
            font-size: 48px;
            font-weight: bold;
            line-height: 1;
        }
        
        .stat-card.login { background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); }
        .stat-card.logout { background: linear-gradient(135deg, #3494e6 0%, #ec6ead 100%); }
        .stat-card.failed { background: linear-gradient(135deg, #eb3349 0%, #f45c43 100%); }
        
        .page {
            display: none;
            animation: fadeIn 0.3s;
        }
        
        .page.active {
            display: block;
        }
        
        @keyframes fadeIn {
            from { opacity: 0; }
            to { opacity: 1; }
        }
        
        .page-title {
            font-size: 24px;
            color: #333;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 3px solid #667eea;
        }
        
        .search-box {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 20px;
        }
        
        .search-input-group {
            display: flex;
            gap: 10px;
            margin-top: 10px;
        }
        
        .search-input {
            flex: 1;
            padding: 12px;
            border: 2px solid #ddd;
            border-radius: 8px;
            font-size: 14px;
        }
        
        .search-input:focus {
            outline: none;
            border-color: #4facfe;
        }
        
        .search-submit {
            background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 8px;
            cursor: pointer;
            font-weight: bold;
        }
        
        .search-submit:hover {
            filter: brightness(1.05);
        }
        
        .search-result {
            margin-top: 20px;
        }
        
        .no-result {
            text-align: center;
            padding: 40px;
            color: #999;
            font-size: 16px;
        }
        
        .data-table {
            width: 100%;
            border-collapse: collapse;
            background: white;
            border-radius: 10px;
            overflow: hidden;
            box-shadow: 0 2px 8px rgba(0,0,0,0.05);
            margin-top: 20px;
        }
        
        .data-table thead {
            background: #2c3e50;
            color: white;
        }
        
        .data-table th {
            padding: 15px;
            text-align: left;
            font-weight: 600;
        }
        
        .data-table td {
            padding: 12px 15px;
            border-bottom: 1px solid #ecf0f1;
        }
        
        .data-table tbody tr:hover {
            background: #f8f9fa;
        }
        
        .alert-box {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 20px;
            border-radius: 10px;
            margin: 20px 0;
        }
        
        .alert-box strong {
            color: #856404;
            font-size: 16px;
        }
        
        .alert-box pre {
            margin-top: 10px;
            font-family: monospace;
            font-size: 13px;
            color: #856404;
            white-space: pre-wrap;
        }
        
        .info-list {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 10px;
            margin: 20px 0;
        }
        
        .info-list li {
            padding: 8px 0;
            list-style: none;
        }
        
        .refresh-btn {
            background: #3498db;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 8px;
            cursor: pointer;
            margin-top: 20px;
        }
        
        .refresh-btn:hover {
            background: #2980b9;
        }
        
        .footer {
            background: #f8f9fa;
            padding: 15px;
            text-align: center;
            color: #666;
            font-size: 12px;
            border-top: 1px solid #e0e0e0;
        }
        
        .loading {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid #f3f3f3;
            border-top: 3px solid #667eea;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin-left: 10px;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        @media (max-width: 768px) {
            .dashboard {
                flex-direction: column;
            }
            .sidebar {
                width: 100%;
                border-right: none;
                border-bottom: 2px solid #e0e0e0;
            }
            .stats-grid {
                grid-template-columns: 1fr;
            }
            body {
                padding: 10px;
            }
        }
    </style>
    <script>
        let currentPage = 'home';
        
        function showPage(pageName, btnElement) {
            currentPage = pageName;
            
            document.querySelectorAll('.page').forEach(page => {
                page.classList.remove('active');
            });
            document.getElementById(pageName).classList.add('active');
            
            document.querySelectorAll('.nav-btn').forEach(btn => {
                btn.classList.remove('active');
            });
            if (btnElement) {
                btnElement.classList.add('active');
            }
        }
        
        function searchUser() {
            const username = document.getElementById('searchUsername').value.trim();
            if (!username) {
                alert('Please enter a username to search');
                return;
            }
            
            const resultDiv = document.getElementById('searchResult');
            resultDiv.innerHTML = '<div style="text-align:center; padding:20px;"><div class="loading"></div> Searching...</div>';
            
            fetch(window.location.href)
                .then(response => response.text())
                .then(html => {
                    const parser = new DOMParser();
                    const doc = parser.parseFromString(html, 'text/html');
                    
                    const loginRows = doc.querySelectorAll('#login .data-table tbody tr');
                    let foundRecords = [];
                    
                    loginRows.forEach(row => {
                        const cells = row.querySelectorAll('td');
                        if (cells.length >= 2) {
                            const user = cells[1].innerText.trim();
                            if (user.toLowerCase() === username.toLowerCase()) {
                                foundRecords.push({
                                    time: cells[0].innerText,
                                    user: user
                                });
                            }
                        }
                    });
                    
                    if (foundRecords.length > 0) {
                        let tableHtml = '<h4 style="margin-bottom: 10px;">✅ Found ' + foundRecords.length + ' record(s) for user: <strong style="color:#4facfe;">' + username + '</strong></h4>';
                        tableHtml += '<table class="data-table"><thead><tr><th>Timestamp</th><th>Username</th></tr></thead><tbody>';
                        foundRecords.forEach(record => {
                            tableHtml += '<tr><td>' + record.time + 'NonNullList<Organization></td><td>' + record.user + 'NonNullList<Organization></tr>';
                        });
                        tableHtml += '</tbody></table>';
                        resultDiv.innerHTML = tableHtml;
                    } else {
                        resultDiv.innerHTML = '<div class="no-result">❌ No user found with username: <strong>' + username + '</strong></div>';
                    }
                })
                .catch(error => {
                    resultDiv.innerHTML = '<div class="no-result">❌ Error searching for user. Please try again.</div>';
                });
        }
        
        function refreshData() {
            document.querySelectorAll('.stat-card .number').forEach(el => {
                el.style.opacity = '0.5';
            });
            
            fetch(window.location.href)
                .then(response => response.text())
                .then(html => {
                    const parser = new DOMParser();
                    const doc = parser.parseFromString(html, 'text/html');
                    
                    const newTotalLogin = doc.querySelector('.stat-card.login .number')?.innerText;
                    const newTotalLogout = doc.querySelector('.stat-card.logout .number')?.innerText;
                    const newTotalFailed = doc.querySelector('.stat-card.failed .number')?.innerText;
                    const newTime = doc.querySelector('.header p:last-child')?.innerHTML;
                    const newAlerts = doc.querySelector('.alert-box pre')?.innerHTML;
                    
                    if (newTotalLogin) document.querySelector('.stat-card.login .number').innerText = newTotalLogin;
                    if (newTotalLogout) document.querySelector('.stat-card.logout .number').innerText = newTotalLogout;
                    if (newTotalFailed) document.querySelector('.stat-card.failed .number').innerText = newTotalFailed;
                    if (newTime) document.querySelector('.header p:last-child').innerHTML = newTime;
                    if (newAlerts) document.querySelector('.alert-box pre').innerHTML = newAlerts;
                    
                    if (currentPage === 'login') {
                        const newLoginTable = doc.querySelector('#login .data-table tbody')?.innerHTML;
                        if (newLoginTable) document.querySelector('#login .data-table tbody').innerHTML = newLoginTable;
                        const newTotal = doc.querySelector('#login p strong')?.innerHTML;
                        if (newTotal) document.querySelector('#login p strong').innerHTML = newTotal;
                    } else if (currentPage === 'logout') {
                        const newLogoutTable = doc.querySelector('#logout .data-table tbody')?.innerHTML;
                        if (newLogoutTable) document.querySelector('#logout .data-table tbody').innerHTML = newLogoutTable;
                        const newTotal = doc.querySelector('#logout p strong')?.innerHTML;
                        if (newTotal) document.querySelector('#logout p strong').innerHTML = newTotal;
                    } else if (currentPage === 'failed') {
                        const newFailedTable = doc.querySelector('#failed .data-table tbody')?.innerHTML;
                        if (newFailedTable) document.querySelector('#failed .data-table tbody').innerHTML = newFailedTable;
                        const newTotal = doc.querySelector('#failed p strong')?.innerHTML;
                        if (newTotal) document.querySelector('#failed p strong').innerHTML = newTotal;
                    } else if (currentPage === 'suspicious') {
                        const newSuspiciousTable = doc.querySelector('#suspicious .data-table tbody')?.innerHTML;
                        if (newSuspiciousTable) document.querySelector('#suspicious .data-table tbody').innerHTML = newSuspiciousTable;
                    } else if (currentPage === 'home') {
                        const newInfoList = doc.querySelector('#home .info-list')?.innerHTML;
                        if (newInfoList) document.querySelector('#home .info-list').innerHTML = newInfoList;
                    }
                    
                    const newFooterTime = doc.querySelector('.footer p')?.innerHTML;
                    if (newFooterTime) document.querySelector('.footer p').innerHTML = newFooterTime;
                    
                    document.querySelectorAll('.stat-card .number').forEach(el => {
                        el.style.opacity = '1';
                    });
                })
                .catch(error => {
                    console.error('Refresh failed:', error);
                    document.querySelectorAll('.stat-card .number').forEach(el => {
                        el.style.opacity = '1';
                    });
                });
        }
        
        function generateReport() {
            const reportWindow = window.open('', '_blank', 'width=1000,height=700');
            
            var reportContent = '<!DOCTYPE html>\n';
            reportContent += '<html>\n';
            reportContent += '<head>\n';
            reportContent += '<title>Security Report - ' + new Date().toLocaleString() + '</title>\n';
            reportContent += '<style>\n';
            reportContent += 'body{font-family:"Segoe UI",Arial,sans-serif;padding:40px;background:#f4f6f9;}\n';
            reportContent += '.report-container{max-width:1000px;margin:auto;background:white;padding:40px;border-radius:15px;box-shadow:0 10px 30px rgba(0,0,0,0.1);}\n';
            reportContent += 'h1{color:#667eea;border-bottom:3px solid #667eea;padding-bottom:10px;font-size:32px;}\n';
            reportContent += 'h2{color:#333;margin-top:30px;font-size:24px;}\n';
            reportContent += '.stats{display:flex;gap:20px;margin:30px 0;}\n';
            reportContent += '.stat-box{flex:1;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:white;padding:25px;border-radius:10px;text-align:center;}\n';
            reportContent += '.stat-box h3{font-size:16px;margin-bottom:10px;}\n';
            reportContent += '.stat-box h2{font-size:48px;margin:10px 0;color:white;}\n';
            reportContent += 'table{width:100%;border-collapse:collapse;margin:20px 0;}\n';
            reportContent += 'th,td{padding:12px;border:1px solid #ddd;text-align:left;}\n';
            reportContent += 'th{background:#2c3e50;color:white;}\n';
            reportContent += '.footer{text-align:center;margin-top:40px;padding-top:20px;border-top:1px solid #ddd;color:#666;}\n';
            reportContent += '</style>\n';
            reportContent += '</head>\n';
            reportContent += '<body>\n';
            reportContent += '<div class="report-container">\n';
            reportContent += '<h1>📊 Login Monitor Security Report</h1>\n';
            reportContent += '<p>Generated: ' + new Date().toLocaleString() + ' | Server: $hostname_val</p>\n';
            reportContent += '<div class="stats">\n';
            reportContent += '<div class="stat-box"><h3>✅ Total Successful Logins</h3><h2>$total_login</h2></div>\n';
            reportContent += '<div class="stat-box"><h3>📤 Total Logouts</h3><h2>$total_logout</h2></div>\n';
            reportContent += '<div class="stat-box"><h3>❌ Total Failed Attempts</h3><h2>$total_failed</h2></div>\n';
            reportContent += '</div>\n';
            reportContent += '<h2>📋 Last 10 Login Activities</h2>\n';
            reportContent += '<table>\n';
            reportContent += '<thead><tr><th>Timestamp</th><th>Username</th></tr></thead>\n';
            reportContent += '<tbody>$report_login_table</tbody>\n';
            reportContent += '</table>\n';
            reportContent += '<h2>⚠️ Suspicious IP Addresses (≥3 failures)</h2>\n';
            reportContent += '</table><thead><tr><th>IP Address</th><th>Attempts</th></tr></thead>\n';
            reportContent += '<tbody>$suspicious_table</tbody>\n';
            reportContent += '</table>\n';
            reportContent += '<div class="footer"><p>IDS Login Monitor - Security Report | Generated by System</p></div>\n';
            reportContent += '</div>\n';
            reportContent += '</body>\n';
            reportContent += '</html>';
            
            reportWindow.document.write(reportContent);
            reportWindow.document.close();
        }
        
        setInterval(refreshData, 30000);
    </script>
</head>
<body>
    <div class="main-container">
        <div class="header">
            <h1>🔐 Login & Logout Monitor (IDS)</h1>
            <p>Intrusion Detection System - Operating System Lab</p>
            <p style="font-size: 12px; margin-top: 5px;">Server: $hostname_val | Time: $current_time</p>
        </div>
        
        <div class="dashboard">
            <div class="sidebar">
                <div class="nav-buttons">
                    <button class="nav-btn btn-dashboard" onclick="showPage('home', this)">🏠 Dashboard</button>
                    <button class="nav-btn btn-login" onclick="showPage('login', this)">📋 Login History</button>
                    <button class="nav-btn btn-logout" onclick="showPage('logout', this)">📤 Logout History</button>
                    <button class="nav-btn btn-failed" onclick="showPage('failed', this)">❌ Failed Attempts</button>
                    <button class="nav-btn btn-suspicious" onclick="showPage('suspicious', this)">⚠️ Suspicious IPs</button>
                    <button class="nav-btn btn-search" onclick="showPage('search', this)">🔍 Search User</button>
                    <button class="nav-btn btn-report" onclick="generateReport()">📊 Generate Report</button>
                </div>
            </div>
            
            <div class="content-area">
                <div class="stats-grid">
                    <div class="stat-card login" onclick="showPage('login', document.querySelector('.btn-login'))">
                        <div class="label">✅ Total Successful Logins</div>
                        <div class="number">$total_login</div>
                    </div>
                    <div class="stat-card logout" onclick="showPage('logout', document.querySelector('.btn-logout'))">
                        <div class="label">📤 Total Logouts</div>
                        <div class="number">$total_logout</div>
                    </div>
                    <div class="stat-card failed" onclick="showPage('failed', document.querySelector('.btn-failed'))">
                        <div class="label">❌ Total Failed Attempts</div>
                        <div class="number">$total_failed</div>
                    </div>
                </div>
                
                <div id="home" class="page active">
                    <div class="page-title">📊 System Status Dashboard</div>
                    <div class="alert-box">
                        <strong>⚠️ Recent Failed Attempts Alert:</strong>
                        <pre>$recent_alerts</pre>
                    </div>
                    <div class="info-list">
                        <li>✅ Total Successful Logins: <strong>$total_login</strong></li>
                        <li>📤 Total Logouts: <strong>$total_logout</strong></li>
                        <li>❌ Total Failed Attempts: <strong>$total_failed</strong></li>
                        <li>🖥️ Server Hostname: <strong>$hostname_val</strong></li>
                        <li>🕐 Last Updated: <strong>$current_time</strong></li>
                        <li>🔄 Auto-refresh: Every 30 seconds (data only, no page reload)</li>
                    </div>
                    <button class="refresh-btn" onclick="refreshData()">🔄 Refresh Data Now</button>
                </div>
                
                <div id="login" class="page">
                    <div class="page-title">📋 Login History</div>
                    <table class="data-table">
                        <thead><tr><th>Timestamp</th><th>Username</th></tr></thead>
                        <tbody>$login_table</tbody>
                    </table>
                    <p style="margin-top: 15px;"><strong>Total Records: $total_login</strong></p>
                </div>
                
                <div id="logout" class="page">
                    <div class="page-title">📤 Logout History</div>
                    <table class="data-table">
                        <thead><tr><th>Timestamp</th><th>Username</th></tr></thead>
                        <tbody>$logout_table</tbody>
                    </table>
                    <p style="margin-top: 15px;"><strong>Total Records: $total_logout</strong></p>
                </div>
                
                <div id="failed" class="page">
                    <div class="page-title">❌ Failed Login Attempts</div>
                    <table class="data-table">
                        <thead><tr><th>Timestamp</th><th>Username</th><th>IP Address</th></tr></thead>
                        <tbody>$failed_table</tbody>
                    </table>
                    <p style="margin-top: 15px;"><strong>Total Failed: $total_failed</strong></p>
                </div>
                
                <div id="suspicious" class="page">
                    <div class="page-title">⚠️ Suspicious IP Addresses (3+ Failed Attempts)</div>
                    <table class="data-table">
                        <thead><tr><th>IP Address</th><th>Failed Attempts</th></tr></thead>
                        <tbody>$suspicious_table</tbody>
                    </table>
                </div>
                
                <div id="search" class="page">
                    <div class="page-title">🔍 Search User History</div>
                    <div class="search-box">
                        <p>Enter a username to see their login history:</p>
                        <div class="search-input-group">
                            <input type="text" id="searchUsername" class="search-input" placeholder="Enter username (e.g., root, admin, user)" onkeypress="if(event.key==='Enter') searchUser()">
                            <button class="search-submit" onclick="searchUser()">🔍 Search</button>
                        </div>
                    </div>
                    <div id="searchResult" class="search-result"></div>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p>Last update: $current_time | Auto-refresh every 30 seconds (data only)</p>
        </div>
    </div>
</body>
</html>
EOF

} | nc -l -p $PORT -q 1

done
