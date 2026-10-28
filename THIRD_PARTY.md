# Лицензии и сторонние материалы

## Код и документация шаблона

Авторский код и документация Byrnane распространяются по [MIT](LICENSE).
Эта лицензия не заменяет условия сторонних библиотек, шрифтов, музыки и других
материалов. Отдельные условия авторских визуальных материалов указаны ниже.

## Шрифты

| Файл в `shared/ui/theme/fonts/` | Авторы и источник | Лицензия |
| --- | --- | --- |
| `Manrope-Variable.ttf` | [The Manrope Project Authors](https://github.com/google/fonts/tree/main/ofl/manrope) | SIL OFL 1.1, [полный текст](shared/ui/theme/fonts/Manrope-OFL.txt) |
| `Exo2-VariableFont_wght.ttf` | [The Exo 2 Project Authors](https://github.com/google/fonts/tree/main/ofl/exo2) | SIL OFL 1.1, [полный текст](shared/ui/theme/fonts/Exo2-OFL.txt) |
| `RubikMonoOne-Regular.ttf` | [The Rubik Project Authors; Hubert and Fischer](https://github.com/google/fonts/tree/main/ofl/rubikmonoone) | SIL OFL 1.1, [полный текст](shared/ui/theme/fonts/RubikMonoOne-OFL.txt) |

Тексты OFL хранятся рядом со шрифтами. Уведомления об авторстве из метаданных
сохранены; смена игровой темы не меняет лицензию самих файлов шрифтов.

## Музыка

Названия и исполнители восстановлены по метаданным MP3; условия проверены
по страницам источников 28 октября 2026 года.

| Файл | Произведение и автор | Источник и лицензия |
| --- | --- | --- |
| `assets/music/level_a.mp3` | Monkeys Spinning Monkeys — Kevin MacLeod | [Incompetech](https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1400011), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| `assets/music/level_b.mp3` | Run Amok — Kevin MacLeod | [Incompetech](https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1400024), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| `assets/music/main_menu.mp3` | Tiny Paws — Sakura Girl | [Audio Library](https://www.audiolibrary.com.co/sakura-girl/tiny-paws), [автор](https://soundcloud.com/sakuragirl_official/sakura-girl-tiny-paws), [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |

В проекте файлы названы по сценам. При дальнейшем редактировании музыки укажите
изменения в атрибуции. Сохраните следующие сведения в титрах или сопровождающих
файлах распространяемой игры:

> Monkeys Spinning Monkeys / Run Amok — Kevin MacLeod (incompetech.com).
> Creative Commons Attribution 4.0: https://creativecommons.org/licenses/by/4.0/

> Tiny Paws — Sakura Girl (https://soundcloud.com/sakuragirl_official).
> Creative Commons Attribution 3.0: https://creativecommons.org/licenses/by/3.0/
> Music promoted by Audio Library: https://www.audiolibrary.com.co/sakura-girl/tiny-paws

## Звуковые эффекты

Перечисленные OGG-файлы взяты из наборов [Kenney](https://kenney.nl/assets).
Происхождение подтверждено владельцем проекта. Автор публикует игровые ассеты
под [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/):
их можно использовать и распространять, в том числе в коммерческих проектах.
[Условия Kenney](https://kenney.nl/support) не требуют атрибуции;
добровольная строка благодарности — `Sound effects: Kenney (kenney.nl)`.

| Файл | Автор | Лицензия |
| --- | --- | --- |
| `assets/sfx/btn_click.ogg`, `btn_hover.ogg` | Kenney | CC0 1.0 |
| `assets/sfx/score.ogg` | Kenney | CC0 1.0 |
| `assets/sfx/heal.ogg` | Kenney | CC0 1.0 |
| `assets/sfx/damage.ogg` | Kenney | CC0 1.0 |

Официальные звуковые наборы: [UI Audio](https://kenney.nl/assets/ui-audio),
[Interface Sounds](https://kenney.nl/assets/interface-sounds),
[RPG Audio](https://kenney.nl/assets/rpg-audio) и
[Digital Audio](https://kenney.nl/assets/digital-audio). Конкретные архивы
для переименованных файлов не восстановлены; метаданные части копий сохранили
имя Kenney и название `handleCoins2`. На эти звуки распространяется CC0,
а на музыку из предыдущего раздела — указанные там лицензии CC BY.

## Графика и модели

Макет `Game Template UI.fig`, фон меню, графика «Лесного хранителя», модели
3D-примера и исходная модель зомби — авторские материалы Byrnane.
Сторонних визуальных ассетов в этих примерах нет; происхождение подтверждено
автором 28 октября 2026 года. MIT распространяется только на код и документацию;
графика, макет и модели под нее не подпадают. Отдельная лицензия на их повторное
использование не назначена. Карточка состава 3D-ассетов находится в
`art_source/retro_prototype/ASSETS.md` ветки `3d`.

## Инструменты и аддоны

Общий аддон: [Godot AI 4.3.0](https://github.com/hi-godot/godot-ai/releases/tag/v4.3.0), MIT; локальная установка в `addons/godot_ai`.

Аддоны не хранятся в Git. `pwsh -File scripts/install_addons.ps1` устанавливает состав текущей ветки из опубликованных архивов с проверкой SHA-256.
Версии, URL и хеши закреплены в `scripts/addons.lock.json`; лицензии поставляются внутри аддонов.
Локальные конфигурации MCP, загрузки и журналы исключены из Git.

Если в записи аддона задан `patches`, установщик применяет указанные патчи из
`scripts/` после проверки архива, а также при повторном запуске для уже
установленного аддона. Для этого нужен Git, используемый при клонировании проекта.
Уже примененный патч пропускается; несовпадение с локальными файлами останавливает
установку без их перезаписи. Патчи входят в Git, полные исходники аддонов — нет.

Ветка `3d` дополнительно содержит установку Cyclops 1.5.1 (MIT) и собственный export plugin шаблона, исключающий его autoload из сборок.
MCP for Blender и сам Blender устанавливаются отдельно от игрового репозитория и нужны только для работы с 3D-исходниками.
