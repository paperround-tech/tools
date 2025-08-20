# Portal Database SSH Tunnels - PowerShell Version
# QA: 5433, UAT: 5434, Staging: 5435, Production: 5436

# Configuration - Change this to your SSH key file name
$script:sshKeyBaseName = "bastion_key"  # Will use bastion_key_qa, bastion_key_uat, etc.
# Alternatively, use a single key for all environments:
# $script:sshKeyBaseName = "bastion_key_portal"  # Will use bastion_key_portal for all

# Global variables for tunnel tracking
$script:tunnelProcesses = @{}

# Helper function to get SSH key path
function Get-SSHKeyPath {
    param([string]$Environment)
    
    if ($script:sshKeyBaseName -eq "bastion_key_portal") {
        # Use single key for all environments
        return "$env:USERPROFILE\.ssh\bastion_key_portal"
    } else {
        # Use environment-specific keys
        return "$env:USERPROFILE\.ssh\${script:sshKeyBaseName}_${Environment}"
    }
}

# Function to start QA tunnel
function Start-PortalQATunnel {
    Write-Host "Starting QA tunnel on port 5433..." -ForegroundColor Green
    $keyPath = Get-SSHKeyPath -Environment "qa"
    $process = Start-Process -FilePath "ssh" -ArgumentList @(
        "-N",
        "-L", "5433:portal-qa-cluster.cluster-ctvaf9l5ench.eu-west-2.rds.amazonaws.com:5432",
        "-o", "ExitOnForwardFailure=yes",
        "ec2-user@35.179.170.3",
        "-i", $keyPath
    ) -PassThru -WindowStyle Hidden
    
    $script:tunnelProcesses["qa"] = $process
    Write-Host "QA tunnel started (PID: $($process.Id))" -ForegroundColor Green
}

# Function to start UAT tunnel
function Start-PortalUATTunnel {
    Write-Host "Starting UAT tunnel on port 5434..." -ForegroundColor Green
    $keyPath = Get-SSHKeyPath -Environment "uat"
    $process = Start-Process -FilePath "ssh" -ArgumentList @(
        "-N",
        "-L", "5434:portal-uat-cluster.cluster-ctvaf9l5ench.eu-west-2.rds.amazonaws.com:5432",
        "-o", "ExitOnForwardFailure=yes",
        "ec2-user@18.175.239.214",
        "-i", $keyPath
    ) -PassThru -WindowStyle Hidden
    
    $script:tunnelProcesses["uat"] = $process
    Write-Host "UAT tunnel started (PID: $($process.Id))" -ForegroundColor Green
}

# Function to start Staging tunnel
function Start-PortalStagingTunnel {
    Write-Host "Starting Staging tunnel on port 5435..." -ForegroundColor Green
    $keyPath = Get-SSHKeyPath -Environment "staging"
    $process = Start-Process -FilePath "ssh" -ArgumentList @(
        "-N",
        "-L", "5435:portal-staging-cluster.cluster-ctvaf9l5ench.eu-west-2.rds.amazonaws.com:5432",
        "-o", "ExitOnForwardFailure=yes",
        "ec2-user@52.56.142.14",
        "-i", $keyPath
    ) -PassThru -WindowStyle Hidden
    
    $script:tunnelProcesses["staging"] = $process
    Write-Host "Staging tunnel started (PID: $($process.Id))" -ForegroundColor Green
}

# Function to start Production tunnel
function Start-PortalProductionTunnel {
    Write-Host "Starting Production tunnel on port 5436..." -ForegroundColor Green
    $keyPath = Get-SSHKeyPath -Environment "production"
    $process = Start-Process -FilePath "ssh" -ArgumentList @(
        "-N",
        "-L", "5436:portal-production-cluster.cluster-ctvaf9l5ench.eu-west-2.rds.amazonaws.com:5432",
        "-o", "ExitOnForwardFailure=yes",
        "ec2-user@18.170.58.57",
        "-i", $keyPath
    ) -PassThru -WindowStyle Hidden
    
    $script:tunnelProcesses["production"] = $process
    Write-Host "Production tunnel started (PID: $($process.Id))" -ForegroundColor Green
}

