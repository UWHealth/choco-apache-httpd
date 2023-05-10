
function Get-TCPConnections {
    param(
        [int]$portNumber
    )
    $ListeningPort = @()
    $GetPorts = netstat -nao | Select-String ":$portNumber  " | Select-Object -First 2
    Foreach ($Port in $GetPorts) {
        $a = $Port -split '\s\s*'
        if ( $a[2] -match ":$portNumber" ) {
            $Ports = New-Object System.Object
            $LA = $a[2] -split ":"
            $FA = $a[3] -split ":"
            $Ports | Add-Member -MemberType NoteProperty -Name 'LocalAddress' -Value $LA[0]
            $Ports | Add-Member -MemberType NoteProperty -Name 'LocalPort' -Value $LA[1]
            $Ports | Add-Member -MemberType NoteProperty -Name 'RemoteAddress' -Value $FA[0]
            $Ports | Add-Member -MemberType NoteProperty -Name 'RemotePort' -Value $FA[1]
            $Ports | Add-Member -MemberType NoteProperty -Name 'State' -Value $a[4]
            $Ports | Add-Member -MemberType NoteProperty -Name 'OwningProcess' -Value $a[5]
        }
        $ListeningPort += $Ports
    }
    return $ListeningPort
}

function Assert-TcpPortIsOpen {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)][ValidateNotNullOrEmpty()][int] $portNumber
    )

    $process = Get-TCPConnections -portNumber $portNumber | `
        Select-Object -First 1 -ExpandProperty OwningProcess | `
        Select-Object @{Name = "Id"; Expression = { $_ } } | `
        Get-Process | `
        Select-Object Name, Path

    if ($process) {
        if ($process.Path) {
            Write-Host "Port '$portNumber' is in use by '$($process.Name)' with path '$($process.Path)'..."
        }
        else {
            Write-Host "Port '$portNumber' is in use by '$($process.Name)'..."
        }

        return $false
    }

    return $true
}

function Get-ApacheInstallOptions {
    $configFile = Join-Path -Path (Get-ChocolateyPath -PathType 'PackagePath') -ChildPath 'config.xml'
    $config = Import-CliXml $configFile

    return $config
}

function Get-ApachePaths {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory)][ValidateNotNullOrEmpty()][string] $installDir
    )

    $apacheDir = Get-ChildItem $installDir -Directory -Filter 'Apache*' | Select-Object -First 1 -ExpandProperty FullName
    $confPath = Join-Path $apacheDir 'conf\httpd.conf'
    $binPath = Join-Path $apacheDir 'bin\httpd.exe'

    return @{ ApacheDir = $apacheDir; ConfPath = $confPath; BinPath = $binPath }
}

function Install-Apache {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory)][ValidateNotNullOrEmpty()][PSCustomObject] $arguments
    )

    Get-ChocolateyUnzip `
        -file64 $arguments.file64 `
        -destination $arguments.destination

    # Copy mod_log_rotate $arguments.modLogRotate
    Copy-Item $arguments.modLogRotate -Destination "$($arguments.destination)\Apache24\modules\mod_log_rotate.so"
    

    Set-ApacheConfig $arguments

    if ($arguments.serviceName) {
        Install-ApacheService $arguments
    }

    Set-ApacheInstallOptions $arguments

    # add uninstall registry keys?
}

function Install-ApacheService {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory)][ValidateNotNullOrEmpty()][PSCustomObject] $arguments
    )

    $apachePaths = Get-ApachePaths $arguments.destination

    & $apachePaths.BinPath -k install -n "$($arguments.serviceName)"

    Start-Service $arguments.serviceName
}

function Set-ApacheConfig {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory)][ValidateNotNullOrEmpty()][PSCustomObject] $arguments
    )

    $apachePaths = Get-ApachePaths $arguments.destination

    $customConfigIncludePath = 'conf/custom/*/*.conf'
    # Set the server root and port number
    $httpConf = Get-Content $apachePaths.ConfPath
    $httpConf = $httpConf -replace 'Define SRVROOT.*', "Define SRVROOT ""$($apachePaths.ApacheDir -replace '\\', '/')"""
    $httpConf = $httpConf -replace 'Listen 80', "Listen $($arguments.port)"
    $httpConf = $httpConf -replace "# Supplemental configuration", "# Supplemental (modified) configuration`r`nIncludeOptional $($customConfigIncludePath)`r`n"


    Set-Content -Path $apachePaths.ConfPath -Value $httpConf -Encoding Ascii
}

function Set-ApacheInstallOptions {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory)][ValidateNotNullOrEmpty()][PSCustomObject] $arguments
    )

    $apachePaths = Get-ApachePaths $arguments.destination

    $config = @{
        Destination = $apachePaths.ApacheDir
        BinPath     = $apachePaths.BinPath
        ServiceName = $arguments.serviceName
    }

    $configFile = Join-Path -Path (Get-ChocolateyPath -PathType 'PackagePath') -ChildPath 'config.xml'
    Export-Clixml -Path $configFile -InputObject $config
}

function Stop-ApacheService {
    $config = Get-ApacheInstallOptions

    $service = Get-Service | Where-Object Name -eq $config.serviceName

    if ($service) {
        Stop-Service $config.serviceName
    }
}

function Uninstall-Apache {
    $config = Get-ApacheInstallOptions

    if ($config.serviceName) {
        & $config.BinPath -k uninstall -n "$($config.serviceName)"
    }

    Remove-Item $config.destination -Recurse -Force
}

function Uninstall-ApacheService {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory)][ValidateNotNullOrEmpty()][PSCustomObject] $arguments
    )

    $apachePaths = Get-ApachePaths $arguments.destination

    & $apachePaths.BinPath -k uninstall -n "$($arguments.serviceName)"
}

function Assert-ChecksumMatch {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory)][ValidateNotNullOrEmpty()][PSCustomObject] $arguments
    )
    $shaType = $arguments.shaType
    $checksum = $arguments.checksum
    $file = $arguments.file

    $hash = (Get-FileHash $file -Algorithm $shaType).Hash
    Write-Debug("$($file), $($shaType), $($checksum), $($hash)")
    if ($hash -eq $checksum) {
        return $true;
    }
    return $false;
}
