$port = 8085
$root = $PSScriptRoot
$listener = New-Object System.Net.HttpListener
$localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -ne '127.0.0.1' }).IPAddress | Select-Object -First 1
$prefixes = @("http://localhost:$port/", "http://127.0.0.1:$port/")
if ($localIP) { $prefixes += "http://$($localIP):$port/" }

foreach ($prefix in $prefixes) {
    try {
        $listener.Prefixes.Add($prefix)
    }
    catch {
        Write-Warning "Could not register prefix $prefix. You might need to run as Administrator for mobile access."
    }
}

try {
    $listener.Start()
}
catch {
    Write-Error "Failed to start listener. Please ensure the port $port is not in use and you have sufficient privileges."
    exit
}
Write-Host "Server running on port $port"
Write-Host "Access from mobile: http://$(((Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -ne '127.0.0.1' }).IPAddress | Select-Object -First 1)):$port"
Write-Host "Press Ctrl+C to stop"

$mimeTypes = @{
    ".html"  = "text/html"
    ".css"   = "text/css"
    ".js"    = "application/javascript"
    ".png"   = "image/png"
    ".jpg"   = "image/jpeg"
    ".jpeg"  = "image/jpeg"
    ".gif"   = "image/gif"
    ".svg"   = "image/svg+xml"
    ".ico"   = "image/x-icon"
    ".json"  = "application/json"
    ".woff"  = "font/woff"
    ".woff2" = "font/woff2"
    ".ttf"   = "font/ttf"
}

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    $localPath = $request.Url.LocalPath
    if ($localPath -eq "/") { $localPath = "/index.html" }

    $filePath = Join-Path $root $localPath.TrimStart("/")

    if (Test-Path $filePath -PathType Leaf) {
        $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
        $contentType = if ($mimeTypes.ContainsKey($ext)) { $mimeTypes[$ext] } else { "application/octet-stream" }
        $response.ContentType = $contentType
        $buffer = [System.IO.File]::ReadAllBytes($filePath)
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
    }
    else {
        $response.StatusCode = 404
        $buffer = [System.Text.Encoding]::UTF8.GetBytes("Not Found")
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
    }
    $response.Close()
    Write-Host "$($request.HttpMethod) $($request.Url.LocalPath) -> $($response.StatusCode)"
}
