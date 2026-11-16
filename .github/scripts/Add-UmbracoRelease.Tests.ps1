BeforeAll {
    $script = Join-Path $PSScriptRoot 'Add-UmbracoRelease.ps1'
    <#
    .SYNOPSIS
    Creates a fixture repository whose Directory.Build.props lists the given releases, with a README that states each
    major version's releases between markers and a NuGet page that lists them after "running Umbraco ", each beside an
    example that names other releases. Returns its folder.
    #>
    function New-Fixture([string[]] $releases) {
        $fixture = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path "$fixture/docs" -Force | Out-Null
        Set-Content -LiteralPath "$fixture/Directory.Build.props" @"
<Project>
  <PropertyGroup>
    <UmbracoReleases>$($releases -join ';')</UmbracoReleases>
    <UmbracoMinimumVersion>$($releases[0])</UmbracoMinimumVersion>
    <UmbracoMaximumVersion>$($releases[-1])</UmbracoMaximumVersion>
    <UmbracoVersion>$($releases[-1])</UmbracoVersion>
    <UmbracoStarterKitVersion Condition="`$(UmbracoVersion.StartsWith('17.'))">17.0.0</UmbracoStarterKitVersion>
  </PropertyGroup>
</Project>
"@
        $majors = @($releases | Group-Object { ([version] $_).Major } | Sort-Object { [int] $_.Name } -Descending | ForEach-Object {
            [pscustomobject]@{ Major = $_.Name; Range = $_.Count -eq 1 ? $_.Group[0] : "$($_.Group[0]) to $($_.Group[-1])" }
        })
        $rows = $majors | ForEach-Object { "| $($_.Major) | <!-- umbraco-releases $($_.Major) -->$($_.Range)<!-- /umbraco-releases --> |" }
        Set-Content -LiteralPath "$fixture/README.md" (@($rows) + 'For example, 18.3.1.2 supports every Umbraco 18 release up to 18.3.1.')
        Set-Content -LiteralPath "$fixture/docs/NUGET.md" "Add the package to a website running Umbraco $($majors.Range -join ' or '). For example, 18.3.1.2 supports Umbraco 18.0.0 to 18.3.1."
        $fixture
    }

    <#
    .SYNOPSIS
    Returns the text of a file in the fixture.
    #>
    function Get-Text([string] $fixture, [string] $path) {
        Get-Content -LiteralPath (Join-Path $fixture $path) -Raw
    }

    <#
    .SYNOPSIS
    Returns the value of a property in the fixture's Directory.Build.props.
    #>
    function Get-Property([string] $fixture, [string] $name) {
        ([xml] (Get-Content -LiteralPath "$fixture/Directory.Build.props")).Project.PropertyGroup.$name
    }
}

