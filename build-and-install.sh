#!/bin/bash

source ./dev-tools/scripts/git/_core.sh
source ./dev-tools/scripts/ci/typescript/_source.sh

source .scripts/setup.sh
source .scripts/modules.sh
source .scripts/params.sh
source .scripts/signature.sh
source .scripts/help.sh

enforceBashVersion 4.4


#################
#               #
#  DECLARATION  #
#               #
#################

function mapModulesVersions() {
    modulesPackageName=()
    modulesVersion=()
    executeOnModules mapModule
}

function mapExistingLibraries() {
    _modules=()
    local module
    for module in "${modules[@]}"; do
        if [[ ! -e "${module}" ]]; then continue; fi
        _modules+=(${module})
    done
    modules=("${_modules[@]}")
}

function purgeModule() {
    logInfo "Purge module: ${1}"
    deleteDir node_modules
    if [[ -e "package-lock.json" ]]; then
        rm package-lock.json
    fi
}

function usingBackend() {
    if [[ ! "${deployBackend}" ]] && [[ ! "${launchBackend}" ]]; then
        echo
        return
    fi

    echo true
}

function usingFrontend() {
    if [[ ! "${deployFrontend}" ]] && [[ ! "${launchFrontend}" ]]; then
        echo
        return
    fi

    echo true
}

function buildModule() {
    local module=${1}

    if [[ `usingFrontend` ]] && [[ ! `usingBackend` ]] && [[ "${module}" == "${backendModule}" ]]; then
        return
    fi

    if [[ `usingBackend` ]] && [[ ! `usingFrontend` ]] && [[ "${module}" == "${frontendModule}" ]]; then
        return
    fi

    compileModule ${module}
}

function testModule() {
    npm run test
}

