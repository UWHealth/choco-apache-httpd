Import-Module au

# $releases = 'https://www.apachehaus.com/cgi-bin/download.plx'
$releases = 'https://www.apachelounge.com/download/'

$versionPostfix = "0000"

$global:au_NoCheckChocoVersion = $true

function global:au_BeforeUpdate {
  Get-RemoteFiles -NoSuffix
  $Latest.ChecksumType64 = 'sha512'
  $Latest.Checksum64 = Get-FileHash "tools\$($Latest.FileName64)" -Algorithm SHA512 | ForEach-Object -MemberName Hash
}

function global:au_GetLatest {
  $versionRegEx = 'httpd\-([\d\.]+)[a-z]*\-win64\-(VS17)[a-z]*\.zip'

  try {
    $downloadPage = Invoke-WebRequest -Uri $releases -Headers @{ 'Accept' = '*/*'; 'User-Agent' = 'Mozilla/5.0' }

  }
  catch {
    $downloadPage = $_.Exception.Response
    write-host ("Exception: {0}" -f $_.Exception.Message)
  }

  $matching = [regex]::match($downloadPage.Content, $versionRegEx)
  Write-Host($matching)


  $version = [version]$matching.Groups[1].Value

  $url = "https://www.apachelounge.com/download/$($matching.Groups[2].Value)/binaries/$($matching.Groups[0].Value)"

  Write-Host($version)

  return @{

    Url64   = $url
    Version = "$($version).$($versionPostfix)"
  }

}

function global:au_SearchReplace {
  Write-Host($Latest)
  return @{
    ".\tools\chocolateyInstall.ps1" = @{
      "(?i)(^\s*file64\s*=\s*`"[$]toolsDir\\).*" = "`${1}$($Latest.FileName64)`""
    }
    ".\legal\VERIFICATION.txt"      = @{
      "(?i)(listed on\s*)\<.*\>" = "`${1}<$releases>"
      "(?i)(64-Bit.+)\<.*\>"     = "`${1}<$($Latest.URL64)>"
      "(?i)(checksum type:).*"   = "`${1} $($Latest.ChecksumType64)"
      "(?i)(checksum:).*"        = "`${1} $($Latest.Checksum64)"
    }
  }
}

# TODO retrieve checksums at https://www.apachelounge.com/download/$($matching.Groups[2].Value)/binaries/$($matching.Groups[0].Value).txt
# retrieve sha512 and compare

update -ChecksumFor none -Debug
