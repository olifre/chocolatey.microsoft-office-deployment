﻿# microsoft-office-deployment install

$ErrorActionPreference = 'Stop';
$PackageParameters = Get-PackageParameters

$toolsDir = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"
$urlPackage = 'https://download.microsoft.com/download/6c1eeb25-cf8b-41d9-8d0d-cc1dbc032140/officedeploymenttool_18827-20140.exe'
$checksumPackage = 'ba03f9fce68bc472c96343cff9ce08a213f95fb5fd7c1b8ca6e0608377bf3b9b932e9e206209265965d5bfe4fe88f76dcd5676259d5aa237ca8b702b5e998e51'
$checksumTypePackage = 'SHA512'

$binDir = "$($toolsDir)\..\bin"
$logDir = "$($toolsDir)\..\logs"

$arch = 32
$sharedMachine = 0
$languages = "MatchOS"
$products = "HomeBusinessRetail" 
$updates = "TRUE"
$ProofingToolLanguages =@()

if ($PackageParameters) {

    if ($PackageParameters["XMLfile"]) {
        Write-Host "Installing using XMLfile."
        if (test-path $PackageParameters["XMLfile"]) {
            $installConfigData = Get-Content $PackageParameters["XMLfile"]
        }
        else {
            throw (new-object System.IO.FileNotFoundException)
        }
    }
    else {

        if ($PackageParameters["64bit"]) {
            Write-Host "Installing 64-bit version."
            $arch = 64
        }
        else {
            Write-Host "Installing 32-bit version."
        }

        if ($PackageParameters["DisableUpdate"]) {
            Write-Host "Update Disabled"
            $updates = "FALSE"
        }
        if ($PackageParameters["RemoveMSI"]) {
            Write-Host "Removing existing MSI versions of Office."
        }
    
        if ($PackageParameters["Shared"]) {
            Write-Host "Installing with Shared Computer Licensing for Remote Desktop Services."
            $sharedMachine = 1
        }

        if ($PackageParameters["Channel"]) {
            Write-Host "The following update channel has been selected $($PackageParameters["Channel"])"
            $channel = $PackageParameters["Channel"]
        }

        if ($PackageParameters["Language"]) {
            $languages = $PackageParameters["Language"].split(",")
            foreach ($language in $languages) {
                if (Get-Content "$($toolsDir)\lists\languagesList.txt" | Select-String $language) {
                    Write-Host "Installing language variant $($language)" 
                }
            }
        }

        if ($PackageParameters["ProofingToolLanguage"]) {
            $ProofingToolLanguages = $PackageParameters["ProofingToolLanguage"].split(",")
            foreach ($language in $ProofingToolLanguages) {
                if (Get-Content "$($toolsDir)\lists\ProofLanguagesList.txt" | Select-String $language) {
                    Write-Host "Installing Proofing Tools language variant $($language)"                 
                }
                else {
                    if ($ProofingToolLanguages.Count -gt 1 ) {
                        Write-Warning "$($language) not found"
                        $ProofingToolLanguages = $ProofingToolLanguages -ne $language
                    } else {
                        Write-Warning "$($language) not found. No proofing tool language will be installed."
                        $ProofingToolLanguages = @()
                    }
                }
            }
        }
            
        if ($PackageParameters["LicenseKey"]) {
            $pidkey = $PackageParameters["LicenseKey"]
            Write-Host "Installing with a License Key"
        }

        if ($PackageParameters["Product"]) {        
            $products = $PackageParameters["Product"].split(",")
            foreach ($product in $products) {
                if (Get-Content "$($toolsDir)\lists\officeList.txt" | Select-String $product) {
                    Write-Host "Installation Product $($product)"                 
                }
                else {
                    if ($products.Count -gt 1 ) {
                        Write-Warning "$($product) not found"
                        $products = $products -ne $product
                    }
                    else {
                        Write-Warning "$($product) not found we installed HomeBusinessRetail"
                        $products = "HomeBusinessRetail"
                    }              
                }
            }
        }

        if ($PackageParameters["Exclude"]) {        
            $excludes = $PackageParameters["Exclude"].split(",")
            foreach ($exclude in $excludes) {
                if (Get-Content "$($toolsDir)\lists\excludeList.txt" | Select-String $exclude) {
                    Write-Host "Excluded $($exclude)"                 
                }
                else {
                    if ($excludes.Count -gt 1 ) {
                        Write-Warning "$($exclude) not found"
                        $excludes = $excludes -ne $exclude
                    }            
                }
            }
        }
    }

}
else {
    Write-Debug "No Package Parameters Passed in"
    Write-Host "Installing 32-bit version."
    Write-Host "Installing language variant $languages."
    Write-Host "Installation Product $product"
}

