﻿
#User Inputs

$NSGName = Read-Host 'Specify the name of the NSG'
$NSGRG = Read-Host 'Specify the name of the NSG resource group'
$SubscriptionId = Read-Host 'Specify the susbcription ID'

#variables

$Locations = @("East Asia", "Southeast Asia", "Central India","South India","North Central US","North Europe","West Europe","East US","West US","South Central US","Central US","East US 2","Japan East","Japan West","Brazil South", "Australia East", "Australia Southeast", "Canada Central", "Canada East" ,"West Central US", "West US 2", "UK West", "UK South", "UK South 2", "UK North", "Korea Central", "Korea South")
$PublicIPlocations = @("asiaeast", "asiasoutheast", "indiacentral", "indiasouth", "usnorth", "europenorth", "europewest", "useast", "uswest", "ussouth", "uscentral", "useast2", "japaneast", "japanwest", "brazilsouth", "australiaeast", "australiasoutheast", "canadacentral", "canadaeast", "uswestcentral", "uswest2", "ukwest", "uksouth", "uksouth2", "uknorth", "koreacentral", "koreasouth")


$SourceLocation = $Locations| Out-GridView -OutputMode Single -Title "Select the source location where your virtual machines are running"
$TargetLocation = $Locations| Out-GridView -OutputMode Single -Title "Select the target location where your virtual machines will be replicated to"

$SourceLocationFormatted = $PublicIPlocations[$Locations.IndexOf($SourceLocation)]  


# Sign-in with Azure account credentials

Login-AzureRmAccount

# Select Azure Subscription

Select-AzureRmSubscription -SubscriptionId $SubscriptionId

$nsg = Get-AzureRmNetworkSecurityGroup -Name $NSGName -ResourceGroupName $NSGRG 

#Step 1 : Configure NSG rules for cache storage account access

        

        # Download the current Azure public IP range list

        $IPUri = "https://www.microsoft.com/en-in/download/confirmation.aspx?id=41653"

        $WebPage = Invoke-WebRequest -Uri $IPUri

        $xmlpage = ($WebPage.RawContent.Split('"') -like "https://*PublicIps*")[0]

        $Webresponse = Invoke-WebRequest -Uri $xmlpage

        # Get list of regions & public IP ranges

        [xml]$xml = [System.Text.Encoding]::UTF8.GetString($Webresponse.Content)


        $ipRange = ( $xml.AzurePublicIpAddresses.Region | where-object Name -In $SourceLocationFormatted ).IpRange


        # Build NSG rules


        $rulePriority = 2001


        ForEach ($subnet in $ipRange.Subnet) {

            $ruleName = "Site-Recovery-Cache-Storage-" + $subnet.Replace("/","-")
    
            $execute = $nsg | Add-AzureRmNetworkSecurityRuleConfig -Name $ruleName -Description "Allow outbound to Site recovery cache storage $subnet" -Access Allow -Protocol TCP -Direction Outbound -Priority $rulePriority -SourceAddressPrefix VirtualNetwork -SourcePortRange * -DestinationAddressPrefix "$subnet" -DestinationPortRange "443"


            $rulePriority++

        }



#Step 2 - Configure NSG rules for Office 365 Authentication access (login.microsoftonline.com)

        # Download the current Office 365 IP list

        $O365IPUri = "https://go.microsoft.com/fwlink/?LinkId=533185"

        $O365IPXML = Invoke-WebRequest -Uri $O365IPUri

        [xml]$O365IPXMLContent  = [xml]($O365IPXML.Content)


        $addresslist = ( $O365IPXMLContent.products.product | where-object Name -In "Identity" ).addresslist
        $IPV4addresslist = ($addresslist | where-object Type -In "IPv4").address

        # Build NSG rules


        $rulePriority = 2501


        ForEach ($address in $IPV4addresslist) {

            $ruleName = "Site-Recovery-Auth-" + $address.Replace("/","-")
    
            $execute = $nsg | Add-AzureRmNetworkSecurityRuleConfig -Name $ruleName -Description "Allow outbound to Site recovery authentication $address" -Access Allow -Protocol TCP -Direction Outbound -Priority $rulePriority -SourceAddressPrefix VirtualNetwork -SourcePortRange * -DestinationAddressPrefix "$address" -DestinationPortRange "443"


            $rulePriority++


        }

