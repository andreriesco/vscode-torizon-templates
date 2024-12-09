#!/usr/bin/env xonsh

import os
import sys
import json
import shutil
import hashlib
import subprocess

# Stub for the Replace-Tasks-Input functionality,
# since we don't have the original script.
def replace_tasks_input():
    # TODO: Implement logic if needed
    pass

# ANSI color helpers
RED = "\x1b[31m"
GREEN = "\x1b[32m"
YELLOW = "\x1b[33m"
RESET = "\x1b[0m"

if len($ARGS) < 2:
    print(f"{RED}❌ Not enough arguments provided.{RESET}")
    sys.exit(1)

project_folder = $ARGS[1]
project_name = $ARGS[2]
accept_all = $ARGS[3] if len($ARGS) > 3 else None
second_run = $ARGS[4] if len($ARGS) > 4 else None

print(project_folder)

def _checkArg(arg):
    if not arg or str(arg).strip() == "":
        raise ValueError("❌ arg is not defined")

def _file_hash(filepath):
    if not os.path.exists(filepath):
        return None
    hasher = hashlib.sha256()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hasher.update(chunk)
    return hasher.hexdigest()

def _checkIfFileContentIsEqual(file1, file2):
    h1 = _file_hash(file1)
    h2 = _file_hash(file2)
    if h1 is None or h2 is None:
        return False
    return h1 == h2

def _openMergeWindow(updated_file, current_file):
    global accept_all
    if accept_all == True:
        # If updated_file doesn't exist, remove current_file
        if not os.path.exists(updated_file):
            if os.path.exists(current_file):
                os.remove(current_file)
        else:
            shutil.copy2(updated_file, current_file)
        return

    # If one of the files doesn't exist, create empty
    if not os.path.exists(updated_file):
        open(updated_file, 'a').close()
    if not os.path.exists(current_file):
        open(current_file, 'a').close()

    if not _checkIfFileContentIsEqual(updated_file, current_file):
        code --wait --diff @(updated_file) @(current_file)
        # If after diff, the file is empty, remove it
        if os.path.exists(current_file) and os.stat(current_file).st_size == 0:
            os.remove(current_file)

def str_to_bool(s):
    if s is None:
        return None
    s = s.lower()
    return s in ["true", "1", "y"]

accept_all = str_to_bool(accept_all)
second_run = str_to_bool(second_run)

if not second_run:
    # Check git repo
    cmd_output = !(git status 2>&1)
    cmd_output_str = "\n".join(cmd_output)
    if "fatal: not a git repository" in cmd_output_str:
        print(f"{RED}❌ fatal: this workspace is not a git repository.{RESET}")
        print(f"{YELLOW}It is highly recommended that you create a repo and commit the current state{RESET}")
        print(f"{YELLOW}before updating it, to keep track of the changes applied on the update.{RESET}")
        print(f"{YELLOW}If the project is not versioned there is no way back!{RESET}")
        sure = input("Do you really want to proceed? [y/n] ")
        if sure.lower() != "y":
            sys.exit(0)

_checkArg(project_folder)
_checkArg(project_name)

if accept_all is None:
    accept_all = False
else:
    if accept_all and not second_run:
        print(f"{YELLOW}You are about to accept all incoming changes from the updated template{RESET}")
        print(f"{YELLOW}If the project is not versioned there is no way back!{RESET}")
        sure = input("Accept all changes? [y/n] ")
        if sure.lower() != "y":
            sys.exit(0)
        accept_all = True
    elif not second_run:
        accept_all = False

HOME = $HOME

