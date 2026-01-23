# =========================================================================== #
#                              SYSTEM COMMANDS                                #
# =========================================================================== #

# Output Encoding
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Edit this file (using my command name for "edit aliases" from my linux setup)
function edital { zed $profile; . $profile }

# Edit this file and update it in the share repo
function wedital {
  Push-Location "V:\repos\git_share" # Store current location to return to later
  Write-Host "Syncing with remote..." -ForegroundColor Cyan; fetch; pull # Sync
  edital; Copy-Item $profile -Destination . -Force # Edit profile, copy to work share repo
  if ($(git status --porcelain)) { # Check if there are actual changes to commit
    $lastMsg = git log -1 --pretty=format:"%s" # Get last commit (subject line)

    # Regex match for 'shr' followed by digits
    if ($lastMsg -match 'shr(\d+)') {
      $prevNum = [int]$matches[1]
      $nextNum = $prevNum + 1
    } else {
      $nextNum = 1 # Fallback if the pattern breaks
    }

    # Format strings to ensure 2 digits (e.g. 5 becomes 05)
    $newMsg = "shr{0:D2}" -f $nextNum

    add .; commit -m $newMsg # Stage (all so profile name may change), Commit, and Push
    Write-Host "Success: Profile updated and pushed ($newMsg)" -ForegroundColor Green
  } else { Write-Host "No changes detected. Nothing to commit." -ForegroundColor Yellow }
  Pop-Location
}

