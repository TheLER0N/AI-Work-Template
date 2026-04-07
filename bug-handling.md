# 🐛 Правила обработки багов — KING Browser

> Если у приложения баг — следуй ЭТИМ правилам. Не импровизируй.

---

## 🚨 КРИТИЧЕСКОЕ ПРАВИЛО: НЕ ЛОМАЙ РАБОЧЕЕ

1. **Перед любым изменением** — сделай `git add -A && git commit -m "checkpoint"`
2. **После каждого изменения** — запусти `dotnet build` → если ошибка, отмени изменения
3. **После успешной сборки** — запусти `dotnet run` → проверь что окно появляется
4. **Если приложение НЕ запускается** — НЕ добавляй новые изменения, а откатывай последнее

---

## 📋 Алгоритм при баге

### Шаг 1: Диагностика (НЕ менять код!)

```
1. taskkill /F /IM GhostBrowser.exe
2. dotnet clean && dotnet restore && dotnet build
3. Запустить bin\Debug\net7.0-windows\GhostBrowser.exe
4. Проверить:
   - Процесс есть? → tasklist | findstr GhostBrowser
   - MainWindowHandle != 0? → PowerShell команда ниже
   - Окно видимо? → AppActivate
   - Есть ли MessageBox с ошибкой? → активировать окно
```

**PowerShell команды:**
```powershell
# Проверить MainWindowHandle
Get-Process | Where-Object {$_.ProcessName -like '*Ghost*'} | Select-Object Id, MainWindowTitle, MainWindowHandle

# Активировать окно (если есть)
Add-Type -AssemblyName Microsoft.VisualBasic
[Microsoft.VisualBasic.Interaction]::AppActivate('KING')
[Microsoft.VisualBasic.Interaction]::AppActivate('KING Browser — Ошибка')
```

### Шаг 2: Если MainWindowHandle = 0 (процесс есть, окна нет)

**Причины (по вероятности):**
1. XAML parsing error → проверить через App.xaml.cs DispatcherUnhandledException
2. WebView2 инициализация падает → проверить %APPDATA%\GhostBrowser
3. Missing ресурс (KING.png, кисть, стиль) → проверить output директорию

**Действия:**
```
1. Убедиться что KING.png есть в bin\Debug\net7.0-windows\
2. Запустить через dotnet run 2>&1 и смотреть вывод
3. Проверить app_error.log если есть
```

### Шаг 3: Если есть MessageBox с ошибкой

```
1. Прочитать текст ошибки ВНИМАТЕЛЬНО
2. Найти строку и файл из stack trace
3. Искать решение в интернете если не знаешь
4. Применить минимальный фикс
```

### Шаг 4: Если приложение зависает

```
1. Проверить CPU usage — если > 5%持续增长 → бесконечный цикл
2. Проверить SizeChanged/Laoded обработчики на рекурсию
3. Откатить последнее изменение
```

---

## 🔴 ЧТО НЕЛЬЗЯ ДЕЛАТЬ (из опыта)

| ❌ Нельзя | ✅ Вместо этого |
|-----------|-----------------|
| Менять StaticResource на HEX в ControlTemplate (App.xaml) | Использовать StaticResource как есть |
| Добавлять LinearGradientBrush с GradientStop Color={StaticResource} | Использовать прямые HEX в LinearGradientBrush |
| Удалять Window.Resources (Storyboard, DataTemplate) | Не трогать Window.Resources |
| Добавлять SizeChanged → ApplyClip() без теста | Тестировать после каждого изменения |
| Менять больше 1 файла за раз без проверки | 1 файл → сборка → запуск → проверка |
| Делать изменения без git commit | Сначала commit, потом изменение |

---

## 🧪 Проверка после каждого изменения

```bash
# 1. Сборка
dotnet build
# Если ошибка → ОТМЕНИТЬ изменения

# 2. Запуск
cd bin\Debug\net7.0-windows && start GhostBrowser.exe
timeout 5

# 3. Проверка
tasklist | findstr GhostBrowser
powershell -Command "Get-Process | Where-Object {$_.ProcessName -like '*Ghost*'} | Select-Object Id, MainWindowTitle, MainWindowHandle"

# 4. Если MainWindowHandle = 0 → ПРОВАЛ → откат
```

---

## 📌 Чек-лист перед изменением

- [ ] Я сделал git commit текущего состояния
- [ ] Я знаю какой файл меняю (МАКСИМУМ 1 файл за раз)
- [ ] Я знаю как проверить что работает
- [ ] Я знаю как отменить изменения если сломается
- [ ] Я записал что меняю в changelog.md

---

## 📌 Чек-лист после изменения

- [ ] dotnet build — успешно
- [ ] MainWindowHandle != 0
- [ ] Окно видимо и реагирует на ввод
- [ ] Нет MessageBox с ошибкой
- [ ] Обновил changelog.md
- [ ] git commit -m "описание изменений"

---

## 🔄 Периодический коммит на GitHub

**Каждые 3 успешных изменения:**
```bash
git add -A
git commit -m "описание изменений"
git push origin main
```

**Если изменения сломали проект:**
```bash
git checkout HEAD -- .  # отменить все изменения
git clean -fd           # удалить новые файлы
rmdir /s /q bin obj     # очистить кэш
dotnet restore && dotnet build
```

---

*Файл обновляется при появлении новых типов багов.*
