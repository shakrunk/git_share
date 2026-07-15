# =========================================================================== #
#                              SYSTEM COMMANDS                                #
# =========================================================================== #

# Output Encoding
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Edit this file (using my command name for "edit aliases" from my linux setup)
function edital {
  Start-Process zed -ArgumentList "--wait", $profile -Wait
  . $profile
}

# Edit this file and update it in the share repo
function wedital {
  # WEDITAL TEST COMMENT: to test the wedital system just iterate the following:
  # 4
  # (or just modify however you see fit)

  Push-Location "C:\Users\kkumar\Documents\git-repos\git_share"
  Write-Host "Syncing with remote..." -ForegroundColor Cyan

  # Use native git commands for script reliability
  git fetch --prune
  git pull

  edital

  Copy-Item $profile -Destination .\work_setup -Force

  if ($(git status --porcelain)) {
    # Scan last 10 commits to find the last 'shr' number, preventing reset on manual commits
    $lastShrCommit = git log -n 10 --pretty=format:"%s" | Select-String -Pattern 'shr(\d+)' | Select-Object -First 1

    if ($lastShrCommit) {
      $prevNum = [int]$lastShrCommit.Matches.Groups[1].Value
      $nextNum = $prevNum + 1
    } else {
      $nextNum = 1
    }

    $newMsg = "shr{0:D3}" -f $nextNum

    git add .
    git commit -m $newMsg
    git push
    Write-Host "Success: Profile updated and pushed ($newMsg)" -ForegroundColor Green
  } else {
    Write-Host "No changes detected." -ForegroundColor Yellow
  }
  Pop-Location
}

# Semantically accurate commands
Set-Alias -Name edit -Value zed
Set-Alias -Name say  -Value Write-Host


# =========================================================================== #
#                   CUSTOM FUNCTIONS (longer operations)                      #
# =========================================================================== #

# Define all theme-switching logic in a single, self-contained function.
function Update-Theme {
  # Helper function to get the current theme from the registry.
  function Get-WindowsTheme {
    $theme = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -ErrorAction SilentlyContinue
    if ($theme -and $theme.AppsUseLightTheme -eq 0) { return 'dark' }
    return 'light'
  }

  # Define the color palettes.
  $darkThemeColors = @{
    Command = '#61AFEF'; String = '#98C379'; Variable = '#E06C75';
    Operator = '#5A6374'; Comment = '#5A6374'; Parameter = '#E5C07B';
    Number = '#E5C07B'; Type = '#56B6C2'; Member = '#DCDFE4';
    Default = '#DCDFE4'; Emphasis = '#56B6C2'; Error = '#E06C75';
    Selection = '#5A6374'; InlinePrediction = '#5A6374'
  }
  $lightThemeColors = @{
    Command = '#4078F2'; String = '#50A14F'; Variable = '#E45649';
    Operator = '#A0A1A7'; Comment = '#A0A1A7'; Parameter = '#C18401';
    Number = '#C18401'; Type = '#0184BC'; Member = '#383A42';
    Default = '#383A42'; Emphasis = '#0184BC'; Error = '#E45649';
    Selection = '#A0A1A7'; InlinePrediction = '#A0A1A7'
  }

  # Check the theme and apply the appropriate colors.
  if ((Get-WindowsTheme) -eq 'dark') {
    Set-PSReadLineOption -Colors $darkThemeColors
  }
  else {
    Set-PSReadLineOption -Colors $lightThemeColors
  }
}

# ---- Helper Functions for "Self-Healing" Profile ----

function Assert-PSModule {
  <#
  .SYNOPSIS
    Checks if a PowerShell module is installed. If not, tries to install it.
    Then imports it.
  #>
  param(
    [string]$Name,
    [switch]$SuppressImport
  )

  if (-not (Get-Module -ListAvailable -Name $Name)) {
    Write-Warning "Module '$Name' is missing. Attempting to install..."
    try {
      Install-Module -Name $Name -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
      Write-Host "✅ Successfully installed '$Name'." -ForegroundColor Green
    } catch {
      Write-Warning "❌ Could not install '$Name'. You may need to run: Install-Module $Name -Scope CurrentUser"
      return
    }
  }

  if (-not $SuppressImport) {
    Import-Module -Name $Name -ErrorAction SilentlyContinue
  }
}

