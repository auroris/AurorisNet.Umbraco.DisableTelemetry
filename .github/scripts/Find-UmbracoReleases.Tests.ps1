BeforeAll {
    $sourceScript = Join-Path $PSScriptRoot 'Find-UmbracoReleases.ps1'
    <#
    .SYNOPSIS
    Creates a fixture repository whose Directory.Build.props lists the given releases, copies the script into it and
    returns the copy's path.
    #>
    function New-Fixture([string[]] $releases) {
        $fixture = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path "$fixture/.github/scripts" -Force | Out-Null
        Copy-Item -LiteralPath $sourceScript -Destination "$fixture/.github/scripts/Find-UmbracoReleases.ps1"
        Set-Content -LiteralPath "$fixture/Directory.Build.props" "<Project><PropertyGroup><UmbracoReleases>$($releases -join ';')</UmbracoReleases></PropertyGroup></Project>"
        "$fixture/.github/scripts/Find-UmbracoReleases.ps1"
    }
}

Describe 'Finding new Umbraco releases' {
    It 'returns the stable releases after the newest listed release of each supported major version' {
        $script = New-Fixture @('17.5.0', '17.8.1', '18.3.1')
        $found = & $script -Published @('17.4.2', '17.8.1', '17.8.2', '17.9.0', '18.3.1', '18.3.2', '18.4.0-rc1')
        $found.Releases | Should -Be @('17.8.2', '17.9.0', '18.3.2')
        $found.NewMajors | Should -BeNullOrEmpty
    }

    It 'reports the newest stable release of each newer major version on its own' {
        $script = New-Fixture @('17.8.1', '18.3.1')
        $found = & $script -Published @('18.3.1', '19.0.0-rc1', '19.0.0', '19.0.1', '20.0.0-beta1')
        $found.Releases | Should -BeNullOrEmpty
        $found.NewMajors | Should -Be @('19.0.1')
    }

    It 'reads the releases from a file with several property groups' {
        $script = New-Fixture @('17.8.1', '18.3.1')
        Set-Content -LiteralPath (Join-Path (Split-Path $script) '../../Directory.Build.props') ('<Project>' +
            '<PropertyGroup><Nullable>enable</Nullable></PropertyGroup>' +
            '<PropertyGroup><UmbracoReleases>17.8.1;18.3.1</UmbracoReleases></PropertyGroup>' +
            '<PropertyGroup Condition="''$(ContinuousIntegrationBuild)'' == ''true''"><TreatWarningsAsErrors>true</TreatWarningsAsErrors>' +
            '</PropertyGroup></Project>')
        $found = & $script -Published @('17.8.1', '18.3.1', '18.3.2')
        $found.Releases | Should -Be @('18.3.2')
    }

    It 'reads the repository''s own Directory.Build.props' {
        # The fixtures above are written for the tests. The file the workflow reads can take another shape, so work out
        # what it lists by a different route than the script's and compare.
        $script = New-Fixture @('1.0.0')
        $real = Join-Path $PSScriptRoot '../../Directory.Build.props'
        Copy-Item -LiteralPath $real -Destination (Join-Path (Split-Path $script) '../../Directory.Build.props')
        $listed = [regex]::Match((Get-Content -LiteralPath $real -Raw), '<UmbracoReleases>([^<]+)</UmbracoReleases>').Groups[1].Value.Split(';') |
            ForEach-Object { [version] $_ }
        $newest = ($listed | Sort-Object)[-1]
        $next = "$($newest.Major).$($newest.Minor).$($newest.Build + 1)"
        $found = & $script -Published (@($listed | ForEach-Object { $_.ToString() }) + $next)
        $found.Releases | Should -Be @($next)
        $found.NewMajors | Should -BeNullOrEmpty
    }

    It 'finds nothing when the newest releases are listed' {
        $script = New-Fixture @('18.3.1')
        $found = & $script -Published @('18.3.0', '18.3.1', '18.4.0-rc1')
        $found.Releases | Should -BeNullOrEmpty
        $found.NewMajors | Should -BeNullOrEmpty
    }
}
