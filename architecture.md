# Архитектура GhostBrowser

> **Версия:** 1.0
> **Дата:** Апрель 2026
> **Платформа:** .NET 7.0, Windows
> **Стек:** C# 12, WPF, WebView2 (Chromium)

---

## ⚠️ ВАЖНО: ЧТЕНИЕ ВСЕХ AI-ФАЙЛОВ ОБЯЗАТЕЛЬНО

**Перед любой задачей ИИ обязан прочитать ВСЕ файлы из папки `AI/`:**
1. `onboarding.md` — ввод в курс дела
2. `task.md` — текущая задача от пользователя
3. `tasks.md` — детализированный список задач и багов
4. `architecture.md` — полная архитектура проекта (этот файл)
5. `rules.md` — правила работы ИИ
6. `user-responses.md` — ответы пользователя о багах

**НЕ начинай работу, пока не прочитал все 6 файлов.**

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

## 1. Общая структура проекта

```
GhostBrowser/
├── App.xaml / App.xaml.cs              # Точка входа, глобальные стили и ресурсы
├── MainWindow.xaml / MainWindow.xaml.cs # Главное окно браузера
├── GhostBrowser.csproj                  # Конфигурация проекта (.NET 10, WPF, WebView2)
├── NewTabPage.html                      # HTML-страница новой вкладки (копируется в output)
│
├── ViewModels/
│   ├── MainViewModel.cs                 # Главный VM: вкладки, навигация, оркестрация сервисов
│   ├── TabViewModel.cs                  # VM одной вкладки: WebView2, URL, заголовок, прогресс
│   ├── ViewModelBase.cs                 # Базовый класс с INotifyPropertyChanged
│   ├── RelayCommand.cs                  # Реализация ICommand для привязки команд
│   └── AsyncRelayCommand.cs             # Async реализация ICommand
│
├── Models/
│   ├── Bookmark.cs                      # Модель закладки
│   └── HistoryEntry.cs                  # Модель записи истории
│
├── Services/
│   ├── StealthService.cs                # Режим невидимости (Win32 SetWindowDisplayAffinity)
│   ├── HistoryService.cs                # CRUD истории с JSON-сохранением
│   ├── BookmarkService.cs               # CRUD закладок с JSON-сохранением
│   ├── SearchService.cs                 # Поисковые системы, нормализация URL
│   └── SettingsService.cs               # Настройки приложения, DNS-тесты, INotifyPropertyChanged
│
└── Views/
    ├── SettingsPage.xaml / SettingsPage.xaml.cs  # Страница меню/настроек (UserControl)
    └── DnsTestWindow.xaml / DnsTestWindow.xaml.cs # Модальное окно результатов DNS-теста
```

---

## 2. Стек технологий

