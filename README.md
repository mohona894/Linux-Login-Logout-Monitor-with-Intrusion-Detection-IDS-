# Linux-Login-Logout-Monitor-with-Intrusion-Detection-IDS

A Bash-based mini web server and terminal toolkit that monitors Linux authentication logs in real time, detects suspicious login activity, and provides both a web dashboard and CLI controls for analysis and response.

This project reads from `/var/log/auth.log`, extracts login/logout/failed attempts, identifies attacking IPs, and can automatically block repeated offenders. It was built for an Operating System lab to demonstrate log analysis, process handling, networking with `nc`, and basic intrusion detection using shell scripting.

Key Features:

Live Web Dashboard (Port 8080) using `nc` (netcat)
Parses `/var/log/auth.log` for:

  * Successful logins
  * Logouts
  * Failed password attempts
* Suspicious IP detection (≥ 3 failures)
* Automatic IP blocking via `/etc/hosts.deny`
* Interactive CLI menu for monitoring and reporting
* Report generation with timestamps
* Username-based log search
* Auto-refreshing dashboard (every 30 seconds)

Project Structure:

| File                   | Purpose                                                             |
| ---------------------- | ------------------------------------------------------------------- |
| `web_final_working.sh` | Runs a Bash-powered HTTP server and renders the live HTML dashboard |
| `project.sh`           | Core log analyzer, IDS logic, IP blocking, reporting, and CLI menu  |

 How It Works:
1. The scripts continuously read authentication logs from `/var/log/auth.log`.
2. `web_final_working.sh` uses `nc -l 8080` to serve a dynamic HTML page with:
   * Login history
   * Logout history
   * Failed attempts with IPs
   * Suspicious IP table
3. `project.sh` provides functions to:
   * Count and display events
   * Detect and list top attacking IPs
   * Block IPs that exceed a failure threshold
   * Generate reports and data files for the web interface
4. The dashboard auto-refreshes to simulate real-time monitoring.

Web Dashboard Sections:
* Home (system status + recent alerts)
* Login History
* Logout History
* Successful Logins
* Failed Logins (with IP)
* Suspicious IPs (≥3 attempts)

How to Run:
> Requires: Linux, `bash`, `netcat (nc)`, and `sudo` access

chmod +x web_final_working.sh
chmod +x project.sh

Start the web server:
sudo ./web_final_working.sh
Open browser:
http://localhost:8080
Run terminal toolkit: sudo ./project.sh

Intrusion Detection Logic:
* Extracts IPs from failed login attempts using regex
* Counts repeated failures per IP
* Flags IPs with ≥3 attempts as suspicious
* Option to automatically block them in `/etc/hosts.deny`

Report Generation:
The system can generate timestamped text reports containing:
* Total logins, logouts, failures
* Suspicious IP list
* Summary statistics

Learning Outcomes:
This project demonstrates:
* Log file parsing with `grep`, `awk`, `sort`, `uniq`
* Networking using `netcat` as a lightweight web server
* Bash scripting for automation and monitoring
* Basic Intrusion Detection System (IDS) concepts
* Process and port management in Linux
* Real-time dashboard rendering without external frameworks

Notes:
* Tested on Debian/Ubuntu-based systems where logs are stored in `/var/log/auth.log`
* Requires root privileges to read logs and update `/etc/hosts.deny`
* For educational/lab purposes (not production hardened)

 Future Improvements:
* Switch from `hosts.deny` to `iptables`/`ufw`
* Add authentication to the web dashboard
* Store logs in a structured database
* Add charts/visual analytics

Author:
Nahida Akter Mohona

