# Сторонние инструменты

Общий аддон: [Godot AI 4.3.0](https://github.com/hi-godot/godot-ai/releases/tag/v4.3.0), MIT; локальная установка в `addons/godot_ai`.

Аддоны не хранятся в Git. `pwsh -File scripts/install_addons.ps1` устанавливает состав текущей ветки из опубликованных архивов с проверкой SHA-256.
Версии, URL и хеши закреплены в `scripts/addons.lock.json`; лицензии поставляются внутри аддонов.
Локальные конфигурации MCP, загрузки и журналы исключены из Git.

Ветка `3d` дополнительно содержит установку Cyclops 1.5.1 (MIT) и собственный export plugin шаблона, исключающий его autoload из сборок.
MCP for Blender и сам Blender устанавливаются отдельно от игрового репозитория и нужны только для работы с 3D-исходниками.

Закрепленный 3D-аддон: [Cyclops 1.5.1](https://github.com/blackears/cyclopsLevelBuilder/releases/tag/v1.5.1), MIT.
Blender MCP: [mcp-for-blender 2.2.2](https://pypi.org/project/mcp-for-blender/2.2.2/), вне репозитория; [preview-плагин 5a3618f](https://github.com/ahujasid/mcp-for-blender/tree/5a3618fccb2d982d0dd61e7a1879912c3100073b).
