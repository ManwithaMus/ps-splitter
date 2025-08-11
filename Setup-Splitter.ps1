<#
.DESCRIPTION
    File Splitter setup script
.NOTES
    Author: giuseppe.strafforello@titantechnologies.com
    Modified By: asipos1@umd.edu
    Version: 1.0
    Requires: PowerShell 3.0 or higher
    Copyright (C) 2025 Titan Technologies. All rights reserved.
    This script is licensed under the Apache License, Version 2.0.
#>

# Run as Administrator
try {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $adminRole = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if (-not $adminRole.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script must be run as an administrator."
    }
} catch {
    Write-Error $_.Exception.Message
    exit 1
}

try {
    $ModulePath = "C:\Program Files\WindowsPowerShell\Modules\FileSplitter"
    New-Item -ItemType Directory -Path $ModulePath -Force
    Copy-Item "Split-File.psm1" $ModulePath
    New-ModuleManifest -Path "$ModulePath\FileSplitter.psd1" -RootModule "Split-File.psm1" -Description "File splitting utility"

    Write-Host "FileSplitter module installed to $ModulePath" -ForegroundColor Green
    Write-Host "You can now use the Split-File cmdlet to split files." -ForegroundColor Green
    Write-Host "Run 'Import-Module FileSplitter' to use the cmdlet in your current session." -ForegroundColor Green
    Write-Host "To make it permanent, add 'Import-Module FileSplitter' to your PowerShell profile." -ForegroundColor Green
    Write-Host "Example usage: Split-File -InputFile 'C:\path\to\your\file.txt' -ChunkSize '100MB' -OutputDirectory 'C:\path\to\output'" -ForegroundColor Green
} catch {
    Write-Error "Failed to set up FileSplitter module: $_"
    exit 1
}
# SIG # Begin signature block
# MIIFlAYJKoZIhvcNAQcCoIIFhTCCBYECAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUyXmGNI+a9WwV6f9eCteXcGfr
# xeygggMiMIIDHjCCAgagAwIBAgIQG+y85FDshr5DK71RaSe6WjANBgkqhkiG9w0B
# AQsFADAnMSUwIwYDVQQDDBxUaXRhbiBUZWNobm9sb2dpZXMgSW50ZXJ2aWV3MB4X
# DTI1MDgxMTE2MzYzM1oXDTI2MDgxMTE2NTYzM1owJzElMCMGA1UEAwwcVGl0YW4g
# VGVjaG5vbG9naWVzIEludGVydmlldzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
# AQoCggEBAMdotUjXNFZEFKVchjH1+pbUx1iqCy4EKQ2VD6gjZFxpL737cJzBx3A8
# 1mcyzGU6rQdhCC/JhZrI4nA65/o9lhpYBx2eHm8TMNOuSRPYbMURRrbj0cyfil1Q
# 3d4ZK1zSOs2nhYMI5JnFJQ6UPYCefvnJBlItAQ7g12doWmbwn4OcFxvjphC6UbaG
# W1zWdMTDl0iOv7zpJfWwnQ79qNr/ijworJ7LN+Qt0iEYsFVLsUxpx7CFIt4IOaxF
# u+TlcgEa42TyboDrgLT7/rECEAXMA6OsNiz4Wc5l3K5n0r3OzNeK39oemF3UbmpN
# FdXG+bOr0C9QXueeSwHTPcwKIqW2Dw0CAwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeA
# MBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBRNxh54jD1ZpzvxjP/ST5lm
# azkN4DANBgkqhkiG9w0BAQsFAAOCAQEAoLRNXqNzCKL0nUv63q6EooQgYNRWtz7B
# 8VEsfHRjIs+WnmWNGvLGC84ILFzOUBoHdWJzWrRGEJNH/n7ECMam5hH/JOI9veJl
# R2lFoTwrhSkErP2weaLYHo1K/dvxIXINB3Fo83I/7Rxbs4zzCuxpg8gTZyittMpK
# dhZyuSXEI34x8oMorNpebB8PNkB8e41wLQpVIYjYk1wi7ypyYILCmNLdjsxQNa+L
# t77PUWHwmtOlMIf6n9hif6TFebCWxc5FBdY0QzS8xHecjAD1FWaQaiVzB4pRVF/l
# llKng2c8qLWts7piGilJJuhCPUUhZMr56LTBOD4DLM4cpk3+Z68F2DGCAdwwggHY
# AgEBMDswJzElMCMGA1UEAwwcVGl0YW4gVGVjaG5vbG9naWVzIEludGVydmlldwIQ
# G+y85FDshr5DK71RaSe6WjAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAig
# AoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgEL
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUAWc8tfb1Wx4vROInLDga
# qB2Zt+AwDQYJKoZIhvcNAQEBBQAEggEApXbRIf9wB1qEqvSgDVZHkCukT8De0pN5
# pv70lSDgNQV1aqOGStJANY+4FsEjqShuHGPso3mOziork3jJXBxGtxGUSstvaaUi
# l8q9k4AjkdNgegY/9YgSnZ+KL64KZh88hNnixbu68D1QROHhLwCLrIlgWngV5c1T
# ql4EGvKLQMC/5MuhzvOAYl6WRE91nBuC0jaAJFtNByECHi960NUd4CiTttoorX0E
# U+3EgVO5mu9PwzqYAmqQQwcTL6ESIFLIn79cqkF9RydLCyEXJevGIolE5VdWxmcM
# WL9kIDv4j8fkuM6RHfB8fNcfohIq3cE2eK0JWjfSTIS88JW5WAOQuw==
# SIG # End signature block
