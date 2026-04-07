# 👻 KING Browser — Задачи для ИИ

> **Дата создания:** 5 апреля 2026
> **Версия проекта:** 2.0 — KING Edition
> **Стек:** C# 12, .NET 7, WPF, WebView2 (Chromium)

---

## 🔗 Связь с `ideas.md`

> **ideas.md** — банк идей (все возможные фичи)
> **tasks.md** — TODO (идеи выбраны для реализации)
> **task.md** — ТЕКУЩАЯ ЗАДАЧА (что делается сейчас)
>
> **Поток:** `ideas.md` → (выбрана) → `tasks.md` → (заказана пользователем) → `task.md` → (выполнена) → `changelog.md`

### Активные идеи из `ideas.md`:

| ID | Идея из ideas.md | Статус в tasks.md |
|----|-----------------|-------------------|
| `STEALTH-001` | Призрачный режим | ⏳ Запланировано |
| `STEALTH-002` | Паник-кнопка | ⏳ Запланировано |
| `STEALTH-003` | Туннельный режим | ⏳ Запланировано |
| `BYPASS-001` | Авто-обход блокировок | ⏳ Запланировано |
| `PRIVACY-001` | Автоочистка | ⏳ Запланировано |
| `PRIVACY-002` | Анти-трекинг | ⏳ Запланировано |

---

## ⚠️ ВАЖНО: ЧТЕНИЕ ВСЕХ AI-ФАЙЛОВ ОБЯЗАТЕЛЬНО

**Перед любой задачей ИИ обязан прочитать ВСЕ файлы из папки `AI/`:**
1. `onboarding.md` — ввод в курс дела
2. `task.md` — текущая задача от пользователя
3. `tasks.md` — детализированный список задач и багов (этот файл)
4. `architecture.md` — полная архитектура проекта
5. `rules.md` — правила работы ИИ
6. `user-responses.md` — ответы пользователя о багах
7. `design.md` — дизайн-система
8. `security.md` — политика безопасности
9. `workflow.md` — рабочий процесс
10. `roadmap.md` — дорожная карта
11. `ideas.md` — банк идей (связано с задачами)
12. `changelog.md` — история изменений
13. `bug-handling.md` — правила обработки багов

**НЕ начинай работу, пока не прочитал все 13 файлов.**

---

## 📝 После выполнения задачи — ОБЯЗАТЕЛЬНО

**После каждого изменения ИИ обязан:**
1. Обновить `tasks.md` — отметить выполненное
2. Обновить `user-responses.md` — записать новый контекст (если есть)
3. Обновить `architecture.md` — если изменилась структура проекта
4. Обновить `rules.md` — если появились новые правила
5. Обновить `onboarding.md` — если изменились приоритеты
6. Написать краткий отчёт пользователю: что сделано, какие файлы изменены

---

## 🔁 Периодическая проверка файлов — КАЖДЫЕ 3 ЗАДАЧИ

**После каждых 3 выполненных задач ИИ обязан перечитать все AI-файлы и проверить на актуальность.**

---

## 📋 Сводка багов от пользователя

### 🔴 КРИТИЧЕСКИЕ (фиксить в первую очередь)

#### Bug #1: Сайт не показывается при переключении вкладок → вылет ✅ ИСПРАВЛЕНО
- **Симптом:** При переключении между вкладками веб-контент иногда не отображается, после чего приложение вылетает без сообщения об ошибке
- **Воспроизведение:** Нестабильно, иногда (race condition)
- **Причина (исправлено):**
  - `DisplayedContent` обновлялся синхронно, без Dispatcher — приводил к конфликту рендеринга
  - `_previousSelectedTab` присваивался ПОСЛЕ подписки на новую вкладку → дублирование событий
  - `async void CreateTab()` без try-catch → необработанное исключение роняло приложение
  - Нет null-проверок WebView перед использованием
