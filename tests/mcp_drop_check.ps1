param([string]$Godot = 'C:\Godot\godot_stable_win64.exe')
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
if (Get-NetTCPConnection -LocalPort 7777 -State Listen -ErrorAction SilentlyContinue) {
    throw 'Port 7777 is already in use. Close the other game before running this isolated MCP check.'
}
$gameProcess = Start-Process -FilePath $Godot -ArgumentList "--path `"$project`" --log-file `"$project\.godot\mcp-drop.log`"" -WindowStyle Hidden -PassThru
$client = [Net.Sockets.TcpClient]::new()
try {
    for ($attempt = 0; $attempt -lt 40 -and -not $client.Connected; $attempt++) {
        try { $client.Connect('127.0.0.1', 7777) } catch { Start-Sleep -Milliseconds 100 }
    }
    if (-not $client.Connected) { throw 'MCP Runtime did not start.' }
    $stream = $client.GetStream()
    $stream.ReadTimeout = 5000
    $reader = [IO.BinaryReader]::new($stream)
    $writer = [IO.StreamWriter]::new($stream)
    $writer.AutoFlush = $true
    function Read-Runtime {
        # StreamPeer.put_utf8_string prefixes responses with a little-endian byte count.
        $length = $reader.ReadUInt32()
        if ($length -gt 16777216) { throw 'Invalid MCP Runtime response length' }
        [Text.Encoding]::UTF8.GetString($reader.ReadBytes($length)) | ConvertFrom-Json
    }
    $welcome = Read-Runtime
    Write-Output "MCP connected: $($welcome.project_name), protocol $($welcome.protocol_version)"
    function Invoke-Runtime($command, $params) {
        $writer.WriteLine((@{id=1;command=$command;params=$params} | ConvertTo-Json -Depth 12 -Compress))
        $result = Read-Runtime
        if ($result.type -eq 'error') { throw $result.message }
        return $result
    }
    function Call-Node($path, $method, $arguments=@()) {
        Invoke-Runtime 'call_method' @{path=$path;method=$method;args=@($arguments)}
    }
    function Set-Node($path, $property, $value) {
        Invoke-Runtime 'set_property' @{path=$path;property=$property;value=$value} | Out-Null
    }
    $village = '/root/Village'
    $terrain = "$village/TerrainReveal"
    $camera = "$village/Camera2D"
    $tree = Invoke-Runtime 'get_tree' @{root=$village;depth=1}
    if (-not ($tree.root.children.name -contains 'TerrainReveal')) { throw 'Missing terrain node' }
    Set-Node "$village/WorldClock" 'preview_enabled' $true
    Set-Node "$village/WorldClock" 'preview_hour' 12.0
    Set-Node $camera 'tracking_enabled' $false
    Call-Node $terrain 'set_process' @($false) | Out-Null
    $tile = @{_type='Vector2i';x=12;y=2}
    Set-Node $camera 'global_position' @{_type='Vector2';x=192;y=256}
    Call-Node $camera 'force_update_scroll' | Out-Null
    Call-Node $terrain 'update_reveal' @(0.0) | Out-Null
    if (-not (Call-Node $terrain 'is_landed' @($tile)).result) { throw 'Interior tile should appear immediately' }
    $cells = (Call-Node $terrain 'get' @('cells')).result
    $dropping = @()
    foreach ($cell in $cells) {
        if (-not (Call-Node $terrain 'is_landed' @($cell)).result) { $dropping += $cell }
    }
    if ($dropping.Count -lt 1 -or $dropping.Count -gt 6) { throw 'Expected 1-6 edge drops' }
    $tile = $dropping[0]
    Write-Output "Sparse edge drops: $($dropping.Count) / $($cells.Count) shown tiles"
    Call-Node $terrain 'update_reveal' @(0.35) | Out-Null
    $offset = (Call-Node $terrain 'drop_offset' @($tile)).result
    if ($offset -ge 0) { throw 'Expected negative drop offset' }
    Invoke-Runtime 'capture_screenshot' @{output_path='res://tests/viewport-drop-preview.png'} | Out-Null
    Call-Node $terrain 'update_reveal' @(3.0) | Out-Null
    if (-not (Call-Node $terrain 'is_landed' @($tile)).result) { throw 'Tile failed to land' }
    Invoke-Runtime 'capture_screenshot' @{output_path='res://tests/viewport-landed-preview.png'} | Out-Null
    Set-Node $camera 'global_position' @{_type='Vector2';x=0;y=480}
    Set-Node $camera 'zoom' @{_type='Vector2';x=0.3;y=0.3}
    Call-Node $camera 'force_update_scroll' | Out-Null
    Call-Node $terrain 'update_reveal' @(0.0) | Out-Null
    $fits = (Call-Node $terrain 'get' @('whole_world_visible')).result
    if (-not $fits) { throw 'Zoomed-out world must bypass drops' }
    Invoke-Runtime 'capture_screenshot' @{output_path='res://tests/viewport-whole-world-preview.png'} | Out-Null
    $metrics = Invoke-Runtime 'get_metrics' @{}
    Write-Output "MCP DROP PASS: scene inspection, camera movement, drop offset=$offset, landing, whole-world bypass."
    Write-Output ($metrics.data | ConvertTo-Json -Compress)
} finally {
    $client.Dispose()
    if (-not $gameProcess.HasExited) { Stop-Process -Id $gameProcess.Id }
}