#Step 3 - Configure NSG rules for Site Recovery service endpoint access

        # Download the Site Recovery IP list

        $SRIPUri = "https://aka.ms/site-recovery-public-ips"

        $SRIPPage = Invoke-WebRequest -Uri $SRIPUri 


        [xml]$SiteRecoveryIPXML  = [xml][System.Text.Encoding]::UTF8.GetString($SRIPPage.Content)


        $SiteRecoveryIPs = ( $SiteRecoveryIPXML.SiteRecoveryIPAddresses.region | where-object Name -In $TargetLocation )

        $SiteRecoveryIPList = @($SiteRecoveryIPs.ServiceIP1, $SiteRecoveryIPs.MonitoringIP1)

        $rulePriority = 2800

        ForEach ($address in $SiteRecoveryIPList) {

            $ruleName = "Site-Recovery-Service-" + $address.Replace("/","-")
    
            $execute = $nsg | Add-AzureRmNetworkSecurityRuleConfig -Name $ruleName -Description "Allow outbound to Site recovery service $address" -Access Allow -Protocol TCP -Direction Outbound -Priority $rulePriority -SourceAddressPrefix VirtualNetwork -SourcePortRange * -DestinationAddressPrefix "$address" -DestinationPortRange "443"


            $rulePriority++


        }

$execute = $nsg | Set-AzureRmNetworkSecurityGroup   