| Компонент | Технология | Назначение |
|-----------|-----------|------------|
| **UI-фреймворк** | WPF (Windows Presentation Foundation) | Декларативный интерфейс через XAML |
| **Язык** | C# 12 | Nullable reference types, паттерн-матчинг |
| **Платформа** | .NET 10.0-windows | WinExe, UseWPF |
| **Браузерный движок** | WebView2 (Chromium, v1.0.2739.15) | Рендеринг веб-страниц на каждой вкладке |
| **Win32 API** | `SetWindowDisplayAffinity` (user32.dll) | Режим невидимости от захвата экрана |
| **Хранение данных** | JSON-файлы в `%APPDATA%\GhostBrowser\` | Закладки, история, настройки |
| **Сетевые операции** | `HttpClient`, `UdpClient` | DNS-тесты, проверка доступности сайтов |

---

## 3. Компоненты

### 3.1. Views (Представления)

#### MainWindow (`MainWindow.xaml` + `MainWindow.xaml.cs`)

**Назначение:** Главное окно браузера. Содержит всю видимую структуру UI.

**Структура окна (Grid с 7 строками):**
1. **Row 0** — Title bar: логотип, индикатор stealth, кнопки управления окном (свернуть, развернуть, закрыть)
2. **Row 1** — Панель вкладок: TabControl с кнопкой "+"
3. **Row 2** — Навигационная панель: кнопки назад/вперёд/обновить/домой, адресная строка, закладка, поисковик, stealth, меню
4. **Row 3** — Панель закладок: горизонтальный скролл с кнопками закладок
5. **Row 4** — Прогресс-бар загрузки (градиентная полоска 3px)
6. **Row 5** — **ContentArea**: ContentControl, привязанный к `DisplayedContent` (WebView или SettingsPage)
7. **Row 6** — Status bar: текст статуса, зум, часы

**Ключевые особенности:**
- `WindowStyle="None"` + `AllowsTransparency="True"` — кастомный title bar
- `WindowChrome` — нативное изменение размера
- `DataTemplate DataType="{x:Type vm:TabViewModel}"` — автоматическое отображение WebView2 для вкладки
- `InputBindings` — привязка горячих клавиш к командам ViewModel

**Code-behind ответственность:**
- Обработка событий UI-контролов (UrlBox_KeyDown, кнопки окна, мышь)
- Инициализация MainViewModel и StealthService
- Анимация появления окна
- Переключение между WebView и SettingsPage
- Полноэкранный режим (F11)
- Обновление индикатора stealth mode

#### SettingsPage (`SettingsPage.xaml` + `SettingsPage.xaml.cs`)

**Назначение:** UserControl с боковой навигацией и разделами: DNS, Общие, Приватность, История, Закладки, О программе.

**Структура:**
- Левая колонка (230px) — сайдбар с кнопками навигации
- Правая колонка (*) — ScrollViewer с переключаемыми секциями

**Секции:**
- **DNS** — ToggleSwitch, ComboBox пресетов DNS, поле ввода, кнопка "Тест"
- **Общие** — тёмная тема, размер шрифта (Slider), домашняя страница
- **Приватность** — блокировка трекеров, блокировка cookies третьих сторон
- **История** — ListView с записями истории, кнопка очистки
- **Закладки** — ListView с закладками
- **О программе** — логотип, версия, список горячих клавиш

**Механизм переключения:** Метод `ShowSection()` устанавливает `Visibility` каждой секции. При активации истории/закладок — подставляет ItemsSource из сервисов.

#### DnsTestWindow (`DnsTestWindow.xaml` + `DnsTestWindow.xaml.cs`)

**Назначение:** Модальное окно с результатами DNS-теста. Принимает коллекцию строк и отображает их в ScrollViewer.

---

### 3.2. ViewModels

#### ViewModelBase

**Назначение:** Базовый абстрактный класс для всех ViewModel. Реализует `INotifyPropertyChanged`.

**Методы:**
- `OnPropertyChanged(propertyName)` — вызывает событие PropertyChanged
- `Set<T>(ref field, value, propertyName)` — устанавливает поле, вызывает уведомление при изменении, возвращает true если значение изменилось

#### RelayCommand

**Назначение:** Реализация `ICommand` для привязки действий к UI.

**Методы:**
- `Execute(parameter)` — вызывает переданный Action
- `CanExecute(parameter)` — проверяет условие (если задано)
- `RaiseCanExecuteChanged()` — уведомляет UI о изменении доступности команды

**Ограничение:** Не поддерживает async/await напрямую. Асинхронные операции запускаются через `async void` в методах ViewModel.

#### MainViewModel

**Назначение:** Центральный оркестратор приложения. Управляет вкладками, навигацией, сервисами и состоянием UI.

**Состояние:**
| Свойство | Тип | Описание |
|----------|-----|----------|
| `Tabs` | `ObservableCollection<TabViewModel>` | Коллекция открытых вкладок |
| `SelectedTab` | `TabViewModel?` | Активная вкладка |
| `DisplayedContent` | `object?` | Текущий контент (WebView или SettingsPage) |
| `UrlInput` | `string` | Текст адресной строки |
| `IsStealthMode` | `bool` | Режим невидимости |
| `IsSettingsOpen` | `bool` | Открыто ли меню |
| `IsBookmarked` | `bool` | Текущая страница в закладках |
| `SearchEngineIcon` | `string` | Иконка текущего поисковика |
| `StatusText` | `string` | Текст в статус-баре |
| `ClockTime` | `string` | Текущее время (обновляется каждую секунду) |

**Сервисы (инициализируются в конструкторе):**
- `StealthService` — режим невидимости
- `HistoryService` — история посещений
- `BookmarkService` — закладки
- `SearchService` — поисковые системы
- `SettingsService` — настройки приложения

**Команды:**
| Команда | Действие |
|---------|----------|
| `AddTabCommand` | Создать новую вкладку |
| `CloseTabCommand` | Закрыть указанную вкладку |
| `GoBackCommand` | Назад в текущей вкладке |
| `GoForwardCommand` | Вперёд в текущей вкладке |
| `RefreshCommand` | Обновить страницу |
| `GoHomeCommand` | Показать новую вкладку |
| `NavigateCommand` | Перейти по URL из адресной строки |
| `NavigateToBookmarkCommand` | Перейти по URL закладки |
| `ToggleStealthCommand` | Переключить режим невидимости |
| `ToggleBookmarkCommand` | Добавить/удалить закладку |
| `CycleSearchEngineCommand` | Переключить поисковую систему |
| `FocusUrlCommand` | Сфокусировать адресную строку |

**Ключевые методы:**
- `CreateTab(url?)` — async void, создаёт новую вкладку с WebView2. Если URL не указан — показывает NewTabPage.
- `CloseTab(parameter)` — закрывает вкладку, выбирает соседнюю, закрывает окно если вкладок не осталось.
- `UpdateFromSelectedTab()` — синхронизирует свойства ViewModel со свойствами выбранной вкладки, подписывается на её события.
- `NavigateFromInput(parameter)` — навигация по тексту из адресной строки.
- `NavigateToUrl(url)` — программная навигация.
- `HandleKeyboardShortcut(key, modifiers)` — обработка горячих клавиш (Ctrl+T, Ctrl+W, Ctrl+L, Ctrl+Shift+H и т.д.).
- `OpenSettings(settingsPage)` / `CloseSettings()` — переключение между WebView и SettingsPage через DisplayedContent.
- `Cleanup()` — остановка таймера, disposal сервисов и вкладок при закрытии окна.

**Подписка на события вкладок:**
- `OnSelectedTabPropertyChanged` — обновляет CanGoBack, CanGoForward, IsLoading в MainViewModel при изменении свойств TabViewModel.
- `OnSelectedTabNavigationCompleted` — сохраняет запись в историю при завершении навигации (если URL не ghost://).

#### TabViewModel

**Назначение:** Обёртка вокруг одного экземпляра WebView2. Инкапсулирует навигацию и состояние вкладки.

**Состояние:**
| Свойство | Тип | Описание |
|----------|-----|----------|
| `WebView` | `WebView2?` | WebView2 контрол (приватный сеттер) |
| `Title` | `string` | Заголовок страницы |
| `Url` | `string` | Текущий URL |
| `IsLoading` | `bool` | Страница загружается |
| `Progress` | `double` | Прогресс загрузки (0-100) |
| `CanGoBack` | `bool` | Есть ли история назад |
| `CanGoForward` | `bool` | Есть ли история вперёд |

**Жизненный цикл WebView2:**
1. **Конструктор** — создаёт WebView2, подписывается на события, запускает `InitializeWebViewAsync`.
2. **InitializeWebViewAsync** — `await EnsureCoreWebView2Async(environment)`, устанавливает тёмную тему, выполняет начальную навигацию.
3. **Navigate/ShowNewTabPage** — навигация на URL или показ встроенной HTML-страницы.
4. **Dispose** — отписка от всех событий ДО вызова `WebView.Dispose()`.

**Обработчики событий WebView2:**
- `WebView_NavigationStarting` — устанавливает Progress=30, IsLoading=true
- `WebView_ContentLoading` — Progress=50
- `WebView_NavigationCompleted` — Progress=100, IsLoading=false, обновляет Title/Url/CanGoBack/CanGoForward, сбрасывает прогресс через 500мс, вызывает событие `NavigationCompleted`.
- `WebView_SourceChanged` — обновляет Url, CanGoBack, CanGoForward

**Методы:**
- `Navigate(url)` — нормализует URL через SearchService и выполняет навигацию.
- `ShowNewTabPage()` — загружает NewTabPage.html через `NavigateToString`. Использует fallback-HTML если файл не найден.
- `GoBack()` / `GoForward()` / `Reload()` / `Stop()` — стандартные операции навигации.
- `Dispose()` — корректное освобождение ресурсов WebView2.

**Событие:** `NavigationCompleted` — передаёт `TabNavigationCompletedEventArgs` (Title, Url) для MainViewModel, который сохраняет запись в историю.

---

### 3.3. Models

#### Bookmark

```
Id: Guid (автогенерация)
Title: string
Url: string
Favicon: string (зарезервировано, не используется)
CreatedAt: DateTime
```

#### HistoryEntry

```
Id: Guid (автогенерация)
Title: string
Url: string
VisitedAt: DateTime
```

Обе модели — простые POCO-классы без логики. Сериализуются в JSON через `System.Text.Json`.

---

### 3.4. Services

#### StealthService

**Назначение:** Управление режимом невидимости через Win32 API `SetWindowDisplayAffinity`.

**Константы:**
- `WDA_NONE (0x00)` — обычное поведение, окно видно всем
- `WDA_MONITOR (0x01)` — fallback, видно только на физическом мониторе
- `WDA_EXCLUDEFROMCAPTURE (0x11)` — полная невидимость для захвата экрана (Windows 10 2004+)

**Методы:**
- `Initialize(Window)` — сохраняет ссылку на окно, подписывается на `SourceInitialized`.
- `OnSourceInitialized` — получает хэндл окна через `WindowInteropHelper`, применяет отложенный запрос.
- `ToggleStealthMode()` — переключает режим.
- `SetStealthMode(bool)` — устанавливает режим. Если хэндл не готов — откладывает применение.
- `ApplyAffinity(bool)` — вызывает `SetWindowDisplayAffinity`. Fallback: если `WDA_EXCLUDEFROMCAPTURE` не поддерживается — использует `WDA_MONITOR`.
- `GetCurrentAffinity()` — возвращает текущее значение affinity.
- `Dispose()` — отписка от событий, сброс affinity в `WDA_NONE`.

**Событие:** `StealthModeChanged` — уведомляет об изменении режима.

#### HistoryService

**Назначение:** Управление историей посещений с сохранением в JSON.

**Хранилище:** `%APPDATA%\GhostBrowser\history.json`

**Методы:**
- `AddEntry(title, url)` — добавляет запись в начало коллекции, ограничивает до 1000 записей, сохраняет.
- `LoadHistory()` — загружает из JSON при инициализации.
- `SaveHistory()` — сериализует коллекцию в JSON.
- `ClearHistory()` — очищает коллекцию и файл.

**Свойство:** `History: ObservableCollection<HistoryEntry>` — публичная коллек для привязки к UI.

#### BookmarkService

**Назначение:** Управление закладками с сохранением в JSON.

**Хранилище:** `%APPDATA%\GhostBrowser\bookmarks.json`

**Методы:**
- `AddBookmark(title, url)` — проверяет дубликаты, добавляет, сохраняет.
- `RemoveBookmark(id)` — удаляет по Guid, сохраняет.
- `IsBookmarked(url)` — проверка по URL.
- `ClearBookmarks()` — полная очистка.
- `LoadBookmarks()` / `SaveBookmarks()` — загрузка/сохранение JSON.

**Свойство:** `Bookmarks: ObservableCollection<Bookmark>` — публичная коллек.

#### SearchService

**Назначение:** Нормализация URL и управление поисковыми системами.

**Поисковые системы (enum SearchEngine):**
- Google → `https://www.google.com/search?q=...`
- Bing → `https://www.bing.com/search?q=...`
- DuckDuckGo → `https://duckduckgo.com/?q=...`
- Yandex → `https://yandex.ru/search/?text=...`

