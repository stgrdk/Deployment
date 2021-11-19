#!/bin/bash
#set -x

function Get-AuthToken() {
    : '
    .SYNOPSIS
    Get Auth token for access to Microsoft Graph Api

    .DESCRIPTION
    The Get-AuthToken cmdlet connects to Microsoft Graph Api with ClientId, ClientSecret and Tenant name.
    Initial Author: Steffen Greve (atea.dk)
    The script is provided "AS IS" with no warrenties.

    .PARAMETER ClientId
    The application id is from the Azure AD Application registration.
    .PARAMENTER ClientSecret
    The client secret created within the above application.
    .PARAMETER TenantName
    The tenant domain name xxxx.onmicrosoft.com
    '
    ClientId=$1
    ClientSecret=$2
    TenantName=$3

    tokenResult=$(curl -sf -X "POST" "https://login.microsoftonline.com/$TenantName/oauth2/token" \
     -H 'Content-Type: application/x-www-form-urlencoded; charset=utf-8' \
     --data-urlencode "client_id=$ClientId" \
     --data-urlencode "client_secret=$ClientSecret" \
     --data-urlencode "Resource=https://graph.microsoft.com/" \
     --data-urlencode "grant_type=client_credentials")

     accessToken=$(echo "${tokenResult}" | jq -r '.access_token')
     echo "$accessToken"
}

function Get-DeviceShellScripts() {
    : '
    .SYNOPSIS
    Get all Intune Shell scripts and save them in specified folder.
    
    .DESCRIPTION
    The Get-DeviceShellScripts cmdlet downloads all Shell scripts from Intune to a specified folder.
    Initial Author: Steffen Greve (atea.dk)
    The script is provided "AS IS" with no warranties.
    
    .PARAMETER AccessToken
    The Access Token to communicate with Graph Api
    .PARAMETER FolderPath
    The folder where the script(s) are saved.
    .EXAMPLE
    Download all Intune Shell scripts to the specified folder
    Get-DeviceShellScripts $accessToken .\ShellScripts 
    '
    AccessToken=$1
    FolderPath=$2
    
    header='Content-Type: application/x-www-form-urlencoded; charset=utf-8'
    graphApiVersion="Beta"
    graphUrl="https://graph.microsoft.com/$graphApiVersion"

    results=$(curl -sf "$graphUrl/deviceManagement/deviceShellScripts" -H "Authorization: Bearer ${AccessToken}" -H 'Content-Type: application/x-www-form-urlencoded; charset=utf-8' | jq -r '.value[] | .id' )
    shellScripts=($results)

    for (( i=0; i<${#shellScripts[@]}; i++ )); do
        displayName=$(curl -sf "$graphUrl/deviceManagement/deviceShellScripts/${shellScripts[$i]}" -H "Authorization: Bearer ${AccessToken}" -H $header | jq -r '. | .displayName')
        fileName=$(curl -sf "$graphUrl/deviceManagement/deviceShellScripts/${shellScripts[$i]}" -H "Authorization: Bearer ${AccessToken}" -H $header | jq -r '. | .fileName')
        scriptContent=$(curl -sf "$graphUrl/deviceManagement/deviceShellScripts/${shellScripts[$i]}" -H "Authorization: Bearer ${AccessToken}" -H $header | jq -r '. | .scriptContent' | base64 -D)
        echo "Exporting $displayName to $FolderPath/$fileName"
        mkdir -p $FolderPath
        echo "$scriptContent" > "$FolderPath/$fileName"
    done
}

accessToken=$(Get-AuthToken "<ClientId>" "<ClientSecret>" "<TenantName>")
Get-DeviceShellScripts $accessToken "/path/to/export/ShellScripts"
