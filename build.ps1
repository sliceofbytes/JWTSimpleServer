# Taken from psake https://github.com/psake/psake

<#
.SYNOPSIS
  This is a helper function that runs a scriptblock and checks the PS variable $lastexitcode
  to see if an error occcured. If an error is detected then an exception is thrown.
  This function allows you to run command-line programs without having to
  explicitly check the $lastexitcode variable.
.EXAMPLE
  exec { svn info $repository_trunk } "Error executing SVN. Please verify SVN command-line client is installed"
#>
function Exec
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)][scriptblock]$cmd,
        [Parameter(Position=1,Mandatory=0)][string]$errorMessage = ($msgs.error_bad_command -f $cmd)
    )
    & $cmd
    if ($lastexitcode -ne 0) {
        throw ("Exec: " + $errorMessage)
    }
}

if(Test-Path .\artifacts) { Remove-Item .\artifacts -Force -Recurse }

exec { & dotnet restore }

$tag = $(git tag -l --points-at HEAD)
$revision = @{ $true = "{0:00000}" -f [convert]::ToInt32("0" + $env:APPVEYOR_BUILD_NUMBER, 10); $false = "local" }[$env:APPVEYOR_BUILD_NUMBER -ne $NULL];
$suffix = @{ $true = ""; $false = "ci-$revision"}[$tag -ne $NULL -and $revision -ne "local"]
$commitHash = $(git rev-parse --short HEAD)
$buildSuffix = @{ $true = "$($suffix)-$($commitHash)"; $false = "$($branch)-$($commitHash)" }[$suffix -ne ""]

echo "build: Tag is $tag"
echo "build: Package version suffix is $suffix"
echo "build: Build version suffix is $buildSuffix" 

exec { & dotnet build JWTSimpleServer.sln -c Release --version-suffix=$buildSuffix -v q /nologo }

echo "running tests"

try {
    
        Push-Location -Path .\test\FunctionalTests
    
        exec { & dotnet test }
    } finally {
        Pop-Location
    }


if ($suffix -eq "") {
    exec { & dotnet pack .\src\JWTSimpleServer\JWTSimpleServer.csproj -c Release -o ..\..\artifacts --include-symbols --no-build }
    exec { & dotnet pack .\src\JWTSimpleServer.EntityFrameworkCoreRefreshTokenStore\JWTSimpleServer.EntityFrameworkCoreRefreshTokenStore.csproj -c Release -o ..\..\artifacts --include-symbols --no-build }
    exec { & dotnet pack .\src\JWTSimpleServer.InMemoryRefreshTokenStore\JWTSimpleServer.InMemoryRefreshTokenStore.csproj -c Release -o ..\..\artifacts --include-symbols --no-build }
    exec { & dotnet pack .\src\JWTSimpleServer.MessagePackRefreshTokenStore\JWTSimpleServer.MessagePackRefreshTokenStore.csproj -c Release -o ..\..\artifacts --include-symbols --no-build }
	exec { & dotnet pack .\src\JWTSimpleServer.RedisDistributedRefreshTokenStore\JWTSimpleServer.RedisDistributedRefreshTokenStore.csproj -c Release -o ..\..\artifacts --include-symbols --no-build }
} else {
    exec { & dotnet pack .\src\JWTSimpleServer\JWTSimpleServer.csproj -c Release -o ..\..\artifacts --include-symbols --no-build --version-suffix=$suffix }
    exec { & dotnet pack .\src\JWTSimpleServer.EntityFrameworkCoreRefreshTokenStore\JWTSimpleServer.EntityFrameworkCoreRefreshTokenStore.csproj -c Release -o ..\..\artifacts --include-symbols --no-build --version-suffix=$suffix }
    exec { & dotnet pack .\src\JWTSimpleServer.InMemoryRefreshTokenStore\JWTSimpleServer.InMemoryRefreshTokenStore.csproj -c Release -o ..\..\artifacts --include-symbols --no-build --version-suffix=$suffix }
    exec { & dotnet pack .\src\JWTSimpleServer.MessagePackRefreshTokenStore\JWTSimpleServer.MessagePackRefreshTokenStore.csproj -c Release -o ..\..\artifacts --include-symbols --no-build --version-suffix=$suffix }
	exec { & dotnet pack .\src\JWTSimpleServer.RedisDistributedRefreshTokenStore\JWTSimpleServer.RedisDistributedRefreshTokenStore.csproj -c Release -o ..\..\artifacts --include-symbols --no-build --version-suffix=$suffix }
}

