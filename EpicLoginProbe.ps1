param([long]$WindowHandle, [string]$OutputPath, [string]$ImagePath, [switch]$Chat)
# Only coordinates and a classified state leave this process. No screenshots or OCR text are saved.
$ErrorActionPreference = 'Stop'
function Await-WinRt($Operation, [Type]$ResultType) {
    $m = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.IsGenericMethodDefinition -and $_.GetGenericArguments().Count -eq 1 -and $_.GetParameters().Count -eq 1
    } | Select-Object -First 1
    $m.MakeGenericMethod($ResultType).Invoke($null, @($Operation)).GetAwaiter().GetResult()
}
$answer = 'unknown'
try {
    Add-Type -AssemblyName System.Drawing, System.Runtime.WindowsRuntime
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class EpicCapture {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left,Top,Right,Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
'@
    [EpicCapture]::SetProcessDPIAware() | Out-Null
    $rect = New-Object EpicCapture+Rect
    if ($ImagePath) { $bitmap = [Drawing.Bitmap]::new($ImagePath) }
    else {
        if (-not [EpicCapture]::GetWindowRect([IntPtr]$WindowHandle, [ref]$rect)) { throw 'No window' }
        $width = $rect.Right - $rect.Left; $height = $rect.Bottom - $rect.Top
        if ($width -lt 400 -or $height -lt 300) { throw 'Not visible' }
        $bitmap = [Drawing.Bitmap]::new($width, $height)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            if ([EpicCapture]::GetForegroundWindow().ToInt64() -eq $WindowHandle) {
                $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
            } else {
                $dc = $graphics.GetHdc()
                try { if (-not [EpicCapture]::PrintWindow([IntPtr]$WindowHandle, $dc, 2)) { throw 'Capture unavailable' } }
                finally { $graphics.ReleaseHdc($dc) }
            }
        } finally { $graphics.Dispose() }
    }
    [Windows.Graphics.Imaging.BitmapDecoder,Windows.Graphics.Imaging,ContentType=WindowsRuntime] | Out-Null
    [Windows.Media.Ocr.OcrEngine,Windows.Media.Ocr,ContentType=WindowsRuntime] | Out-Null
    [Windows.Storage.Streams.InMemoryRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime] | Out-Null
    $chatTarget = $null
    if ($Chat -and -not $ImagePath -and [EpicCapture]::GetForegroundWindow().ToInt64() -eq $WindowHandle) {
        # Find the three light cyan toolbar capsules as a group, never by absolute position.
        # Ambiguous or changed layouts deliberately yield no target.
        $targets = @{}
        for ($cy = 25; $cy -lt [Math]::Min(150, $bitmap.Height); $cy += 2) {
            $runs = @(); $start = -1
            for ($cx = [int]($bitmap.Width * 0.5); $cx -lt $bitmap.Width; $cx++) {
                $p = $bitmap.GetPixel($cx, $cy)
                $match = $p.R -ge 145 -and $p.R -le 250 -and $p.G -ge 165 -and $p.G -le 255 -and $p.B -ge 165 -and $p.B -le 255 -and $p.G -ge ($p.R + 5) -and $p.B -ge ($p.R + 5)
                if ($match -and $start -lt 0) { $start = $cx }
                if (-not $match -and $start -ge 0) {
                    $len = $cx - $start
                    if ($len -ge 35 -and $len -le 105) { $runs += ,@($start, $len) }
                    $start = -1
                }
            }
            for ($i = 0; $i -le $runs.Count - 3; $i++) {
                $a = $runs[$i]; $b = $runs[$i+1]; $c = $runs[$i+2]
                $gap1 = $b[0]-$a[0]-$a[1]; $gap2 = $c[0]-$b[0]-$b[1]
                if ([Math]::Abs($a[1]-$b[1]) -le 8 -and [Math]::Abs($b[1]-$c[1]) -le 8 -and $gap1 -ge 3 -and $gap1 -le 20 -and $gap2 -ge 3 -and $gap2 -le 20) {
                    $center = [int]($b[0]+$b[1]/2)
                    $key = [int]([Math]::Round($center/10)*10)
                    $targets[$key] = @($center, $cy)
                }
            }
        }
        if ($targets.Count -eq 1) { $chatTarget = @($targets.Values)[0] }
    }
    $memory = [IO.MemoryStream]::new()
    $bitmap.Save($memory, [Drawing.Imaging.ImageFormat]::Bmp)
    $bitmap.Dispose()
    $random = [Windows.Storage.Streams.InMemoryRandomAccessStream]::new()
    $writer = [Windows.Storage.Streams.DataWriter]::new($random)
    $writer.WriteBytes($memory.ToArray())
    $memory.Dispose()
    Await-WinRt ($writer.StoreAsync()) ([uint32]) | Out-Null
    $writer.DetachStream() | Out-Null
    $writer.Dispose(); $random.Seek(0)
    $decoder = Await-WinRt ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($random)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $software = Await-WinRt ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
    $result = Await-WinRt ($engine.RecognizeAsync($software)) ([Windows.Media.Ocr.OcrResult])
    $lines = @($result.Lines)
    $user = @($lines | Where-Object { $_.Text -match '^User\s*ID$' })
    $password = @($lines | Where-Object { $_.Text -match '^Password$' })
    $login = @($lines | Where-Object { $_.Text -match '^Log\s*In$' })
    if ($result.Text -match 'Hyperspace' -and $user.Count -eq 1 -and $password.Count -eq 1 -and $login.Count -eq 1) {
        $u = @($user[0].Words)[0].BoundingRect; $p = @($password[0].Words)[0].BoundingRect; $l = @($login[0].Words)[0].BoundingRect
        if ($u.Y -lt $p.Y -and $p.Y -lt $l.Y -and [Math]::Abs($u.X-$p.X) -lt 40) {
            $answer = 'login,{0},{1},{2},{3},{4},{5},{6},{7}' -f $rect.Left,$rect.Top,[int]($u.X+10),[int]($u.Y+$u.Height/2),[int]($l.X+10),[int]($l.Y+$l.Height/2),($rect.Right-$rect.Left),($rect.Bottom-$rect.Top)
        }
    } elseif ($result.Text -match 'Hyperspace' -and @($lines | Where-Object {
        $_.Text -match '(?i)\bLog\s*Out\b' -and @($_.Words)[0].BoundingRect.Y -lt 200
    }).Count -gt 0) {
        $answer = 'authenticated'
    } elseif ($result.Text -match 'Hyperspace' -and $result.Text -match '(?i)(incorrect|invalid|failed|locked|expired)') {
        $answer = 'attention'
    }
    $software.Dispose(); $random.Dispose()
    if ($Chat) {
        $chatHeading = @($lines | Where-Object { $_.Text -match '^Secure Chat$' -and @($_.Words)[0].BoundingRect.Y -gt 100 -and @($_.Words)[0].BoundingRect.Y -lt 250 })
        $signedInToolbar = @($lines | Where-Object { $_.Text -match '(?i)\bLog\s*Out\b' -and @($_.Words)[0].BoundingRect.Y -lt 200 }).Count -gt 0
        if ($chatHeading.Count -eq 1) {
            $answer = 'chat-open'
        } elseif ($signedInToolbar -and $chatTarget) {
            $answer = 'chat-target,{0},{1},{2},{3},{4},{5}' -f $rect.Left,$rect.Top,$chatTarget[0],$chatTarget[1],($rect.Right-$rect.Left),($rect.Bottom-$rect.Top)
        } else { $answer = 'unknown' }
    }
} catch { $answer = 'unknown' }
if ($OutputPath) { [IO.File]::WriteAllText($OutputPath, $answer) } else { $answer }
