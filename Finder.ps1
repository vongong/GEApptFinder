
$SchedulerUriBase = "https://ttp.cbp.dhs.gov/schedulerapi/slot-availability?locationId={{Code}}"
$SiteCodeFilePath = ".\SiteCodes.json"
$histFileTemplate = ".\SiteCodesHist{{value}}.json"
$histFile1 = $histFileTemplate.Replace("{{value}}","-1")
$histFile = $histFileTemplate.Replace("{{value}}","")

Write-Host "Global Entry Appointment Finder"
Write-Host "Loading Site List"
if (-not (Test-Path -Path $SiteCodeFilePath -PathType Leaf)) {    
    $msg = "Can't find $SiteCodeFilePath"
    Write-Error $msg
    throw $msg
}
$SiteCodes = Get-Content -Path $SiteCodeFilePath | ConvertFrom-Json -AsHashtable
# Make backup
$SiteCodesPrior = @{}
if (Test-Path -Path $histFile -PathType Leaf) {    
    Write-Host "Loading History"
    $SiteCodesPrior = Get-Content -Path $histFile | ConvertFrom-Json -AsHashtable
    Copy-Item -Path $histFile -Destination $histFile1 -Force
}
$SiteCodesHist = @{}

Write-Host "Processing List"
foreach ($sitekey in $siteCodes.Keys) {
    $siteCode = $SiteCodes[$sitekey]
    $SchedulerUri = $SchedulerUriBase.Replace("{{Code}}",$siteCode)
    $resp = Invoke-WebRequest -Uri $SchedulerUri
    $rJson = $resp.Content | ConvertFrom-Json
    Write-Host "  $sitekey`: " -NoNewline -ForegroundColor White
    if ($rJson.availableSlots.Length -eq 0) {
        $msg = "No Available Slots"
        Write-Host $msg
    } else {                        
        $fgColor = "Yellow"
        $dateStr = $rJson.availableSlots[0].startTimestamp
        $msg = ([datetime]$dateStr).ToString('dd MMM yyyy')
        if ($SiteCodesPrior.ContainsKey($sitekey)) {   
            if ($SiteCodesPrior[$sitekey] -ne $dateStr) {
                $fgColor = "Green"
                $dateStr = "New " + $dateStr 
                $PriorDate = ([datetime]$SiteCodesPrior[$sitekey]).ToString('dd MMM yyyy')
                $msg += " (Prev $PriorDate)"
            }
        }
        Write-Host $msg -ForegroundColor $fgColor
    }
    $SiteCodesHist[$sitekey] = $rJson.availableSlots[0].startTimestamp
}

Write-Host "Writing History"
Set-Content -Path ".\SiteCodesHist.json" -Value ($SiteCodesHist | ConvertTo-Json -Depth 10)

Write-Host "Complete"

