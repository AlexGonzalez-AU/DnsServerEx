#Requires -Module ActiveDirectory, DnsServer

[CmdletBinding()]

param (
    [Parameter(Mandatory=$true,ValueFromPipeline=$false,Position=0)]
    $DomainFQDN,
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=1)]
    $RecordName
)

$computerNames = Get-ADGroupMember -Identity 'Domain Controllers' -Server $DomainFQDN |
    Select-Object -ExpandProperty Name

$i = 0 

$computerNames | 
    ForEach-Object {
        $i++
        $computerName = "{0}.{0}" -f $_, $DomainFQDN

        Write-Progress -Activity ("Searching domain '{0}' for '{1}' record data" -f $DomainFQDN, $RecordName) -Status $computerName -PercentCompleted ($i / $computerNames.Count * 100)

        Get-DnsServerZones -ComputerName $computerName -WarningAction SilentlyContinue |
        Where-Object {
            ($_.ZoneName -eq "Primary") -and 
            ($_.ZoneName -like "*{0}" -f $DomainFQDN)
        } |
        ForEach-Object {
            $zoneName = $_.ZoneName
            $_ | Get-DnsServerResourceRecord -ComputerName $computerName -Name $RecordName -ErrorAction SilentlyContinue |
            Select-Object `
                @{n='ComputerName'; e={$computerName.ToLower()}},
                @{n='RecordName'; e={"{0}.{1}" -f $_.HostName, $zoneName}},
                RecordType,
                @{n='RecordData'; e={$_.RecordData.HostNameAlias.Trim(".")}},
                RecordClass,
                Timestamp,
                TimeToLive,
                Type,
                HostName,
                DistinguishedName,
                @{n='ZoneName'; e={$zoneName}}
        }

    }