# SIG # Begin signature block
# MIIaygYJKoZIhvcNAQcCoIIauzCCGrcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUWSpsvHqp0TEIoS6VJqwhrnef
# pcegghWDMIIEwzCCA6ugAwIBAgITMwAAALWsfW2HayYRRwAAAAAAtTANBgkqhkiG
# 9w0BAQUFADB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwHhcNMTYwOTA3MTc1ODQ0
# WhcNMTgwOTA3MTc1ODQ0WjCBszELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjENMAsGA1UECxMETU9QUjEnMCUGA1UECxMebkNpcGhlciBEU0UgRVNO
# OkI4RUMtMzBBNC03MTQ0MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApXwz2j7k2rDl
# 2QO9eyz1qUm3FyqD7dksbP5M3NCOq/j95vpOeHG2w0S1SyNmN8VEqjiHSeopO5b+
# VbOIbpqqG9PyfyDc0WdzIilufZOuwyZI15hI3uRgZ78E/cbljXUW5Me75jGGEOlr
# Gek41eOyGRUxkejFapqkiHCLxHSMHEpPdT95ylPhuLz7Bq01fsQSbclDoQye3EzO
# YFlqcFMYb3s61siEbpvKgf0qcQjPzAh3vsySXqzeeLc3Kzss74E9HDduQGO1ZZTZ
# FadL4bzwlgVhux25DZr0zqybZIBiy8/J9oyKCi2OuWLqxf+YgSWp0YMY9ktvKwGr
# VW7W8/UJVwIDAQABo4IBCTCCAQUwHQYDVR0OBBYEFIMd6iA083bzGHST2k2O6R6l
# XnyFMB8GA1UdIwQYMBaAFCM0+NlSRnAK7UD7dvuzK7DDNbMPMFQGA1UdHwRNMEsw
# SaBHoEWGQ2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3Rz
# L01pY3Jvc29mdFRpbWVTdGFtcFBDQS5jcmwwWAYIKwYBBQUHAQEETDBKMEgGCCsG
# AQUFBzAChjxodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY3Jv
# c29mdFRpbWVTdGFtcFBDQS5jcnQwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZI
# hvcNAQEFBQADggEBAAez+vxJWgDsgMtouMLKUcbt+zRbXcxWm2HmTU7rhIVVyh2E
# IFS5ebVknSGsKoR1/xlEmnMo3fHtvWaDRo/2qXIg1jMnOQp1d4wqFh9hKfnDeCQA
# 9tCnM8C/mYu3axXxKmyxJXDOm2MqcoZ9CBlmk96o/hzV9QWo5c+Y94j7qEYpGRPG
# 6Adqoc/HNxnce3Ik0ZlpbD8TbmbIjDORxQ3Jjbn3AGXBQ+smsInwWFzut2EwpGPC
# 2xWhLjXLdzJReIM1geh3oM/wti4zZ4w7hr4CvedMnU29OkcnoyMEUAQnZfB7PsXm
# adKxnklsJCsr1UOu7g/nwX5/mcw7R9G3RSvrI0EwggTtMIID1aADAgECAhMzAAAB
# eXwuV05S4crWAAEAAAF5MA0GCSqGSIb3DQEBBQUAMHkxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xIzAhBgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBMB4XDTE3MDgxMTIwMTExNVoXDTE4MDgxMTIwMTExNVowgYMxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xDTALBgNVBAsTBE1PUFIx
# HjAcBgNVBAMTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjCCASIwDQYJKoZIhvcNAQEB
# BQADggEPADCCAQoCggEBAKgp/tQQyP9VCp6ZAANSj9ywv/mr+FH+XIxUwifOTCuW
# 69uBHMuGK3nKdX64Z4Mmhr3WLxw+x1iqj2+V+1r8p8YbwcPoTBdOIj23W1Zcf9da
# 9S26u6YJvwZ87pj+QPkwuGv+QG90s7jWOEnJ0IcHLzHftrxOo9Cet2J7VnB1T2e/
# Bcyjrr4AksIbUKFhOxAAAbGG0CnzQPUP2aMPV6tjCajcqWrnR0OnvhXEPSek6FZS
# iM9ZmaEAhDab0DnSKg0v5gTivxOWiIOpUTcYQYni+YWdjmUaPQNkzMXeUHBd8guF
# qY+xReh3/4OdCbty4OZWCJW5K4MSiTH851hyHb35gyMCAwEAAaOCAWEwggFdMBMG
# A1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBT45H6NHGN8AKrMcwBK0/JtOKrN
# gTBSBgNVHREESzBJpEcwRTENMAsGA1UECxMETU9QUjE0MDIGA1UEBRMrMjI5ODAz
# KzFhYmY5ZTVmLWNlZDAtNDJlNi1hNjVkLWQ5MzUwOTU5ZmUwZTAfBgNVHSMEGDAW
# gBTLEejK0rQWWAHJNy4zFha5TJoKHzBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8v
# Y3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNDb2RTaWdQQ0Ff
# MDgtMzEtMjAxMC5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY0NvZFNpZ1BDQV8wOC0z
# MS0yMDEwLmNydDANBgkqhkiG9w0BAQUFAAOCAQEAb0trfoYN2AsmUGs6iMhaqfay
# 6iqZp+UGNEQB73P7rS/97fjVgGo1HDTHEwy1XmQ8c2uM8m/Tab7OOw+b+QVyPB1G
# 4eicPjaxbzWpplBUf+HUVz07HnpcjwE/dz9ecydX+qcw59Ryr4vfcSL9iuD64C3f
# X/Led2Tf2rAGAAmrRpCj9f6BhiyTK3XGESjX5YriHCerl4yaxOIHGdPyZBexK93z
# CHp4UIUGMhw5UKPNi3DeCNV7b0w/muh1beTLE1ccKVk4X75Fq6aayvkpns04z7nI
# Bbos+8Qlv2gN3w97QhqVx4+9WmuQC1H617fnj7KzMyhzA1x/o0aCnK22Nnd2hzCC
# BbwwggOkoAMCAQICCmEzJhoAAAAAADEwDQYJKoZIhvcNAQEFBQAwXzETMBEGCgmS
# JomT8ixkARkWA2NvbTEZMBcGCgmSJomT8ixkARkWCW1pY3Jvc29mdDEtMCsGA1UE
# AxMkTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5MB4XDTEwMDgz
# MTIyMTkzMloXDTIwMDgzMTIyMjkzMloweTELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEjMCEGA1UEAxMaTWljcm9zb2Z0IENvZGUgU2lnbmluZyBQ
# Q0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCycllcGTBkvx2aYCAg
# Qpl2U2w+G9ZvzMvx6mv+lxYQ4N86dIMaty+gMuz/3sJCTiPVcgDbNVcKicquIEn0
# 8GisTUuNpb15S3GbRwfa/SXfnXWIz6pzRH/XgdvzvfI2pMlcRdyvrT3gKGiXGqel
# cnNW8ReU5P01lHKg1nZfHndFg4U4FtBzWwW6Z1KNpbJpL9oZC/6SdCnidi9U3RQw
# WfjSjWL9y8lfRjFQuScT5EAwz3IpECgixzdOPaAyPZDNoTgGhVxOVoIoKgUyt0vX
# T2Pn0i1i8UU956wIAPZGoZ7RW4wmU+h6qkryRs83PDietHdcpReejcsRj1Y8wawJ
# XwPTAgMBAAGjggFeMIIBWjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTLEejK
# 0rQWWAHJNy4zFha5TJoKHzALBgNVHQ8EBAMCAYYwEgYJKwYBBAGCNxUBBAUCAwEA
# ATAjBgkrBgEEAYI3FQIEFgQU/dExTtMmipXhmGA7qDFvpjy82C0wGQYJKwYBBAGC
# NxQCBAweCgBTAHUAYgBDAEEwHwYDVR0jBBgwFoAUDqyCYEBWJ5flJRP8KuEKU5VZ
# 5KQwUAYDVR0fBEkwRzBFoEOgQYY/aHR0cDovL2NybC5taWNyb3NvZnQuY29tL3Br
# aS9jcmwvcHJvZHVjdHMvbWljcm9zb2Z0cm9vdGNlcnQuY3JsMFQGCCsGAQUFBwEB
# BEgwRjBEBggrBgEFBQcwAoY4aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9j
# ZXJ0cy9NaWNyb3NvZnRSb290Q2VydC5jcnQwDQYJKoZIhvcNAQEFBQADggIBAFk5
# Pn8mRq/rb0CxMrVq6w4vbqhJ9+tfde1MOy3XQ60L/svpLTGjI8x8UJiAIV2sPS9M
# uqKoVpzjcLu4tPh5tUly9z7qQX/K4QwXaculnCAt+gtQxFbNLeNK0rxw56gNogOl
# VuC4iktX8pVCnPHz7+7jhh80PLhWmvBTI4UqpIIck+KUBx3y4k74jKHK6BOlkU7I
# G9KPcpUqcW2bGvgc8FPWZ8wi/1wdzaKMvSeyeWNWRKJRzfnpo1hW3ZsCRUQvX/Ta
# rtSCMm78pJUT5Otp56miLL7IKxAOZY6Z2/Wi+hImCWU4lPF6H0q70eFW6NB4lhhc
# yTUWX92THUmOLb6tNEQc7hAVGgBd3TVbIc6YxwnuhQ6MT20OE049fClInHLR82zK
# wexwo1eSV32UjaAbSANa98+jZwp0pTbtLS8XyOZyNxL0b7E8Z4L5UrKNMxZlHg6K
# 3RDeZPRvzkbU0xfpecQEtNP7LN8fip6sCvsTJ0Ct5PnhqX9GuwdgR2VgQE6wQuxO
# 7bN2edgKNAltHIAxH+IOVN3lofvlRxCtZJj/UBYufL8FIXrilUEnacOTj5XJjdib
# Ia4NXJzwoq6GaIMMai27dmsAHZat8hZ79haDJLmIz2qoRzEvmtzjcT3XAH5iR9HO
# iMm4GPoOco3Boz2vAkBq/2mbluIQqBC0N1AI1sM9MIIGBzCCA++gAwIBAgIKYRZo
# NAAAAAAAHDANBgkqhkiG9w0BAQUFADBfMRMwEQYKCZImiZPyLGQBGRYDY29tMRkw
# FwYKCZImiZPyLGQBGRYJbWljcm9zb2Z0MS0wKwYDVQQDEyRNaWNyb3NvZnQgUm9v
# dCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkwHhcNMDcwNDAzMTI1MzA5WhcNMjEwNDAz
# MTMwMzA5WjB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwggEiMA0GCSqGSIb3DQEB
# AQUAA4IBDwAwggEKAoIBAQCfoWyx39tIkip8ay4Z4b3i48WZUSNQrc7dGE4kD+7R
# p9FMrXQwIBHrB9VUlRVJlBtCkq6YXDAm2gBr6Hu97IkHD/cOBJjwicwfyzMkh53y
# 9GccLPx754gd6udOo6HBI1PKjfpFzwnQXq/QsEIEovmmbJNn1yjcRlOwhtDlKEYu
# J6yGT1VSDOQDLPtqkJAwbofzWTCd+n7Wl7PoIZd++NIT8wi3U21StEWQn0gASkdm
# EScpZqiX5NMGgUqi+YSnEUcUCYKfhO1VeP4Bmh1QCIUAEDBG7bfeI0a7xC1Un68e
# eEExd8yb3zuDk6FhArUdDbH895uyAc4iS1T/+QXDwiALAgMBAAGjggGrMIIBpzAP
# BgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBQjNPjZUkZwCu1A+3b7syuwwzWzDzAL
# BgNVHQ8EBAMCAYYwEAYJKwYBBAGCNxUBBAMCAQAwgZgGA1UdIwSBkDCBjYAUDqyC
# YEBWJ5flJRP8KuEKU5VZ5KShY6RhMF8xEzARBgoJkiaJk/IsZAEZFgNjb20xGTAX
# BgoJkiaJk/IsZAEZFgltaWNyb3NvZnQxLTArBgNVBAMTJE1pY3Jvc29mdCBSb290
# IENlcnRpZmljYXRlIEF1dGhvcml0eYIQea0WoUqgpa1Mc1j0BxMuZTBQBgNVHR8E
# STBHMEWgQ6BBhj9odHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9k
# dWN0cy9taWNyb3NvZnRyb290Y2VydC5jcmwwVAYIKwYBBQUHAQEESDBGMEQGCCsG
# AQUFBzAChjhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY3Jv
# c29mdFJvb3RDZXJ0LmNydDATBgNVHSUEDDAKBggrBgEFBQcDCDANBgkqhkiG9w0B
# AQUFAAOCAgEAEJeKw1wDRDbd6bStd9vOeVFNAbEudHFbbQwTq86+e4+4LtQSooxt
# YrhXAstOIBNQmd16QOJXu69YmhzhHQGGrLt48ovQ7DsB7uK+jwoFyI1I4vBTFd1P
# q5Lk541q1YDB5pTyBi+FA+mRKiQicPv2/OR4mS4N9wficLwYTp2OawpylbihOZxn
# LcVRDupiXD8WmIsgP+IHGjL5zDFKdjE9K3ILyOpwPf+FChPfwgphjvDXuBfrTot/
# xTUrXqO/67x9C0J71FNyIe4wyrt4ZVxbARcKFA7S2hSY9Ty5ZlizLS/n+YWGzFFW
# 6J1wlGysOUzU9nm/qhh6YinvopspNAZ3GmLJPR5tH4LwC8csu89Ds+X57H2146So
# dDW4TsVxIxImdgs8UoxxWkZDFLyzs7BNZ8ifQv+AeSGAnhUwZuhCEl4ayJ4iIdBD
# 6Svpu/RIzCzU2DKATCYqSCRfWupW76bemZ3KOm+9gSd0BhHudiG/m4LBJ1S2sWo9
# iaF2YbRuoROmv6pH8BJv/YoybLL+31HIjCPJZr2dHYcSZAI9La9Zj7jkIeW1sMpj
# tHhUBdRBLlCslLCleKuzoJZ1GtmShxN1Ii8yqAhuoFuMJb+g74TKIdbrHk/Jmu5J
# 4PcBZW+JC33Iacjmbuqnl84xKf8OxVtc2E0bodj6L54/LlUWa8kTo/0xggSxMIIE
# rQIBATCBkDB5MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSMw
# IQYDVQQDExpNaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQQITMwAAAXl8LldOUuHK
# 1gABAAABeTAJBgUrDgMCGgUAoIHKMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEE
# MBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQ4
# z33/nkrPuD1iy8x2Fnmt7+cAzjBqBgorBgEEAYI3AgEMMVwwWqA8gDoATQBpAGMA
# cgBvAHMAbwBmAHQAIABBAHoAdQByAGUAIABTAGkAdABlACAAUgBlAGMAbwB2AGUA
# cgB5oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTANBgkqhkiG9w0BAQEFAASC
# AQAPU0JJyOQP4z3Md0G0b9O1a32vlTmApH/AUgwMDcrkiy6yBzNFtNZwMCILNE/1
# pAr7tzhBUcPJ1WPr+KqZ62Bt1k6NWIvUBTcHIAHtJsy9XjqrcTIOlQkQ9A7vfrZg
# LoDqDsw4Xx03oPHX8vl1PHV5ocb5q7mZnqLAKyS3lGDNdDSLZV1PMU78gqWrdWcc
# wEKmbRGK0M5fkcPznjOp6kco6eMonP41etu1V+kYvtDo38RcAb6dXhcF/eP6dZbS
# F3bJYoXjEQ+gCZO09MccPADzHKRCVzE/Qt2Yn5hygM+FzlN0oPMfcRNk8Bq3VWJq
# 42JXDR4qv6Fb2PqP17YIfvr8oYICKDCCAiQGCSqGSIb3DQEJBjGCAhUwggIRAgEB
# MIGOMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xITAfBgNV
# BAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQQITMwAAALWsfW2HayYRRwAAAAAA
# tTAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG
# 9w0BCQUxDxcNMTcwODI4MDUzMzA4WjAjBgkqhkiG9w0BCQQxFgQUscfGis43HHJq
# lJATdlMnxQ/V8OMwDQYJKoZIhvcNAQEFBQAEggEAEN8veGKYlS1Kcew4K5zLPXMA
# hfxIJ4VVfSk7zK9UtY/okt/BN3eLgN1hp90R5sYB0JKUfcg8/nUTJNUOljBamPU/
# C9rkE7OVwYPJCUP3LGMDhM9piPWAex1zy9ea2HK9S17JInHnuLtaiTtwCDw0QtMg
# m9mk24W0MpA7Z3oRS2CLmgxw9u/xVZkaLy2TqC54+RvCn0ZQaB8Xb41BcLAyp0FP
# z9KPJhE6yfNPvVbqA25oUFKdbnwOLT5q8VpOQMKrYtnvfBmIRPr1kOLXYv/CauzI
# vxUgRdhXr4611RQalsuh/Kd3bUSAy9wIaptmaYoR1pn39+Vsl6OU7sCSAbglTQ==
# SIG # End signature block
