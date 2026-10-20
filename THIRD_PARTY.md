# Сторонние инструменты

- [Godot AI 4.3.0](https://github.com/hi-godot/godot-ai/releases/tag/v4.3.0), MIT; локальная установка в `addons/godot_ai`.
- [Cyclops 1.5.1](https://github.com/blackears/cyclopsLevelBuilder/releases/tag/v1.5.1), MIT; локальная установка в `addons/cyclops_level_builder`.
- [MCP for Blender 2.2.2](https://pypi.org/project/mcp-for-blender/2.2.2/) установлен вне игрового репозитория. Локальный checkout preview-плагина: [ahujasid/mcp-for-blender, 5a3618f](https://github.com/ahujasid/mcp-for-blender/tree/5a3618fccb2d982d0dd61e7a1879912c3100073b).

Сторонние аддоны не хранятся в Git. Команда `pwsh -File scripts/install_addons.ps1` устанавливает их из опубликованных архивов с проверкой SHA-256. Версии, URL и хеши находятся в `scripts/addons.lock.json`; лицензии поставляются внутри аддонов. Локальные конфигурации MCP, загрузки и журналы также исключены из Git.

Скрипты `addons/template_export` принадлежат шаблону и удаляют редакторский autoload Cyclops из экспортированных игр.