**Методы:**
- `IsSearchQuery(input)` — определяет, является ли ввод поисковым запросом (нет точки, нет http://, есть пробелы).
- `NormalizeUrl(input)` — если поисковый запрос → формирует URL поиска, иначе добавляет `https://` если нет протокола.
- `GetSearchUrl(query)` — формирует URL для текущего поисковика.
- `GetEngineIcon(engine)` — возвращает однобуквенную иконку (G, B, D, Я).

**Свойство:** `CurrentEngine` — текущий поисковик (по умолчанию Google).

**Событие:** `EngineChanged` — уведомляет при смене поисковика.

#### SettingsService

**Назначение:** Настройки приложения + DNS-тестирование. Реализует `INotifyPropertyChanged` (архитектурная проблема — сервис не должен это делать).

**Хранилище:** `%APPDATA%\GhostBrowser\settings.json`

**Модель настроек (AppSettings):**
- `UseCustomDns: bool`
- `CustomDns: string`
- `SelectedDnsPreset: string`
- `DarkTheme: bool` (по умолчанию true)
- `FontSize: double` (по умолчанию 14)
- `HomePage: string` (по умолчанию "ghost://newtab")
- `DefaultSearchEngine: string`
- `BlockTrackers: bool` (по умолчанию true)
- `BlockThirdPartyCookies: bool`

**DNS-пресеты:** 17 предустановленных серверов (Google, Cloudflare, OpenDNS, Quad9, AdGuard, UncensoredDNS, Yandex, Control D, NextDNS и др.)

**Методы:**
- `RunDnsTestAsync(dns)` — тестирует доступность 5 сайтов (Google, Gmail, Cloudflare, Gemini, YouTube) через `HttpClient.Get`, проверяет DNS-сервер через UDP-запрос. Возвращает список строк с результатами.
- `TestDnsAsync(dns)` — обёртка над RunDnsTestAsync с обновлением свойств UI.
- `SaveSettings()` / `LoadSettings()` — сериализация.
- `ResetToDefaults()` — сброс настроек.
- `ApplyDnsPreset(name)` — применение выбранного пресета.

**Свойства UI-состояния:**
- `IsTestingDns: bool`
- `DnsTestResult: string`
- `SaveNotification: string`

---

## 4. Поток данных (Data Flow)

### 4.1. Инициализация приложения

```
App.xaml (StartupUri="MainWindow.xaml")
    → MainWindow.ctor()
        → InitializeComponent()
        → var vm = new MainViewModel()
            → new StealthService()
            → new HistoryService() → LoadHistory() из JSON
            → new BookmarkService() → LoadBookmarks() из JSON
            → new SearchService()
            → new SettingsService() → LoadSettings() из JSON
            → Создание команд (RelayCommand)
            → Запуск DispatcherTimer (часы, 1 сек)
            → Подписка: BookmarkService.Bookmarks.CollectionChanged → UpdateBookmarkState
            → CreateTab() — создание первой вкладки
                → GetEnvironmentAsync() → CoreWebView2Environment (%APPDATA%\GhostBrowser)
                → Dispatcher.InvokeAsync
                    → new TabViewModel(env, searchService, url)
                        → new WebView2()
                        → Подписка на события WebView2
                        → InitializeWebViewAsync()
                            → await EnsureCoreWebView2Async(env)
                            → CoreWebView2.Profile.PreferredColorScheme = Dark
                            → ShowNewTabPage() → NavigateToString(NewTabPage.html)
                    → Tabs.Add(tab)
                    → SelectedTab = tab
        → vm.StealthService.Initialize(this) — подписка на SourceInitialized
        → UpdateBookmarksBar() — BookmarksBar.ItemsSource = vm.BookmarkService.Bookmarks
        → Подписка: vm.StealthService.StealthModeChanged → OnStealthModeChanged
        → Подписка: vm.PropertyChanged → ViewModel_PropertyChanged (плейсхолдер URL)
```

### 4.2. Управление вкладками

```
User нажимает "+" или Ctrl+T
    → AddTabCommand → CreateTab(url: null)
        → await GetEnvironmentAsync() (кэшируется)
        → Dispatcher.InvokeAsync
            → new TabViewModel(env, SearchService)
                → WebView2 создаётся, инициализируется асинхронно
            → Tabs.Add(tab)
            → SelectedTab = tab
                → set { UpdateFromSelectedTab() }
                    → Подписка на SelectedTab.PropertyChanged
                    → Подписка на SelectedTab.NavigationCompleted
                    → UrlInput, CanGoBack, CanGoForward, IsLoading синхронизированы
                    → DisplayedContent = SelectedTab.WebView (т.к. IsSettingsOpen == false)
```

```
User нажимает Ctrl+W или кнопку закрытия вкладки
    → CloseTabCommand → CloseTab(parameter)
        → Определение tabToClose
        → Если закрывается SelectedTab → выбор соседней (index или index-1)
        → tabToClose.Dispose() (отписка от событий WebView2 + WebView.Dispose)
        → Tabs.Remove(tabToClose)
        → UpdateCloseTabCanExecute()
        → Если Tabs.Count == 0 → Application.Current.MainWindow?.Close()
```

### 4.3. Навигация

```
User вводит URL в адресную строку, нажимает Enter
    → UrlBox_KeyDown (Key.Enter)
        → vm.NavigateFromInput(UrlBox.Text)
            → SelectedTab?.Navigate(UrlInput)
                → SearchService.NormalizeUrl(UrlInput)
                    → IsSearchQuery()? → URL поисковика
                    → Нет http:// → "https://" + input
                → WebView.Source = new Uri(normalizedUrl)
                → IsLoading = true, Progress = 10

    → WebView_NavigationStarting
        → Progress = 30, IsLoading = true

    → WebView_ContentLoading
        → Progress = 50

    → WebView_NavigationCompleted
        → Progress = 100, IsLoading = false
        → Title = DocumentTitle, Url = Source
        → CanGoBack/CanGoForward обновлены
        → Task.Delay(500ms) → Progress = 0
        → NavigationCompleted?.Invoke(this, args)

    → OnSelectedTabNavigationCompleted
        → HistoryService.AddEntry(title, url)
            → History.Insert(0, entry)
            → Ограничение до 1000 записей
            → SaveHistory() → history.json

    → UpdateFromSelectedTab() (при изменении SelectedTab)
        → UrlInput = (Url != "ghost://newtab" ? Url : "")
        → CanGoBack, CanGoForward, IsLoading синхронизированы
```

### 4.4. Открытие/закрытие меню (Settings)

```
User нажимает "⋮" (BtnMenu_Click)
    → Если IsSettingsOpen == true → vm.CloseSettings()
        → IsSettingsOpen = false
        → DisplayedContent = SelectedTab?.WebView
    → Если IsSettingsOpen == false
        → _settingsPage ??= new SettingsPage { DataContext = vm }
        → vm.OpenSettings(_settingsPage)
            → IsSettingsOpen = true
            → DisplayedContent = settingsPage

ContentControl (Grid.Row=5, Content="{Binding DisplayedContent}")
    → Автоматически обновляется при изменении DisplayedContent
    → DataTemplate для TabViewModel → ContentControl { Binding WebView }

SettingsPage → раздел "История"
    → ShowSection("История")
        → HistorySection.Visibility = Visible
        → HistoryList.ItemsSource = VM.HistoryService.History

SettingsPage → раздел "Закладки"
    → ShowSection("Закладки")
        → BookmarksSection.Visibility = Visible
        → BookmarksList.ItemsSource = VM.BookmarkService.Bookmarks
```

### 4.5. Режим невидимости

```
User нажимает "👻" или Ctrl+Shift+H
    → ToggleStealthCommand → ToggleStealth()
        → StealthService.ToggleStealthMode()
            → SetStealthMode(!_isStealthMode)
                → ApplyAffinity(enabled)
                    → affinity = enabled ? WDA_EXCLUDEFROMCAPTURE : WDA_NONE
                    → SetWindowDisplayAffinity(hWnd, affinity)
                    → Fallback: WDA_MONITOR при неудаче
                    → StealthModeChanged?.Invoke(this, true/false)

    → vm.StealthService.StealthModeChanged → IsStealthMode = stealth
    → MainWindow.OnStealthModeChanged
        → StealthIndicatorBorder.Background = SuccessBrush / TextMutedBrush
        → StealthStatusText.Text = "Stealth: ON" / "Stealth: OFF"
```

---

## 5. Ключевые классы и их ответственность

| Класс | Файл | Ответственность |
|-------|------|----------------|
| **App** | `App.xaml.cs` | Точка входа (StartupUri), пустой — всё в XAML |
| **MainWindow** | `MainWindow.xaml.cs` | UI-обработчики, связь XAML с ViewModel, управление окном |
| **MainViewModel** | `ViewModels/MainViewModel.cs` | Оркестрация вкладок, навигации, сервисов, состояния UI |
| **TabViewModel** | `ViewModels/TabViewModel.cs` | Обёртка WebView2, навигация одной вкладки, события |
| **ViewModelBase** | `ViewModels/ViewModelBase.cs` | INotifyPropertyChanged, Set-метод |
| **RelayCommand** | `ViewModels/RelayCommand.cs` | ICommand с Action/Func |
| **StealthService** | `Services/StealthService.cs` | Win32 SetWindowDisplayAffinity, скрытие от OBS/Discord |
| **HistoryService** | `Services/HistoryService.cs` | CRUD истории, JSON (%APPDATA%/history.json), лимит 1000 |
| **BookmarkService** | `Services/BookmarkService.cs` | CRUD закладок, JSON (%APPDATA%/bookmarks.json) |
| **SearchService** | `Services/SearchService.cs` | Нормализация URL/поиск, 4 поисковика |
| **SettingsService** | `Services/SettingsService.cs` | Настройки (JSON), DNS-пресеты, DNS-тестирование, INotifyPropertyChanged |
| **SettingsPage** | `Views/SettingsPage.xaml.cs` | UserControl меню, 6 разделов, навигация, DNS-тест |
| **DnsTestWindow** | `Views/DnsTestWindow.xaml.cs` | Модальное окно результатов DNS-теста |
| **HistoryWindow** | `HistoryWindow.cs` | Code-only окно истории (НЕ ИСПОЛЬЗУЕТСЯ, заменено SettingsPage) |
| **Bookmark** | `Models/Bookmark.cs` | POCO-модель закладки |
| **HistoryEntry** | `Models/HistoryEntry.cs` | POCO-модель записи истории |

---

## 6. Известные архитектурные проблемы

### КРИТИЧЕСКИЕ (исправлены)

1. **Дублирование WebView2** — WebView рендерился дважды: через DataTemplate TabControl И через ручное добавление в ContentGrid.
   - **Исправление:** ContentControl с Binding к DisplayedContent.

2. **Краш при открытии меню** — SettingsPage и WebView конкурировали за одно место в Grid.
   - **Исправление:** Единый ContentControl переключается через DisplayedContent.

3. **Утечка памяти в WebView2** — События не отписывались перед Dispose().
   - **Исправление:** Отписка выполняется ДО вызова Dispose().

4. **Пустые catch-блоки** — Исключения глотались без логирования.
   - **Исправление:** Все catch теперь логируют через Debug.WriteLine.

### СРЕДНИЕ (требуют исправления)

5. **SettingsService реализует INotifyPropertyChanged** — Сервис не должен реализовывать INPC, это ответственность ViewModel.
   - **Рекомендация:** Вынести настройки в SettingsViewModel.

6. **Code-behind вызывает конструктор View** — MainWindow создаёт SettingsPage напрямую, нарушая MVVM.
   - **Рекомендация:** Использовать DataTemplate + DataTrigger для автоматического отображения View по типу ViewModel.

7. **Нет валидации URL** — Navigate() не проверяет корректность URL перед созданием Uri.
   - **Рекомендация:** Добавить валидацию с пользовательским уведомлением.

8. **RelayCommand не поддерживает async** — Все команды синхронные, CreateTab — async void.
   - **Рекомендация:** Создать AsyncRelayCommand для асинхронных операций.

### НИЗКИЕ (улучшения)

9. **SettingsViewModel.cs не используется** — Файл мёртвый код. Можно удалить или интегрировать.

10. **HistoryWindow.cs не используется** — Code-only окно истории, функциональность перенесена в SettingsPage. Мёртвый код.

11. **Нет unit-тестов** — Сервисы (SearchService, BookmarkService, HistoryService) не покрыты тестами.

12. **Жёсткая привязка к UI** — StealthService зависит от Window, что усложняет тестирование.
    - **Рекомендация:** Ввести интерфейс IWindowHandleProvider.

13. **SettingsService смешивает ответственность** — Хранение настроек, DNS-тестирование, INotifyPropertyChanged, HTTP/UDP запросы.
    - **Рекомендация:** Разделить на SettingsStore и DnsTestService.

14. **Каждая вкладка — отдельный WebView2** — Высокое потребление RAM (~50-100MB на вкладку).
    - **Рекомендация:** Для большого числа вкладок可以考虑 виртуализацию (уничтожение неактивных WebView2).

---

## 7. Безопасность и хранение данных

| Данные | Путь | Формат |
|--------|------|--------|
| Настройки | `%APPDATA%\GhostBrowser\settings.json` | JSON |
| Закладки | `%APPDATA%\GhostBrowser\bookmarks.json` | JSON |
| История | `%APPDATA%\GhostBrowser\history.json` | JSON |
| WebView2 UserDataFolder | `%APPDATA%\GhostBrowser\` | Chromium-формат |

**Stealth mode:** Не шифрует данные, только скрывает окно от захвата экрана. Не защищает от Display Capture (захват всего экрана) или скриншотов.

**DNS-тесты:** Используют системный HttpClient — не меняют DNS-настройки ОС. Проверка DNS-сервера через UDP-запрос (порт 53) — не влияет на системную конфигурацию.

---

## 8. Производительность

- **WebView2 на вкладку:** Каждая вкладка создаёт отдельный WebView2 → ~50-100MB RAM на экземпляр.
- **Оптимизация:** При закрытии вкладки WebView.Dispose() освобождает ресурсы.
- **Лимит истории:** 1000 записей для предотвращения разрастания JSON.
- **ClockTimer:** DispatcherTimer с интервалом 1 сек — минимальное влияние на CPU.
- **JSON-сохранение:** Синхронная сериализация при каждом изменении (закладка, история, настройки). При большом объёме данных может вызывать задержки.

---

*Документ создан на основе полного анализа всех файлов проекта GhostBrowser v1.0.*
