<#
.SYNOPSIS
    Quick export of Hewalex PCWU registers to raw Home Assistant MQTT discovery entities.
.DESCRIPTION
    Parses hewalex_geco/devices/pcwu.py and emits a raw YAML file for Home Assistant MQTT discovery.
    This is a small helper; output still requires manual formatting/validation before use.
.PARAMETER WorkingDir
    Root working directory (defaults to the parent of the script folder).
.PARAMETER EntityNamePrefix
    Optional prefix for entity names.
.PARAMETER EntityIdPrefix
    Prefix for entity IDs (default 'heatpump_hewalex').
.PARAMETER MqttTopicPrefix
    MQTT topic root (default 'heatpump/hewalex').
.PARAMETER OutputFile
    Path to write the formatted YAML (defaults to homeassistant\hewalex_raw_mqtt_entities.yaml under WorkingDir).
.PARAMETER InstallYamlModule
    If set, attempt to install powershell-yaml when missing.
.EXAMPLE
    .\Get-Entities.ps1
#>

param(
    [Parameter(Position=0)]
    [string]$WorkingDir = (Get-Item -Path $PSScriptRoot).Parent.FullName,

    [string]$EntityNamePrefix = '',
    [string]$EntityIdPrefix = 'heatpump_hewalex',
    [string]$MqttTopicPrefix = 'heatpump/hewalex',

    [string]$OutputFile = $null,

    [bool]$InstallYamlModule = $true
)

# Resolve working directory and default output paths
$workingDirItem = Get-Item -Path $WorkingDir
if (-not $OutputFile) { $OutputFile = Join-Path $workingDirItem.FullName 'homeassistant\hewalex_raw_mqtt_entities.yaml' }

# load source file
$pcwuContent = Get-Content -Path (Join-Path $workingDirItem.FullName 'hewagate\hewalex_geco\devices\pcwu.py')

$deviceIdentifier = @{
    identifiers = @($entityIdPrefix)
    name = "Hewalex Heatpump"
}

# Regex to find register lines
$registryRegex = '^\s+(?<number>\d{3}: (?<registerProperties>.+)),'
$addNextLine = $false

$pcwuRegisters = @()
# Loop through every line
foreach($line in $pcwuContent) {
    # Find related entries
    if($line -match $registryRegex -or $addNextLine){
        # Check if next line is part of previous line
        if($addNextLine) {
            # Add next line
            $registerObject += ($line -Replace('#.*','') -Replace('None,','')).Trim()
            if($registerObject.Endswith('},')) {
                $registerObject = $registerObject.Replace('},', '}')
            }
        }
        else {
            # Treat as first line
            $registerObject = (($Matches.registerProperties) -Replace('#.*','') -Replace('None,','')).Trim()
        }
        
        # Check if line ends here
        if($registerObject.Endswith('}')) {
            # If so, add this entry to the list
            Write-Host "Adding register: $registerObject"
            $pcwuRegisters += $registerObject | ConvertFrom-Json
            $addNextLine = $false
        }
        else {
            #Read-Host "Continue?"
            $registerObject
            # Line not ended yet, continue to next line
            $addNextLine = $true
        }
    }
}

$entities = @()
foreach($register in $pcwuRegisters) {
    switch($register.type) {
        'te10' { 
            $entity = [PSCustomObject]@{
                name = "$entityNamePrefix $($register.desc)"
                command_topic = "$mqttTopicPrefix/Command/$($register.name)"
                state_topic = "$mqttTopicPrefix/$($register.name)"
                unit_of_measurement = "°C"
                min = 0
                max = 100
                unique_id = "$($entityIdPrefix)_$($register.name)"
                deviceClass = 'temperature'
                stateClass = 'measurement'
                icon = 'mdi:thermometer'
                device = $deviceIdentifier
            }   
        }
        'bool' {
            $entity = [PSCustomObject]@{
                name = "$entityNamePrefix $($register.desc)"
                command_topic = "$mqttTopicPrefix/Command/$($register.name)"
                state_topic = "$mqttTopicPrefix/$($register.name)"
                payload_on = "True"
                payload_off = "False"
                state_on = "True"
                state_off = "False"
                unique_id = "$($entityIdPrefix)_$($register.name)"
                device = $deviceIdentifier
            }   
        }
        default {
            $entity = [PSCustomObject]@{
                name = "$entityNamePrefix $($register.desc)"
                command_topic = "$mqttTopicPrefix/Command/$($register.name)"
                state_topic = "$mqttTopicPrefix/$($register.name)"
                unit_of_measurement = "°C"
                unique_id = "$($entityIdPrefix)_$($register.name)"
                deviceClass = 'temperature'
                stateClass = 'measurement'
                icon = 'mdi:thermometer'
                device = $deviceIdentifier
            }   
        }
    }
    $entities += $entity
}

if(-not (Get-Module -Listavailable -Name powershell-yaml) and $InstallYamlModule){
    Install-Module -Name powershell-yaml -Scope CurrentUser -Force
}

$yamlConfig = $entities | ConvertTo-Yaml
Write-Host "----- Home Assistant MQTT Discovery Entities -----"
Write-Host $yamlConfig

Write-Host "Writing to file: $($workingDir.Fullname)\homeassistant\hewalex_mqtt_entities.yaml"
$yamlConfig | Out-File -FilePath "$($workingDir.Fullname)\homeassistant\hewalex_raw_mqtt_entities.yaml" -Encoding utf8