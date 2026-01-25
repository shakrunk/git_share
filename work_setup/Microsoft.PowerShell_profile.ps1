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
  # 3
  # (or just modify however you see fit)

  Push-Location "V:\repos\git_share"
  Write-Host "Syncing with remote..." -ForegroundColor Cyan

  # Use native git commands for script reliability
  git fetch --prune
  git pull

  edital

  Copy-Item $profile -Destination . -Force

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

# Setup my workspace
function start-work {
  # Navigate to the iip repo
  cd iip

  # Setup `Comms`
  Start-AppOnDesktop -DesktopName "Comms Desktop" -App "olk" # Outlook
  Start-AppOnDesktop -DesktopName "Comms Desktop" -App "ms-teams" -ProcessName "ms-teams" # Teams

  # Setup `Main Work`
  Start-AppOnDesktop -DesktopName "Main Work Desktop" -App "zen" -ProcessName "zen"# Browser
  Start-AppOnDesktop -DesktopName "Main Work Desktop" -App "zed" -Args "." -ProcessName "Zed" # Editor
}

# Start the production api (server run only)
function start-api {
  Set-Location C:\GitRepos\rmleb-iip\backend;
  poetry run uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 8;
}

function Get-GCommitPrompt {
  #
  # Creates a smart commit prompt (with staged diffs) and copies it to the clipboard.
  # This version asks the AI to determine if changes should be split into multiple commits.
  #
  param()

  # Get the diff output
  $diffOutput = git diff --staged | Out-String

  # Check if there is actual output to avoid copying an empty prompt
  if ([string]::IsNullOrWhiteSpace($diffOutput)) {
    Write-Host "⚠️ No staged changes found. Nothing copied." -ForegroundColor Yellow
    return
  }

  # Define the prompt template using a verbatim here-string
  $promptTemplate = @'
Please review the following staged git changes:
```
{0}
```

**Instructions:**
1. **Analyze Atomicity:** Determine if these changes represent a single logical unit of work or multiple distinct units that should be split.
2. **If Multiple Commits are needed:**
   - List the suggested commits.
   - For each commit, describe exactly which files or logic chunks belong to it.
   - Provide the commit message for each in a dedicated code block labeled "plaintext".
3. **If a Single Commit is sufficient:**
   - Provide the single professional commit message in a code block labeled "plaintext".

**Constraint:**
The GUI I use will ONLY display a copy button if the code block language is specified. You must label all commit message blocks as "plaintext".
'@

  # Inject diff and copy to clipboard
  ($promptTemplate -f $diffOutput) | Set-Clipboard

  # Feedback
  Write-Host "✅ Smart split-commit prompt copied to clipboard!" -ForegroundColor Green
}
Set-Alias -Name gcommit -Value Get-GCommitPrompt

