<#
.SYNOPSIS
    Splits a binary file into smaller chunks of specified size.

.DESCRIPTION
    This script reads a binary file and splits it into smaller chunks of a specified size.
    Each chunk is saved as a separate file in the output directory with sequential naming.

.PARAMETER InputFile
    The path to the input file that will be split into chunks.
    This parameter is mandatory.

.PARAMETER OutputDirectory
    The directory where the split chunks will be saved.
    If not specified, defaults to the same directory as the input file with "_chunks" suffix.

.PARAMETER ChunkSize
    The size of each chunk. Supports units like KB, MB, GB.
    Default is 1MB. Examples: 512KB, 2MB, 1GB

.PARAMETER ChunkPrefix
    The prefix for the output chunk files.
    Default is "chunk_". Files will be named like "chunk_0001.bin"

.PARAMETER Overwrite
    If specified, existing chunk files in the output directory will be overwritten.
    Otherwise, the script will prompt for confirmation.

.PARAMETER Quiet
    Suppresses progress output. Only errors and final results will be displayed.

.EXAMPLE
    .\Split-File.ps1 -InputFile "C:\data\largefile.bin" -ChunkSize 2MB
    
    Splits largefile.bin into 2MB chunks in the default output directory.

.EXAMPLE
    .\Split-File.ps1 -InputFile "data.zip" -OutputDirectory "C:\chunks" -ChunkSize 512KB -ChunkPrefix "part_"
    
    Splits data.zip into 512KB chunks in C:\chunks directory with "part_" prefix.

.EXAMPLE
    .\Split-File.ps1 -InputFile "archive.tar" -ChunkSize 1GB -Overwrite -Quiet
    
    Splits archive.tar into 1GB chunks, overwriting existing files without prompting, with minimal output.

.NOTES
    Author: giuseppe.strafforello@titantechnologies.com
    Modified By: asipos1@umd.edu
    Version: 1.0
    Requires: PowerShell 3.0 or higher
    Copyright (C) 2025 Titan Technologies. All rights reserved.
    This script is licensed under the Apache License, Version 2.0.
#>

function Split-File{ # Wrapped everything in Split-File function to support correctly importing modules
    [CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Path to the input file to split")]
    [ValidateScript({
        if (-not (Test-Path $_ -PathType Leaf)) {
            throw "Input file '$_' does not exist or is not a file."
        }
        $true
    })]
    [string]$InputFile,

    [Parameter(HelpMessage = "Output directory for chunk files")]
    [string]$OutputDirectory,

    [Parameter(HelpMessage = "Size of each chunk (supports KB, MB, GB units)")]
    [ValidateScript({
        if ($_ -match '^\d+(\.\d+)?\s*(KB|MB|GB|B)?$') {
            $true
        } else {
            throw "Invalid chunk size format. Use format like '1MB', '512KB', '2GB', or just a number for bytes."
        }
    })]
    [string]$ChunkSize = "1MB",

    [Parameter(HelpMessage = "Prefix for output chunk files")]
    [ValidatePattern('^[a-zA-Z0-9_-]+$')]
    [string]$ChunkPrefix = "chunk_",

    [Parameter(HelpMessage = "Overwrite existing chunk files without prompting")]
    [switch]$Overwrite,

    [Parameter(HelpMessage = "Suppress progress output")]
    [switch]$Quiet
)

# Check
# Function to convert size string to bytes
function ConvertTo-Bytes {
    param([string]$SizeString)
    
    $SizeString = $SizeString.Trim().ToUpper()
    
    if ($SizeString -match '^(\d+(?:\.\d+)?)\s*(KB|MB|GB|B)?$') {
        $number = [double]$matches[1]
        $unit = $matches[2]
        
        switch ($unit) {
            'KB' { return [long]($number * 1KB) }
            'MB' { return [long]($number * 1MB) }
            'GB' { return [long]($number * 1GB) }
            'B'  { return [long]$number }
            default { return [long]$number }  # No unit specified, assume bytes
        }
    }
    
    throw "Invalid size format: $SizeString"
}

# Function to format bytes for display
function Format-Bytes {
    param([long]$Bytes)
    
    if ($Bytes -ge 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    } elseif ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    } elseif ($Bytes -ge 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    } else {
        return "$Bytes bytes"
    }
}

