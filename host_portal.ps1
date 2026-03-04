$port = 8083
$ip = [System.Net.IPAddress]::Any
$listener = New-Object System.Net.Sockets.TcpListener($ip, $port)
$listener.Start()

$localIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -like "*Wi-Fi*" -or $_.InterfaceAlias -like "*Ethernet*" }).IPAddress | Select-Object -First 1
Write-Host "Portfolio Hub started!"
Write-Host "Local:  http://localhost:$port/"
Write-Host "Mobile: http://$($localIp):$port/"

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $requestLine = $reader.ReadLine()
        if ($null -eq $requestLine) { $client.Close(); continue }

        $parts = $requestLine.Split(" ")
        $method = $parts[0]
        $url = $parts[1].Split('?')[0]
        if ($url -eq "/") { $url = "/index.html" }
        $url = [System.Net.WebUtility]::UrlDecode($url)

        $path = Join-Path (Get-Location) $url.TrimStart('/')
        if (Test-Path $path -PathType Leaf) {
            $bytes = [System.IO.File]::ReadAllBytes($path)
            $type = "application/octet-stream"
            if ($path -like "*.html") { $type = "text/html" }
            elseif ($path -like "*.js") { $type = "application/javascript" }
            elseif ($path -like "*.css") { $type = "text/css" }
            
            $header = "HTTP/1.1 200 OK`r`nContent-Type: $type`r`nCache-Control: no-cache, no-store, must-revalidate`r`nContent-Length: $($bytes.Length)`r`nAccess-Control-Allow-Origin: *`r`n`r`n"
            $stream.Write([System.Text.Encoding]::UTF8.GetBytes($header), 0, [System.Text.Encoding]::UTF8.GetByteCount($header))
            $stream.Write($bytes, 0, $bytes.Length)
        }
        else {
            $resp = "HTTP/1.1 404 Not Found`r`nContent-Length: 0`r`n`r`n"
            $stream.Write([System.Text.Encoding]::UTF8.GetBytes($resp), 0, [System.Text.Encoding]::UTF8.GetByteCount($resp))
        }
        $stream.Flush(); $client.Close()
    }
}
catch { Write-Host "Error: $_" } finally { $listener.Stop() }