function Get-WeeklyReportPromptV3 {
  #
  # Creates a full weekly report prompt (with commits) and copies it to the clipboard.
  # This version uses a verbatim here-string to avoid all character escaping issues.
  #
  param(
    [int]$Days = 7,
    [switch]$IncludeDiffs
  )

  $since = "$Days days ago"

  # --- CONSTANTS ---
  $projectContext = @"
The Rocky Mountain Lions Eye Bank Internal Information Portal (RMLEB IIP) is a data visualization and analytics platform.
It eliminates external data transfers to 3rd-party BI tools, enabling evidence-based decision-making.
Key Modules:
1. Community/Professional Relations (CPR) Dashboard: Insights for hospital presentations.
2. Donor Recovery Center (DRC) Dashboard: Real-time performance feedback for technicians.
"@

  # --- GIT DATA COLLECTION ---
  $gitLogOutput = git log --all --since=$since --no-merges `
    --pretty=format:"### Commit %h by %an (%ar)%n**Subject:** %s%n**Description:** %b%n**Changes:**" `
    --stat=120 | Out-String

  if (-not $gitLogOutput) {
    Write-Host "⚠️  No commits found in the specified timeframe" -ForegroundColor Yellow
    return
  }

  $fileImpact = git log --all --since=$since --no-merges `
    --pretty=format: --numstat | Out-String

  $commitCount = (git rev-list --all --since=$since --no-merges --count)
  $authorCount = (git log --all --since=$since --no-merges --format='%an' | Sort-Object -Unique | Measure-Object).Count
  $filesChangedCount = (git log --all --since=$since --no-merges --name-only --pretty=format: | Sort-Object -Unique | Where-Object { $_ }).Count

  # --- PROMPT CONSTRUCTION ---
  $promptTemplate = @"
You are an expert Technical Product Manager and Full-Stack Developer.
Your goal is to generate a standalone HTML Status Report for the **RMLEB IIP** project.

**=== PROJECT CONTEXT ===**
$projectContext

**=== SUMMARY STATISTICS ===**
- Time Period: Past $Days days
- Total Commits: $commitCount
- Contributors: $authorCount
- Files Modified: $filesChangedCount

**=== DETAILED COMMIT HISTORY ===**
$gitLogOutput

**=== FILE CHANGE IMPACT ===**
$fileImpact

**=== INSTRUCTIONS ===**

**STEP 1: ANALYZE (Internal Mental Sandbox)**
Do not output this step. Read the git logs to construct the narrative.
* **Identify Major Features:** Look for heavy edits in core files.
* **Contextualize:** Translate technical changes into business value for RMLEB stakeholders (CPR and DRC teams).

**STEP 2: GENERATE THE WEBSITE**
Create a single-file, production-ready HTML document.

**Content Strategy:**
1.  **Executive Summary:** High-level overview of value delivered this week.
2.  **Key Highlights:** Bullet points of features/fixes.
3.  **Technical Deep Dive:** Granular details grouped by feature.
4.  **Impact Analysis:** Which departments (CPR vs. DRC) are affected.

**Technical Constraints & UI Requirements:**
* **Single File:** Embed all CSS/JS.
* **Styling:** Professional corporate aesthetic (Blues/Grays).
*

* **Responsive:** Must work on Desktop, Tablet, and Mobile.
* **Navigation:** * Include a **Sticky Table of Contents** on the side or top.
    * Include placeholder **"Previous Report"** and **"Next Report"** buttons at the bottom.
* **Interactivity:** Search bar for commits; Collapsible details; Smooth scrolling.

**PRINT-READY REQUIREMENT (CRITICAL):**
You must include a robust \`@media print\` CSS block.
When the user prints this page (Ctrl+P):
1.  **Hide UI Elements:** The Sticky TOC, Search bars, Navigation buttons, and "Show/Hide" toggles must disappear.
2.  **Auto-Expand:** All collapsible sections (details/summary) must be expanded by default so the full text is visible on paper.
3.  **Typography:** Ensure high contrast (black text on white background) and remove any scrollbars.
4.  **Layout:** The printed version should look like a formal memo or Word document.

**OUTPUT FORMAT:**
Provide ONLY the HTML code block.
"@

  $promptTemplate | Set-Clipboard
  Write-Host "✅ Enhanced RMLEB report prompt (V3 - Web & Print Optimized) copied!" -ForegroundColor Green
}
Set-Alias -Name report -Value Get-WeeklyReportPromptV3

# Helper function to Launch -> Wait -> Move
function Start-AppOnDesktop {
  param (
    [string]$App,         # The command to run (e.g. "zed")
    [string]$Args = $null,
    [string]$DesktopName,
    [string]$ProcessName  # Mandatory for multi-process apps (e.g. "zen", "ms-teams", etc.)
  )

  # Check if module is loaded; if not, try to find and import it
  if (-not (Get-Module -Name VirtualDesktop)) {
    if (Get-Module -ListAvailable -Name VirtualDesktop) {
      Import-Module VirtualDesktop
    } else {
      Write-Warning "VirtualDesktop module not found. Launching $App on current desktop."
      Start-Process $App -ArgumentList $Args
      return
    }
  }

  # Get the desktop index from the list by name
  $desktopInfo = Get-DesktopList | Where-Object { $_.Name -match $DesktopName } | Select-Object -First 1

  if ($null -eq $desktopInfo) {
    Write-Warning "Desktop '$DesktopName' not found. Launching on current desktop."
    Start-Process $App -ArgumentList $Args
    return
  }

  # Getthe target desktop object using the index
  $targetDesktop = Get-Desktop -Index $desktopInfo.Number

  # Capture start time and lanuch (going back 2s to account for clock skews/fast launching)
  $startTime = (Get-Date).AddSeconds(-2)

  # Start the process and pass the object through
  Start-Process $App -ArgumentList $Args -PassThru

  # Hunt for the windaw handle
  $timeout = 0
  $targetHandle = 0

  # If no ProcessName provided, assume the App name might be the process name (fallback)
  if ([string]::IsNullOrEmpty($ProcessName)) { $ProcessName = $App }

  Write-Host "Waiting for process '$ProcessName' to spawn a window..." -NoNewline

  while ($targetHandle -eq 0 -and $timeout -lt 20) {
    # Find candidates (same name, started recently, has a window)
    $candidates = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue |
      Where-Object { $_.StartTime -ge $startTime -and $_.MainWindowHandle -ne 0 }

    # Grab the first one that qualifies
    if ($candidates) {
      # On the rare chance that multiple windows appeared this fast, pick the first
      $p = $candidates | Select-Object -First 1
      $targetHandle = $p.MainWindowHandle
      break
    }

    Start-Sleep -Milliseconds 500
    Write-Host "." -NoNewline
    $timeout++
  }
  Write-Host "" # (New line)

  # Move the window if we found a handle
  if ($targetHandle -ne 0) {
    $targetHandle | Move-Window $targetDesktop
  } else {
    Write-Warning "Timed out waiting for a window handle for '$ProcessName'."
  }
}

# =========================================================================== #
#                                GIT ALIASES                                  #
# =========================================================================== #

# ------------------------------------------
# PART I: PowerShell Native Functions
# ------------------------------------------

function Show-GitStatus {
  # Renamed from Get-GitStatus to avoid conflict with posh-git
  # Wrapper for 'git status'
  [CmdletBinding()]
  param([Parameter(ValueFromRemainingArguments)]$GitArgs)
  git status @GitArgs
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

# ------------------------------------------
# PART II: Aliases
# ------------------------------------------

Set-Alias -Name status  -Value Show-GitStatus
Set-Alias -Name switchb -Value Switch-GitBranch
Set-Alias -Name merge   -Value Merge-GitBranch
Set-Alias -Name push    -Value Push-GitBranch
Set-Alias -Name fetch   -Value Sync-GitRemote
Set-Alias -Name pull    -Value Update-GitBranch
Set-Alias -Name add     -Value Add-GitItem
Set-Alias -Name commit  -Value Submit-GitChanges
Set-Alias -Name stash   -Value Save-GitStash
Set-Alias -Name pop     -Value Restore-GitStash

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
Register-ArgumentCompleter -CommandName 'Switch-GitBranch', 'switchb', 'Merge-GitBranch', 'merge', 'Push-GitBranch', 'push' -ScriptBlock $GitCompleter

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