# Check if we need to update projectUpdater.xsh to new version
# In the original script this is done before we know about OS major version change
# Since we've now switched to xonsh, we can skip that step or adapt it:
old_updater_ps1 = f"{project_folder}/.conf/projectUpdater.xsh"
new_updater_ps1 = f"{HOME}/.apollox/scripts/projectUpdater.xsh"
if os.path.exists(new_updater_ps1) and os.path.exists(old_updater_ps1):
    if not _checkIfFileContentIsEqual(new_updater_ps1, old_updater_ps1):
        shutil.copy2(new_updater_ps1, old_updater_ps1)
        print(f"{YELLOW}⚠️ project updater updated, running it again{RESET}")
        # Re-run script
        xonsh $old_updater_ps1 $project_folder $project_name $accept_all $true
        sys.exit(0)


# Load templates.json
with open(f"{HOME}/.apollox/templates.json", "r", encoding="utf-8") as f:
    templates_json = json.load(f)

# metadata
metadata_path = os.path.join(project_folder, ".conf", "metadata.json")
template_path = os.path.join(project_folder, ".conf", ".template")
container_path = os.path.join(project_folder, ".conf", ".container")

if os.path.exists(template_path) and os.path.exists(container_path):
    with open(template_path, "r", encoding="utf-8") as f:
        templateName = f.read().strip()
    with open(container_path, "r", encoding="utf-8") as f:
        containerName = f.read().strip()

    torizonOSMajor = templates_json.get("TorizonOSMajor", "6")

    metadata = {
        "templateName": templateName,
        "containerName": containerName,
        "torizonOSMajor": torizonOSMajor
    }

    with open(metadata_path, "w", encoding="utf-8") as f:
        json.dump(metadata, f, ensure_ascii=False)

    os.remove(template_path)
    os.remove(container_path)

with open(metadata_path, "r", encoding="utf-8") as f:
    metadata_json = json.load(f)

templateName = metadata_json["templateName"]
containerName = metadata_json["containerName"]
_torizonOSMajor = metadata_json["torizonOSMajor"]

_templatesJsonTorizonMajor = templates_json.get("TorizonOSMajor", None)

if _templatesJsonTorizonMajor != "7":
    print(f"{YELLOW}The current Torizon OS version is 7. If you want to do an upgrade in the current version, remove the torizon.templatesBranch setting.{RESET}")
    exit(0)



# Ensure tmp folder
tmp_dir = os.path.join(project_folder, ".conf", "tmp")
if not os.path.exists(tmp_dir):
    os.makedirs(tmp_dir)

# Load template metadata
_templateMetadata = None
for t in templates_json["Templates"]:
    if t["folder"] == templateName:
        _templateMetadata = t
        break

if _templateMetadata is None:
    print(f"{RED}Template metadata not found.{RESET}")
    sys.exit(1)

# Check template status
if _templateMetadata["status"] == "deprecated":
    print(f"{RED}This template is deprecated in the most recent version.{RESET}")
    sys.exit(0)
elif _templateMetadata["status"] == "notok":
    print(f"{RED}This template is broken in the most recent version.{RESET}")
    print(f"{RED}{_templateMetadata['customMessage']}{RESET}")
    sys.exit(0)
elif _templateMetadata["status"] == "incomplete":
    print(f"{RED}This template is incomplete in the most recent version.{RESET}")
    print(f"{RED}{_templateMetadata['customMessage']}{RESET}")
    sure = input("Are you sure you want to proceed with the update? [y/n] ")
    if sure.lower() != "y":
        sys.exit(0)

