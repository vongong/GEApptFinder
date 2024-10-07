# GEApptFinder

This scripts queries the appointment scheduler. The sites codes that it will query are in SiteCodes.json. The schduler api base is https://ttp.cbp.dhs.gov/schedulerapi/slot-availability?locationId=xxx

## SiteCodes.json Format

```json
{
    "site-name": "site-id",
}
```

example
```json
{
  "mke": 7740,
  "rockford": 11001,
  "ord": 5183,
  "dayton": 16242,
  "hi": 5340
}
```

## How to run

Finder.ps1 was designed to run in powershell 7. Wasn't tested with any prior version. Create data folder and create SiteCodes.json file in data folder.

```powershell
.\Finder.ps1
```