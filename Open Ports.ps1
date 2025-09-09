# Define the ports to be opened
$ports = @(30120, 40120)

# Loop through each port and create firewall rules for both TCP and UDP protocols
foreach ($port in $ports) {
    foreach ($protocol in @("TCP", "UDP")) {
        # Create inbound rule
        New-NetFirewallRule -DisplayName "FiveM - $protocol Inbound Port $port" `
                            -Direction Inbound `
                            -Protocol $protocol `
                            -LocalPort $port `
                            -Action Allow `
                            -Profile Any
    }
}
