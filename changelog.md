# 📋 Changelog — KING Browser

> Файл отслеживания всех изменений. Перед каждым изменением записывай сюда
> что было ДО и что стало ПОСЛЕ. Это предотвращает потерю рабочего кода.

---

## Формат записи

```
### [Дата и время] — [Краткое описание]
**Файл:** `путь/к/файлу`
**Причина:** почему меняем
**ДО:**
```csharp
// старый код
```
**ПОСЛЕ:**
```csharp
// новый код
```
**Результат:** ✅ работает / ❌ сломало
```

---

## История изменений

### 2026-04-07 03:30 — Восстановление рабочей версии из git
**Файл:** Весь проект
**Причина:** После изменений в App.xaml (замена StaticResource на HEX) проект перестал запускаться
**Действие:** `git checkout 2e390fb -- .` + чистая пересборка
**Результат:** ✅ работает

### 2026-04-07 03:30 — KING.png: Resource → Content
**Файл:** `GhostBrowser.csproj`
**Причина:** KING.png не попадал в output директорию → приложение падало с XAML ошибкой при загрузке изображения
**ДО:**
```xml
<!-- отсутствует -->
```
**ПОСЛЕ:**
```xml
  <ItemGroup>
    <Content Include="KING.png">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </Content>
  </ItemGroup>
```
**Результат:** ✅ работает

### 2026-04-07 03:30 — Кнопки окна: TextBlock → Path (SVG)
**Файл:** `MainWindow.xaml` (строки ~120-200)
**Причина:** Пользователь просил элегантные иконки вместо текста "─", "□", "✕"
**ДО:**
```xml
<Button x:Name="BtnMinimize" ...>
  <Button.Style>
    <Style TargetType="Button">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bg" Background="Transparent" CornerRadius="6">
              <TextBlock Text="─" Foreground="{TemplateBinding Foreground}"
                         HorizontalAlignment="Center" VerticalAlignment="Center"
                         FontSize="13" FontFamily="Consolas"/>
            </Border>
            ...
```
**ПОСЛЕ:**
```xml
<Button x:Name="BtnMinimize" ... ToolTip="Свернуть">
  <Button.Style>
    <Style TargetType="Button">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bg" Background="Transparent" CornerRadius="6">
              <Path Data="M2,6 L10,6" StrokeThickness="1.2" StrokeLineJoin="Round"
                    HorizontalAlignment="Center" VerticalAlignment="Center"
                    Width="12" Height="12">
                <Path.Stroke>
                  <Binding Path="Foreground" RelativeSource="{RelativeSource AncestorType=Button}"/>
                </Path.Stroke>
              </Path>
            </Border>
            ...
```
**Результат:** ✅ работает (проверено 2026-04-07 03:29)

### 2026-04-07 03:30 — Title Bar: убрать тёмный градиент
**Файл:** `MainWindow.xaml` (строка ~69)
**Причина:** Пользователь просил убрать тёмный цвет (#06090f) наверху
**ДО:**
```xml
<Border Grid.Row="0" BorderBrush="{StaticResource BorderSubtleBrush}" BorderThickness="0,0,0,1">
    <Border.Background>
        <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
            <GradientStop Color="{StaticResource BgDeepest}" Offset="0"/>
            <GradientStop Color="#06090f" Offset="0.5"/>
            <GradientStop Color="{StaticResource BgDeep}" Offset="1"/>
        </LinearGradientBrush>
    </Border.Background>
```
**ПОСЛЕ:**
```xml
<Border Grid.Row="0" BorderBrush="{StaticResource BorderSubtleBrush}" BorderThickness="0,0,0,1"
        Background="{StaticResource BgDeepestBrush}">
```
**Результат:** ✅ работает (проверено 2026-04-07 03:29)

---

## ⚠️ Известные проблемы (НЕ повторять)

### ❌ Замена StaticResource на HEX в ControlTemplate (App.xaml)
**Что случилось:** Заменил `{StaticResource XxxBrush}` на `#hex` внутри ControlTemplate Setter значений → XamlParseException `DeferredBinaryDeserializerExtension`
**Причина:** BAML-компилятор SDK 10 создаёт некорректный binary формат при прямых HEX в ControlTemplate
**Вывод:** НЕ менять StaticResource на HEX внутри ControlTemplate в App.xaml

### ❌ Добавление ApplyClip() с Dispatcher.InvokeAsync
**Что случилось:** Добавил `SizeChanged += ... ApplyClip()` → процесс запускается но MainWindowHandle = 0
**Причина:** Возможно конфликт с WPF Layout или бесконечный цикл
**Вывод:** НЕ добавлять ApplyClip через SizeChanged без тщательного тестирования

### ❌ Удаление Window.Resources (Storyboard, DataTemplate)
**Что случилось:** Убрал Storyboard и DataTemplate → краш
**Причина:** Storyboard нужен для анимации появления, DataTemplate для отображения TabViewModel
**Вывод:** НЕ удалять Window.Resources