# ALWAYS ACCEPT NEW
shutil.copy2(f"{HOME}/.apollox/{templateName}/.conf/update.json", f"{project_folder}/.conf/update.json")
shutil.copy2(f"{HOME}/.apollox/scripts/tasks.xsh", f"{project_folder}/.vscode/tasks.xsh")
shutil.copy2(f"{HOME}/.apollox/scripts/checkDeps.xsh", f"{project_folder}/.conf/checkDeps.xsh")
shutil.copy2(f"{HOME}/.apollox/scripts/runContainerIfNotExists.xsh", f"{project_folder}/.conf/runContainerIfNotExists.xsh")
shutil.copy2(f"{HOME}/.apollox/scripts/shareWSLPorts.xsh", f"{project_folder}/.conf/shareWSLPorts.xsh")
shutil.copy2(f"{HOME}/.apollox/scripts/torizonIO.xsh", f"{project_folder}/.conf/torizonIO.xsh")
shutil.copy2(f"{HOME}/.apollox/scripts/createDockerComposeProduction.xsh", f"{project_folder}/.conf/createDockerComposeProduction.xsh")
shutil.copy2(f"{HOME}/.apollox/scripts/bash/tcb-env-setup.sh", f"{project_folder}/.conf/tcb-env-setup.sh")
shutil.copy2(f"{HOME}/.apollox/scripts/checkCIEnv.xsh", f"{project_folder}/.conf/checkCIEnv.xsh")
shutil.copy2(f"{HOME}/.apollox/scripts/validateDepsRunning.xsh", f"{project_folder}/.conf/validateDepsRunning.xsh")
shutil.copy2(f"{HOME}/.apollox/scripts/torizonPackages.xsh", f"{project_folder}/.conf/torizonPackages.xsh")

print(f"{GREEN}✅ always accept new{RESET}")

# Load updateTable
with open(f"{project_folder}/.conf/update.json", "r", encoding="utf-8") as f:
    updateTable = json.load(f)

# .VSCODE merging
if templateName != "tcb":
    # launch.json
    if os.path.exists(f"{HOME}/.apollox/{templateName}/.vscode/launch.json"):
        shutil.copy2(f"{HOME}/.apollox/{templateName}/.vscode/launch.json", f"{project_folder}/.conf/tmp/launch-next.json")

shutil.copy2(f"{HOME}/.apollox/{templateName}/.vscode/settings.json", f"{project_folder}/.conf/tmp/settings-next.json")

if os.path.exists(f"{HOME}/.apollox/{templateName}/.vscode/extensions.json"):
    shutil.copy2(f"{HOME}/.apollox/{templateName}/.vscode/extensions.json", f"{project_folder}/.conf/tmp/extensions-next.json")

shutil.copy2(f"{HOME}/.apollox/{templateName}/.vscode/tasks.json", f"{project_folder}/.conf/tmp/tasks-next.json")

# merge common tasks if needed
if _templateMetadata.get("mergeCommon", True) != False:
    print(f"{YELLOW}Applying common tasks ...{RESET}")
    with open(f"{HOME}/.apollox/assets/tasks/common.json","r",encoding="utf-8") as f:
        commonTasks = json.load(f)
    with open(f"{HOME}/.apollox/assets/tasks/inputs.json","r",encoding="utf-8") as f:
        commonInputs = json.load(f)
    with open(f"{project_folder}/.conf/tmp/tasks-next.json","r",encoding="utf-8") as f:
        projTasks = json.load(f)

    projTasks["tasks"] += commonTasks["tasks"]
    projTasks["inputs"] += commonInputs["inputs"]

    with open(f"{project_folder}/.conf/tmp/tasks-next.json","w",encoding="utf-8") as f:
        json.dump(projTasks, f, indent=4)

os.chdir(os.path.join(project_folder, ".conf", "tmp"))

