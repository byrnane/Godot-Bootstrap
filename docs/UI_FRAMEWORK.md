# UI: оформление, компоненты и экраны

Общая база для 2D и 3D использует Godot Control, контейнеры и Theme. В ней нет
собственного рендера, второго стека окон или обязательного плагина.
Исходный макет Figma: [Game Template UI](https://www.figma.com/design/le33QeQV2WWwvlW0hGpT0M/Game-Template-UI).
Порядок работы — в [FIGMA.md](FIGMA.md).
Текущее состояние приемки и переноса между ветками: [READINESS.md](READINESS.md).

## Где что менять

| Слой | Место | Ответственность |
| --- | --- | --- |
| Оформление | `shared/ui/theme/neutral_theme.tres` | Шрифты, StyleBox, состояния, семантические иконки и цвета |
| Компоненты | `shared/ui/components/` | Показ переданных данных, локальное взаимодействие, сигналы намерений |
| Композиция | `features/`, `shared/ui/feedback/`, `shared/ui/loading/` | Состав экрана, адаптация данных к компонентам |
| Навигация | `AppFlow`, `SceneRouter`, `UiShell`, `BaseModal` | Маршруты, стек окон, пауза, загрузка, возврат фокуса |
| Данные | Существующие managers и контексты | Настройки, ввод, сохранения, игровая сессия |

Компоненты не читают SessionContext, не сохраняют данные и не переключают сцены.
Функции настроек, переназначения клавиш, сохранения/загрузки и подтверждений
сохраняют своих прежних владельцев. Поведение не копируется для каждого стиля.
В `UiFeedback.confirm` опция `destructive: true` выбирает оформление опасного
действия; она не меняет обработчики подтверждения и отмены.

## Другой стиль

1. Дублируйте `neutral_theme.tres` **вместе с вложенными ресурсами**, чтобы правка
   StyleBox не меняла исходную тему. В Theme editor сохраните нужные вариации типов.
2. Замените шрифты, формы, отступы стилей, состояния и иконки.
3. Назначьте ресурс в Project Settings → GUI → Theme → Custom. Для локального
   оформления можно назначить Theme корневому Control сцены.
4. Запустите `shared/ui/catalog/ui_catalog.tscn` через F6, затем основные экраны.

Основные роли:

- `UiButtonPrimary`, `UiButtonSecondary`, `UiButtonGhost`, `UiButtonDanger`,
  `UiIconButton`, `UiNavigationItem`, `UiTabItem`, `UiSaveSlot` наследуют Button.
- `UiCanvas`, `UiSurface`, `UiRaised`, `UiDialog`, `UiTransparent` — PanelContainer.
- `UiHero`, `UiDisplay`, `UiHeading`, `UiSection`, `UiBody`, `UiLabel`, `UiSmall`,
  `UiCaption`, `UiMuted` — Label.
- `UiHealthBar`, `UiManaBar`, `UiStaminaBar` — ProgressBar.
- `UiToggle` — CheckBox; `UiNumberEdit` — внутренний LineEdit компактного SpinBox.
- `UiStatusInfo/Success/Warning/Error` и соответствующие типы `…Text` — статусы;
  `UiToastInfo/Success/Warning/Error` — уведомления.
- `UiIcons` содержит именованные иконки; `UiResourceBar` — health/mana/stamina;
  `UiStatusIcons` — info/success/warning/error.
- `UiTokens` содержит дополнительные семантические цвета и размеры. Это обычные
  элементы Godot Theme: они не являются автоматическими алиасами цветов StyleBox.
  При смене палитры редактируйте и нужные StyleBox, и соответствующие цвета иконок.

Обычные Button, CheckBox, OptionButton, LineEdit, Slider, ScrollBar, ProgressBar
получают оформление из той же темы. Hover, pressed, disabled и видимый focus
используют штатные состояния Godot. Новая обертка над каждым Control не нужна.
`UiButton` добавляет только необязательный `icon_role` из `UiIcons`.

Тема выбирается проектом; переключатель стиля в пользовательские настройки не добавлен.
Старая `scifi_dark_theme.tres` не используется и не содержит нового набора ролей.

## Компоненты

| Компонент | Контракт |
| --- | --- |
| UiCard | Контент в `ContentMargin/Content`, `elevated`, `inner_padding` |
| UiSectionHeader / UiFormRow | Ключи заголовка/описания; у строки отдельный Content для контролов, stacked/compact |
| UiTabStrip | Страницы в PagesContainer, `set_current_tab`, `tab_changed`; sidebar для вертикальной навигации |
| UiResourceBar | `set_amount(current, maximum)`, kind; отрицательные значения и переполнение ограничиваются при показе |
| UiResources | `apply_resources(Dictionary)`; отсутствующие ресурсы скрываются |
| UiCounter | `icon_role` из Theme или произвольная `icon`, строковое `value` |
| UiVolumeRow | `title_key`, нормализованное `value`; публичный native HSlider `slider`, процент вычисляется из значения |
| UiBindingRow | `title_key`, два native Button, `binding_requested(slot)`; InputManager подключает экран настроек |
| UiSaveSlot | `title`, `detail`, `preview`; штатные pressed/toggle/focus, без файлового IO |
| UiTextPanel | `caption_key`, `text`; используется сценами objective, level_badge, tooltip, key_hint |
| UiInteractionPrompt | `key_text`, `text`; игра передает актуальную подсказку ввода |
| UiResultContent | `configure(title, message, metrics, primary_text, secondary_text)`; два сигнала действий |
| UiStatusBadge | `variant`, `text_key` или `set_badge_text` |
| UiSpinner | Нативная SVG-иконка и вращение; в редакторе статичен |

Победа и поражение используют один UiResultContent. Игра сама определяет исход,
метрики и обработку действий; демонстрационные условия победы в шаблон не внесены.
Подсказки мыши, клавиатуры и геймпада используют UiKeyHint и переданный текст.

## Добавление компонента

Сначала проверьте native Control и существующие сцены. Если нужен составной элемент,
создайте PackedScene в `shared/ui/components/`, используйте контейнеры и семантические
Theme variations. Данные передавайте через свойства/метод, действия наружу — сигналами.
Для независимого предпросмотра можно использовать `@tool`; такой скрипт не должен
вызывать autoload-сервисы. Добавьте пример в каталог. Проверяйте значимые контракты,
а не точное дерево узлов или пиксельные координаты.

Статические пользовательские подписи используют `translations/UI.csv`.
В компоненты HUD можно передавать уже подготовленные игровые строки.

## HUD и размеры

GameplayHud показывает обязательные health/score/level и принимает необязательные
`mana`, `max_mana`, `stamina`, `max_stamina`, `objective`, `interaction_text`,
`interaction_key`, `time_text`, `max_health` через `apply_view_model`.
Входной словарь копируется. В HUD нет зависимости от Node2D, Node3D или камеры.
Кнопки симуляции шаблона остаются в раскрываемой панели «Демо-действия».

Базовая композиция — 1280×720; штатный canvas_items/stretch сохраняет пропорции
при изменении окна. HUD использует якоря краев и центра. Контент настроек/сохранений
прокручивается отдельно от действий. Список переназначений имеет свой ScrollContainer.
Контролы в UiFormRow имеют собственную минимальную ширину, поэтому переключатель
не растягивается до размера выпадающего списка.

`UiDensity` включает компактную компоновку при логической ширине меньше 960 или
высоте меньше 540. Она использует текущую Theme с уменьшенными метриками,
сохраняя палитру, шрифты и семантические роли. Общие экраны и контроллеры остаются
одинаковыми во всех ветках. Настройки переключают sidebar на горизонтальные вкладки,
колонки и сохранения располагаются вертикально; панели действий поддерживают перенос.
В компактном списке сейвов прокруткой и следованием за фокусом владеет внешний
BodyScroll. Компоненты, создаваемые динамически, также получают компактные размеры.
PixelArt сохраняет единый viewport 640×360, integer/nearest и общий стек модальных окон.

## Проверка

Через штатный wrapper запускайте `-Suite ui`, `flow`, `localization` и `transitions`,
когда затронуты соответствующие сценарии. UI-группа проверяет смену темы через
наследование, граничные значения ресурсов, повторное заполнение результатов,
намерения обоих слотов биндингов, отмену черновика настроек и создание первого сейва.
Графическую проверку выполняйте отдельно: F6 для каталога, обычный запуск проекта
для меню → настройки → игра → пауза → сохранения → подтверждение.

Manrope включен локально с SIL OFL: `shared/ui/theme/fonts/Manrope-OFL.txt`.
Windows/Web-пресеты явно включают этот текст лицензии в экспорт.
Источник шрифта: [Google Fonts](https://github.com/google/fonts/tree/main/ofl/manrope).
Ресурсы FontVariation задают веса 500/700/800. Для оси `wght` в `.tres` используется
числовой OpenType-тег `2003265652`: строковый ключ в проверенном Godot 4.7.2
не применял нужный вес. После замены шрифта проверьте реальное начертание в каталоге.
Семантические SVG и фон меню экспортированы из утвержденного Figma-файла.
Фон — заменяемая иллюстрация примера в MainMenu; он не является частью UI-логики.
