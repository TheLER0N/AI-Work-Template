# 🤖 AI Work Automator — Автоматизация работы с AI-файлами
# Использование: .\ai-automator.ps1 [команда]

param(
    [string]$Command = "help",
    [string]$ProjectPath = "",
    [string]$Message = ""
)

$AI_DIR = "AI"
$TIMESTAMP = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# ==================== ЦВЕТА ====================
function Write-Header($text) { Write-Host "`n═══ $text ═══" -ForegroundColor Cyan }
function Write-Ok($text) { Write-Host "  ✅ $text" -ForegroundColor Green }
function Write-Info($text) { Write-Host "  ℹ️  $text" -ForegroundColor Yellow }
function Write-Err($text) { Write-Host "  ❌ $text" -ForegroundColor Red }
function Write-Success($text) { Write-Host "`n✅ $text" -ForegroundColor Green }

# ==================== СПРАВКА ====================
function Show-Help {
    Write-Header "AI Work Automator — Команды"
    Write-Host @"
  scan [путь]          — Сканировать проект и заполнить AI-файлы
  status               — Показать статус всех AI-файлов
  commit [сообщение]   — Сделать git commit всех изменений
  push                 — Git push origin main
  backup               — Создать бэкап AI-файлов
  check                — Проверить целостность AI-файлов
  link [ID]            — Показать детали идеи по ID из ideas.md
  suggest              — Предложить следующую задачу из ideas.md
  help                 — Эта справка

Примеры:
  .\ai-automator.ps1 scan "C:\MyProject"
  .\ai-automator.ps1 commit "Добавил новую фичу"
  .\ai-automator.ps1 link STEALTH-001
  .\ai-automator.ps1 suggest
"@
}

