# Import the module
Import-Module Snmp

# Define the UPS IP
$UPS_IP = "192.168.20.177"

# Define your OIDs
$OidRoomTemp     = ".1.3.6.1.4.1.3808.1.1.8.2.3.1.3.1"
$OidInternalTemp = ".1.3.6.1.4.1.3808.1.1.1.10.2.0"
$OidBatteryTemp  = ".1.3.6.1.4.1.3808.1.1.1.2.2.2.0"
$OidHumidity     = ".1.3.6.1.4.1.3808.1.1.8.3.2.1.3.1"
$OidBatteryCap   = ".1.3.6.1.4.1.3808.1.1.1.2.2.1.0"

# Local Git Repository Folder
$RepoFolder = "C:\ups-telemetry"
$OutputPath = "$RepoFolder\index.html"

# Verify local repo folder exists
if (!(Test-Path -Path $RepoFolder)) {
    Write-Host "Error: Local git repository folder not found at $RepoFolder. Please clone it first!" -ForegroundColor Red
    exit
}

Write-Host "Initializing..." -ForegroundColor Cyan

# --- PRE-LOOP SCRIPT BACKUP ---
# This block grabs the script file you are running and backs it up to GitHub
if ($PSCommandPath) {
    try {
        $ScriptDestination = Join-Path $RepoFolder "ups_telemetry_script.ps1"
        Copy-Item -Path $PSCommandPath -Destination $ScriptDestination -Force
        
        Set-Location $RepoFolder
        git add "ups_telemetry_script.ps1"
        $gitStatusScript = git status --porcelain
        
        if ($gitStatusScript -match "ups_telemetry_script.ps1") {
            git commit -m "Auto-backup of PowerShell script"
            git push origin main
            Write-Host "-> Script file successfully backed up to GitHub!" -ForegroundColor Green
        } else {
            Write-Host "-> Script file backup is already up-to-date on GitHub." -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "-> Failed to backup the script file to GitHub." -ForegroundColor Red
    }
} else {
    Write-Host "-> Note: You are running this from the console instead of a saved .ps1 file. The script cannot upload itself." -ForegroundColor Yellow
}

Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
Write-Host "GitHub Telemetry script is running. Press Ctrl+C to stop." -ForegroundColor Yellow

# Start the infinite loop
while ($true) {
    try {
        # 1. Room Temperature (Divide by 100)
        $respRoomTemp = Get-SnmpData -IP $UPS_IP -Community public -OID $OidRoomTemp -Version V1
        $RoomTempF = $respRoomTemp.Data / 100.0
        Start-Sleep -Milliseconds 500

        # 2. Internal Temp Celsius (No math needed)
        $respInternalTemp = Get-SnmpData -IP $UPS_IP -Community public -OID $OidInternalTemp -Version V1
        $InternalTempC = $respInternalTemp.Data
        Start-Sleep -Milliseconds 500

        # 3. Battery Temp Celsius (Divide by 10)
        $respBatteryTemp = Get-SnmpData -IP $UPS_IP -Community public -OID $OidBatteryTemp -Version V1
        $BatteryTempC = $respBatteryTemp.Data / 10.0
        Start-Sleep -Milliseconds 500

        # 4. Humidity (Divide by 100)
        $respHumidity = Get-SnmpData -IP $UPS_IP -Community public -OID $OidHumidity -Version V1
        $Humidity = $respHumidity.Data / 100.0
        Start-Sleep -Milliseconds 500

        # 5. Battery Capacity (No math needed)
        $respBatteryCap = Get-SnmpData -IP $UPS_IP -Community public -OID $OidBatteryCap -Version V1
        $BatteryCap = $respBatteryCap.Data

        # Get Current Time for the webpage timestamp
        $Time = Get-Date -Format "MM/dd/yyyy hh:mm tt"

        # Build the HTML Page
        $HTML = @"
        <!DOCTYPE html>
        <html>
        <head>
            <title>Server Room Dashboard</title>
            <meta http-equiv="refresh" content="60">
            <style>
                body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #1e1e1e; color: #ffffff; text-align: center; margin-top: 40px; }
                h1 { color: #ffffff; font-weight: normal; margin-bottom: 30px; }
                .dashboard-container { display: flex; justify-content: center; flex-wrap: wrap; gap: 20px; max-width: 900px; margin: 0 auto; }
                .card { background-color: #2d2d2d; border-radius: 10px; padding: 20px; box-shadow: 0 4px 8px rgba(0,0,0,0.3); width: 400px; }
                h2 { color: #4da6ff; margin-top: 0; margin-bottom: 25px; font-size: 22px; font-weight: normal; }
                
                /* Layout */
                .gauges { display: flex; justify-content: center; gap: 30px; flex-wrap: wrap; }
                
                /* Pure CSS Speedometer Design */
                .gauge-wrapper { display: flex; flex-direction: column; align-items: center; width: 160px; margin-bottom: 15px; }
                .gauge { width: 160px; height: 80px; position: relative; overflow: hidden; margin-bottom: 10px; }
                .gauge-track { width: 160px; height: 160px; border-radius: 50%; border: 20px solid #444; position: absolute; top: 0; left: 0; box-sizing: border-box; }
                .gauge-fill { 
                    width: 160px; height: 160px; border-radius: 50%; border: 20px solid #4da6ff; 
                    border-bottom-color: transparent !important; border-right-color: transparent !important; 
                    position: absolute; top: 0; left: 0; box-sizing: border-box; 
                    transform: rotate(-135deg); transition: transform 1s ease-out; 
                }
                .gauge-text { position: absolute; bottom: 0; width: 100%; font-size: 24px; font-weight: bold; color: #fff; text-align: center; }
                .gauge-label { font-size: 16px; font-weight: bold; color: #cccccc; margin-top: 5px; }

                /* Progress Bar Design */
                .progress-wrapper { width: 100%; margin-bottom: 30px; display: flex; flex-direction: column; align-items: center; }
                .progress-container { width: 80%; height: 35px; background-color: #444; border-radius: 17px; position: relative; overflow: hidden; box-shadow: inset 0 2px 5px rgba(0,0,0,0.5); }
                .progress-fill { height: 100%; width: 0%; background-color: #00cc66; transition: width 1s ease-out, background-color 1s ease-out; }
                .progress-text { position: absolute; top: 0; left: 0; width: 100%; line-height: 35px; font-weight: bold; font-size: 18px; text-shadow: 1px 1px 2px rgba(0,0,0,0.8); }
                .progress-label { font-size: 16px; font-weight: bold; color: #cccccc; margin-bottom: 10px; }

                .timestamp { color: #888888; font-size: 14px; margin-top: 40px; }
            </style>
        </head>
        <body>
            <h1>UPS & Environment Status</h1>

            <div class="dashboard-container">
                <div class="card">
                    <h2>Environment</h2>
                    <div class="gauges">
                        <div class="gauge-wrapper">
                            <div class="gauge">
                                <div class="gauge-track"></div>
                                <div class="gauge-fill" id="fill-room"></div>
                                <div class="gauge-text">$RoomTempF&deg;F</div>
                            </div>
                            <div class="gauge-label">Room Temp</div>
                        </div>
                        <div class="gauge-wrapper">
                            <div class="gauge">
                                <div class="gauge-track"></div>
                                <div class="gauge-fill" id="fill-humid"></div>
                                <div class="gauge-text">$Humidity%</div>
                            </div>
                            <div class="gauge-label">Humidity</div>
                        </div>
                    </div>
                </div>
                
                <div class="card">
                    <h2>UPS Internal Health</h2>
                    
                    <!-- Battery Progress Bar -->
                    <div class="progress-wrapper">
                        <div class="progress-label">Battery Capacity</div>
                        <div class="progress-container">
                            <div class="progress-fill" id="bar-batt"></div>
                            <div class="progress-text" id="bar-batt-text">$BatteryCap%</div>
                        </div>
                    </div>

                    <!-- Internal Temps -->
                    <div class="gauges">
                        <div class="gauge-wrapper">
                            <div class="gauge">
                                <div class="gauge-track"></div>
                                <div class="gauge-fill" id="fill-int"></div>
                                <div class="gauge-text">$InternalTempC&deg;C</div>
                            </div>
                            <div class="gauge-label">Internal Temp</div>
                        </div>
                        <div class="gauge-wrapper">
                            <div class="gauge">
                                <div class="gauge-track"></div>
                                <div class="gauge-fill" id="fill-btemp"></div>
                                <div class="gauge-text">$BatteryTempC&deg;C</div>
                            </div>
                            <div class="gauge-label">Battery Temp</div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="timestamp">Last Updated: $Time</div>

            <script>
                // Dial Graphic Logic
                function setDial(id, value, min, max, warnLevel, critLevel) {
                    var val = parseFloat(value) || 0;
                    if (val < min) val = min;
                    if (val > max) val = max;
                    
                    var pct = (val - min) / (max - min);
                    var deg = (pct * 180) - 135; 
                    var fill = document.getElementById(id);
                    fill.style.transform = 'rotate(' + deg + 'deg)';

                    var color = '#00cc66'; // Default Green
                    if (val >= critLevel) color = '#ff4d4d'; // Red
                    else if (val >= warnLevel) color = '#ffaa00'; // Orange
                    
                    fill.style.borderTopColor = color;
                    fill.style.borderLeftColor = color;
                }

                // Progress Bar Logic
                function setProgressBar(id, value) {
                    var val = parseFloat(value) || 0;
                    if (val < 0) val = 0;
                    if (val > 100) val = 100;

                    var fill = document.getElementById(id);
                    fill.style.width = val + '%';

                    var color = '#00cc66'; // Default Green
                    if (val <= 20) color = '#ff4d4d'; // Red if battery under 20%
                    else if (val <= 50) color = '#ffaa00'; // Orange if battery under 50%
                    
                    fill.style.backgroundColor = color;
                }

                // Apply logic to elements
                // Temp parameters: ID, Current Value, Min Dial, Max Dial, Orange Threshold, Red Threshold
                setDial('fill-room', '$RoomTempF', 40, 110, 85, 95);
                setDial('fill-humid', '$Humidity', 0, 100, 60, 80);
                setDial('fill-int', '$InternalTempC', 0, 45, 35, 40);
                setDial('fill-btemp', '$BatteryTempC', 0, 45, 35, 40);

                // Apply Battery Bar
                setProgressBar('bar-batt', '$BatteryCap');
            </script>
        </body>
        </html>
"@

        # Save HTML file directly into the local repo folder
        $HTML | Out-File -FilePath $OutputPath -Force

        # --- GITHUB AUTOMATION BLOCK ---
        Set-Location $RepoFolder
        
        # Check if git has changes
        $gitStatus = git status --porcelain
        if ($gitStatus) {
            git add index.html
            git commit -m "Automated telemetry update: $Time"
            git push origin main
            Write-Host "[$Time] Successfully updated and pushed to GitHub!" -ForegroundColor Green
        } else {
            Write-Host "[$Time] No changes detected, skipped push." -ForegroundColor DarkGray
        }

    }
    catch {
        $ErrorTime = Get-Date -Format "hh:mm tt"
        Write-Host "[$ErrorTime] Failed to retrieve SNMP data or push to GitHub." -ForegroundColor Red
        Write-Error $_
    }

    # Pause for 60 seconds before looping again
    Start-Sleep -Seconds 60
}