- **Исправление (05.04.2026):**
  - `_previousSelectedTab` присваивается ДО подписки — предотвращает race condition
  - `DisplayedContent` обновляется через `Dispatcher.InvokeAsync(Background)` — безопасно для UI-потока
  - `CreateTab()` и `CloseTab()` обёрнуты в try-catch
  - `OnSelectedTabPropertyChanged` проверяет `tab.WebView != null`
  - Добавлен глобальный `DispatcherUnhandledException` в `App.xaml.cs`
- **Файлы:** `MainViewModel.cs`, `App.xaml.cs`

#### Bug #2: F11 → зависание намертво → вылет без ошибки ✅ ИСПРАВЛЕНО
- **Симптом:** При нажатии F11 (вход в полноэкранный режим) и последующем нажатии на кнопку развёртывания приложение зависает, затем вылетает без сообщения об ошибке
- **Причина (исправлено):**
  - Один флаг `_isMaximized` использовался и для `ToggleMaximize()`, и для `ToggleFullScreen()` — при быстрой последовательности F11 → кнопка происходил конфликт состояний
  - Не сохранялось состояние окна перед фуллскрином — при выходе восстанавливались жёстко заданные 1280x720, игнорируя реальное состояние
  - Не вызывалась перерисовка после выхода из фуллскрина
- **Исправление (05.04.2026):**
  - Разделены флаги: `_isWindowMaximized` (кнопка) и `_isFullScreen` (F11)
  - `ToggleMaximize()` заблокирована во время фуллскрина (`if (_isFullScreen) return`)
  - Перед входом сохраняются: `WindowState`, `Width`, `Height`, `Left`, `Top`, `WindowStyle`, `ResizeMode`
  - При выходе — полное восстановление + `InvalidateVisual()` + `UpdateLayout()` через `Dispatcher.InvokeAsync(Background)`
  - Весь метод обёрнут в try-catch с аварийным восстановлением
- **Файлы:** `MainWindow.xaml.cs` (методы `ToggleFullScreen`, `ToggleMaximize`)

---

### 🟡 ВАЖНЫЕ

#### Bug #3: Визуальные артефакты при изменении размера окна ✅ ИСПРАВЛЕНО
- **Симптом:** При ресайзе окна элементы интерфейса могут отображаться некорректно
- **Причина (исправлено):**
  - `WindowChrome` + `AllowsTransparency="True"` — известная проблема WPF, вызывает субпиксельное размытие
  - Отсутствие корректной перерисовки при изменении размера
  - WebView2 не всегда корректно масштабируется без принудительного UpdateLayout
- **Исправление (05.04.2026):**
  - Добавлены `SnapsToDevicePixels="True"` и `UseLayoutRounding="True"` на Window и корневые Border
  - Обработчик `Window_SizeChanged` вызывает `InvalidateVisual()` + `UpdateLayout()` через Dispatcher
  - Это устраняет субпиксельные артефакты и заставляет WPF пересчитать layout
- **Файлы:** `MainWindow.xaml`, `MainWindow.xaml.cs`

---

## 🏗️ Архитектурные проблемы (из ARCHITECTURE.md)

### Фаза 1: Стабилизация ✅ (уже исправлено)
- [x] Исправить дублирование WebView2
- [x] Исправить краш меню
- [x] Исправить утечку памяти
- [x] Добавить обработку ошибок

### Фаза 2: Чистота кода ✅ ВЫПОЛНЕНО
- [x] Удалить `SettingsViewModel.cs` (мёртвый код)
- [x] Создать `AsyncRelayCommand` для `CreateTab` (убрать async void)
- [ ] Добавить валидацию URL в `Navigate()`
- [ ] Покрыть `SearchService` unit-тестами

### Фаза 3: Архитектурный рефакторинг 🔜
- [ ] Вынести настройки из `SettingsService` (INotifyPropertyChanged) в `SettingsViewModel`
- [ ] Создать `ViewLocator` для автоматического отображения View
- [ ] Добавить DI-контейнер для управления зависимостями
- [ ] Разделить слой сервисов и слой UI

---

## 🚀 Фичи из TODO (потом)