if templateName != "tcb":
    if os.path.exists(f"{HOME}/.apollox/{templateName}/Dockerfile.debug"):
        shutil.copy2(f"{HOME}/.apollox/{templateName}/Dockerfile.debug", "./")
    if os.path.exists(f"{HOME}/.apollox/{templateName}/Dockerfile.sdk"):
        shutil.copy2(f"{HOME}/.apollox/{templateName}/Dockerfile.sdk", "./")

    shutil.copy2(f"{HOME}/.apollox/{templateName}/Dockerfile", "./")
    shutil.copy2(f"{HOME}/.apollox/{templateName}/docker-compose.yml", "./")
    shutil.copy2(f"{HOME}/.apollox/assets/github/workflows/build-application.yaml", "./")
    shutil.copy2(f"{HOME}/.apollox/assets/gitlab/.gitlab-ci.yml", "./")
    if os.path.exists(f"{HOME}/.apollox/{templateName}/.dockerignore"):
        shutil.copy2(f"{HOME}/.apollox/{templateName}/.dockerignore", "./")

    # torizonPackages.json
    with open(f"{HOME}/.apollox/assets/json/torizonPackages.json", "r", encoding="utf-8") as f:
        _torPackagesJson = json.load(f)

    # Check if Dockerfile has torizon_packages_build
    buildDepDockerfile = False
    if os.path.exists(f"{HOME}/.apollox/{templateName}/Dockerfile"):
        with open(f"{HOME}/.apollox/{templateName}/Dockerfile","r",encoding="utf-8") as f:
            for line in f:
                if "torizon_packages_build" in line:
                    buildDepDockerfile = True
                    break

    if os.path.exists(f"{HOME}/.apollox/{templateName}/Dockerfile.sdk") or buildDepDockerfile:
        _torPackagesJson["buildDeps"] = []

    with open("./torizonPackages.json","w",encoding="utf-8") as f:
        json.dump(_torPackagesJson,f,indent=4)

shutil.copy2(f"{HOME}/.apollox/{templateName}/.gitignore", "./")

# deps.json
shutil.copy2(f"{HOME}/.apollox/{templateName}/.conf/deps.json", "./")

with open("./deps.json","r",encoding="utf-8") as f:
    _deps = json.load(f)

# handle installDepsScripts
if "installDepsScripts" in _deps and len(_deps["installDepsScripts"]) > 0:
    installDepsScriptsDir = os.path.join(project_folder, ".conf", "installDepsScripts")
    if not os.path.exists(installDepsScriptsDir):
        os.makedirs(installDepsScriptsDir)

    if not os.path.exists("./installDepsScripts"):
        os.makedirs("./installDepsScripts")

    for script in _deps["installDepsScripts"]:
        if (not os.path.exists(f"{HOME}/.apollox/{templateName}/{script}")) and (".conf/installDepsScripts" in script):
            # script comes from scripts/installDepsScripts
            scriptSource = script.replace(".conf","scripts")
            shutil.copy2(f"{HOME}/.apollox/{scriptSource}", "./installDepsScripts/" + os.path.basename(script))
        else:
            scriptSource = f"{HOME}/.apollox/{templateName}/{script}"
            shutil.copy2(scriptSource, "./" + script.replace(".conf/",""))

# copy sources from updateTable
for item in updateTable:
    source = item["source"]
    shutil.copy2(f"{HOME}/.apollox/{templateName}/{source}", "./")

# Replace placeholders in files
print(f"{YELLOW}Renaming file contents ...{RESET}")
for root, dirs, files in os.walk(".", topdown=False):
    for name in files:
        a = os.path.join(root, name)
        # check if binary
        # We can use `file` command if available:
        mime_output = !(file --mime-encoding @(a))
        if len(mime_output) > 0:
            if "binary" in mime_output[0]:
                # if id_rsa but not pub, chmod 0400
                if "id_rsa" in a and not "id_rsa.pub" in a:
                    os.chmod(a,0o400)
                continue

        if "id_rsa" in a and not "id_rsa.pub" in a:
            os.chmod(a,0o400)
            continue

        # do replacements
        with open(a,"r",encoding="utf-8",errors="ignore") as f:
            content = f.read()
        content = content.replace("__change__", project_name)
        content = content.replace("__container__", containerName)
        content = content.replace("__home__", HOME)
        content = content.replace("__templateFolder__", templateName)
        with open(a,"w",encoding="utf-8") as f:
            f.write(content)

# Replace tasks input (stub)
replace_tasks_input()

# back to project folder
os.chdir(project_folder)

# MERGE with current files
_openMergeWindow(os.path.join(project_folder,".conf","tmp","tasks-next.json"), os.path.join(project_folder,".vscode","tasks.json"))
print(f"{GREEN}✅ tasks.json{RESET}")

