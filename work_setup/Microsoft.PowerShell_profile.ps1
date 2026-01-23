# --------------------------------------------------------------------------- #
#                              SYSTEM COMMANDS                                #
# --------------------------------------------------------------------------- #

# Output Encoding
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Edit this file (using my command for "edit aliases" in my linux setup)
function edital { nvim $profile; . $profile }

# Edit this function and update it in the share file
function wedital {
  Push-Location "C:/Users/kkumar/Documents/git-repos/git_share/work_setup" # Store current location to return to later
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

    add; commit -m $newMsg # Stage, Commit, and Push
    Write-Host "Success: Profile updated and pushed ($newMsg)" -ForegroundColor Green
  } else { Write-Host "No changes detected. Nothing to commit." -ForegroundColor Yellow }
  Pop-Location
}

# Semantically accurate commands
Set-Alias -Name edit -Value nvim

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


# --------------------------------------------------------------------------- #
#                                GIT ALIASES                                  #
# --------------------------------------------------------------------------- #

# Don't say "git"
function st { git switch $args }
function status { git status }
function fetch { Write-Host "Fetching with 'prune'..."; git fetch --prune }
function pull { git pull }
function add { git add . }
function commit { git commit $args; push }
function commit-np { git commit $args }
function merge { git merge $args }
function push { git push }
function stash { git stash -u }
function pop { git stash pop }

# Lazy commit
function adc { add; gcommit }

# General branch switching
function main { git switch main }
function dev { git switch develop }

# Project-specific branch switching
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


# --------------------------------------------------------------------------- #
#                                SYSTEM SETUP                                 #
# --------------------------------------------------------------------------- #

# Add the local machine modules directory to the path
$env:PSModulePath = "$env:LOCALAPPDATA\PowerShell\Modules;$env:PSModulePath"

# Make the system prompt look good with oh-my-posh
oh-my-posh init pwsh --config 'takuya' | Invoke-Expression

# Make use zoxide for more agile directory changing (and replace the 'cd' aliases with it)
Invoke-Expression (& { (C:\Users\kkumar\AppData\Local\Microsoft\WinGet\Packages\ajeetdsouza.zoxide_Microsoft.Winget.Source_8wekyb3d8bbwe\zoxide.exe init powershell --cmd cd) -join "`n" })

# Use eza to get better directory listing outputs (replace built-in aliases)
Set-Alias -Name ls -Value eza -Force -Option AllScope
Set-Alias -Name dir -Value eza -Force -Option AllScope

# Use eza to get better directory listing outputs (replace built-in aliases)
function l { eza -l --git --icons $args }           # l = long list with git and icons
function ll { eza --icons $args }                   # ll = direct eza alias
function la { eza -la --git --icons $args }         # la = long list, all files
function lt { eza --tree --level=3 --icons $args }  # lt = tree view, 3 levels deep


# --------------------------------------------------------------------------- #
#                   CUSTOM FUNCTIONS (longer operations)                      #
# --------------------------------------------------------------------------- #

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

# --------------------------------------------------------------------------- #
#                    FINAL ALIASES FOR CUSTOM FUNCTIONS                       #
# --------------------------------------------------------------------------- #

Set-Alias -Name gcommit -Value Get-GCommitPrompt
Set-Alias -Name report -Value Get-WeeklyReportPromptV3
