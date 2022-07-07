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
$commitFile = "V" + $newVersion + " - " + $commitFile
$commitFile | Out-File $commitPath -Encoding utf8 -Force #Commit File schreiben

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
        $newLine = "- " + $commitFile
        $newReadmeFile += $newLine

        #Versionsnummern in Array speichern
        $versions += $readmeFile[$i]
        $versions += $newLine
    }

    else 
    {
        #Versionsbereich ist bei nächste Überschrift fertig
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
$newReadmeFile | Out-File $readmePath -Encoding utf8 -Force #File schreiben
$versions | Out-File $releasenotesPath -Encoding utf8 -Force #releasenotes File schreiben