# Semantically accurate commands
Set-Alias -Name edit -Value zed
Set-Alias -Name say  -Value Write-Host


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
        $confirmation = Read-Host -Prompt "Type 'y' to confirm git add ."
        if ($confirmation -eq 'y') {
            git add .
        } else {
            Write-Warning "Operation cancelled."
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
        Write-Host "🚀 Auto-Pushing..." -ForegroundColor Green
        git push
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

# Lazy commit
function adc { add; gcommit }

# General branch switching
function main { git switch main }
function dev { git switch develop }

# Project-specific branch switching
# Add any project-specific git aliases here
# Include the project name and a timestamp for easy maintenence


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

#
# Creates a smart commit prompt (with staged diffs) and copies it to the clipboard.
# This version asks the AI to determine if changes should be split into multiple commits.
#
function Get-GCommitPrompt {
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


#
# Creates a full weekly report prompt (with commits) and copies it to the clipboard.
# This version uses a verbatim here-string to avoid all character escaping issues.
#
function Get-WeeklyReportPromptV3 {
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


# =========================================================================== #
#                         KANATA MANAGEMENT                                   #
# =========================================================================== #

function Install-Kanata {
    <#
    .SYNOPSIS
        One-time setup: Generates the launcher script and registers the Scheduled Task.
        Run this only if you change the Kanata path or if the task is deleted.
    #>

    # 1. Setup Variables
    $Dir = "$env:USERPROFILE\.config"
    $Exe = "$Dir\kanata.exe"
    $Kbd = "$Dir\kanata.kbd"
    $Log = "$Dir\kanata.log"
    $Launcher = "$Dir\kanata_launcher.ps1"
    $PwshPath = (Get-Process -Id $PID).Path

    # 2. Unblock DLL if present
    Unblock-File "$Dir\interception.dll" -ErrorAction SilentlyContinue

    # 3. Create PowerShell Launcher Script
    $LauncherContent = @"
Set-Location "$Dir"
try {
    & "$Exe" --cfg "$Kbd" *>&1 | Out-File -FilePath "$Log" -Encoding utf8
} catch {
    "CRITICAL LAUNCH ERROR: `$_" | Out-File -FilePath "$Log" -Append
}
"@
    Set-Content -Path $Launcher -Value $LauncherContent -Force
    Write-Host "Launcher script created at $Launcher" -ForegroundColor Gray

    # 4. Create Task Action
    $Action = New-ScheduledTaskAction -Execute $PwshPath `
        -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File ""$Launcher""" `
        -WorkingDirectory $Dir

    # 5. Register Task
    $Trigger = New-ScheduledTaskTrigger -AtLogon
    $Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
    $Settings = New-ScheduledTaskSettingsSet `
        -ExecutionTimeLimit (New-TimeSpan -Days 0) `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -MultipleInstances IgnoreNew `
        -Priority 0

    Unregister-ScheduledTask -TaskName "KanataKbHook" -Confirm:$false -ErrorAction SilentlyContinue

    Register-ScheduledTask -TaskName "KanataKbHook" `
        -Action $Action `
        -Trigger $Trigger `
        -Principal $Principal `
        -Settings $Settings `
        -Force | Out-Null

    Write-Host "✅ Kanata Scheduled Task registered successfully." -ForegroundColor Green
}

function Restart-Kanata {
    <#
    .SYNOPSIS
        Runtime control: Kills any running Kanata process and kicks off the Scheduled Task.
        Use this after exiting via layer binds.
    #>

    # 1. Kill existing instances
    Stop-Process -Name "kanata" -Force -ErrorAction SilentlyContinue

    # 2. Start the Task
    Write-Host "Starting Kanata..." -ForegroundColor Cyan
    try {
        Start-ScheduledTask -TaskName "KanataKbHook" -ErrorAction Stop
    } catch {
        Write-Error "Could not start task. Has it been registered? Try running 'Install-Kanata' first."
        return
    }

    # 3. Verify with Retry Loop
    $Retries = 0
    while ($Retries -lt 5) {
        Start-Sleep -Seconds 1
        if (Get-Process kanata -ErrorAction SilentlyContinue) {
            Write-Host "SUCCESS: Kanata is active." -ForegroundColor Green
            return
        }
        $Retries++
    }

    # 4. Failure Handler
    Write-Host "ERROR: Kanata process not found after 5 seconds." -ForegroundColor Red
    $Log = "$env:USERPROFILE\.config\kanata.log"
    if (Test-Path $Log) {
        Get-Content $Log -Tail 10 | Write-Host -ForegroundColor Yellow
    }
}


# =========================================================================== #
#                    FINAL ALIASES FOR CUSTOM FUNCTIONS                       #
# =========================================================================== #

Set-Alias -Name gcommit -Value Get-GCommitPrompt
Set-Alias -Name report -Value Get-WeeklyReportPromptV3
Set-Alias -Name kstart -Value Restart-Kanata # Quick alias for the daily driver command


# =========================================================================== #
#                                SYSTEM SETUP                                 #
# =========================================================================== #

# Apply theme immediately on startup
Update-Theme

# Set up git function autocomplete
if (Get-Module -ListAvailable posh-git) {
    Import-Module posh-git
} else {
    Write-Warning "posh-git not found. ."
    Install-Module posh-git -Scope AllUsers
    Import-Module posh-git
}

# Make the system prompt look good with oh-my-posh
oh-my-posh init pwsh --config $env:POSH_THEMES_PATH\custom.omp.json | Invoke-Expression

# Set up terminal icons
Import-Module -Name Terminal-Icons

# Set up zoxide
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# Use eza to get better directory listing outputs (replace built-in aliases)
Set-Alias -Name ls -Value eza -Force -Option AllScope
Set-Alias -Name dir -Value eza -Force -Option AllScope

# Use eza to get better directory listing outputs (replace built-in aliases)
function l { eza -l --git --icons $args }           # l = long list with git and icons
function ll { eza --icons $args }                   # ll = direct eza alias
function la { eza -la --git --icons $args }         # la = long list, all files
function lt { eza --tree --level=3 --icons $args }  # lt = tree view, 3 levels deep

# Set PSReadLine options for prediction
Import-Module PSReadLine
Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows

#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module

Import-Module -Name Microsoft.WinGet.CommandNotFound
#f45873b3-b655-43a6-b217-97c00aa0db58