function Assert-BinaryTool {
  <#
  .SYNOPSIS
    Checks if a command line tool (exe) exists.
    If yes, runs the provided ScriptBlock (initialization logic).
    If no, prints a helpful install tip without crashing the profile.
  #>
  param(
    [string]$Name,         # The command to check (e.g. "zoxide")
    [string]$InstallHint,  # Command to show user if missing (e.g. "winget install...")
    [ScriptBlock]$OnFound  # Code to run if the tool is found
  )

  if (Get-Command $Name -ErrorAction SilentlyContinue) {
    # Tool exists, run the setup logic
    & $OnFound
  } else {
    # Tool missing, print warning but don't crash
    Write-Host "⚠️  '$Name' not found. Skipping setup." -ForegroundColor DarkGray
    if ($InstallHint) {
      Write-Host "   To install: $InstallHint" -ForegroundColor DarkGray
    }
  }
}

# ---- Helper Function for instant y/n detection ----
function Assert-Confirmation {
  param([string]$Message)
  Write-Host "$Message (y/n) " -NoNewline -ForegroundColor Yellow

  # ReadKey options: NoEcho (don't print char automatically), IncludeKeyDown (ignore key-up events)
  $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

  if ($key.Character -eq 'y') {
    Write-Host "y" -ForegroundColor Green # Manually print the 'y' for visual confirmation
    return $true
  }

  Write-Host "$($key.Character)" -ForegroundColor Red # Print whatever else they typed
  return $false
}

# =========================================================================== #
#                         CLAUDE MANAGEMENT                                   #
# =========================================================================== #
$env:CLAUDE_SESSIONS = "$env:LOCALAPPDATA\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\local-agent-mode-sessions"

if (Test-Path $env:CLAUDE_SESSIONS) {
    New-PSDrive -Name "ClaudeSess" -PSProvider FileSystem -Root $env:CLAUDE_SESSIONS | Out-Null
}

function Set-ClaudeSession {
    <#
    .SYNOPSIS
      Automatically finds and changes the directory to the most recently modified agent session workspace.
    #>
    if (Test-Path $env:CLAUDE_SESSIONS) {
        $latestSession = Get-ChildItem -Path $env:CLAUDE_SESSIONS -Directory -Depth 2 |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($latestSession) {
            Set-Location $latestSession.FullName
        } else {
            Set-Location $env:CLAUDE_SESSIONS
        }
    } else {
        Write-Error "Claude session path unavailable or package removed."
    }
}

Set-Alias -Name cd-claude -Value Set-ClaudeSession

# =========================================================================== #
#                                GIT ALIASES                                  #
# =========================================================================== #

# ------------------------------------------
# PART I: PowerShell Native Functions
# ------------------------------------------

function Show-GitStatus {
  # Renamed from Get-GitStatus to avoid conflict with posh-git
  # Wrapper for 'git status'. Defaults to short+branch format (-sb), which
  # keeps color (unlike --porcelain) while staying compact.
  [CmdletBinding()]
  param([Parameter(ValueFromRemainingArguments)]$GitArgs)
  if ($GitArgs) {
    git status @GitArgs
  } else {
    git status -sb
  }
}

function Show-GitBranch {
  # Wrapper for 'git branch'. Defaults to --list (local branches).
  # Use -D <name> to delete a local branch, e.g. `branch -D old-feature`.
  [CmdletBinding()]
  param([Parameter(ValueFromRemainingArguments)]$GitArgs)
  if ($GitArgs) {
    git branch @GitArgs
  } else {
    git branch --list
  }
}

function Show-GitLog {
  # Wrapper for 'git log'. Defaults to a compact decorated graph view.
  [CmdletBinding()]
  param([Parameter(ValueFromRemainingArguments)]$GitArgs)
  if ($GitArgs) {
    git log @GitArgs
  } else {
    git log --oneline --graph --decorate -20
  }
}

function Show-GitDiff {
  # Wrapper for 'git diff'
  [CmdletBinding()]
  param([Parameter(ValueFromRemainingArguments)]$GitArgs)
  git diff @GitArgs
}

function Switch-GitBranch {
  # Wrapper for 'git switch' (and 'git checkout' when compatible)
  [CmdletBinding()]
  param([Parameter(ValueFromRemainingArguments)]$GitArgs)
  git switch @GitArgs
}

function Merge-GitBranch {
  # Wrapper for 'git merge'
  [CmdletBinding()]
  param([Parameter(ValueFromRemainingArguments)]$GitArgs)
  git merge @GitArgs
}