if templateName != "tcb":
    _openMergeWindow(os.path.join(project_folder,".conf","tmp","launch-next.json"), os.path.join(project_folder,".vscode","launch.json"))
    print(f"{GREEN}✅ launch.json{RESET}")

_openMergeWindow(os.path.join(project_folder,".conf","tmp","settings-next.json"), os.path.join(project_folder,".vscode","settings.json"))
print(f"{GREEN}✅ settings.json{RESET}")

if os.path.exists(f"{HOME}/.apollox/{templateName}/.vscode/extensions.json"):
    _openMergeWindow(os.path.join(project_folder,".conf","tmp","extensions-next.json"), os.path.join(project_folder,".vscode","extensions.json"))
    print(f"{GREEN}✅ extensions.json{RESET}")

if templateName != "tcb":
    if os.path.exists(os.path.join(project_folder,".conf","tmp","Dockerfile.debug")):
        _openMergeWindow(os.path.join(project_folder,".conf","tmp","Dockerfile.debug"), os.path.join(project_folder,"Dockerfile.debug"))
    if os.path.exists(os.path.join(project_folder,".conf","tmp","Dockerfile.sdk")):
        _openMergeWindow(os.path.join(project_folder,".conf","tmp","Dockerfile.sdk"), os.path.join(project_folder,"Dockerfile.sdk"))

    _openMergeWindow(os.path.join(project_folder,".conf","tmp","Dockerfile"), os.path.join(project_folder,"Dockerfile"))
    _openMergeWindow(os.path.join(project_folder,".conf","tmp","docker-compose.yml"), os.path.join(project_folder,"docker-compose.yml"))
    _openMergeWindow(os.path.join(project_folder,".conf","tmp","build-application.yaml"), os.path.join(project_folder,".github","workflows","build-application.yaml"))
    _openMergeWindow(os.path.join(project_folder,".conf","tmp",".gitlab-ci.yml"), os.path.join(project_folder,".gitlab-ci.yml"))

    doc_dir = os.path.join(project_folder,".doc")
    if not os.path.exists(doc_dir):
        os.makedirs(doc_dir)

    if os.path.exists(os.path.join(project_folder,".conf","tmp",".dockerignore")):
        _openMergeWindow(os.path.join(project_folder,".conf","tmp",".dockerignore"), os.path.join(project_folder,".dockerignore"))

    _openMergeWindow(os.path.join(project_folder,".conf","tmp","torizonPackages.json"), os.path.join(project_folder,"torizonPackages.json"))

# Copy documentation
shutil.copytree(f"{HOME}/.apollox/{templateName}/.doc", os.path.join(project_folder,".doc"), dirs_exist_ok=True)

_openMergeWindow(os.path.join(project_folder,".conf","tmp",".gitignore"), os.path.join(project_folder,".gitignore"))
_openMergeWindow(os.path.join(project_folder,".conf","tmp","deps.json"), os.path.join(project_folder,".conf","deps.json"))

for script in _deps.get("installDepsScripts", []):
    scriptSource = script.replace(".conf/","")
    _openMergeWindow(os.path.join(project_folder,".conf","tmp", os.path.basename(scriptSource)), os.path.join(project_folder, script))

print(f"{GREEN}✅ common{RESET}")

# SPECIFIC
for item in updateTable:
    _source = os.path.basename(item["source"])
    _target = item["target"]
    # The original code: $_target = (Invoke-Expression "echo `$_target`")
    # We'll assume _target is a direct path.
    target_path = os.path.join(project_folder, _target)

    if os.path.exists(target_path):
        _openMergeWindow(os.path.join(project_folder,".conf","tmp",_source), target_path)
    else:
        shutil.copy2(os.path.join(project_folder,".conf","tmp",_source), target_path)

print(f"{GREEN}✅ specific{RESET}")

# clean up tmp
shutil.rmtree(os.path.join(project_folder,".conf","tmp"), ignore_errors=True)

print(f"{GREEN}✅ Update done{RESET}")
