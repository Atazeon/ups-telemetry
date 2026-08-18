# Server Room UPS Telemetry Dashboard

A lightweight, robust PowerShell automation tool that pulls real-time environmental and internal health data from a server room UPS via SNMP, and automatically publishes it to a live GitHub Pages dashboard. 

Built specifically to be resilient in strict enterprise and educational network environments.

---

## Project Origins
This project was successfully engineered and deployed by **two college student interns** for the **Coral Academy of Science Las Vegas**. It was designed from the ground up to solve real-world infrastructure monitoring challenges while navigating the strict security policies of a live school network.

---

## Features
* **Real-Time SNMP Polling:** Continuously fetches Room Temperature, Humidity, Internal Temperature, Battery Temperature, and Battery Capacity.
* **Automated Dashboard Deployment:** Generates a custom HTML file and silently pushes it to GitHub every 60 seconds.
* **Zero-Dependency UI:** The dashboard uses 100% pure CSS and vanilla JavaScript to render speedometer dials and progress bars. It requires **zero** external libraries, making it completely immune to strict web filters and ad-blockers.
* **Self-Backing Script:** The PowerShell script automatically detects its own location and pushes a backup of itself to the repository before the infinite telemetry loop begins.

---

## The Development Journey & Roadblocks Overcome
Building this telemetry system required navigating several unique IT and environmental hurdles. Documenting these struggles ensures future maintainers understand *why* certain architectural decisions were made.

### 1. The SNMP Module Conflict
Initially, the script was designed around an older SNMP module utilizing `Invoke-SnmpGet`. Moving to a new Windows 11 machine introduced TLS 1.2 download blocks and hidden administrator profile locks. Upon forcing the module installation, we discovered the new environment utilized a completely different SharpSnmpLib wrapper. We successfully adapted the script to map different parameter syntaxes (e.g., `-IPAddress` vs `-IP`, `-Version Ver1` vs `-Version V1`) and transitioned entirely to `Get-SnmpData`.

### 2. The Headless Git Authorization
Automating `git push` on a 60-second loop requires a silent, non-interactive pipeline. We initially hit the classic `src refspec main does not match any` error due to an uninitialized local repository. By manually forcing the first commit, setting up the `main` branch, and authenticating through the Git Credential Manager, we secured a token that allows the script to push updates endlessly in the background without prompting for a password.

### 3. The Web Filter Blockade
The original dashboard design relied on the Google Charts API to render visual speedometer dials. However, the school's strict network web filter blocked external scripts from `gstatic.com`, causing the gauges to render as invisible, empty boxes. 

**The Solution:** We engineered a custom, hybrid "Pure CSS" solution. The script now calculates the mathematical rotation of the dials natively inside standard HTML `<div>` elements. Because it relies on standard browser geometry rather than external downloads, the visual dashboard is completely unblockable on the school's network. 

### 4. Mathematical Dial Inversions
During the transition to pure CSS dials, a mathematical error in the JavaScript rotation formula (`-45deg`) caused the gauges to invert and empty backward once they crossed the 50% threshold. The rotation logic was rewritten (`-135deg` offset) and the temperature boundaries were recalibrated (e.g., setting the room temp floor to 40°F) to ensure the needles center correctly and accurately reflect warning (orange) and critical (red) zones.

---

## Setup & Installation

### Prerequisites
1. **Git for Windows:** Must be installed and authenticated with your GitHub account.
2. **PowerShell SNMP Module:** Ensure the `Snmp` module is installed for all users (`Install-Module Snmp -Scope AllUsers -Force`).
3. **Local Repository:** Clone this repository to your local machine (default path: `C:\ups-telemetry`).

### Configuration
Open the PowerShell script (`ups_telemetry_script.ps1`) and configure the following variables to match your environment:
* `$UPS_IP`: The local IP address of your UPS.
* `$Oid...`: The specific SNMP OIDs for your hardware.
* `$RepoFolder`: The local path where this Git repository is cloned.

### Usage
1. Open Windows PowerShell.
2. Navigate to your repository folder.
3. Run the script: `.\ups_telemetry_script.ps1`
4. The script will back itself up, begin polling the UPS, and push the live `index.html` dashboard to GitHub Pages every minute. Press `Ctrl+C` at any time to terminate the loop.