function Push-GitBranch {
  # Wrapper for 'git push'
  [CmdletBinding()]
  param([Parameter(ValueFromRemainingArguments)]$GitArgs)
  git push @GitArgs
}

function Sync-GitRemote {
  # Wrapper for 'git fetch'
  [CmdletBinding()]
  param(
    [switch]$NoPrune,
    [Parameter(ValueFromRemainingArguments)]$GitArgs
  )

  if ($NoPrune) {
    Write-Host "Fetching..." -ForegroundColor Cyan
    git fetch @GitArgs
  } else {
    Write-Host "Fetching (and pruning)..." -ForegroundColor Cyan
    git fetch --prune @GitArgs
  }
}

function Update-GitBranch {
  # Wrapper for 'git pull'
  [CmdletBinding()]
  param([Parameter(ValueFromRemainingArguments)]$GitArgs)
  git pull @GitArgs
}

function Add-GitItem {
  # Warpper for 'git add' with auto-bulk-adding capability
  [CmdletBinding()]
  param([Parameter(ValueFromRemainingArguments)]$GitArgs)

  if ($GitArgs) {
    git add @GitArgs
  } else {
    Write-Host "No file specified." -ForegroundColor Yellow
    Write-Host "Adding ALL tracked/untracked changes (git add .)" -ForegroundColor Yellow

    # Adding a clearer visual prompt
    if (Assert-Confirmation "Stage ALL changes (git add .)?") {
      git add .
    } else {
      Write-Warning "`nOperation cancelled."
    }
  }
}

function Submit-GitChanges {
  # Wrapper for 'git commit' with Auto-Push capability
  [CmdletBinding()]
  param(
    [switch]$NoPush,
    [Parameter(ValueFromRemainingArguments)]$GitArgs
  )

  # Pass the arguments to commit
  git commit @GitArgs

  # Check if commit was successful ($?) and NoPush is NOT active
  if ($LASTEXITCODE -eq 0 -and -not $NoPush) {
    Write-Host "" -ForegroundColor Green
    if (Assert-Confirmation "`n🚀 Auto-Push to remote?") {
      Write-Host "Pushing"
      git push
    } else {
      Write-Host "`nAuto-Push aborted by user. Changes committed locally only." -ForegroundColor Gray
    }
  } elseif ($NoPush) {
    Write-Host "Changes committed locally. (Auto-Push skipped)" -ForegroundColor Gray
  }
}

function Update-LastCommit {
  <#
  .SYNOPSIS
    Amends the last commit with staged changes.
    Defaults to keeping the previous commit message (--no-edit).
    Use -Edit to open the configured text editor.
  #>
  [CmdletBinding()]
  param(
    [switch]$Edit,
    [Parameter(ValueFromRemainingArguments)]$GitArgs
  )

  # Define base arguments
  $params = @("commit", "--amend")

  # Detect if the user manually passed a message flag (-m) via GitArgs
  # We do this because git errors out if you combine --no-edit with -m
  $hasMsgArg = ($GitArgs -join " ") -match '(-m\b|--message\b|-F\b|--file\b)'

  # Apply --no-edit ONLY if:
  #   - The user did NOT ask to edit (-Edit is false)
  #   - The user did NOT provide a new message manually
  if (-not $Edit -and -not $hasMsgArg) {
    $params += "--no-edit"
  }

  # Append any other arguments (filenames, flags, etc.)
  if ($GitArgs) {
    $params += $GitArgs
  }

  # Run Git
  git @params

  # Check if the commit was successful before prompting to push
  if ($LASTEXITCODE -eq 0) {
    Write-Host "" # Visual spacer

    # Use your existing instant-confirmation tool
    if (Assert-Confirmation "🚀 Force Push to remote?") {
      Write-Host "Force Pushing..." -ForegroundColor Cyan
      git push --force
    } else {
      Write-Host "`nForce Push skipped." -ForegroundColor Gray
    }
  }
}

function Save-GitStash {
  # Wrapper for 'git stash -u'
  [CmdletBinding()]
  param([Parameter(ValueFromRemainingArguments)]$GitArgs)
  git stash -u @GitArgs
}

function Restore-GitStash {
  # Wrapper for 'git stash pop'
  [CmdletBinding()]
  param([Parameter(ValueFromRemainingArguments)]$GitArgs)
  git stash pop @GitArgs
}

