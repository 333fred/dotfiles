Set-Alias g git
Set-Alias v nvim

Import-Module PSReadline

Set-PSReadLineOption -HistorySearchCursorMovesToEnd -BellStyle None -EditMode Vi

Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

Import-Module posh-git
Import-Module posh-sshell
Start-SshAgent -Quiet

Invoke-Expression (&starship init powershell)

Import-Module -Name Terminal-Icons

# PowerShell parameter completion shim for the dotnet CLI
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
   param($commandName, $wordToComplete, $cursorPosition)
   dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object {
      [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
   }
}

 
# Add this to your PowerShell profile ($PROFILE)

function c {
   # Prefer 'code-insiders' if available; else fall back to 'code'
   $cmd = if (Get-Command code-insiders -ErrorAction SilentlyContinue) {
      'code-insiders'
   }
   elseif (Get-Command code -ErrorAction SilentlyContinue) {
      'code'
   }
   else {
      Write-Warning "Neither 'code-insiders' nor 'code' is installed or in PATH."
      return
   }

   & $cmd @args
}

function upgrade {
   function Invoke-OptionalUpdate($description, [scriptblock]$command) {
      $ErrorActionPreference = 'Stop'
      $PSNativeCommandUseErrorActionPreference = $false

      try {
         & $command
         if ($LASTEXITCODE -ne 0) {
            Write-Warning "${description} failed with exit code $LASTEXITCODE."
         }
      }
      catch {
         Write-Warning "${description} failed: $($_.Exception.Message)"
      }
   }

   Invoke-OptionalUpdate 'winget source update' { & winget source update }
   Invoke-OptionalUpdate 'winget upgrade' { & winget upgrade --all --accept-source-agreements --accept-package-agreements }
   Invoke-OptionalUpdate 'npm update' { & npm update --global }

   & copilot update
   if ($LASTEXITCODE -ne 0) {
      Write-Error "Copilot update failed with exit code $LASTEXITCODE."
      return
   }

   & dotnet tool update --global complog
   if ($LASTEXITCODE -ne 0) {
      Write-Error "Updating the complog .NET tool failed with exit code $LASTEXITCODE."
      return
   }

   & dotnet tool update --global roslyn-language-server --prerelease
   if ($LASTEXITCODE -ne 0) {
      Write-Error "Updating the roslyn-language-server .NET tool failed with exit code $LASTEXITCODE."
      return
   }

   $sourceDir = & chezmoi source-path
   if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sourceDir)) {
      Write-Error 'Could not determine the chezmoi source directory.'
      return
   }

   $gitStatus = & git -C $sourceDir status --porcelain
   if ($LASTEXITCODE -ne 0) {
      Write-Error 'Could not check the chezmoi source status.'
      return
   }

   if ([string]::IsNullOrWhiteSpace(($gitStatus -join "`n"))) {
      & git -C $sourceDir pull --ff-only
      if ($LASTEXITCODE -ne 0) {
         Write-Error 'Chezmoi source pull failed; skipping apply.'
         return
      }
   }
   else {
      Write-Warning 'Chezmoi source has local changes; skipping pull.'
   }

   & chezmoi apply --refresh-externals=always --error-on-conflict
   if ($LASTEXITCODE -ne 0) {
      Write-Error 'Chezmoi apply failed.'
   }
}

$dotnetup = Join-Path $HOME '.dotnetup\dotnetup.exe'
if (Test-Path -LiteralPath $dotnetup -PathType Leaf) {
   $dotnetupScript = & $dotnetup env script --shell pwsh --dotnet --dotnetup | Out-String
   if ($LASTEXITCODE -ne 0) {
      Write-Error 'dotnetup environment initialization failed.'
   }
   elseif (-not [string]::IsNullOrWhiteSpace($dotnetupScript)) {
      Invoke-Expression $dotnetupScript
   }
}
