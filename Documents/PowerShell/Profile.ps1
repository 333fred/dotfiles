Set-Alias g git

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
