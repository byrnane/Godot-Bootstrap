# Maintainer Guide

This page is for contributors who develop and maintain the template itself.
If you are building your own game on top of the template, start from [README.md](../README.md) and the [game-development guides](README.md).

## Основная ветка и производные варианты

Цель проекта — универсальный шаблон Godot в `main` и специализированные шаблоны 2D, 2D PixelArt и 3D на его основе.
Основное ядро и основная разработка находятся в `main`: здесь развиваются и исправляются общие системы, сервисы, UI-поведение, контракты и инструменты.
`3d` и `2d` получают обновления непосредственно из `main`, а `2d-pixelart` — через `2d`, вместе с ее игровой логикой. Общие изменения переносятся обычным merge; собственные ассеты, представление и настройки вариантов сохраняются.
В вариантах разрабатываются только их специфические системы, игровые фичи и контент, настройки, представление, ресурсы и аддоны, сохраняя общие сценарии и поведение базы.
Исправление дефекта общего ядра должно попасть в `main` и затем во все варианты; отдельные реализации общей инфраструктуры в вариантах не поддерживаются.

Порядок переноса изменений, разрешения конфликтов и проверки: [Варианты шаблона](VARIANTS.md).
Инструкции для агентов: [AGENTS.md](../AGENTS.md).
Эти правила относятся к сопровождению шаблона. Команда новой игры выбирает вариант и ведет отдельный репозиторий по [Bootstrap Checklist](BOOTSTRAP_CHECKLIST.md).

## Architecture and Development

- [Architecture](ARCHITECTURE.md)
- [Architecture Guardrails](ARCHITECTURE_GUARDRAILS.md)
- [Code Style](CODESTYLE.md)
- [UI Framework](UI_FRAMEWORK.md)
- [Figma source and backup](FIGMA.md)

## Quality and Validation

- [Manual Test Plan](MANUAL_TEST_PLAN.md)
- [Local Testing](TESTING.md)
- [Current acceptance and limitations](READINESS.md)

## Release and Planning

- [Release Process](RELEASE_PROCESS.md)
- [Changelog](../CHANGELOG.md)
- [Roadmap / TODO](../TODO.md)

## RU

Этот раздел для команды, которая развивает сам шаблон.
Если вы делаете свою игру на его основе, начните с [README.md](../README.md) и [руководств для разработчиков игр](README.md).
