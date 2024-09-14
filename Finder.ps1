
$fgDef = "Gray"
$fgBold = "White"
$fgGood = "Green"
$fgWarn = "Yellow"
$fgErr = "Red"
$dateFormat = "dd MMM yyyy HH:mm"
$SchedulerUriBase = "https://ttp.cbp.dhs.gov/schedulerapi/slot-availability?locationId={{Code}}"
$SiteCodeFilePath = ".\data\SiteCodes.json"
$histFileTemplate = ".\out\SiteCodesHist{{value}}.json"
$histFile1 = $histFileTemplate.Replace("{{value}}","-1")
$histFile = $histFileTemplate.Replace("{{value}}","")

Write-Host "Global Entry Appointment Finder" -ForegroundColor $fgBold
Write-Host "Loading Site List"
if (-not (Test-Path -Path $SiteCodeFilePath -PathType Leaf)) {
    $msg = "Can't find $SiteCodeFilePath"
    Write-Host $msg -ForegroundColor $fgErr
    throw $msg
}
$SiteCodes = Get-Content -Path $SiteCodeFilePath | ConvertFrom-Json -AsHashtable
$SiteCodesPrior = $SiteCodes.Clone()

if (-not (Test-Path -Path (Split-Path $histFile) )) {
    Write-Host "Create folder for History"
    $msg = mkdir (Split-Path $histFile)
}
if (Test-Path -Path $histFile -PathType Leaf) {
    Write-Host "Loading History"
    $SiteCodesPrior = Get-Content -Path $histFile | ConvertFrom-Json -AsHashtable
    Copy-Item -Path $histFile -Destination $histFile1 -Force
}

Write-Host "Pull Data"
$SiteCodesCurr = $SiteCodes.Clone()
$SiteCodes.Keys | Foreach-Object -ThrottleLimit 5 -Parallel {
    $key = $_
    $SiteCodes = $using:SiteCodes
    $SiteCodesCurr = $using:SiteCodesCurr
    $SchedulerUriBase = $using:SchedulerUriBase
    $value = $SiteCodes[$key]
    $SchedulerUri = $SchedulerUriBase.Replace("{{Code}}",$value)

    $resp = Invoke-WebRequest -Uri $SchedulerUri
    $rJson = $resp.Content | ConvertFrom-Json
    $SiteCodesCurr[$key] = $rJson.availableSlots[0].startTimestamp
}

Write-Host "Process Data"
foreach ($key in $SiteCodes.Keys) {
    $fgColor = $fgDef
    $fgSubColor = $fgDef
    if ($SiteCodesCurr[$key].Length -eq 0) {
        $msg = "No Available Slots"
    } else {
        $fgSubColor = $fgWarn
        $CurrDate = [datetime]$SiteCodesCurr[$key]
        $msg = $CurrDate.ToString($dateFormat)
        if ($SiteCodesPrior[$key] -ne $SiteCodesCurr[$key]) {
            $PriorDate = [datetime]$SiteCodesPrior[$key]
            $diffDate = New-TimeSpan -Start $PriorDate -End $CurrDate
            if ($PriorDate -gt $CurrDate) {
                $fgSubColor = $fgGood
                $fgColor = $fgBold
            }
            if ($diffDate.Days -ne 0) {
                $msg += " ($($diffDate.Days) Days)"
            } elseif ($diffDate.Hours -ne 0) {
                $msg += " ($($diffDate.Hours) Hours)"
            } else {
                $msg += " ($($diffDate.Minutes) Min)"
            }
        }
    }
    Write-Host "  $Key`: " -NoNewline -ForegroundColor $fgColor
    Write-Host $msg  -ForegroundColor $fgSubColor
}

Write-Host "Writing History"
Set-Content -Path $histFile -Value ($SiteCodesCurr | ConvertTo-Json -Depth 10)

Write-Host "Complete"
