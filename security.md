# 🔒 Безопасность — KING Browser v2.0

> Скрытый браузер с обходом блокировок и защитой от скриншотов

---

## 1. Обзор модели безопасности

### 1.1 Угрозы и защита

| Угроза | Механизм защиты | Статус |
|--------|----------------|--------|
| **Захват экрана (OBS, Discord, Zoom)** | `SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)` | ✅ Реализовано |
| **PrintScreen** | Глобальный хук клавиатуры | ⏳ Запланировано |
| **Snipping Tool** | Обработка WM_PRINTCLIENT | ⏳ Запланировано |
| **Скриншоты WebView2** | Отключение CapturePreview API | ⏳ Запланировано |
| **История посещений** | Сохранение в JSON, возможность очистки | ✅ Реализовано |
| **Cookies и трекеры** | Настройки блокировки в WebView2 Profile | ⏳ Частично |
| **Утечка DNS** | DoH, DoT, кастомный DNS | ⏳ Запланировано |
| **Блокировка сайтов (РФ)** | DoH, прокси, мосты | ⏳ Запланировано |
| **Фишинг** | Нет встроенной защиты | ⏳ Планируется |
| **Отслеживание через fingerprint** | Кастомный User-Agent, блокировка Canvas | ⏳ Планируется |

### 1.2 Принципы безопасности

1. **Минимальное хранение данных** — только история и закладки, всё можно очистить
2. **Изоляция приватных сессий** — режим инкогнито использует временный профиль
3. **Прозрачность для пользователя** — индикаторы stealth mode, статус DNS
4. **Защита от захвата** — Win32 API скрывает окно от программ захвата экрана
5. **Автоматический обход** — при обнаружении блокировки → переключение на DoH/прокси

---

## 2. Режим невидимости (Stealth Mode)

### 2.1 Технология

**API:** `SetWindowDisplayAffinity` (user32.dll)

**Константы:**
```csharp
private const int WDA_NONE = 0x00;              // Обычное поведение
private const int WDA_MONITOR = 0x01;           // Видно только на физическом мониторе
private const int WDA_EXCLUDEFROMCAPTURE = 0x11; // Полная невидимость для захвата
```

### 2.2 Что скрывается

| Программа | Тип захвата | Результат |
|-----------|------------|-----------|
| OBS Studio | Захват экрана/окна | ❌ KING не виден |
| Discord (стрим) | Захват экрана/окна | ❌ KING не виден |
| Zoom | Демонстрация экрана | ❌ KING не виден |
| Teams | Демонстрация экрана | ❌ KING не виден |
| Windows Snipping Tool | Скриншот | ❌ KING не виден |
| PrintScreen | Системный скриншот | ❌ Чёрный квадрат |

### 2.3 Что НЕ скрывается (Stealth 2.0)

| Сценарий | Решение |
|----------|---------|
| PrintScreen | Глобальный хук клавиатуры → блокировка |
| Snipping Tool | WM_PRINTCLIENT → отклонение |
| Скриншот WebView2 | Отключение CapturePreview API |
| Task Manager | Скрытие процесса (опционально) |

### 2.4 Блокировка PrintScreen

```csharp
// Services/GlobalHotkey.cs
public class GlobalHotkey
{
    [DllImport("user32.dll")]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    public void BlockPrintScreen(IntPtr hWnd)
    {
        // VK_SNAPSHOT = 0x2C
        RegisterHotKey(hWnd, 1, 0, 0x2C);
        RegisterHotKey(hWnd, 2, 0x0002, 0x2C); // Ctrl+PrintScreen
        RegisterHotKey(hWnd, 3, 0x0004, 0x2C); // Alt+PrintScreen
    }
}
```

### 2.5 Блокировка скриншотов WebView2

```csharp
// В TabViewModel
WebView.CoreWebView2.Settings.IsGeneralAutofillEnabled = false;
// Отключение доступа к screencast API
await WebView.CoreWebView2.ExecuteScriptAsync(@"
  // Блокировка screencast API
  Object.defineProperty(navigator, 'getDisplayMedia', { value: undefined });
  // Блокировка canvas toDataURL (для fingerprint)
  const origToDataURL = HTMLCanvasElement.prototype.toDataURL;
  HTMLCanvasElement.prototype.toDataURL = function() { return ''; };
");
```