function linkDependenciesImpl() {
    local module=${1}

    logVerbose
    logInfo "Sorting package json file: ${module}"
    sort-package-json
    throwError "Please install sort-package-json:\n   npm i -g sort-package-json"

    copyFileTo package.json dist/
    logInfo "Linking dependencies sources to: ${module}"

    if [[ `contains "${module}" "${projectModules[@]}"` ]]; then
        for otherModule in "${otherModules[@]}"; do
            local target="`pwd`/src/main/${otherModule}"
            local origin="`pwd`/../${otherModule}/src/main/ts"

            createDir ${target}
            deleteDir ${target}

            logDebug "ln -s ${origin} ${target}"
            ln -s ${origin} ${target}
            throwError "Error symlink dependency: ${otherModule}"
        done
    fi

    local i
    for (( i=0; i<${#modules[@]}; i+=1 )); do
        if [[ "${module}" == "${modules[${i}]}" ]];then break; fi

        if [[ `contains "${modules[${i}]}" "${projectModules[@]}"` ]]; then
            return
        fi

        local modulePackageName="${modulesPackageName[${i}]}"
        if [[ ! "`cat package.json | grep ${modulePackageName}`" ]]; then
            continue;
        fi

        logInfo "Linking ${modules[${i}]} (${modulePackageName}) => ${module}"
        local target="`pwd`/node_modules/${modulePackageName}"
        local origin="`pwd`/../${modules[${i}]}/dist"

        createDir ${target}
        deleteDir ${target}

        logDebug "ln -s ${origin} ${target}"
        ln -s ${origin} ${target}
        throwError "Error symlink dependency: ${modulePackageName}"

        local moduleVersion="${modulesVersion[${i}]}"
        if [[ ! "${moduleVersion}" ]]; then continue; fi

        logDebug "Updating dependency version to ${modulePackageName} => ${moduleVersion}"
        local escapedModuleName=${modulePackageName/\//\\/}

        if [[ `isMacOS` ]]; then
            sed -i '' "s/\"${escapedModuleName}\": \".*\"/\"${escapedModuleName}\": \"^${moduleVersion}\"/g" package.json
        else
            sed -i "s/\"${escapedModuleName}\": \".*\"/\"${escapedModuleName}\": \"^${moduleVersion}\"/g" package.json
        fi
        throwError "Error updating version of dependency in package.json"
    done
}

function backupPackageJson() {
    cp package.json _package.json
    throwError "Error backing up package.json in module: ${1}"
}

function restorePackageJson() {
    rm package.json
    throwError "Error restoring package.json in module: ${1}"

    mv _package.json package.json
    throwError "Error restoring package.json in module: ${1}"
}

function setupModule() {
    local module=${1}

    function cleanPackageJson() {
        local i
        for (( i=0; i<${#modules[@]}; i+=1 )); do
            local dependencyModule=${modules[${i}]}
            local dependencyPackageName="${modulesPackageName[${i}]}"

            if [[ "${module}" == "${dependencyModule}" ]]; then break; fi
            if [[ ! -e "../${dependencyModule}" ]]; then logWarning "BAH `pwd`/${dependencyModule}"; continue; fi

            local escapedModuleName=${dependencyPackageName/\//\\/}

            if [[ `isMacOS` ]]; then
                sed -i '' "/${escapedModuleName}/d" package.json
            else
                sed -i "/${escapedModuleName}/d" package.json
            fi
        done
    }

    backupPackageJson
    cleanPackageJson

    if [[ "${install}" ]]; then
        trap 'restorePackageJson' SIGINT
            deleteFile package-lock.json
            logVerbose
            logInfo "Installing ${module}"
            logVerbose
            npm install
            throwError "Error installing module"

#            npm audit fix
#            throwError "Error fixing vulnerabilities"
        trap - SIGINT
    fi

    restorePackageJson
}

function executeOnModules() {
    local toExecute=${1}
    local async=${2}

    local i
    for (( i=0; i<${#modules[@]}; i+=1 )); do
        local module="${modules[${i}]}"
        local packageName="${modulesPackageName[${i}]}"
        local version="${modulesVersion[${i}]}"
        if [[ ! -e "./${module}" ]]; then continue; fi

        cd ${module}
            if [[ "${async}" == "true" ]]; then
                ${toExecute} ${module} ${packageName} ${version} &
            else
                ${toExecute} ${module} ${packageName} ${version}
            fi
        cd ..
    done
}

function getModulePackageName() {
    local packageName=`cat package.json | grep '"name":' | head -1 | sed -E "s/.*\"name\".*\"(.*)\",?/\1/"`
    echo "${packageName}"
}

function getModuleVersion() {
    local version=`cat package.json | grep '"version":' | head -1 | sed -E "s/.*\"version\".*\"(.*)\",?/\1/"`
    echo "${version}"
}

function mapModule() {
    local packageName=`getModulePackageName`
    local version=`getModuleVersion`
    modulesPackageName+=(${packageName})
    modulesVersion+=(${version})
}

function printModule() {
    local output=`printf "Found: %-15s %-20s  %s\n" ${1} ${2} v${3}`
    logDebug "${output}"
}

function cloneNuArtModules() {
    local module
    for module in "${nuArtModules[@]}"; do
        if [[ ! -e "${module}" ]]; then
            git clone git@github.com:nu-art-js/${module}.git
        else
            cd ${module}
                git pull
            cd ..
        fi
    done
}

function mergeFromFork() {
    local repoUrl=`gitGetRepoUrl`
    if [[ "${repoUrl}" == "${boilerplateRepo}" ]]; then
        throwError "HAHAHAHA.... You need to be careful... this is not a fork..." 2
    fi

    logInfo "Making sure repo is clean..."
    gitAssertRepoClean
    git remote add public ${boilerplateRepo}
    git fetch public
    git merge public/master
    throwError "Need to resolve conflicts...."

    git submodule update dev-tools
}

function pushNuArt() {
    for module in "${nuArtModules[@]}"; do
        if [[ ! -e "${module}" ]]; then
            throwError "In order to promote a version ALL nu-art dependencies MUST be present!!!" 2
        fi
    done

    for module in "${nuArtModules[@]}"; do
        cd ${module}
            gitPullRepo
            gitNoConflictsAddCommitPush ${module} `gitGetCurrentBranch` "${pushNuArtMessage}"
        cd ..
    done
}

function deriveVersion() {
    local _version=${1}
    case "${_version}" in
        "patch" | "minor" | "major")
            echo ${_version}
            return
        ;;

        "p")
            echo "patch"
            return
        ;;

        *)
            throwError "Bad version type: ${_version}" 2
        ;;
    esac
}

function promoteNuArt() {
    local versionFile="version-nu-art.json"
    local promotionType=`deriveVersion ${promoteNuArtVersion}`
    local versionName=`getVersionName ${versionFile}`
    local promotedVersion=`promoteVersion ${versionName} ${promotionType}`

    logInfo "Promoting Nu-Art: ${versionName} => ${promotedVersion}"

    logInfo "Asserting main repo readiness to promote a version..."
    gitAssertBranch master
    gitAssertRepoClean
    gitFetchRepo
    gitAssertNoCommitsToPull
    logInfo "Main Repo is ready for version promotion"

    for module in "${nuArtModules[@]}"; do
        if [[ ! -e "${module}" ]]; then
            throwError "In order to promote a version ALL nu-art dependencies MUST be present!!!" 2
        fi

        cd ${module}
            gitAssertBranch master
            gitAssertRepoClean
            gitFetchRepo
            gitAssertNoCommitsToPull

            if [[ `git tag -l | grep ${promotedVersion}` ]]; then
                throwError "Tag already exists: v${promotedVersion}" 2
            fi
        cd ..
    done

    logInfo "Repo is ready for version promotion"
    logInfo "Starting Nu-Art Promotion..."
    for module in "${nuArtModules[@]}"; do
        cd ${module}
            logInfo "Promoting module: ${module} to version: ${promotedVersion}"
            linkDependenciesImpl ${module}
            setVersionName ${promotedVersion} package.json
        cd ..

        mapModulesVersions
    done

    for module in "${nuArtModules[@]}"; do
        cd ${module}
            gitNoConflictsAddCommitPush ${module} `gitGetCurrentBranch` "Promoted to: v${promotedVersion}"

            gitTag "v${promotedVersion}" "Promoted to: v${promotedVersion}"
            gitPushTags
            throwError "Error pushing promotion tag"
        cd ..
    done

    logInfo "Starting Apps Promotion..."
    for module in "${projectModules[@]}"; do
        cd ${module}
            logInfo "Promoting dependencies module: ${module} to version: ${promotedVersion}"
            linkDependenciesImpl ${module}
        cd ..
    done

    setVersionName ${promotedVersion} ${versionFile}
    gitNoConflictsAddCommitPush ${module} `gitGetCurrentBranch` "Promoted infra version to: v${promotedVersion}"
    gitTag "libs-v${promotedVersion}" "Promoted libs to: v${promotedVersion}"
    gitPushTags
    throwError "Error pushing promotion tag"
}

function promoteApps() {
    logInfo "Asserting repo readiness to promote a version..."

    local versionFile="version-app.json"
    local promotionType=`deriveVersion ${promoteAppVersion}`
    local versionName=`getVersionName ${versionFile}`
    local promotedVersion=`promoteVersion ${versionName} ${promotionType}`

    gitAssertBranch "${allowedBranchesForPromotion[@]}"
    gitAssertRepoClean
    gitFetchRepo
    gitAssertNoCommitsToPull

    logInfo "Repo is ready for version promotion: ${promotionType}"


    logInfo "Promoting Apps: ${versionName} => ${promotedVersion}"
    if [[ `git tag -l | grep ${promotedVersion}` ]]; then
        throwError "Tag already exists: v${promotedVersion}" 2
    fi


    for module in "${projectModules[@]}"; do
        cd ${module}
            logInfo "Promoting module: ${module} to version: ${promotedVersion}"
            setupModule ${module}
            setVersionName ${promotedVersion} package.json
        cd ..
    done

    setVersionName ${promotedVersion} ${versionFile}
    gitNoConflictsAddCommitPush ${module} `gitGetCurrentBranch` "Promoted apps version to: v${promotedVersion}"
    gitTag "apps-v${promotedVersion}" "Promoted apps to: v${promotedVersion}"
    gitPushTags
    throwError "Error pushing promotion tag"
}

function publishNuArt() {
    for module in "${nuArtModules[@]}"; do
        cd ${module}
            logInfo "publishing module: ${module}"
            cp package.json dist/
            cd dist
                npm publish --access public
                throwError "Error publishing module: ${module}"
            cd ..
        cd ..
    done
}

function getFirebaseConfig() {
    logInfo "Fetching config for serving function locally..."
    firebase functions:config:get > .runtimeconfig.json
    throwError "Error while getting functions config"
}

function copyConfigFile() {
    local message=${1}
    local pathTo=${2}
    local envFile=${3}
    local targetFile=${4}
    local envConfigFile="${pathTo}/${envFile}"
    logInfo "${message}"

    if [[ ! -e "${envConfigFile}" ]]; then
        throwError "File not found: ${envConfigFile}" 2
    fi
    cp "${envConfigFile}" ${targetFile}


}

function setEnvironment() {
    logInfo "Setting envType: ${envType}"
    copyConfigFile "Setting firebase.json for env: ${envType}" "./.config" "firebase-${envType}.json" "firebase.json"
    copyConfigFile "Setting .firebaserc for env: ${envType}" "./.config" ".firebaserc-${envType}" ".firebaserc"

    cd ${backendModule}
        copyConfigFile "Setting frontend config.ts for env: ${envType}" "./.config" "config-${envType}.ts" "./src/main/config.ts"
    cd - > /dev/null

    cd ${frontendModule}
        copyConfigFile "Setting frontend config.ts for env: ${envType}" "./.config" "config-${envType}.ts" "./src/main/config.ts"
    cd - > /dev/null

    firebase use `getJsonValueForKey .firebaserc "default"`
}

function compileOnCodeChanges() {
    logDebug "Stop all fswatch listeners..."
    killAllProcess fswatch

    pids=()
    local sourceDirs=()
    for module in ${modules[@]}; do
        if [[ ! -e "./${module}" ]]; then continue; fi
        sourceDirs+=(${module}/src)

        logInfo "Dirt watcher on: ${module}/src => bash build-and-install.sh --flag-dirty=${module}"
        fswatch -o -0 ${module}/src | xargs -0 -n1 -I{} bash build-and-install.sh --flag-dirty=${module} &
        pids+=($!)
    done

    logInfo "Cleaning team on: ${sourceDirs[@]} => bash build-and-install.sh --clean-dirt"
    fswatch -o -0 ${sourceDirs[@]} | xargs -0 -n1 -I{} bash build-and-install.sh --clean-dirt &
    pids+=($!)

    for pid in "${pids[@]}"; do
        wait ${pid}
    done
}

function compileModule() {
    local compileLib=${1}

    if [[ "${cleanDirt}" ]] && [[ ! -e ".dirty" ]]; then
        return
    fi

    if [[ "${clean}" ]]; then
        logVerbose
        clearFolder dist
    fi

    logInfo "${compileLib} - Compiling..."
    npm run build
    throwError "Error compiling:  ${compileLib}"

    cp package.json dist/
    deleteFile .dirty
    logInfo "${compileLib} - Compiled!"
}

function lintModule() {
    local module=${1}

    logInfo "${module} - linting..."
    tslint --project tsconfig.json
    throwError "Error while linting:  ${module}"

    logInfo "${module} - linted!"
}

#################
#               #
#    PREPARE    #
#               #
#################

# Handle recursive sync execution
if [[ ! "${1}" =~ "dirt" ]]; then
    signature
    printCommand "$@"
fi

extractParams "$@"

if [[ "${dirtyLib}" ]]; then
    touch ${dirtyLib}/.dirty
    logInfo "flagged ${dirtyLib} as dirty... waiting for cleaning team"
    exit 0
fi

if [[ "${cleanDirt}" ]]; then
    logDebug "Cleaning team is ready, stalling 3 sec for dirt to pile up..."
    sleep 3s
else
    printDebugParams ${debug} "${params[@]}"
fi


#################
#               #
#   EXECUTION   #
#               #
#################

if [[ "${#modules[@]}" == 0 ]]; then
    modules+=(${nuArtModules[@]})
    modules+=(${projectModules[@]})
fi

if [[ "${mergeOriginRepo}" ]]; then
    mergeFromFork
    logInfo "Merged from origin boilerplate... DONE"
    exit 0
fi

if [[ "${cloneNuArt}" ]]; then
    cloneNuArtModules
    bash $0 --setup
fi

mapExistingLibraries
mapModulesVersions
executeOnModules printModule

# BUILD

if [[ "${purge}" ]]; then
    executeOnModules purgeModule
fi

if [[ "${envType}" ]]; then
    setEnvironment
fi

if [[ "${setup}" ]]; then
    executeOnModules setupModule
fi

if [[ "${linkDependencies}" ]]; then
    executeOnModules linkDependenciesImpl
fi

if [[ "${build}" ]]; then
    executeOnModules buildModule
fi

if [[ "${lint}" ]]; then
    executeOnModules lintModule
fi

if [[ "${test}" ]]; then
    executeOnModules testModule
fi

# LAUNCH

if [[ "${launchBackend}" ]]; then
    npm list -g nodemon > /dev/null
    throwError "nodemon package is missing... Please install nodemon:\n npm i -g nodemon"

    setupBackend
    cd ${backendModule}
        if [[ "${launchFrontend}" ]]; then
            npm run serve &
        else
            npm run serve
        fi
    cd ..
fi

if [[ "${launchFrontend}" ]]; then
    cd ${frontendModule}
        if [[ "${launchBackend}" ]]; then
            npm run dev &
        else
            npm run dev
        fi
    cd ..
fi

# Deploy

if [[ "${deployBackend}" ]] || [[ "${deployFrontend}" ]]; then
    if [[ ! "${envType}" ]]; then
        throwError "MUST set env while deploying!!" 2
    fi

    firebaseProject=`getJsonValueForKey .firebaserc "default"`

    if [[ "${deployBackend}" ]]; then
        logInfo "Using firebase project: ${firebaseProject}"
        firebase use ${firebaseProject}
        firebase deploy --only functions
        throwError "Error while deploying functions"
    fi

    if [[ "${deployFrontend}" ]]; then
        logInfo "Using firebase project: ${firebaseProject}"
        firebase use ${firebaseProject}
        firebase deploy --only hosting
        throwError "Error while deploying hosting"
    fi
fi

# PRE-Launch and deploy

if [[ "${promoteAppVersion}" ]]; then
    promoteApps
fi

# OTHER

if [[ "${pushNuArtMessage}" ]]; then
    pushNuArt
fi

if [[ "${promoteNuArtVersion}" ]]; then
    gitAssertOrigin "${boilerplateRepo}"
    promoteNuArt
fi

if [[ "${publish}" ]]; then
    gitAssertOrigin "${boilerplateRepo}"
    publishNuArt
    executeOnModules setupModule
    gitNoConflictsAddCommitPush ${module} `gitGetCurrentBranch` "built with new dependencies version"
fi

if [[ "${listen}" ]]; then
    compileOnCodeChanges
fi