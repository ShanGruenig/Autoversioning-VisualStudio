# Introducing
This project is for automatic versioning of Visual Studio (mainly for WPF) projects.
All GitHooks scripts run the PowerShell scripts that contain the functions.

# Get started
- Paste all files into GitHook's folder (\.git\hooks).
- If versions should be visible in README.md -> add chapter ***Buildversion*** (In Markdown -> # Buildversion)

And now for each commit:
- The version number written in the commit
- A releasenotes.txt is written (only if ***Buildversion*** in README.md | otherwise only current commit is written). This file is written as a markdown table.
- If ***Buildversion*** in README.md then the commit is written as a markdown table under ***Buildversion***

---

# Autoversioning Scripts
## VersionEdit.ps1
This script is run by the GitHooks script (pre-commit) and changes the version number of the application. It increments the last version number (0.0.0.0 -> 0.0.0.1).

```powershell
#Pfad
$fullProjectPath = (Get-ChildItem -Include *.csproj -Recurse | Select-Object DirectoryName).DirectoryName #Projektpfad herausfinden
$assemblyPath = "$fullProjectPath\Properties\AssemblyInfo.cs" #Pfad zum AssemblyInfo.cs
$file = Get-Content $assemblyPath #File öffnen

#Version suchen und ersetzen
for ($i = 0; $i -lt $file.Length; $i++)
{
    #AssemblyVersion
    if ($file[$i].Contains("AssemblyVersion") -and !$file[$i].Contains("//"))
    {
        $oldLine = $file[$i]

        #Version erstellen
        $oldVersion = $oldLine.Substring($oldLine.IndexOf('"') + 1, $oldLine.LastIndexOf('"') - $oldLine.IndexOf('"') - 1) #Alte Version auslesen
        $newVersion = $oldVersion.Substring(0, $oldVersion.LastIndexOf('.')) + "." + ([int]$oldVersion.Substring($oldVersion.LastIndexOf('.') + 1) + 1) #Neue Version erstellen

        $newLine = "[assembly: AssemblyVersion("+'"'+$newVersion+'"'+")]"
        $file = $file.Replace($oldLine, $newLine)
    }
    #AssemblyFileVersion
    if ($file[$i].Contains("AssemblyFileVersion"))
    {
        $oldLine = $file[$i]
        $newLine = "[assembly: AssemblyFileVersion("+'"'+$newVersion+'"'+")]"
        $file = $file.Replace($oldLine, $newLine)
    }
}
$file | Out-File $assemblyPath -Force #File schreiben

#In Git erneut hinzufügen
git add $assemblyPath

#Temp .commit erstellen
Out-File ".commit" -Force
```

### CommitEdit.ps1
This script is run by the GitHooks script (commit-msg) and changes the commit message so that the version is in the commit. If available, the commit message is written in chapter ***# Buildversion*** (latest always first) and finally all versions are written in ***releasenote.txt*** (is created automatically and contains all versions under the Chapter ***# Buildversion*** are written).

```powershell
param ($commitPath) #Übergabeparameter -> ".\.git\COMMIT_EDITMSG"

#Pfad
$readmePath = ".\README.md" #Pfad zur README.md
$releasenotesPath = ".\releasenotes.txt" #Pfad zur releasenotes.txt
$fullProjectPath = (Get-ChildItem -Include *.csproj -Recurse | Select-Object DirectoryName).DirectoryName #Projektpfad herausfinden
$assemblyPath = "$fullProjectPath\Properties\AssemblyInfo.cs" #Pfad zum AssemblyInfo.cs

$file = Get-Content $assemblyPath #File öffnen

#Version holen
for ($i = 0; $i -lt $file.Length; $i++)
{
    #AssemblyVersion holen
    if ($file[$i].Contains("AssemblyVersion") -and !$file[$i].Contains("//"))
    {
        $oldLine = $file[$i]

        #Version ausslesen
        $oldVersion = $oldLine.Substring($oldLine.IndexOf('"') + 1, $oldLine.LastIndexOf('"') - $oldLine.IndexOf('"') - 1) #Alte Version auslesen
        $newVersion = $oldVersion.Substring(0, $oldVersion.LastIndexOf('.')) + "." + ([int]$oldVersion.Substring($oldVersion.LastIndexOf('.') + 1)) #Neue Version erstellen
    }
}

#Commit-Message
$commitFile = Get-Content $commitPath -Encoding utf8 #File öffnen

#Version in Commit schreiben
$newCommitFile = "V" + $newVersion + " - " + $commitFile
$newCommitFile | Out-File $commitPath -Encoding utf8 -Force #Commit File schreiben

#Version in README schreiben
$readmeFile = Get-Content $readmePath -Encoding utf8 #File öffnen

$newReadmeFile = @() #Array erstellen

$versions = @() #Array erstellen
$isInVersion = $false #Variable für die Erkennung ob im Versionsbereich

#Suchen und hinzufügen der Version
for ($i = 0; $i -lt $readmeFile.Length; $i++)
{
    $newReadmeFile += $readmeFile[$i]
    if ($readmeFile[$i].Contains("# Buildversion"))
    {
        $isInVersion = $true

        #Tabellen Header schreiben
        $newReadmeFile += "| Version | Release Notes |"
        $newReadmeFile += "|--|--|"
        $newLine = "| " + $newVersion + " | " + $commitFile + " |"
        $newReadmeFile += $newLine

        #Versionsnummern in Array speichern
        $versions += "# Buildversion"
        $versions += "| Version | Release Notes |"
        $versions += "|--|--|"
        $versions += $newLine

        #Index hochzählen
        $i += 2
    }

    else 
    {
        #Versionsbereich ist bei nächster Überschrift fertig
        if($isInVersion -and $readmeFile[$i].Contains("#"))
        {
            $isInVersion = $false
        }

        #Alle Versionen in releasenotes schreiben
        if($isInVersion)
        {
            $versions += $readmeFile[$i]
        }
    }    
}
$newReadmeFile | Out-File $readmePath -Encoding utf8 -Force #Readme File schreiben

#releasenotes.txt schreiben
if ($versions.Length -gt 0)
{
    $versions | Out-File $releasenotesPath -Encoding utf8 -Force
}
#Nur die aktuelle Version einfügen
else
{
    $versionNoReadme = @() #Array erstellen
    $versionNoReadme += "# Buildversion"
    $versionNoReadme += "| Version | Release Notes |"
    $versionNoReadme += "|--|--|"
    $versionNoReadme += "| " + $newVersion + " | " + $commitFile + " |"
    $versionNoReadme | Out-File $releasenotesPath -Encoding utf8 -Force
}
```

### PostCommitEdit.ps1
This script is executed by the GitHooks script (post-commit) and adds the files that have been changed afterwards.

```powershell
#.commit File wird erstellt um eine loop zuverhindern
if(Test-Path ".commit")
{
    Remove-Item ".commit" -Force
    git add . #Alle geänderten Files in git hinzufügen
    git commit --amend -C HEAD --no-verify #Letzter Commit bearbeiten ohne Hooks
}
```

---

### pre-commit
This GitHook script starts the VersionEdit.ps1 script before committing.

```bash
#!/bin/sh
echo
exec powershell -NoProfile -ExecutionPolicy Bypass -File '.\.git\hooks\VersionEdit.ps1'
exit
```

### commit-msg
This GitHook script starts the CommitEdit.ps1 script before the commit is executed.

```bash
#!/bin/sh
echo
exec powershell -NoProfile -ExecutionPolicy Bypass -File ".\.git\hooks\CommitEdit.ps1" $1
exit
```

### post-commit
This GitHook script starts the PostCommitEdit.ps1 script after the commit has been executed.

```bash
#!/bin/sh
echo
exec powershell -NoProfile -ExecutionPolicy Bypass -File ".\.git\hooks\PostCommitEdit.ps1"
exit
```