---

## 3. Обход блокировок

### 3.1 DNS over HTTPS (DoH)

**Почему DoH?** Обычный DNS (порт 53) блокируется провайдером. DoH шифрует DNS-запросы через HTTPS.

**Провайдеры:**

| Провайдер | URL | Описание |
|-----------|-----|----------|
| Cloudflare | `https://cloudflare-dns.com/dns-query` | Быстрый, не логирует |
| Google | `https://dns.google/resolve` | Быстрый, логирует |
| Quad9 | `https://dns.quad9.net/dns-query` | Блокировка вредоносных |
| AdGuard | `https://dns.adguard.com/dns-query` | Блокировка рекламы |

### 3.2 Прокси

**SOCKS5:**
```csharp
// WebView2 поддерживает прокси через CoreWebView2EnvironmentOptions
var options = new CoreWebView2EnvironmentOptions(
    additionalBrowserArguments: "--proxy-server=socks5://127.0.0.1:1080"
);
var env = await CoreWebView2Environment.CreateAsync(null, userDataFolder, options);
```

**HTTP/HTTPS:**
```
--proxy-server=http://proxy.example.com:8080
--proxy-server=https://proxy.example.com:3128
```

### 3.3 Мосты (Bridge Mode)

**Концепция:** Если DoH и прокси не помогают, использовать публичный сервер-зеркало.

```
Пользователь → KING Browser → DoH → Если не помогло → Прокси → Если не помогло → Мост
```

### 3.4 Список заблокированных сайтов (РФ)

**Реестр:** https://blocklist.rkn.gov.ru/

**Автоматическое определение:**
```csharp
// При загрузке страницы → таймаут или ошибка
// Проверить: это известный заблокированный сайт?
// Если да → автоматически включить обход
```

---

## 4. Хранение данных

### 4.1 Расположение файлов

| Файл | Путь | Шифрование |
|------|------|-----------|
| `settings.json` | `%APPDATA%\KING\settings.json` | ❌ Нет (планируется DPAPI) |
| `history.json` | `%APPDATA%\KING\history.json` | ❌ Нет |
| `bookmarks.json` | `%APPDATA%\KING\bookmarks.json` | ❌ Нет |
| `profiles.json` | `%APPDATA%\KING\profiles.json` | ❌ Нет |

### 4.2 Шифрование (планируется)

```csharp
// DPAPI — Windows Data Protection API
byte[] encrypted = ProtectedData.Protect(
    plaintextBytes,
    optionalEntropy: null,
    scope: DataProtectionScope.CurrentUser
);
```

---

## 5. Рекомендации по безопасности

### 5.1 Критические (высокий приоритет)

| Задача | Описание | Приоритет |
|--------|----------|-----------|
| Блокировка PrintScreen | Глобальный хук клавиатуры | 🔴 Высокий |
| DoH поддержка | Шифрование DNS-запросов | 🔴 Высокий |
| Блокировка скриншотов WebView2 | Отключение CapturePreview API | 🔴 Высокий |

### 5.2 Важные (средний приоритет)

| Задача | Описание | Приоритет |
|--------|----------|-----------|
| Прокси поддержка | SOCKS5/HTTP прокси | 🟡 Средний |
| Anti-fingerprint | Кастомный User-Agent | 🟡 Средний |
| Шифрование JSON | DPAPI для настроек | 🟡 Средний |

### 5.3 Желательные (низкий приоритет)

| Задача | Описание | Приоритет |
|--------|----------|-----------|
| Мастер-пароль | Защита доступа к истории | 🟢 Низкий |
| Автоочистка | Таймер очистки истории | 🟢 Низкий |
| Safe Browsing | Проверка URL по чёрным спискам | 🟢 Низкий |

---

## 6. Горячие клавиши безопасности

| Комбинация | Действие |
|------------|----------|
| `Ctrl+Shift+H` | Переключить stealth mode |
| `Ctrl+Shift+N` | Открыть инкогнито |
| `Ctrl+Shift+S` | Блокировка PrintScreen |
| `Ctrl+Shift+P` | Прокси режим |
| `Ctrl+Shift+B` | Мост режим |

---

*Файл обновляется при изменении настроек безопасности или добавлении новых механизмов защиты.*