Describe 'Adding Umbraco releases' {
    It 'adds the newest release and moves the maximum, the tested release and its major version''s releases to it' {
        $fixture = New-Fixture @('17.5.0', '17.8.1', '18.0.0', '18.3.1')
        & $script -Releases '18.3.2' -Repository $fixture | Should -Be '18.3.2'
        Get-Property $fixture 'UmbracoReleases' | Should -Be '17.5.0;17.8.1;18.0.0;18.3.1;18.3.2'
        Get-Property $fixture 'UmbracoMinimumVersion' | Should -Be '17.5.0'
        Get-Property $fixture 'UmbracoMaximumVersion' | Should -Be '18.3.2'
        Get-Property $fixture 'UmbracoVersion' | Should -Be '18.3.2'
        $readme = Get-Text $fixture 'README.md'
        $readme | Should -BeLike '*<!-- umbraco-releases 18 -->18.0.0 to 18.3.2<!-- /umbraco-releases -->*'
        $readme | Should -BeLike '*<!-- umbraco-releases 17 -->17.5.0 to 17.8.1<!-- /umbraco-releases -->*'
        $readme | Should -BeLike '*18.3.1.2 supports every Umbraco 18 release up to 18.3.1.*'
        Get-Text $fixture 'docs/NUGET.md' |
            Should -BeLike 'Add the package to a website running Umbraco 18.0.0 to 18.3.2 or 17.5.0 to 17.8.1. For example, 18.3.1.2 supports Umbraco 18.0.0 to 18.3.1.*'
    }

    It 'keeps the list oldest first when a release of an older major version arrives' {
        $fixture = New-Fixture @('17.5.0', '17.8.1', '18.3.1')
        & $script -Releases '17.8.2' -Repository $fixture | Should -Be '17.8.2'
        Get-Property $fixture 'UmbracoReleases' | Should -Be '17.5.0;17.8.1;17.8.2;18.3.1'
        Get-Property $fixture 'UmbracoMaximumVersion' | Should -Be '18.3.1'
        Get-Property $fixture 'UmbracoVersion' | Should -Be '18.3.1'
        $readme = Get-Text $fixture 'README.md'
        $readme | Should -BeLike '*<!-- umbraco-releases 17 -->17.5.0 to 17.8.2<!-- /umbraco-releases -->*'
        $readme | Should -BeLike '*<!-- umbraco-releases 18 -->18.3.1<!-- /umbraco-releases -->*'
        Get-Text $fixture 'docs/NUGET.md' | Should -BeLike '*running Umbraco 18.3.1 or 17.5.0 to 17.8.2. For example*'
    }

    It 'lists a third major version''s releases first, and turns a release on its own into a range' {
        $fixture = New-Fixture @('17.8.1', '18.3.1', '19.0.0')
        & $script -Releases '19.0.1' -Repository $fixture | Should -Be '19.0.1'
        Get-Text $fixture 'README.md' | Should -BeLike '*<!-- umbraco-releases 19 -->19.0.0 to 19.0.1<!-- /umbraco-releases -->*'
        Get-Text $fixture 'docs/NUGET.md' | Should -BeLike '*running Umbraco 19.0.0 to 19.0.1, 18.3.1 or 17.8.1. For example*'
    }

    It 'changes nothing when the NuGet page has no list of releases' {
        $fixture = New-Fixture @('17.8.1', '18.3.1')
        Set-Content -LiteralPath "$fixture/docs/NUGET.md" 'Add the package to a website.'
        $props = Get-Text $fixture 'Directory.Build.props'
        $readme = Get-Text $fixture 'README.md'
        { & $script -Releases '18.3.2' -Repository $fixture } | Should -Throw '*NUGET.md has no list of supported releases*'
        Get-Text $fixture 'Directory.Build.props' | Should -Be $props
        Get-Text $fixture 'README.md' | Should -Be $readme
    }

    It 'accepts several releases in one comma-separated value' {
        $fixture = New-Fixture @('17.8.1', '18.3.1')
        & $script -Releases '18.3.2,17.8.2' -Repository $fixture | Should -Be @('18.3.2', '17.8.2')
        Get-Property $fixture 'UmbracoReleases' | Should -Be '17.8.1;17.8.2;18.3.1;18.3.2'
    }

    It 'changes nothing for a release that is already listed' {
        $fixture = New-Fixture @('18.3.1')
        $before = Get-Content -LiteralPath "$fixture/Directory.Build.props" -Raw
        & $script -Releases '18.3.1' -Repository $fixture | Should -BeNullOrEmpty
        Get-Content -LiteralPath "$fixture/Directory.Build.props" -Raw | Should -Be $before
    }

    It 'refuses a release of a major version the list does not include' {
        $fixture = New-Fixture @('17.8.1', '18.3.1')
        { & $script -Releases '19.0.0' -Repository $fixture } | Should -Throw '*major version the package does not support*'
    }

    It 'refuses a value that is not a release number' {
        $fixture = New-Fixture @('18.3.1')
        { & $script -Releases '18.3.2-rc1' -Repository $fixture } | Should -Throw '*not a release number*'
    }
}
