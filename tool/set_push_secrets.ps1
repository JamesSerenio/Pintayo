param([Parameter(Mandatory = $true)][string]$ServiceAccountPath)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$accountPath = (Resolve-Path -LiteralPath $ServiceAccountPath).Path
if ($accountPath.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Keep the service-account file outside the application workspace.'
}
$account = Get-Content -LiteralPath $accountPath -Raw | ConvertFrom-Json
if (-not $account.client_email -or -not $account.private_key -or $account.project_id -ne 'pintayo') {
    throw 'Choose the genuine service-account JSON for Firebase project pintayo.'
}
$appConfig = Get-Content -LiteralPath (Join-Path $projectRoot 'config/app_config.json') -Raw | ConvertFrom-Json
$projectRef = $appConfig.SUPABASE_PROJECT_REF
if ($projectRef -notmatch '^[a-z]{20}$') { throw 'Invalid configured Supabase project reference.' }
$privateDirectory = Split-Path -Parent $accountPath
$workerPath = Join-Path $privateDirectory 'pintayo-push-worker-secret.txt'
if (Test-Path -LiteralPath $workerPath) {
    $workerSecret = (Get-Content -LiteralPath $workerPath -Raw).Trim()
    if ($workerSecret.Length -lt 40) { throw 'The saved worker secret is too short.' }
} else {
    $randomBytes = New-Object byte[] 32
    $random = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $random.GetBytes($randomBytes) } finally { $random.Dispose() }
    $workerSecret = [Convert]::ToBase64String($randomBytes)
    [IO.File]::WriteAllText($workerPath, $workerSecret, (New-Object Text.UTF8Encoding($false)))
}
$envPath = Join-Path $privateDirectory ('.pintayo-' + [Guid]::NewGuid().ToString('N') + '.secrets.env')
try {
    $serviceJson = $account | ConvertTo-Json -Depth 20 -Compress
    $environment = "FCM_SERVICE_ACCOUNT=$serviceJson`nPUSH_WORKER_SECRET=$workerSecret`n"
    [IO.File]::WriteAllText($envPath, $environment, (New-Object Text.UTF8Encoding($false)))
    & npx.cmd supabase secrets set --project-ref $projectRef --env-file $envPath
    if ($LASTEXITCODE -ne 0) { throw 'Secret upload failed. Check Supabase CLI authentication and project access.' }
    Write-Output 'Supabase secrets uploaded. Set the matching worker secret in Supabase Vault from the private file.'
    Write-Output "Private worker-secret file: $workerPath"
} finally {
    # Delete exactly the temporary file created above; never recursively remove.
    if (Test-Path -LiteralPath $envPath) { Remove-Item -LiteralPath $envPath -Force }
}