Import-Module -Name "$($toolsDir)\helpers.ps1"

$packageArgs = @{
    packageName    = 'Office-Deployment-Tool'
    fileType       = 'EXE'
    url            = $urlPackage
    checksum       = $checksumPackage
    checksumType   = $checksumTypePackage
    silentArgs     = "/extract:$($binDir) /log:$($logDir)\Office-Deployment-Tool.log /quiet /norestart"
    validExitCodes = @(
        0, # success
        3010, # success, restart required
        2147781575, # pending restart required
        2147205120  # pending restart required for setup update
    )
}

Install-ChocolateyPackage @packageArgs
if (!($installConfigData)) {
    $installConfigData = @"
<Configuration>
    $(
        if($channel -ne $null){ 
    "<Add OfficeClientEdition=""$($arch)"" Channel=""$($channel)"">"
        } else {
    "<Add OfficeClientEdition=""$($arch)"">"
        }
    )
    $(
        foreach($product in $products) {
            if($pidkey -ne $null){
"`r`n       <Product ID=""$($product)"" PIDKEY=""$($pidkey)"">"
            }
            else {
"`r`n       <Product ID=""$($product)"">" }
        foreach($language in $languages) {
"`r`n           <Language ID=""$($language)"" />"

        }
        foreach($exclude in $excludes) {
"`r`n           <ExcludeApp ID=""$($exclude)"" />"

        }
"`r`n       </Product>"
        }
        if ($ProofingToolLanguages.Count -gt 0)
        {
"`r`n       <Product ID=""ProofingTools"">"
            foreach($prooflanguage in $ProofingToolLanguages) {
"`r`n           <Language ID=""$($prooflanguage)"" />"

            }
"`r`n       </Product>"
        }
    )
    </Add>  
    $(
        if($channel -ne $null){ 
    "<Updates Enabled=""$($updates)"" Channel=""$($channel)"" />"
        } else  {
    "<Updates Enabled=""$($updates)"" />"
        }
    )
    $(
        if($PackageParameters["RemoveMSI"]){
            "<RemoveMSI />"
        }
    )
    <Display Level="None" AcceptEULA="TRUE" />  
    <Logging Level="Standard" Path="$logDir" /> 
    <Property Name="SharedComputerLicensing" Value="$sharedMachine" />  
</Configuration>
"@
}
 
$uninstallConfigData = @"
<Configuration>
    <Remove>
    $(
        foreach($product in $products) {
"`r`n       <Product ID=""$($product)"">"
"`r`n       </Product>"
        }
        if ($ProofingToolLanguages.Count -gt 0)
        {
"`r`n       <Product ID=""ProofingTools"">"
"`r`n       </Product>"
        }
    )
    </Remove>
    <Display Level="None" AcceptEULA="TRUE" />  
    <Logging Level="Standard" Path="$logDir" /> 
    <Property Name="FORCEAPPSHUTDOWN" Value="True" />
</Configuration>
"@

$installConfigData | Out-File "$($binDir)\Install.xml"
$uninstallConfigData | Out-File "$($binDir)\Uninstall.xml"
 
$packageArgs = @{
    packageName    = $env:ChocolateyPackageName
    fileType       = 'EXE'
    file           = "$($binDir)\setup.exe"
    checksum       = 'C0CE754C373D1DC7161A3706AEED1C895B9A678AE3C0BE131590F593E4D43F66'
    checksumType   = 'sha256'
    silentArgs     = "/configure $($binDir)\Install.xml"
    validExitCodes = @(
        0, # success
        3010, # success, restart required
        2147781575, # pending restart required
        2147205120  # pending restart required for setup update
    )
}

Install-ChocolateyInstallPackage @packageArgs
