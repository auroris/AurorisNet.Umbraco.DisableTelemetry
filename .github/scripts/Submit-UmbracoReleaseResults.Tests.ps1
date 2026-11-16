BeforeAll {
    $script = Join-Path $PSScriptRoot 'Submit-UmbracoReleaseResults.ps1'
}

Describe 'Reporting the results of new Umbraco releases' {
    It 'passes a release only when every summary passed it, and exits with 1 when one failed' {
        $quick = Join-Path $TestDrive 'quick.json'
        $browser = Join-Path $TestDrive 'browser.json'
        Set-Content -LiteralPath $quick '[{"Release":"18.3.2","Result":"passed","Tests":"total: 2, failed: 0, succeeded: 2, skipped: 0","Failures":[]},{"Release":"17.8.2","Result":"passed","Tests":"total: 2, failed: 0, succeeded: 2, skipped: 0","Failures":[]}]'
        Set-Content -LiteralPath $browser '[{"Release":"18.3.2","Result":"passed","Tests":"total: 2, failed: 0, succeeded: 2, skipped: 0","Failures":[]},{"Release":"17.8.2","Result":"failed","Tests":"total: 2, failed: 1, succeeded: 1, skipped: 0","Failures":["Site_starts_without_telemetry_and_manages_hundreds_of_users"]}]'
        $output = pwsh -NoProfile -File $script -Releases '18.3.2,17.8.2' -Summaries "$quick,$browser" -DryRun
        $LASTEXITCODE | Should -Be 1
        $output | Should -Contain 'Passed: 18.3.2'
        $output | Should -Contain 'Failed: 17.8.2'
        ($output -join "`n") | Should -BeLike '*Would open the issue "Umbraco 17.8.2 fails the tests"*browser: Site_starts_without_telemetry_and_manages_hundreds_of_users*'
        ($output -join "`n") | Should -BeLike '*push umbraco-releases/18.3.2 and open the pull request "Add Umbraco 18.3.2"*'
    }

    It 'fails every release when a summary is missing, as when its tests never ran' {
        $quick = Join-Path $TestDrive 'quick-only.json'
        Set-Content -LiteralPath $quick '[{"Release":"18.3.2","Result":"passed","Tests":"total: 2, failed: 0, succeeded: 2, skipped: 0","Failures":[]}]'
        $output = pwsh -NoProfile -File $script -Releases '18.3.2' -Summaries "$quick,$(Join-Path $TestDrive 'browser-missing.json')" -DryRun
        $LASTEXITCODE | Should -Be 1
        $output | Should -Contain 'Failed: 18.3.2'
        ($output -join "`n") | Should -BeLike '*The browser-missing tests did not run.*'
    }

    It 'exits with 0 when every release passed' {
        $quick = Join-Path $TestDrive 'all-quick.json'
        Set-Content -LiteralPath $quick '[{"Release":"18.3.2","Result":"passed","Tests":"total: 2, failed: 0, succeeded: 2, skipped: 0","Failures":[]}]'
        $output = pwsh -NoProfile -File $script -Releases '18.3.2' -Summaries $quick -DryRun
        $LASTEXITCODE | Should -Be 0
        $output | Should -Contain 'Passed: 18.3.2'
    }
}
