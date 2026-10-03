# SFESWCSD-91 - seeds a Recurring Donation with 12 installments for testing
# OpportunityService.buildSuccessfulPaymentMilestoneTargets.
# Installments 3, 4 and 7 are set to Missed, all the others to Closed Won, one at a time: NPSP only
# creates the next installment Opportunity after the previous one is processed, so the script waits
# (polling every 5 seconds) for the RD's next open Pledged Opportunity (the installment number field
# is not reliable right after creation, so it is not used) before moving it on.
# WARNING: closing installments fires the real triggers, so milestone emails go to the Contact's email
# and Tasks go to the Donations_Calls queue.
# Usage: pwsh scripts/seedMilestoneRD.ps1 [-ContactId 003...] [-TargetOrg eth-sdx]
param(
    [string]$ContactId = '003du00000HQkocAAD',
    [string]$TargetOrg = 'eth-sdx',
    [int[]]$MissedInstallments = @(3, 4, 7),
    [int]$Installments = 12,
    # Resume on an existing Recurring Donation, starting at installment number -StartAt
    [string]$RdId,
    [int]$StartAt = 1,
    [int]$PollSeconds = 5,
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'

function Invoke-SfJson([string[]]$sfArgs) {
    # The CLI prints update warnings on stderr, which must not abort the script
    $ErrorActionPreference = 'Continue'
    $raw = & sf @sfArgs --target-org $TargetOrg --json 2>$null
    $parsed = $raw | ConvertFrom-Json
    if ($parsed.status -ne 0) { throw "sf $($sfArgs -join ' ') failed: $($parsed.message)" }
    return $parsed.result
}

$contact = $null
if (-not $RdId) { $contact = (Invoke-SfJson @('data', 'query', '-q', "SELECT Id, Name, AccountId FROM Contact WHERE Id = '$ContactId'")).records[0] }
if (-not $RdId -and -not $contact) { throw "Contact $ContactId not found" }

if (-not $RdId) {
    $today = (Get-Date).ToString('yyyy-MM-dd')
    $values = "Name='Milestone test $($contact.Name)' npe03__Contact__c='$ContactId' npe03__Organization__c='$($contact.AccountId)' " +
        "npe03__Amount__c=12 npe03__Installment_Period__c='Monthly' npsp__InstallmentFrequency__c=1 npsp__Day_of_Month__c='1' " +
        "npsp__PaymentMethod__c='Check' npsp__RecurringType__c='Open' npsp__StartDate__c=$today npe03__Date_Established__c=$today " +
        "Donor_Type__c='Individual' Donation_Type__c='Recurring Donation'"
    $RdId = (Invoke-SfJson @('data', 'create', 'record', '--sobject', 'npe03__Recurring_Donation__c', '--values', $values)).id
    Write-Host "Recurring Donation $RdId created"
}
$rdId = $RdId

$wonRun = 0
for ($n = $StartAt; $n -le $Installments; $n++) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $opp = $null
    while (-not $opp) {
        Start-Sleep -Seconds $PollSeconds
        $q = "SELECT Id FROM Opportunity WHERE npe03__Recurring_Donation__c = '$rdId' AND StageName = 'Pledged' ORDER BY CloseDate LIMIT 1"
        $opp = (Invoke-SfJson @('data', 'query', '-q', $q)).records | Select-Object -First 1
        if (-not $opp -and (Get-Date) -gt $deadline) { throw "Installment $n was not created within $TimeoutSeconds seconds" }
    }

    $stage = if ($MissedInstallments -contains $n) { 'Missed' } else { 'Closed Won' }
    Invoke-SfJson @('data', 'update', 'record', '--sobject', 'Opportunity', '--record-id', $opp.Id, '--values', "StageName='$stage'") | Out-Null

    $wonRun = if ($stage -eq 'Closed Won') { $wonRun + 1 } else { 0 }
    Write-Host ("Installment {0,2} -> {1,-10} {2}  (Closed Won run so far: {3})" -f $n, $stage, $opp.Id, $wonRun)
}

Write-Host "Done. Recurring Donation: $rdId"
Write-Host "Check DLE_Email_Log__c (What_Id__c = $rdId) and Tasks (WhatId = $rdId) for the milestones that fired."
