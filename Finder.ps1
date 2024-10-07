<#
.DESCRIPTION
This scripts scraps data from the Global Entry Scheduler

.PARAMETER SiteCodeFilePath
This contains filepath to Sites Code Data. Default: .\data\SiteCodes.json

.PARAMETER histFolder
This contains filepath to the history folder. Default: .\out

.EXAMPLE
.\Finder.ps1

.\Finder.ps1 -SiteCodeFilePath ".\data\myCodes.json"

.\Finder.ps1 -SiteCodeFilePath ".\data\SiteCodes-test.json"

A Using variable cannot be retrieved. 

.\Finder.ps1 -histFolder ".\hist"

#>

param (
    [string] $SiteCodeFilePath = ".\data\SiteCodes.json"
    , [string] $histFolder = ".\out"
)

# Variable
$fgDef = "Gray"
$fgBold = "White"
$fgGood = "Green"
$fgWarn = "Yellow"
$fgErr = "Red"
$typefull = "full"
$typeopen = "open"
$ArrType = 0
$ArrDate = 1
$sep = "__"
$dateFormatDisplay = "dd MMM yyyy HH:mm"
$dateFormatStore = "yyyy-MM-ddTHH:mm"
$idStr = "{{Code}}"
$SchedulerUriBase = "https://ttp.cbp.dhs.gov/schedulerapi/slot-availability?locationId=$idStr"
$histFileTemplate = "SiteCodesHist$idStr.json"
$histFile1 = Join-Path -Path $histFolder -ChildPath $histFileTemplate.Replace($idStr,"-1")
$histFile = Join-Path -Path $histFolder -ChildPath $histFileTemplate.Replace($idStr,"")

Write-Host "Global Entry Appointment Finder" -ForegroundColor $fgBold
Write-Host "Parameters"
Write-Host "  SiteCodeFilePath = $SiteCodeFilePath"
Write-Host "  histFolder = $histFolder"
Write-Host "Loading Site List"
if (-not (Test-Path -Path $SiteCodeFilePath -PathType Leaf)) {
    $msg = "Can't find $SiteCodeFilePath"
    Write-Host $msg -ForegroundColor $fgErr
    throw $msg
}
$SiteCodes = Get-Content -Path $SiteCodeFilePath | ConvertFrom-Json -AsHashtable
$SiteCodesPrior = $SiteCodes.Clone()

if (-not (Test-Path -Path $histFolder )) {
    Write-Host "Create folder for History"
    $msg = mkdir $histFolder
}
if (Test-Path -Path $histFile -PathType Leaf) {
    Write-Host "Loading History"
    $SiteCodesPrior = Get-Content -Path $histFile | ConvertFrom-Json -AsHashtable
    Copy-Item -Path $histFile -Destination $histFile1 -Force
}

Write-Host "Pull Data " -NoNewline
$SiteCodesCurr = $SiteCodes.Clone()
$SiteCodes.Keys | Foreach-Object -ThrottleLimit 5 -Parallel {
    $key = $_
    $SiteCodes = $using:SiteCodes
    $SiteCodesCurr = $using:SiteCodesCurr
    $SchedulerUriBase = $using:SchedulerUriBase
    $locationId = $using:idStr
    $value = $SiteCodes[$key]
    $SchedulerUri = $SchedulerUriBase.Replace($locationId,$value)

    $resp = Invoke-WebRequest -Uri $SchedulerUri
    $rJson = $resp.Content | ConvertFrom-Json    
    $dataStr = $using:typeOpen + $using:sep + $rJson.availableSlots[0].startTimestamp
    if ($rJson.availableSlots.Length -eq 0) {
        $dataStr = $using:typeFull + $using:sep + $rJson.lastPublishedDate.ToString($using:dateFormatStore)
    }
    $SiteCodesCurr[$key] = $dataStr    
    Write-Host "." -NoNewline
}
Write-Host "."

Write-Host "Process Data"
foreach ($key in $SiteCodes.Keys) {
    $fgColor = $fgDef
    $fgSubColor = $fgDef
    $currArr = $SiteCodesCurr[$key] -Split $sep
    $CurrDate = [datetime]$currArr[$ArrDate]
    if ($currArr[$ArrType] -eq $typefull) {
        $msg = "None Available until " + $CurrDate.ToString($dateFormatDisplay)
    } else {
        $fgSubColor = $fgWarn        
        $msg = $CurrDate.ToString($dateFormatDisplay)
        $PriorDate = $CurrDate
        if ($SiteCodesPrior.ContainsKey($key)) {            
            $PriorArr = $SiteCodesPrior[$key].Split("__")        
            if ($PriorArr.Length -eq 2) {            
                $PriorDate = [datetime]$PriorArr[$ArrDate]
            } elseif ($PriorArr.Length -eq 1) {
                $PriorDate = $SiteCodesPrior[$key]
            }
        }
        if ($PriorDate -ne $CurrDate) {            
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