function Update-GitWip {
  <#
  .SYNOPSIS
    Auto-stages all changes.
    If last commit was 'wip', amends it (and force pushes).
    Otherwise, creates new 'wip' commit (and pushes).
  #>

  # 1. Check for changes
  if (-not $(git status --porcelain)) {
    Write-Host "No changes to save." -ForegroundColor Yellow
    return
  }

  # 2. Stage all changes
  Write-Host "Staging all changes..." -ForegroundColor Cyan
  git add .

  # 3. Get last commit message
  # 2>$null prevents error if this is a fresh repo with 0 commits
  $lastMsg = git log -1 --pretty=%s 2>$null

  if ($lastMsg -eq "wip") {
    # --- AMEND PATH ---
    Write-Host "Last commit was 'wip'. Amending..." -ForegroundColor Cyan
    git commit --amend --no-edit

    # Check for remote before pushing
    if ($(git remote)) {
      Write-Host "Force pushing update to remote..." -ForegroundColor Cyan
      git push --force
    } else {
      Write-Host "No remote detected. Local amend only." -ForegroundColor Gray
    }

  } else {
    # --- NEW COMMIT PATH ---
    Write-Host "Creating new 'wip' commit..." -ForegroundColor Cyan
    git commit -m "wip"

    # Check for remote before pushing
    if ($(git remote)) {
      Write-Host "Pushing to remote..." -ForegroundColor Cyan
      git push
    } else {
      Write-Host "No remote detected. Local commit only." -ForegroundColor Gray
    }
  }

  Write-Host "✅ Work-In-Progress state saved." -ForegroundColor Green
}

# ------------------------------------------
# PART II: Aliases
# ------------------------------------------

Set-Alias -Name status  -Value Show-GitStatus
Set-Alias -Name branch  -Value Show-GitBranch
Set-Alias -Name log     -Value Show-GitLog
Set-Alias -Name diff    -Value Show-GitDiff -Force # -Force needed: overrides built-in read-only 'diff' -> Compare-Object
Set-Alias -Name switchb -Value Switch-GitBranch
Set-Alias -Name merge   -Value Merge-GitBranch
Set-Alias -Name push    -Value Push-GitBranch
Set-Alias -Name fetch   -Value Sync-GitRemote
Set-Alias -Name pull    -Value Update-GitBranch
Set-Alias -Name add     -Value Add-GitItem
Set-Alias -Name commit  -Value Submit-GitChanges
Set-Alias -Name stash   -Value Save-GitStash
Set-Alias -Name pop     -Value Restore-GitStash
Set-Alias -Name amend   -Value Update-LastCommit
Set-Alias -Name wip     -Value Update-GitWip

# ------------------------------------------
# PART III: The "Bridge" Autocompleter
# ------------------------------------------

$GitCompleter = {
  param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

  # 1. Try to use Posh-Git if available
  if (Get-Module posh-git) {
    # This function is internal to posh-git, but we can call it.
    # It asks git to list refs based on the input.
    # This supports branches AND tags.
    return Get-GitReference $wordToComplete
  }

  # 2. Fallback: Manual method (if posh-git isn't loaded)
  $branches = git branch -a --format='%(refname:short)' 2>$null
  $branchMatches = $branches | Where-Object { $_ -like "$wordToComplete*" }
  foreach ($match in $branchMatches) {
    [System.Management.Automation.CompletionResult]::new($match, $match, 'ParameterValue', $match)
  }
}

# Apply to relevant commands
Register-ArgumentCompleter -CommandName 'Switch-GitBranch', 'switchb', 'Merge-GitBranch', 'merge', 'Push-GitBranch', 'push', 'Show-GitBranch', 'branch', 'Show-GitLog', 'log', 'Show-GitDiff', 'diff' -ScriptBlock $GitCompleter

# ------------------------------------------
# PART IV: Convenience Commands
# ------------------------------------------

# General branch switching
function main { git switch main }
function dev { git switch develop }

# Lazy commit
function adc { add; gcommit }

# Project-specific branch switching
# Add any project-specific git aliases here
# Include the project name and a timestamp for easy maintenence
function back { git switch develop-backend }           # RMLEB-IIP: Switch to the backend development branch
function cpr { git switch develop-cpr-dash }           # RMLEB-IIP: Switch to the cpr-dashboard development branch
function drc { git switch develop-drc-dash }           # RMLEB-IIP: Switch to the drc-dashboard development branch