# ==================== СКАНИРОВАНИЕ ПРОЕКТА ====================
function Scan-Project {
    param([string]$Path)
    
    if (-not $Path) { $Path = Get-Location }
    if (-not (Test-Path $Path)) { Write-Err "Путь не найден: $Path"; return }
    
    Write-Header "Сканирование проекта: $Path"
    
    # Структура файлов
    Write-Header "Структура файлов"
    $files = Get-ChildItem -Path $Path -Recurse -File | 
             Where-Object { $_.FullName -notmatch '\\\\(bin|obj|\\.git|node_modules)\\\\' } |
             Select-Object -First 50
    
    foreach ($f in $files) {
        $relPath = $f.FullName.Replace($Path, "").TrimStart('\')
        $size = if ($f.Length -gt 1MB) { "$([math]::Round($f.Length/1MB, 1)) MB" } 
                elseif ($f.Length -gt 1KB) { "$([math]::Round($f.Length/1KB, 1)) KB" } 
                else { "$($f.Length) B" }
        Write-Info "$relPath ($size)"
    }
    
    # Технологии
    Write-Header "Технологии"
    $csproj = Get-ChildItem -Path $Path -Filter "*.csproj" -Recurse | Select-Object -First 1
    if ($csproj) {
        $content = Get-Content $csproj.FullName -Raw
        if ($content -match '<TargetFramework>([^<]+)</TargetFramework>') { Write-Ok ".NET: $($matches[1])" }
        if ($content -match '<UseWPF>([^<]+)</UseWPF>') { Write-Ok "WPF: $($matches[1])" }
        if ($content -match 'PackageReference.*Version="([^"]+)"') { Write-Ok "Пакеты: $($matches[1])" }
    }
    
    $packageJson = Get-ChildItem -Path $Path -Filter "package.json" -Recurse | Select-Object -First 1
    if ($packageJson) {
        Write-Ok "Node.js проект (package.json найден)"
    }
    
    # Считаем строки кода
    $totalLines = 0
    $codeFiles = Get-ChildItem -Path $Path -Include "*.cs","*.xaml","*.js","*.ts","*.py" -Recurse |
                 Where-Object { $_.FullName -notmatch '\\\\(bin|obj|\\.git|node_modules)\\\\' }
    foreach ($f in $codeFiles) {
        $totalLines += (Get-Content $f.FullName | Measure-Object -Line).Lines
    }
    Write-Ok "Всего строк кода: $totalLines"
    
    # Обновляем architecture.md
    Write-Header "Обновление AI-файлов"
    Update-Architecture $Path
    Update-TaskStatus
    
    Write-Success "Сканирование завершено!"
}

# ==================== ОБНОВЛЕНИЕ ARCHITECTURE ====================
function Update-Architecture {
    param([string]$Path)
    
    $archPath = Join-Path $Path "$AI_DIR\architecture.md"
    if (-not (Test-Path $archPath)) { Write-Err "architecture.md не найден"; return }
    
    # Получаем реальную структуру
    $tree = tree $Path /F /A 2>$null | Select-Object -First 80
    $treeText = $tree -join "`n"
    
    $content = Get-Content $archPath -Raw
    
    # Обновляем секцию структуры
    $pattern = '(## 1\. Общая структура проекта[\s\S]*?```\n)[\s\S]*?(\n```)`
    if ($content -match $pattern) {
        $content = $content -replace $pattern, "`${1}$treeText`${2}"
        $content | Set-Content $archPath -Encoding UTF8
        Write-Ok "architecture.md обновлён (структура файлов)"
    }
}

# ==================== СТАТУС ЗАДАЧ ====================
function Update-TaskStatus {
    $taskFile = "$AI_DIR\task.md"
    $ideasFile = "$AI_DIR\ideas.md"
    $tasksFile = "$AI_DIR\tasks.md"
    
    if (-not (Test-Path $taskFile)) { return }
    
    # Обновляем дату
    $content = Get-Content $taskFile -Raw
    $content = $content -replace 'Дата последнего обновления.*', "Дата последнего обновления: $TIMESTAMP"
    $content | Set-Content $taskFile -Encoding UTF8
    
    Write-Ok "task.md обновлён (дата: $TIMESTAMP)"
}

# ==================== СТАТУС ФАЙЛОВ ====================
function Show-Status {
    Write-Header "Статус AI-файлов"
    
    $requiredFiles = @(
        "onboarding.md", "task.md", "tasks.md", "architecture.md",
        "rules.md", "user-responses.md", "design.md", "security.md",
        "workflow.md", "roadmap.md", "ideas.md", "changelog.md", "bug-handling.md"
    )
    
    $found = 0
    foreach ($f in $requiredFiles) {
        $path = Join-Path $AI_DIR $f
        if (Test-Path $path) {
            $size = (Get-Item $path).Length
            $lines = (Get-Content $path | Measure-Object -Line).Lines
            Write-Ok "$f — $lines строк, $($size) байт"
            $found++
        } else {
            Write-Err "$f — ОТСУТСТВУЕТ"
        }
    }
    
    Write-Host "`n  📊 Найдено: $found/$($requiredFiles.Count)" -ForegroundColor White
}

# ==================== GIT COMMIT ====================
function Git-Commit {
    param([string]$Msg)
    
    if (-not $Msg) { $Msg = "AI-файлы обновлены: $TIMESTAMP" }
    
    Write-Header "Git commit"
    
    # Проверяем что это git репозиторий
    if (-not (Test-Path ".git")) { Write-Err "Это не git репозиторий"; return }
    
    git add -A 2>&1 | Out-Null
    $result = git commit -m $Msg 2>&1
    Write-Host $result
    
    if ($LASTEXITCODE -eq 0) { Write-Success "Commit: $Msg" }
    else { Write-Err "Commit не удался" }
}

# ==================== GIT PUSH ====================
function Git-Push {
    Write-Header "Git push"
    
    if (-not (Test-Path ".git")) { Write-Err "Это не git репозиторий"; return }
    
    $result = git push origin main 2>&1
    Write-Host $result
    
    if ($LASTEXITCODE -eq 0) { Write-Success "Push на GitHub выполнен" }
    else { Write-Err "Push не удался" }
}

# ==================== БЭКАП ====================
function Backup-AI {
    $backupDir = "AI_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    
    if (-not (Test-Path $AI_DIR)) { Write-Err "AI папка не найдена"; return }
    
    Copy-Item $AI_DIR $backupDir -Recurse
    Write-Success "Бэкап создан: $backupDir"
}

# ==================== ПРОВЕРКА ЦЕЛОСТНОСТИ ====================
function Check-Integrity {
    Write-Header "Проверка целостности AI-файлов"
    
    $requiredFiles = @(
        "onboarding.md", "task.md", "tasks.md", "architecture.md",
        "rules.md", "user-responses.md", "design.md", "security.md",
        "workflow.md", "roadmap.md", "ideas.md", "changelog.md", "bug-handling.md"
    )
    
    $errors = 0
    
    foreach ($f in $requiredFiles) {
        $path = Join-Path $AI_DIR $f
        
        if (-not (Test-Path $path)) {
            Write-Err "$f — ОТСУТСТВУЕТ"
            $errors++
            continue
        }
        
        $content = Get-Content $path -Raw
        
        # Проверяем что файл не пустой
        if ($content.Length -lt 50) {
            Write-Err "$f — ПУСТОЙ (меньше 50 символов)"
            $errors++
            continue
        }
        
        # Проверяем что нет незаполненных плейсхолдеров [АВТО
        if ($path -notmatch '\\AI_work\\') {
            $autoCount = ([regex]::Matches($content, '\[АВТО')).Count
            if ($autoCount -gt 10) {
                Write-Err "$f — МНОГО незаполненных [АВТО] ($autoCount)"
                $errors++
                continue
            }
        }
        
        Write-Ok "$f — OK"
    }
    
    # Проверяем связи между файлами
    Write-Host "`n  🔗 Проверка связей:" -ForegroundColor Cyan
    
    $taskContent = Get-Content (Join-Path $AI_DIR "task.md") -Raw
    $ideasContent = Get-Content (Join-Path $AI_DIR "ideas.md") -Raw
    
    if ($taskContent -match 'ideas\.md') { Write-Ok "task.md → ideas.md связана" }
    else { Write-Err "task.md → ideas.md НЕ связана" ; $errors++ }
    
    if ($taskContent -match 'tasks\.md') { Write-Ok "task.md → tasks.md связана" }
    else { Write-Err "task.md → tasks.md НЕ связана"; $errors++ }
    
    # Итог
    Write-Host "`n  📊 Ошибок: $errors" -ForegroundColor $(if ($errors -eq 0) { 'Green' } else { 'Red' })
    if ($errors -eq 0) { Write-Success "Все файлы в порядке!" }
}

# ==================== ИДЕЯ ПО ID ====================
function Show-IdeaDetail {
    param([string]$Id)
    
    $ideasFile = Join-Path $AI_DIR "ideas.md"
    if (-not (Test-Path $ideasFile)) { Write-Err "ideas.md не найден"; return }
    
    $content = Get-Content $ideasFile -Raw
    
    # Ищем идею по ID
    $pattern = "(?s)(###\s+\d+\.\s+.*?$Id.*?\n[\s\S]*?)(?=###|\Z)"
    $match = [regex]::Match($content, $pattern)
    
    if ($match.Success) {
        Write-Header "Идея: $Id"
        Write-Host $match.Groups[1].Value
    } else {
        Write-Err "Идея с ID '$Id' не найдена"
    }
}

# ==================== ПРЕДЛОЖИТЬ ЗАДАЧУ ====================
function Suggest-Task {
    $ideasFile = Join-Path $AI_DIR "ideas.md"
    if (-not (Test-Path $ideasFile)) { Write-Err "ideas.md не найден"; return }
    
    Write-Header "Рекомендуемые задачи (ТОП-6)"
    
    $content = Get-Content $ideasFile -Raw
    
    # Ищем критические задачи
    Write-Host "`n  🔴 КРИТИЧЕСКИЕ:" -ForegroundColor Red
    $criticals = [regex]::Matches($content, '(?m)^1\.\s+`([^`]+)`\s*—\s*(.*)')
    foreach ($m in $criticals) {
        Write-Host "    $($m.Groups[1].Value) — $($m.Groups[2].Value)" -ForegroundColor Yellow
    }
    
    Write-Host "`n  🟡 ВАЖНЫЕ:" -ForegroundColor Yellow
    $importants = [regex]::Matches($content, '(?m)^(?:10|11|12|13|14)\.\s+`([^`]+)`\s*—\s*(.*)')
    foreach ($m in $importants) {
        Write-Host "    $($m.Groups[1].Value) — $($m.Groups[2].Value)" -ForegroundColor White
    }
    
    Write-Host "`n  💡 Напишите в task.md: 'Сделай [ID]' чтобы начать" -ForegroundColor Cyan
}

# ==================== MAIN ====================
switch ($Command.ToLower()) {
    "scan"    { Scan-Project $ProjectPath }
    "status"  { Show-Status }
    "commit"  { Git-Commit $Message }
    "push"    { Git-Push }
    "backup"  { Backup-AI }
    "check"   { Check-Integrity }
    "link"    { Show-IdeaDetail $ProjectPath }
    "suggest" { Suggest-Task }
    "help"    { Show-Help }
    default   { Show-Help }
}