try {
    # Resolve full path for input file
    $InputFile = Resolve-Path $InputFile -ErrorAction Stop
    
    # Set default output directory if not specified
    if (-not $OutputDirectory) {
        $inputDir = Split-Path $InputFile -Parent
        $inputName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
        $OutputDirectory = Join-Path $inputDir "${inputName}_chunks"
    }

    # Ensure the output directory exists
    if (-not (Test-Path $OutputDirectory)) {
        if (-not $Quiet) {
            Write-Host "Creating output directory: $OutputDirectory" -ForegroundColor Yellow
        }
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    # Convert chunk size to bytes
    $chunkSizeBytes = ConvertTo-Bytes $ChunkSize
    
    # Get input file info
    $fileInfo = Get-Item $InputFile
    $totalSize = $fileInfo.Length
    
    if (-not $Quiet) {
        Write-Host "Input file: $InputFile" -ForegroundColor Green
        Write-Host "File size: $(Format-Bytes $totalSize)" -ForegroundColor Green
        Write-Host "Chunk size: $(Format-Bytes $chunkSizeBytes)" -ForegroundColor Green
        Write-Host "Output directory: $OutputDirectory" -ForegroundColor Green
        Write-Host ""
    }

    # Check if output directory has existing chunk files
    $existingChunks = Get-ChildItem -Path $OutputDirectory -Filter "${ChunkPrefix}*.bin" -ErrorAction SilentlyContinue
    if ($existingChunks -and -not $Overwrite) {
        $response = Read-Host "Output directory contains existing chunk files. Continue? [Y/N]"
        if ($response -notmatch '^[Yy]') {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }
    
    # Open the input file for reading
    $inputStream = [System.IO.File]::OpenRead($InputFile)
    
    try {
        $buffer = New-Object byte[] $chunkSizeBytes
        $chunkIndex = 0
        $totalBytesProcessed = 0

        while (($bytesRead = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            # Define the output file name
            $outputFile = Join-Path $OutputDirectory ("{0}{1:D4}.bin" -f $ChunkPrefix, $chunkIndex)

            # Write the chunk to the output file
            if ($bytesRead -eq $buffer.Length) {
                [System.IO.File]::WriteAllBytes($outputFile, $buffer)
            } else {
                # Last chunk might be smaller
                $lastChunkBuffer = New-Object byte[] $bytesRead
                [Array]::Copy($buffer, $lastChunkBuffer, $bytesRead)
                [System.IO.File]::WriteAllBytes($outputFile, $lastChunkBuffer)
            }

            $totalBytesProcessed += $bytesRead
            $chunkIndex++

            # Show progress
            if (-not $Quiet) {
                $percentComplete = [math]::Round(($totalBytesProcessed / $totalSize) * 100, 1)
                Write-Progress -Activity "Splitting file" -Status "Processing chunk $chunkIndex" -PercentComplete $percentComplete
            }
        }

        if (-not $Quiet) {
            $checkMark = [char]0x2713 # Added variable for unicode checkmark character
            Write-Progress -Activity "Splitting file" -Completed
            Write-Host ""
            Write-Host "$checkMark File successfully split into $chunkIndex chunks." -ForegroundColor Green
            Write-Host "Total size processed: $(Format-Bytes $totalBytesProcessed)" -ForegroundColor Green
            Write-Host "Output location: $OutputDirectory" -ForegroundColor Green
        } else {
            Write-Host "Split complete: $chunkIndex chunks created in $OutputDirectory"
        }

    } finally {
        # Close the input stream
        $inputStream.Close()
    }

} catch {
    Write-Error 'An error occurred: $($_.Exception.Message)'
    exit 1
}
}
# SIG # Begin signature block
# MIIcuwYJKoZIhvcNAQcCoIIcrDCCHKgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUF5VgVAs7DLWgR3CqkJmUxM3O
# s3CgghbqMIIDrDCCApSgAwIBAgIQEUMWNzAbeqtDhPoUB6plqjANBgkqhkiG9w0B
# AQsFADBcMSUwIwYDVQQKDBxUaXRhbiBUZWNobm9sb2dpZXMgSW50ZXJ2aWV3MR4w
# HAYJKoZIhvcNAQkBFg9hc2lwb3MxQHVtZC5lZHUxEzARBgNVBAMMCkFyb24gU2lw
# b3MwHhcNMjUwODExMjAxMTEwWhcNMjYwODExMjAzMTEwWjBcMSUwIwYDVQQKDBxU
# aXRhbiBUZWNobm9sb2dpZXMgSW50ZXJ2aWV3MR4wHAYJKoZIhvcNAQkBFg9hc2lw
# b3MxQHVtZC5lZHUxEzARBgNVBAMMCkFyb24gU2lwb3MwggEiMA0GCSqGSIb3DQEB
# AQUAA4IBDwAwggEKAoIBAQCl+EJDsAoMGJlxKsrSox1SJxfS6mDrHNTl/XShpSkh
# Xode0mqYTSdYwHc6FNeqSHERqjy5BmBjB+W8RQZ4XIYr3o6cJYIMGlY5XUFNnbWe
# ywZegJh4MLCWrDq71CPwkH+KG8JYKujSkNLGPoaTZ0XMm//pXTRODeljluVeWY74
# mW/au7yGVIiira/pStPSjbam0nysIxcP0Yh/JWS4hsrf1p3e1WXxwG1GQuclgSnX
# C+31MKcB58emfHuxTyDM4daaD0sQ8SoDuwVASGzdnGZv4RXPadh93ChG3zIbQO2V
# EF+Kh4qmOwiqEeZwif5Nn14CCDX86rKapAOLnBsiwy/BAgMBAAGjajBoMA4GA1Ud
# DwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAiBgNVHREEGzAZghdtdXMt
# YXJjaGl2ZS5kdWNrZG5zLm9yZzAdBgNVHQ4EFgQU4THLmSY3b79CCDjc6CGxUMcJ
# fhswDQYJKoZIhvcNAQELBQADggEBAJ9j2HdzDqDcXWCjvmkqqjvvfuduCBeopzWE
# r6249uqRllMU7RGsY/3QPaxpsFGheJmxApP5ILJjc6PSClRK9fC0Xi/0/Yt/XDFX
# e8FZVkJhlmQBl4P7BcjFIVrZAYH3NNRNXdfvpP9bPh0hvCtyYuj49820FTG6cUEx
# yWXF0ULV5+i8bEmVdUBJLS4HsWDFfNiGtH7cmm9OZZ/5osspcu5x4A9vrw2KRi/p
# M17sUIro1UvADizI0O4CPBTsOzJ78Jf5VpG5t7oDZCZvyvdW1WBgEC7cPzYjGLF2
# B1U9/7KY6OR5cqBazRg05nvrtYXrnpC4jt/3y4CkLJ6hJMG+yFIwggWNMIIEdaAD
# AgECAhAOmxiO+dAt5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNVBAYT
# AlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2Vy
# dC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0y
# MjA4MDEwMDAwMDBaFw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUwEwYD
# VQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAf
# BgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4Smn
# PVirdprNrnsbhA3EMB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6f
# qVcWWVVyr2iTcMKyunWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O
# 7F5OyJP4IWGbNOsFxl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZ
# Vu7Ke13jrclPXuU15zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4F
# fYj1gj4QkXCrVYJBMtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLm
# qaBn3aQnvKFPObURWBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMre
# Sx7nDmOu5tTvkpI6nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/ch
# srIRt7t/8tWMcCxBYKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+U
# DCEdslQpJYls5Q5SUUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xM
# dT9j7CFfxCBRa2+xq4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUb
# AgMBAAGjggE6MIIBNjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC0nFd
# ZEzfLmc/57qYrhwPTzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAO
# BgNVHQ8BAf8EBAMCAYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRw
# Oi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRz
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwRQYDVR0f
# BD4wPDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNz
# dXJlZElEUm9vdENBLmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcNAQEM
# BQADggEBAHCgv0NcVec4X6CjdBs9thbX979XB72arKGHLOyFXqkauyL4hxppVCLt
# pIh3bb0aFPQTSnovLbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP+fT3rDB6mouy
# XtTP0UNEm0Mh65ZyoUi0mcudT6cGAxN3J0TU53/oWajwvy8LpunyNDzs9wPHh6jS
# TEAZNUZqaVSwuKFWjuyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K2yCNNWAc
# AgPLILCsWKAOQGPFmCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4VC0nftg62fC2
# h5b9W9FcrBjDTZ9ztwGpn1eqXijiuZQwgga0MIIEnKADAgECAhANx6xXBf8hmS5A
# QyIMOkmGMA0GCSqGSIb3DQEBCwUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxE
# aWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMT
# GERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDAeFw0yNTA1MDcwMDAwMDBaFw0zODAx
# MTQyMzU5NTlaMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5j
# LjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNB
# NDA5NiBTSEEyNTYgMjAyNSBDQTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK
# AoICAQC0eDHTCphBcr48RsAcrHXbo0ZodLRRF51NrY0NlLWZloMsVO1DahGPNRcy
# bEKq+RuwOnPhof6pvF4uGjwjqNjfEvUi6wuim5bap+0lgloM2zX4kftn5B1IpYzT
# qpyFQ/4Bt0mAxAHeHYNnQxqXmRinvuNgxVBdJkf77S2uPoCj7GH8BLuxBG5AvftB
# dsOECS1UkxBvMgEdgkFiDNYiOTx4OtiFcMSkqTtF2hfQz3zQSku2Ws3IfDReb6e3
# mmdglTcaarps0wjUjsZvkgFkriK9tUKJm/s80FiocSk1VYLZlDwFt+cVFBURJg6z
# MUjZa/zbCclF83bRVFLeGkuAhHiGPMvSGmhgaTzVyhYn4p0+8y9oHRaQT/aofEnS
# 5xLrfxnGpTXiUOeSLsJygoLPp66bkDX1ZlAeSpQl92QOMeRxykvq6gbylsXQskBB
# BnGy3tW/AMOMCZIVNSaz7BX8VtYGqLt9MmeOreGPRdtBx3yGOP+rx3rKWDEJlIqL
# XvJWnY0v5ydPpOjL6s36czwzsucuoKs7Yk/ehb//Wx+5kMqIMRvUBDx6z1ev+7ps
# NOdgJMoiwOrUG2ZdSoQbU2rMkpLiQ6bGRinZbI4OLu9BMIFm1UUl9VnePs6BaaeE
# WvjJSjNm2qA+sdFUeEY0qVjPKOWug/G6X5uAiynM7Bu2ayBjUwIDAQABo4IBXTCC
# AVkwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQU729TSunkBnx6yuKQVvYv
# 1Ensy04wHwYDVR0jBBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/
# BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMIMHcGCCsGAQUFBwEBBGswaTAkBggr
# BgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVo
# dHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0
# LmNydDBDBgNVHR8EPDA6MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjAL
# BglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBABfO+xaAHP4HPRF2cTC9vgvI
# tTSmf83Qh8WIGjB/T8ObXAZz8OjuhUxjaaFdleMM0lBryPTQM2qEJPe36zwbSI/m
# S83afsl3YTj+IQhQE7jU/kXjjytJgnn0hvrV6hqWGd3rLAUt6vJy9lMDPjTLxLgX
# f9r5nWMQwr8Myb9rEVKChHyfpzee5kH0F8HABBgr0UdqirZ7bowe9Vj2AIMD8liy
# rukZ2iA/wdG2th9y1IsA0QF8dTXqvcnTmpfeQh35k5zOCPmSNq1UH410ANVko43+
# Cdmu4y81hjajV/gxdEkMx1NKU4uHQcKfZxAvBAKqMVuqte69M9J6A47OvgRaPs+2
# ykgcGV00TYr2Lr3ty9qIijanrUR3anzEwlvzZiiyfTPjLbnFRsjsYg39OlV8cipD
# oq7+qNNjqFzeGxcytL5TTLL4ZaoBdqbhOhZ3ZRDUphPvSRmMThi0vw9vODRzW6Ax
# nJll38F0cuJG7uEBYTptMSbhdhGQDpOXgpIUsWTjd6xpR6oaQf/DJbg3s6KCLPAl
# Z66RzIg9sC+NJpud/v4+7RWsWCiKi9EOLLHfMR2ZyJ/+xhCx9yHbxtl5TPau1j/1
# MIDpMPx0LckTetiSuEtQvLsNz3Qbp7wGWqbIiOWCnb5WqxL3/BAPvIXKUjPSxyZs
# q8WhbaM2tszWkPZPubdcMIIG7TCCBNWgAwIBAgIQCoDvGEuN8QWC0cR2p5V0aDAN
# BgkqhkiG9w0BAQsFADBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQs
# IEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5n
# IFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0ExMB4XDTI1MDYwNDAwMDAwMFoXDTM2MDkw
# MzIzNTk1OVowYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMu
# MTswOQYDVQQDEzJEaWdpQ2VydCBTSEEyNTYgUlNBNDA5NiBUaW1lc3RhbXAgUmVz
# cG9uZGVyIDIwMjUgMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBANBG
# rC0Sxp7Q6q5gVrMrV7pvUf+GcAoB38o3zBlCMGMyqJnfFNZx+wvA69HFTBdwbHwB
# SOeLpvPnZ8ZN+vo8dE2/pPvOx/Vj8TchTySA2R4QKpVD7dvNZh6wW2R6kSu9RJt/
# 4QhguSssp3qome7MrxVyfQO9sMx6ZAWjFDYOzDi8SOhPUWlLnh00Cll8pjrUcCV3
# K3E0zz09ldQ//nBZZREr4h/GI6Dxb2UoyrN0ijtUDVHRXdmncOOMA3CoB/iUSROU
# INDT98oksouTMYFOnHoRh6+86Ltc5zjPKHW5KqCvpSduSwhwUmotuQhcg9tw2YD3
# w6ySSSu+3qU8DD+nigNJFmt6LAHvH3KSuNLoZLc1Hf2JNMVL4Q1OpbybpMe46Yce
# NA0LfNsnqcnpJeItK/DhKbPxTTuGoX7wJNdoRORVbPR1VVnDuSeHVZlc4seAO+6d
# 2sC26/PQPdP51ho1zBp+xUIZkpSFA8vWdoUoHLWnqWU3dCCyFG1roSrgHjSHlq8x
# ymLnjCbSLZ49kPmk8iyyizNDIXj//cOgrY7rlRyTlaCCfw7aSUROwnu7zER6EaJ+
# AliL7ojTdS5PWPsWeupWs7NpChUk555K096V1hE0yZIXe+giAwW00aHzrDchIc2b
# Qhpp0IoKRR7YufAkprxMiXAJQ1XCmnCfgPf8+3mnAgMBAAGjggGVMIIBkTAMBgNV
# HRMBAf8EAjAAMB0GA1UdDgQWBBTkO/zyMe39/dfzkXFjGVBDz2GM6DAfBgNVHSME
# GDAWgBTvb1NK6eQGfHrK4pBW9i/USezLTjAOBgNVHQ8BAf8EBAMCB4AwFgYDVR0l
# AQH/BAwwCgYIKwYBBQUHAwgwgZUGCCsGAQUFBwEBBIGIMIGFMCQGCCsGAQUFBzAB
# hhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wXQYIKwYBBQUHMAKGUWh0dHA6Ly9j
# YWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFRpbWVTdGFtcGlu
# Z1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNydDBfBgNVHR8EWDBWMFSgUqBQhk5odHRw
# Oi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRUaW1lU3RhbXBp
# bmdSU0E0MDk2U0hBMjU2MjAyNUNBMS5jcmwwIAYDVR0gBBkwFzAIBgZngQwBBAIw
# CwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQBlKq3xHCcEua5gQezRCESe
# Y0ByIfjk9iJP2zWLpQq1b4URGnwWBdEZD9gBq9fNaNmFj6Eh8/YmRDfxT7C0k8FU
# FqNh+tshgb4O6Lgjg8K8elC4+oWCqnU/ML9lFfim8/9yJmZSe2F8AQ/UdKFOtj7Y
# MTmqPO9mzskgiC3QYIUP2S3HQvHG1FDu+WUqW4daIqToXFE/JQ/EABgfZXLWU0zi
# TN6R3ygQBHMUBaB5bdrPbF6MRYs03h4obEMnxYOX8VBRKe1uNnzQVTeLni2nHkX/
# QqvXnNb+YkDFkxUGtMTaiLR9wjxUxu2hECZpqyU1d0IbX6Wq8/gVutDojBIFeRlq
# AcuEVT0cKsb+zJNEsuEB7O7/cuvTQasnM9AWcIQfVjnzrvwiCZ85EE8LUkqRhoS3
# Y50OHgaY7T/lwd6UArb+BOVAkg2oOvol/DJgddJ35XTxfUlQ+8Hggt8l2Yv7roan
# cJIFcbojBcxlRcGG0LIhp6GvReQGgMgYxQbV1S3CrWqZzBt1R9xJgKf47CdxVRd/
# ndUlQ05oxYy2zRWVFjF7mcr4C34Mj3ocCVccAvlKV9jEnstrniLvUxxVZE/rptb7
# IRE2lskKPIJgbaP5t2nGj/ULLi49xTcBZU8atufk+EMF/cWuiC7POGT75qaL6vdC
# vHlshtjdNXOCIUjsarfNZzGCBTswggU3AgEBMHAwXDElMCMGA1UECgwcVGl0YW4g
# VGVjaG5vbG9naWVzIEludGVydmlldzEeMBwGCSqGSIb3DQEJARYPYXNpcG9zMUB1
# bWQuZWR1MRMwEQYDVQQDDApBcm9uIFNpcG9zAhARQxY3MBt6q0OE+hQHqmWqMAkG
# BSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJ
# AzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMG
# CSqGSIb3DQEJBDEWBBTSU1bIrxcgqHijZwVyJneRxBjm/zANBgkqhkiG9w0BAQEF
# AASCAQAqGuahpfy5LnwrgBVy7eH1fCsnwP4M4KWiN8v8EtWfRqyr+NNXGCICTN/f
# h0p9ZM75sj9irb+mEy3dfBv1CQt23bno/ro+wyXyOoGGee6I+FqjTT5egIWcSrZy
# my8wRhRnWEfkFjXDi0S1iEqHOCsT8UZ5EsEzK83M+yVmNvHEJ3lMKA4UxLK0UXis
# g1zw2MSq9n/G5zyp+JGv7CD6Ig5lVy4AApUKIda8hEIaCzNHRdKwoJj1zRSwzlx+
# 0hAjDSnf2VK6k+YZGjeAwv5RVcLnfqmIftIdl0K2wSAiCcmDGARrBeaOdZfuvUnV
# pPM2kVFN8VEn4PnnREk99K/xQsnmoYIDJjCCAyIGCSqGSIb3DQEJBjGCAxMwggMP
# AgEBMH0waTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEw
# PwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2
# IFNIQTI1NiAyMDI1IENBMQIQCoDvGEuN8QWC0cR2p5V0aDANBglghkgBZQMEAgEF
# AKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI1
# MDgxMTIwMjIzNlowLwYJKoZIhvcNAQkEMSIEIHu2ENkMtU/WMadxKUWuz2OaUM13
# nrFLrsQSDmYEAz8zMA0GCSqGSIb3DQEBAQUABIICACOLrvGsMUAUYVdNvZ/8qbaa
# nzwXgWMovLrBiPDVLkO5/FrkfhXkXEQB7IBg4QhZKCkUwT1/5TnX6FR3Bpla/2eD
# 3Q7fx5ad8IbRMmFaXHJznP24iW8vi2GRkL1RQdO5y/pXESNLl1VwqK6kjRcNJI0V
# HDr178bLmOaIInsyzWlDR4YOTaOeRF/fqIt2RT6rxy7M5PPvx4nUndKjnpkH5j5P
# YDp9bRCDCKXWnNLcVRgcFuzWUpC1ZvPMMC6vKn0ljstS6o5YlMUImerqQpEStllt
# j0fCv+eCQftiFkCxHCF2ZqVihkOO7rvq9emiW57T2WTEODyUKu3tnNipyaD9CMWD
# OZfhYpfPLaj7IhjOcAeVWW7hNNvGQdy6M4rZcE1vO7XZT7wraRrjXH3U0VDJrW+/
# qMwvLnLqbz4f8KVvZRfhJjr9C6S0dvLvM91ZAy+EiYXSLBhQ5Z5v2sejz2XG+fL+
# qDJyTi9xq8VuEgHelWdcmeug2mkneq949xrI9j0bwqb4JWtmltrR3TaBLPdjbn0G
# 8kYWlmVH2iUoRmQtRZ7XzROfMhaCFwZhWDsDqT4KvdEiSxUAeb//WyvInhe6udN9
# p3B5amLC+uVeAhKWs9NYWb6Adouh37+DU0D+PtTQbJGS2pUdJQScQlYW7Np3K2NR
# JMYQnu86Qb43YqHS0JMf
# SIG # End signature block
