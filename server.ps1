$port = 8080
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Prefixes.Add("http://127.0.0.1:$port/")

try {
    $listener.Start()
    Write-Host "Servidor HTTP ativo em http://127.0.0.1:$port/"
    $baseDir = $PSScriptRoot

    while ($listener.IsListening) {
        $context = $listener.GetContext()
        [System.Threading.ThreadPool]::QueueUserWorkItem({
            param($ctx, $root)
            $req = $ctx.Request
            $res = $ctx.Response
            try {
                $rawPath = $req.Url.LocalPath.TrimStart('/')
                if ([string]::IsNullOrWhiteSpace($rawPath)) {
                    $rawPath = "index.html"
                }
                $filePath = [System.IO.Path]::Combine($root, $rawPath)

                if ([System.IO.File]::Exists($filePath)) {
                    $bytes = [System.IO.File]::ReadAllBytes($filePath)
                    $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
                    $contentType = switch ($ext) {
                        ".html" { "text/html; charset=utf-8" }
                        ".js"   { "text/javascript; charset=utf-8" }
                        ".mjs"  { "text/javascript; charset=utf-8" }
                        ".css"  { "text/css; charset=utf-8" }
                        ".json" { "application/json; charset=utf-8" }
                        ".png"  { "image/png" }
                        ".jpg"  { "image/jpeg" }
                        ".svg"  { "image/svg+xml" }
                        ".wav"  { "audio/wav" }
                        ".mp3"  { "audio/mpeg" }
                        default { "application/octet-stream" }
                    }
                    $res.ContentType = $contentType
                    $res.AddHeader("Access-Control-Allow-Origin", "*")
                    $res.AddHeader("Cache-Control", "no-cache, no-store, must-revalidate")
                    $res.ContentLength64 = $bytes.Length
                    $res.OutputStream.Write($bytes, 0, $bytes.Length)
                } else {
                    $res.StatusCode = 404
                    $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Arquivo nao encontrado")
                    $res.ContentType = "text/plain; charset=utf-8"
                    $res.ContentLength64 = $msg.Length
                    $res.OutputStream.Write($msg, 0, $msg.Length)
                }
            } catch {
                # Ignore client aborts or stream disconnects
            } finally {
                try { $res.Close() } catch {}
            }
        }, $context)
    }
} catch {
    Write-Host "Erro servidor: $_"
} finally {
    try { $listener.Stop() } catch {}
}