# Function to stop a specific tunnel
function Stop-PortalTunnel {
    param([string]$Environment)
    
    if ($script:tunnelProcesses.ContainsKey($Environment)) {
        $process = $script:tunnelProcesses[$Environment]
        try {
            if (!$process.HasExited) {
                $process.Kill()
                Write-Host "$Environment tunnel stopped (PID: $($process.Id))" -ForegroundColor Yellow
            } else {
                Write-Host "$Environment tunnel was already stopped" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "Error stopping $Environment tunnel: $($_.Exception.Message)" -ForegroundColor Red
        }
        $script:tunnelProcesses.Remove($Environment)
    } else {
        # Try to find and kill SSH processes by port
        $portMap = @{
            "qa" = 5433
            "uat" = 5434
            "staging" = 5435
            "production" = 5436
        }
        
        if ($portMap.ContainsKey($Environment)) {
            $port = $portMap[$Environment]
            $processes = Get-Process | Where-Object { $_.ProcessName -eq "ssh" -and $_.CommandLine -like "*-L ${port}:*" }
            if ($processes) {
                $processes | ForEach-Object { 
                    $_.Kill()
                    Write-Host "$Environment tunnel stopped (PID: $($_.Id))" -ForegroundColor Yellow
                }
            } else {
                Write-Host "No $Environment tunnel process found" -ForegroundColor Yellow
            }
        }
    }
}

# Function to stop all tunnels
function Stop-AllPortalTunnels {
    Write-Host "Stopping all portal tunnels..." -ForegroundColor Yellow
    @("qa", "uat", "staging", "production") | ForEach-Object {
        Stop-PortalTunnel -Environment $_
    }
}

# Function to start all tunnels
function Start-AllPortalTunnels {
    Write-Host "Starting all portal tunnels..." -ForegroundColor Green
    Start-PortalQATunnel
    Start-PortalUATTunnel
    Start-PortalStagingTunnel
    Start-PortalProductionTunnel
    Write-Host "All tunnels started. Use Get-PortalTunnelStatus to verify." -ForegroundColor Green
}

# Function to list running tunnels
function Get-PortalTunnelStatus {
    Write-Host "Portal tunnel status:" -ForegroundColor Cyan
    
    $portMap = @{
        "qa" = @{Port=5433; Host="35.179.170.3"}
        "uat" = @{Port=5434; Host="18.175.239.214"}
        "staging" = @{Port=5435; Host="52.56.142.14"}
        "production" = @{Port=5436; Host="18.170.58.57"}
    }
    
    foreach ($env in $portMap.Keys) {
        $port = $portMap[$env].Port
        $host = $portMap[$env].Host
        
        # Check if we have a tracked process
        if ($script:tunnelProcesses.ContainsKey($env)) {
            $process = $script:tunnelProcesses[$env]
            if (!$process.HasExited) {
                Write-Host "$env`: running (PID: $($process.Id))" -ForegroundColor Green
                continue
            } else {
                $script:tunnelProcesses.Remove($env)
            }
        }
        
        # Look for SSH processes by command line
        $sshProcesses = Get-Process | Where-Object { 
            $_.ProcessName -eq "ssh" -and 
            $_.CommandLine -like "*-L ${port}:*${host}*" 
        }
        
        if ($sshProcesses) {
            $pid = $sshProcesses[0].Id
            Write-Host "$env`: running (PID: $pid)" -ForegroundColor Green
        } else {
            Write-Host "$env`: not running" -ForegroundColor Red
        }
    }
}

# Aliases for easier use
Set-Alias -Name portal-qa-tunnel -Value Start-PortalQATunnel
Set-Alias -Name portal-uat-tunnel -Value Start-PortalUATTunnel
Set-Alias -Name portal-staging-tunnel -Value Start-PortalStagingTunnel
Set-Alias -Name portal-production-tunnel -Value Start-PortalProductionTunnel
Set-Alias -Name portal-tunnel-stop-all -Value Stop-AllPortalTunnels
Set-Alias -Name portal-tunnel-start-all -Value Start-AllPortalTunnels
Set-Alias -Name portal-tunnel-list -Value Get-PortalTunnelStatus

# Display usage information
function Show-PortalTunnelHelp {
    Write-Host @"
Portal SSH Tunnel Commands:
    Start-PortalQATunnel       (or portal-qa-tunnel)       - Start QA tunnel on port 5433
    Start-PortalUATTunnel      (or portal-uat-tunnel)      - Start UAT tunnel on port 5434
    Start-PortalStagingTunnel  (or portal-staging-tunnel)  - Start Staging tunnel on port 5435
    Start-PortalProductionTunnel (or portal-production-tunnel) - Start Production tunnel on port 5436
    
    Start-AllPortalTunnels     (or portal-tunnel-start-all) - Start all tunnels
    Stop-PortalTunnel -Environment <env> - Stop specific tunnel (qa/uat/staging/production)
    Stop-AllPortalTunnels      (or portal-tunnel-stop-all) - Stop all tunnels
    Get-PortalTunnelStatus     (or portal-tunnel-list)     - Show tunnel status
    Show-PortalTunnelHelp      - Show this help
"@ -ForegroundColor Cyan
}

Write-Host "Portal SSH Tunnels loaded. Use Show-PortalTunnelHelp for usage information." -ForegroundColor Green
