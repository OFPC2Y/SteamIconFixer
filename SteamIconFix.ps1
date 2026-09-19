$shortcuts = Get-ChildItem `
    "$env:USERPROFILE\Desktop" `
    -Filter *.url


foreach($file in $shortcuts){

    $content = Get-Content $file.FullName

    $iconLine = $content | 
        Where-Object {$_ -like "IconFile=*"} 

    $urlLine =
        $content |
        Where-Object {$_ -like "URL=*"} 


    if(!$iconLine){
        continue
    }


    $icon =
        $iconLine -replace "IconFile=",""


    if(Test-Path $icon){
        continue
    }


    $hash =
        [System.IO.Path]::GetFileNameWithoutExtension($icon)


    if($urlLine -match "rungameid/(\d+)"){
        $appid=$matches[1]
    }
    else{
        continue
    }


    Write-Host "Repairing $($file.Name)"
    Write-Host "$appid $hash"


    $cdn =
    "https://cdn.cloudflare.steamstatic.com/steamcommunity/public/images/apps/$appid/$hash.ico"


    try{

        Invoke-WebRequest `
        $cdn `
        -OutFile $icon

        Write-Host "OK"

    }
    catch{

        Write-Host "Failed"

    }
}