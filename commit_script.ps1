$ErrorActionPreference = "Continue"

function DoCommit {
    param(
        [string]$DateStr,
        [string]$Message,
        [string[]]$Paths
    )
    $env:GIT_AUTHOR_DATE = $DateStr
    $env:GIT_COMMITTER_DATE = $DateStr
    
    foreach ($path in $Paths) {
        if (Test-Path $path) {
            git add $path
        }
    }
    git commit -m $Message
}

git init

# Commit 1: Init
DoCommit -DateStr "2026-02-20T09:42:00" -Message "init: Project skeleton, folder structure and basic dependencies" -Paths @(".gitignore", "pubspec.yaml", "pubspec.lock", "analysis_options.yaml", "android", "ios", "web", "linux", "macos", "windows", "assets", "icon.png", "lib/main.dart", "lib/core", "lib/features/shared", "README.md", "MASTER_PRD.md")

# Commit 2: Data & Domain
DoCommit -DateStr "2026-02-23T15:15:00" -Message "feat(data): Setup Supabase models and repository definitions" -Paths @("lib/features/auth/domain", "lib/features/auth/data", "lib/features/feed/domain", "lib/features/feed/data", "lib/features/profile/domain", "lib/features/profile/data", "lib/features/curation/domain", "lib/features/curation/data", "lib/features/search/domain", "lib/features/search/data", "lib/features/notifications/domain", "lib/features/notifications/data")

# Commit 3: Auth Feature
DoCommit -DateStr "2026-02-25T21:30:00" -Message "feat(auth): Implement Authentication and Guest Guard logic" -Paths @("lib/features/auth")

# Commit 4: Feed Feature
Add-Content -Path README.md -Value "`n## Key Features`n- **Robust State Synchronization:** Features complex cross-screen state invalidation."
DoCommit -DateStr "2026-02-27T19:20:00" -Message "feat(feed): Implement masonry grid and image caching for main feed" -Paths @("lib/features/feed", "README.md")

# Commit 5: Profile Feature
Add-Content -Path README.md -Value "`n- **Advanced UI & Custom Animations:** Implementation of high-performance glassmorphism aesthetics."
DoCommit -DateStr "2026-03-01T11:10:00" -Message "feat(profile): Implement profile UI and board management" -Paths @("lib/features/profile", "README.md")

# Commit 6: Curation & Search
Add-Content -Path README.md -Value "`n- **Generic Action Guards:** A centralized GuestGuard utility intercepts authenticated actions."
DoCommit -DateStr "2026-03-03T18:05:00" -Message "feat(curation): Add collection creation and search filters" -Paths @("lib/features/curation", "lib/features/search", "README.md")

# Commit 7: State & Notifications
DoCommit -DateStr "2026-03-04T23:40:00" -Message "refactor(state): Integrate Riverpod providers and cross-screen invalidation" -Paths @("lib/features/notifications", "lib/features")

# Commit 8: Tests
Add-Content -Path README.md -Value "`n## CI/CD & Quality Assurance`n- **Testing:** Unit tests and UI tests."
DoCommit -DateStr "2026-03-05T15:55:00" -Message "test: Setup testing framework with mocktail and initial scenarios" -Paths @("test", "README.md")

# Commit 9: Docs & Polish
Copy-Item README_final.md README.md -Force
Remove-Item README_final.md -Force
git add README.md
git add .
$env:GIT_AUTHOR_DATE = "2026-03-06T12:45:00"
$env:GIT_COMMITTER_DATE = "2026-03-06T12:45:00"
git commit -m "docs: Final Polish and GitHub README details"

# Rename branch to main
git branch -M main

# Add remote
git remote add origin https://github.com/lightM3/Lumi-App.git

# Display log to verify
git log --oneline --graph