function landing { git switch develop-landing }        # RMLEB-IIP: Switch to the landing page development branch
function land { git switch develop-landing }           # RMLEB-IIP: Switch to the landing page development branch

function packages { git switch develop-packages }      # RMLEB-IIP: Switch to the package development branch
function pack { git switch develop-packages }          # RMLEB-IIP: Switch to the package development branch
function api { git switch develop-packages }           # RMLEB-IIP: Switch to the package development branch
function api-client { git switch develop-packages }    # RMLEB-IIP: Switch to the package development branch
function client { git switch develop-packages }        # RMLEB-IIP: Switch to the package development branch
function types { git switch develop-packages }         # RMLEB-IIP: Switch to the package development branch
function ui { git switch develop-packages }            # RMLEB-IIP: Switch to the package development branch
function components { git switch develop-packages }    # RMLEB-IIP: Switch to the package development branch
function ui-components { git switch develop-packages } # RMLEB-IIP: Switch to the package development branch

function components { git switch develop-packages }    # RMLEB-IIP: Switch to the branch for handling UI components
function types { git switch develop-packages }         # RMLEB-IIP: Switch to the branch for handling UI components
function apiclient { git switch develop-packages }     # RMLEB-IIP: Switch to the branch for handling UI components


function build-types { pnpm --filter @rmleb-iip/types build }
function build-components { pnpm --filter @rmleb-iip/ui-components build }
function build-client { pnpm --filter @rmleb-iip/api-client build }
function githist { git log --author="Krishna A. Kumar" --pretty=format:"%ad: %s" --date=human }

# Typos
Set-Alias -Name celar -Value Clear-Host

# =========================================================================== #
#                             FINAL SYSTEM SETUP                              #
# =========================================================================== #

# Add the local machine modules directory to the path
$env:PSModulePath = "$env:LOCALAPPDATA\PowerShell\Modules;$env:PSModulePath"

# Apply theme immediately on startup
Update-Theme

# Git Integration (posh-git autocomplete)
Assert-PSModule -Name "posh-git"

# System Prompt Formatting (oh-my-posh theme)
Assert-BinaryTool -Name "oh-my-posh" -InstallHint "winget install JanDeDobbeleer.OhMyPosh" -OnFound {
  if (Test-Path "$env:POSH_THEMES_PATH\custom.omp.json") {
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\custom.omp.json" | Invoke-Expression
  } else {
    # Fallback if custom config is missing
    oh-my-posh init pwsh | Invoke-Expression
  }
}

# Terminal Icons
Assert-PSModule -Name "Terminal-Icons"

# Zoxide (Better `cd`)
Assert-BinaryTool -Name "zoxide" -InstallHint "winget install ajeetdsouza.zoxide" -OnFound {
  Invoke-Expression (& { (zoxide init powershell --cmd cd | Out-String) })
}

# Eza (Better `ls`)
Assert-BinaryTool -Name "eza" -InstallHint "scoop install eza" -OnFound {
  # Remove the built-in ls/dir aliases so we can define functions with the same names
  if (Test-Path alias:ls) { Remove-Item alias:ls -Force }
  if (Test-Path alias:dir) { Remove-Item alias:dir -Force }

  # Define ls as a function to include default flags (e.g., icons)
  function global:ls { eza --icons $args }
  function global:dir { eza --icons $args }

  # Define eza-specific helper functions globally
  function global:l  { eza -l --git --icons $args }         # l = long list with git and icons
  function global:ll { eza --icons $args }                  # ll = direct eza alias
  function global:la { eza -la --git --icons $args }        # la = long list, all files
  function global:lt { eza --tree --level=3 --icons $args } # lt = tree view
}

# PSReadLine (Built-in, but good to ensure options are set)
if (Get-Module -ListAvailable PSReadLine) {
  Import-Module PSReadLine
  Set-PSReadLineOption -PredictionSource History
  Set-PSReadLineOption -PredictionViewStyle InlineView # Options: InlineView, ListView
  Set-PSReadLineOption -EditMode Windows
}

# PowerToys CommandNotFound module
# We check ListAvailable because this cannot be installed via Install-Module
if (Get-Module -ListAvailable -Name Microsoft.WinGet.CommandNotFound) {
  #f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module
  Import-Module -Name Microsoft.WinGet.CommandNotFound
}
