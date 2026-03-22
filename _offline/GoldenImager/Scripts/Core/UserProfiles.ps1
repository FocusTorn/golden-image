function GetUserName {
    if ($script:Params.ContainsKey("User")) {
        return $script:Params.Item("User")
    }

    return $env:USERNAME
}



# Returns the directory path of the specified user, exits script if user path can't be found
function GetUserDirectory {
    param (
        $userName,
        $fileName = "",
        $exitIfPathNotFound = $true
    )

    try {
        if (-not (CheckIfUserExists -userName $userName) -and $userName -ne "*") {
            Write-Error "User $userName does not exist on this system"
            AwaitKeyToExit
        }

        $userDirectoryExists = Test-Path "$env:SystemDrive\Users\$userName"
        $userPath = "$env:SystemDrive\Users\$userName\$fileName"

        if ((Test-Path $userPath) -or ($userDirectoryExists -and (-not $exitIfPathNotFound))) {
            return $userPath
        }

        $userDirectoryExists = Test-Path ($env:USERPROFILE -Replace ('\\' + $env:USERNAME + '$'), "\$userName")
        $userPath = $env:USERPROFILE -Replace ('\\' + $env:USERNAME + '$'), "\$userName\$fileName"

        if ((Test-Path $userPath) -or ($userDirectoryExists -and (-not $exitIfPathNotFound))) {
            return $userPath
        }
    }
    catch {
        Write-Error "Something went wrong when trying to find the user directory path for user $userName. Please ensure the user exists on this system"
        AwaitKeyToExit
    }

    Write-Error "Unable to find user directory path for user $userName"
    AwaitKeyToExit
}


function CheckIfUserExists {
    param (
        $userName
    )

    if ($userName -match '[<>:"|?*]') {
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($userName)) {
        return $false
    }

    try {
        $userExists = Test-Path "$env:SystemDrive\Users\$userName"

        if ($userExists) {
            return $true
        }

        $userExists = Test-Path ($env:USERPROFILE -Replace ('\\' + $env:USERNAME + '$'), "\$userName")

        if ($userExists) {
            return $true
        }
    }
    catch {
        Write-Error "Something went wrong when trying to find the user directory path for user $userName. Please ensure the user exists on this system"
    }

    return $false
}


# Target is determined from $script:Params["AppRemovalTarget"] or defaults to "AllUsers"
# Target values: "AllUsers" (removes for all users + from image), "CurrentUser", or a specific username
function GetTargetUserForAppRemoval {
    if ($script:Params.ContainsKey("AppRemovalTarget")) {
        return $script:Params["AppRemovalTarget"]
    }
    
    return "AllUsers"
}


function GetFriendlyTargetUserName {
    $target = GetTargetUserForAppRemoval

    switch ($target) {
        "AllUsers" { return "all users" }
        "CurrentUser" { return "the current user" }
        default { return "user $target" }
    }
}
