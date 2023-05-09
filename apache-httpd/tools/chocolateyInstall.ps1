$toolsDir = Split-Path -parent $MyInvocation.MyCommand.Definition
. "$toolsDir\helpers.ps1"

$pp = Get-PackageParameters

$arguments = @{
    packageName = $env:chocolateyPackageName
    file64      = "$toolsDir\httpd-2.4.57-win64-VS17.zip"
    modLogRotate = "$toolsDir\mod_log_rotate-win64-VS17.so"
    destination = if ($pp.installLocation) { $pp.installLocation } else { $env:ProgramFiles }
    port        = if ($pp.Port) { $pp.Port } else { 81 }
    serviceName = if ($pp.NoService) { $null } elseif ($pp.serviceName) { $pp.serviceName } else { 'Apache' }
}

if (-not (Assert-TcpPortIsOpen $arguments.port)) {
    throw 'Please specify a different port number...'
}

Install-Apache $arguments

# TODO add Windows registry keys to display installed version of Apache httpd
