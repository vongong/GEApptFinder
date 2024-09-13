
$fgBold = "White"
$fgGood = "Green"
$fgWarn = "Yellow"
# $fgErr = "Red"
$fgDef = "Gray"
$SchedulerUriBase = "https://ttp.cbp.dhs.gov/schedulerapi/slot-availability?locationId={{Code}}"
$SiteCodeFilePath = ".\SiteCodes.json"
$histFileTemplate = ".\out\SiteCodesHist{{value}}.json"
$histFile1 = $histFileTemplate.Replace("{{value}}","-1")
$histFile = $histFileTemplate.Replace("{{value}}","")

Write-Host "Global Entry Appointment Finder" -ForegroundColor $fgBold
Write-Host "Loading Site List"
if (-not (Test-Path -Path $SiteCodeFilePath -PathType Leaf)) {
    $msg = "Can't find $SiteCodeFilePath"
    Write-Error $msg
    throw $msg
}
$SiteCodes = Get-Content -Path $SiteCodeFilePath | ConvertFrom-Json -AsHashtable

# Make backup
$SiteCodesPrior = @{}
if (-not (Test-Path -Path (Split-Path $histFile) )) {
    Write-Host "Create folder for History"
    $msg = mkdir (Split-Path $histFile)
}
if (Test-Path -Path $histFile -PathType Leaf) {
    Write-Host "Loading History"
    $SiteCodesPrior = Get-Content -Path $histFile | ConvertFrom-Json -AsHashtable
    Copy-Item -Path $histFile -Destination $histFile1 -Force
}
$SiteCodesHist = @{}

Write-Host "Processing List" -ForegroundColor $fgBold
foreach ($sitekey in $siteCodes.Keys) {
    $siteCode = $SiteCodes[$sitekey]
    $SchedulerUri = $SchedulerUriBase.Replace("{{Code}}",$siteCode)
    $resp = Invoke-WebRequest -Uri $SchedulerUri
    $rJson = $resp.Content | ConvertFrom-Json    
    $fgColor = $fgDef
    $fgSubColor = $fgDef
    if ($rJson.availableSlots.Length -eq 0) {
        $msg = "No Available Slots"        
    } else {        
        $fgSubColor = $fgWarn
        $dateStr = $rJson.availableSlots[0].startTimestamp
        $msg = ([datetime]$dateStr).ToString('dd MMM yyyy')
        if ($SiteCodesPrior.ContainsKey($sitekey)) {
            if ($SiteCodesPrior[$sitekey] -ne $dateStr) {
                $fgSubColor = $fgGood
                $fgColor = $fgBold
                $dateStr = "New " + $dateStr
                $PriorDate = ([datetime]$SiteCodesPrior[$sitekey]).ToString('dd MMM yyyy')
                $msg += " (Prev $PriorDate)"
            }
        }
    }
    Write-Host "  $sitekey`: " -NoNewline -ForegroundColor $fgColor
    Write-Host $msg -ForegroundColor $fgSubColor
    $SiteCodesHist[$sitekey] = $rJson.availableSlots[0].startTimestamp
}

Write-Host "Writing History"
Set-Content -Path $histFile -Value ($SiteCodesHist | ConvertTo-Json -Depth 10)

Write-Host "Complete"