- [ ] Менеджер загрузок
- [ ] Расширенные настройки
- [ ] Расширения (uBlock Origin и т.д.)
- [ ] Синхронизация закладок
- [ ] Режим инкогнито
- [ ] Скриншотер с защитой
- [ ] Автозаполнение форм
- [ ] Профили пользователей

---

## 📝 План действий

### Этап 1: Критические баги (СРОЧНО)

**1.1. Исправить Bug #2 (F11 зависание)** — ✅ ИСПРАВЛЕНО
- ✅ Разделены флаги: `_isWindowMaximized` и `_isFullScreen`
- ✅ `ToggleMaximize()` заблокирована во время фуллскрина
- ✅ Сохранение/восстановление состояния окна
- ✅ `InvalidateVisual()` + `UpdateLayout()` при выходе
- ✅ try-catch с аварийным восстановлением

**1.2. Исправить Bug #1 (вылет при переключении вкладок)** — ✅ ИСПРАВЛЕНО
- ✅ `_previousSelectedTab` присваивается ДО подписки
- ✅ `DisplayedContent` обновляется через `Dispatcher.InvokeAsync(Background)`
- ✅ Добавлены проверки `WebView != null`
- ✅ `CreateTab()`, `CloseTab()`, `UpdateFromSelectedTab()`, `OnSelectedTabPropertyChanged` обёрнуты в try-catch
- ✅ Глобальный `DispatcherUnhandledException` в `App.xaml.cs`

**1.3. Исправить Bug #3 (артефакты при ресайзе)** — ✅ ИСПРАВЛЕНО
- ✅ `SnapsToDevicePixels="True"` и `UseLayoutRounding="True"` на Window и Border
- ✅ `Window_SizeChanged` → `InvalidateVisual()` + `UpdateLayout()`

### Этап 2: Стабилизация ✅ ВЫПОЛНЕНО (кроме валидации URL и тестов)

**2.1. Исправить утечку HttpClient** — ✅ ВЫПОЛНЕНО
- SettingsService реализует IDisposable
- HttpClient DISPOSится в Cleanup()

**2.2. Исправить race condition SaveNotification** — ✅ ВЫПОЛНЕНО
- ContinueWith заменён на DispatcherTimer

**2.3. Исправить пустые catch** — ✅ ВЫПОЛНЕНО
- LoadSettings() логирует ошибку, использует дефолтные настройки
- TestDns() показывает результат ошибки пользователю
- ResetProgressAsync обёрнут в try-catch

**2.4. Убрать ContinueWith из TabViewModel** — ✅ ВЫПОЛНЕНО
- Заменён на async/await (ResetProgressAsync)

**2.5. Упростить CreateTab** — ✅ ВЫПОЛНЕНО
- Убран async внутри Dispatcher.InvokeAsync

**2.6. Удалить мёртвый код** — ✅ ВЫПОЛНЕНО
- Удалён HistoryWindow.cs

**2.7. Создать `AsyncRelayCommand`** — ✅ ВЫПОЛНЕНО
- `CreateTab()` переписан на `async Task CreateTabAsync()`
- `AddTabCommand` теперь `AsyncRelayCommand`

**2.8. Добавить валидацию URL** — ⏳ ПОЗЖЕ
- Проверять корректность URL перед `new Uri()`
- Показывать ошибку пользователю

**2.9. Поисковик сохраняется** — ✅ ВЫПОЛНЕНО
- `CycleSearchEngine()` сохраняет в `SettingsService.DefaultSearchEngine`
- При инициализации загружается из настроек

**2.10. Закладки case-insensitive** — ✅ ВЫПОЛНЕНО
- `OrdinalIgnoreCase` в `AddBookmark()` и `IsBookmarked()`
- `DateTime.UtcNow` вместо `DateTime.Now`

**2.11. BookmarksBar через XAML Binding** — ✅ ВЫПОЛНЕНО
- Убран code-behind `UpdateBookmarksBar()`
- `ItemsSource="{Binding BookmarkService.Bookmarks}"` в XAML

