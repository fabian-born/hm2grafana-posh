#$doc = New-Object System.Xml.XmlDocument
#$doc.Load("http://192.168.10.250/config/xmlapi/devicelist.cgi") 
#$i=0
#foreach($device in ($doc.deviceList.device | ?{$_.interface -ne "VirtualDevices"})){
#    $devicename = ($device.name).replace(" ","_")
#    write-host $devicename
#    foreach ($channel in $device.channel){
#        write-host " | -> [$($channel.ise_id)] $($channel.name)"
#    }
#}
function replace-charachter([string]$text){
    $replace = $text.replace("ä","ae")
    $replace = $text.replace("Ä","Ae")
    $replace = $text.replace("ö","oe")
    $replace = $text.replace("Ö","Oe")
    $replace = $text.replace("ü","ue")
    $replace = $text.replace("Ü","Ue")
    $replace = $text.replace(" ","")
    return $replace
}
function Send-ToGraphite {
    param(
        [string]$carbonServer,
        [string]$carbonServerPort,
        [string[]]$metrics
    )
      try
        {
        $socket = New-Object System.Net.Sockets.TCPClient 
        $socket.connect($carbonServer, $carbonServerPort) 
        $stream = $socket.GetStream() 
        $writer = new-object System.IO.StreamWriter($stream)
        foreach ($metric in $metrics){
          #  Write-Host $metric
            $newMetric = $metric.TrimEnd()
           $writer.WriteLine($newMetric) 
            }
        $writer.Flush()
        $writer.Close() 
        $stream.Close()
        }
        catch
        {
            Write-Error $_
        }
}

$rooms = New-Object System.Xml.XmlDocument
$rooms.Load("http://192.168.1.99/config/xmlapi/roomlist.cgi")
$rchannel = New-Object System.Xml.XmlDocument
$base="hm.dev"
$carbonServer = "192.168.1.98"
$carbonServerPort = 2003

$date = [int][double]::Parse((Get-Date -UFormat %s))

foreach ($room in $rooms.roomlist.room)
{
    $roomname = ($room.name).Replace(" ","")
    $roomname = replace-charachter($roomname)
    foreach ($channel in $room.channel){
        $rchannel.Load("http://192.168.1.99/config/xmlapi/state.cgi?channel_id=$($channel.ise_id)") 
        $devicename = replace-charachter $rchannel.state.device.name
        if ( $devicename -ne "$($__last__)"){
            #write-host $rchannel.state.device.name "($($channel.ise_id))"
        }
        $__last__ = $rchannel.state.device.name 
        $channeldevice = $rchannel.state.device.channel | ? { $_.ise_id -eq $($channel.ise_id) } 
        $channeldevice = replace-charachter($channeldevice)
        # write-host "`t" $channeldevice.name
        foreach($datapoints in ($rchannel.state.device.channel | ? { $_.ise_id -eq $($channel.ise_id) }).datapoint | select name,value){
            $datapoint_name = (($datapoints.name).split("."))[(($datapoints.name).split(".")).length-1]
            if ($datapoints.value -ne ""){
                if ( $datapoints.value -eq "true" ) { $datapoint_value = 1 }
                elseif($datapoints.value -eq "false") { $datapoint_value = 0}
                else{ $datapoint_value = $datapoints.value}
                Send-ToGraphite -carbonServer $carbonServer -carbonServerPort $carbonServerPort -metric "$($base).$($roomname).$($devicename).$($datapoint_name) $($datapoint_value) $($date)"
                write-host -NoNewline "."
            }
        }
    }
}


