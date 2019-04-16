#!/bin/bash

source ./dev-tools/scripts/git/_core.sh
source ./dev-tools/scripts/ci/typescript/_source.sh
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
    if [[ ! "${deployBackend}" ]] && [[ ! "${launchBackend}" ]] && [[ ! "${serveBackend}" ]]; then
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

    sort-package-json
    throwError "Please install sort-package-json:\n   npm i -g sort-package-json"

    function cleanPackageJson() {
        local i
        for (( i=0; i<${#modules[@]}; i+=1 )); do
            if [[ "${module}" == "${modules[${i}]}" ]]; then break; fi

            local moduleName="${modulesPackageName[${i}]}"
            local escapedModuleName=${moduleName/\//\\/}

            if [[ `isMacOS` ]]; then
                sed -i '' "/${escapedModuleName}/d" package.json
            else
                sed -i "/${escapedModuleName}/d" package.json
            fi
        done
    }

    if [[ "${linkDependencies}" ]]; then
        backupPackageJson
        cleanPackageJson
    fi

    if [[ "${install}" ]]; then
        trap 'restorePackageJson' SIGINT
            deleteFile package-lock.json
            logVerbose
            logInfo "Installing ${module}"
            logVerbose
            npm install
            throwError "Error installing module"
        trap - SIGINT
    fi

    if [[ "${linkDependencies}" ]]; then
        restorePackageJson
        linkDependenciesImpl $@
    fi
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
        throwError "HAHAHAHA.... You need to be careful... this is not a fork..."
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
            throwError "In order to promote a version ALL nu-art dependencies MUST be present!!!"
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
            echo
            return
        ;;
    esac

    if [[ ! "${_version}" ]]; then
        throwError "Bad version type: ${promoteNuArtVersion}"
    fi

}

function promoteNuArt() {
    local versionPromotion=`deriveVersion ${promoteNuArtVersion}`
    local versionName=`getVersionName version-nu-art.json`
    local promotedVersion=`promoteVersion ${versionName} ${versionPromotion}`

    logInfo "Promoting Nu-Art: ${versionName} => ${promotedVersion}"

    logInfo "Asserting repo readiness to promote a version..."

    gitAssertBranch master
    gitAssertRepoClean
    gitFetchRepo
    gitAssertNoCommitsToPull

    for module in "${nuArtModules[@]}"; do
        if [[ ! -e "${module}" ]]; then
            throwError "In order to promote a version ALL nu-art dependencies MUST be present!!!"
        fi

        cd ${module}
            gitAssertBranch master
            gitAssertRepoClean
            gitFetchRepo
            gitAssertNoCommitsToPull

            if [[ `git tag -l | grep ${promotedVersion}` ]]; then
                throwError "Tag already exists: v${promotedVersion}"
            fi
        cd ..
    done

    logInfo "Repo is ready for version promotion"

    for module in "${nuArtModules[@]}"; do
        cd ${module}
            logInfo "Promoting module: ${module} to version: ${promotedVersion}"
            setupModule ${module}

            setVersionName ${promotedVersion} package.json
            gitNoConflictsAddCommitPush ${module} `gitGetCurrentBranch` "Promoted to: v${promotedVersion}"

            gitTag "v${promotedVersion}" "Promoted to: v${promotedVersion}"
            gitPushTags
            throwError "Error pushing promotion tag"
        cd ..

        mapModulesVersions
    done

    setVersionName ${promotedVersion} version-nu-art.json
    gitNoConflictsAddCommitPush ${module} `gitGetCurrentBranch` "Promoted to: v${promotedVersion}"
}

function promoteApps() {
    logInfo "Asserting repo readiness to promote a version..."

    local _version=`deriveVersion ${promoteAppVersion}`
    gitAssertBranch master
    gitAssertRepoClean
    gitFetchRepo
    gitAssertNoCommitsToPull

    logInfo "Repo is ready for version promotion"

    local versionPromotion=`deriveVersion ${promoteNuArtVersion}`
    local versionName=`getVersionName version-app.json`
    local promotedVersion=`promoteVersion ${versionName} ${versionPromotion}`

    logInfo "Promoting Apps: ${versionName} => ${promotedVersion}"
    if [[ `git tag -l | grep ${promotedVersion}` ]]; then
        throwError "Tag already exists: v${promotedVersion}"
    fi


    for module in "${projectModules[@]}"; do
        cd ${module}
            logInfo "Promoting module: ${module} to version: ${promotedVersion}"
            setupModule ${module}
            setVersionName ${promotedVersion} package.json
        cd ..
    done

    setVersionName ${promotedVersion} package.json
    gitNoConflictsAddCommitPush ${module} `gitGetCurrentBranch` "Promoted to: v${promotedVersion}"
    gitTag "v${promotedVersion}" "Promoted to: v${promotedVersion}"
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
            cd ..
            throwError "Error publishing module: ${module}"
        cd ..
    done
}

function getFirebaseConfig() {
    logInfo "Fetching config for serving function locally..."
    firebase functions:config:get > .runtimeconfig.json
}

function prepareConfigImpl() {
    cd ${backendModule}
        if [[ -e ".example-config.json" ]] && [[ ! -e ".config.json" ]]; then
            logInfo "Setting first time .config.json"
            mv .example-config.json .config.json

            if [[ ! -e ".config-dev.json" ]]; then
                cp .config.json .config-dev.json
            fi
            if [[ ! -e ".config-prod.json" ]]; then
                cp .config.json .config-prod.json
            fi
        fi

        if [[ "${envType}" ]] && [[ -e ".config-${envType}.json" ]]; then
            logInfo "Setting to backend envType: ${envType}"
            cp -f ".config-${envType}.json" .config.json
        fi

        logInfo "Preparing config as base64..."
        local configAsJson=`cat .config.json`
        configAsBase64=

        if [[ `isMacOS` ]]; then
            configAsBase64=`echo "${configAsJson}" | base64 --break 0`
            throwError "Error base64 config"
        else
            configAsBase64=`echo "${configAsJson}" | base64 --wrap=0`
            throwError "Error base64 config"
        fi

        echo "{\"app\": {\"config\":\"${configAsBase64}\"}}" > .runtimeconfig.json
        logInfo "Backend Config is ready as base64!"
    cd -

    cd ${frontendModule}/src/main
        if [[ "${envType}" ]] && [[ -e "config-${envType}.ts" ]]; then
            logInfo "Setting to frontend envType: ${envType}"
            cp -f "config-${envType}.ts" config.ts
        fi
        logInfo "Frontend config is set!"
    cd -
}

function updateBackendConfig() {
    if [[ ! "${configAsBase64}" ]]; then
        throwError "config was not prepared!!"
    fi

    cd ${backendModule}
        logInfo "Updating config in firebase..."
        firebase functions:config:set ${configEntryName}="${configAsBase64}"
        throwError "Error Updating config as base 64 in firebase..."

        getFirebaseConfig
    cd ..
    throwError "Error while deploying functions"
}

function fetchBackendConfig() {
    cd ${backendModule}
        getFirebaseConfig

        logInfo "Updating config locally..."
        local configAsBase64=`firebase functions:config:get ${configEntryName}`
        configAsBase64=${configAsBase64:1:-1}
        local configEntry=`echo ${configAsBase64} | base64 --decode`
        echo "${configEntry}" > .config.json
    cd ..
    throwError "Error while deploying functions"
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

if [[ "${purge}" ]]; then
    executeOnModules purgeModule
fi

if [[ "${prepareConfig}" ]]; then
    prepareConfigImpl
fi

if [[ "${setBackendConfig}" ]]; then
    updateBackendConfig
fi

if [[ "${getBackendConfig}" ]]; then
    fetchBackendConfig
fi

if [[ "${setup}" ]]; then
    executeOnModules setupModule
fi

if [[ "${build}" ]]; then
    executeOnModules buildModule
fi

if [[ "${test}" ]]; then
    executeOnModules testModule
fi

if [[ "${launchBackend}" ]]; then
    npm list -g nodemon > /dev/null
    throwError "nodemon package is missing... Please install nodemon:\n npm i -g nodemon"

    cd ${backendModule}
        if [[ -e "_launch.sh" ]]; then
            _launch.sh
        fi

        if [[ "${launchFrontend}" ]]; then
            nodemon &
        else
            nodemon
        fi
    cd ..
fi

if [[ "${serveBackend}" ]]; then
    cd ${backendModule}
        npm run serve
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

if [[ "${deployBackend}" ]]; then
    firebase deploy --only functions
    throwError "Error while deploying functions"
fi

if [[ "${deployFrontend}" ]]; then
    firebase deploy --only hosting
    throwError "Error while deploying hosting"
fi

if [[ "${pushNuArtMessage}" ]]; then
    pushNuArt
fi

if [[ "${promoteNuArtVersion}" ]]; then
    gitAssertOrigin "${boilerplateRepo}"
    promoteNuArt
fi

if [[ "${promoteAppVersion}" ]]; then
    promoteApps
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