**2.12. SettingsPage — нет дублирования подписок** — ✅ ВЫПОЛНЕНО
- DNS Toggle, TextBox, Slider — через XAML Binding
- `InitializeSettings()` упрощён

**2.13. Удалён мёртвый код** — ✅ ВЫПОЛНЕНО
- Удалён `SettingsViewModel.cs`

### Этап 3: Архитектура ✅ ВЫПОЛНЕНО

- [x] Создать AsyncRelayCommand
- [x] DateTime.Now → UtcNow (HistoryService)
- [x] Дедупликация истории при загрузке
- [x] Магическое число 500ms → константа ProgressResetDelayMs
- [x] Убраны дубликаты DNS-пресетов (17 → 14)
- [x] SettingsPage обнуляется при закрытии

---

## 🆕 Новые фичи

### ✅ Режим инкогнито (05.04.2026)
- [x] IncognitoWindow.xaml(.cs) — отдельное окно с фиолетовым индикатором
- [x] IncognitoViewModel.cs — без истории/закладок, изолированный UserDataFolder
- [x] Кнопка 🕶️ в MainWindow + горячая клавиша Ctrl+Shift+N
- [x] Очистка cookies, кэша и папки профиля при закрытии
- [x] Фиолетовый прогресс-бар и индикатор "INCOGNITO"

### ✅ Менеджер загрузок (05.04.2026)
- [x] Models/DownloadItem.cs — модель загрузки с прогрессом и скоростью
- [x] Models/DownloadItemStatus.cs — enum статусов
- [x] Services/DownloadService.cs — сервис загрузок с pause/resume (HTTP Range)
- [x] Перехват загрузок WebView2 (DownloadStarting → e.Cancel)
- [x] Секция "📥 Загрузки" в SettingsPage
- [x] Пауза/возобновление/отмена/удаление загрузок
- [x] Папка загрузок по умолчанию (настраивается)
- [x] История загрузок → downloads.json

---

## 🗂️ Структура проекта (для справки)

```
GhostBrowser/
├── App.xaml / App.xaml.cs          # Точка входа, глобальные стили
├── MainWindow.xaml / .cs           # Главное окно
├── GhostBrowser.csproj             # .NET 10, WPF, WebView2
├── NewTabPage.html                 # HTML новой вкладки
│
├── ViewModels/
│   ├── MainViewModel.cs            # Главный VM: вкладки, навигация, сервисы
│   ├── TabViewModel.cs             # VM вкладки: WebView2, URL, заголовок
│   ├── ViewModelBase.cs            # INotifyPropertyChanged
│   ├── RelayCommand.cs             # ICommand реализация
│   └── AsyncRelayCommand.cs        # Async ICommand
│
├── Models/
│   ├── Bookmark.cs                 # Модель закладки
│   └── HistoryEntry.cs             # Модель истории
│
├── Services/
│   ├── StealthService.cs           # Режим невидимости (Win32 API) ✅ Работает
│   ├── HistoryService.cs           # История → JSON
│   ├── BookmarkService.cs          # Закладки → JSON
│   ├── SearchService.cs            # Поисковики
│   └── SettingsService.cs          # Настройки (INPC — вынести в VM)
│
└── Views/
    ├── SettingsPage.xaml / .cs     # Страница настроек
    └── DnsTestWindow.xaml / .cs    # Модалка теста DNS
```

---

## ⚙️ Известные технические детали

- **OS:** Windows 11 (пользователь подтвердил)
- **Stealth mode:** Работает (WDA_EXCLUDEFROMCAPTURE)
- **Хранилище:** `%APPDATA%\GhostBrowser\{settings,bookmarks,history}.json`
- **UserDataFolder WebView2:** `%APPDATA%\GhostBrowser`

---

## ❗ Что НЕ делать сейчас

- НЕ добавлять новые фичи без согласования с пользователем
- НЕ ломать рабочий stealth mode
- НЕ удалять файлы без подтверждения
