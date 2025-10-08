#!/usr/bin/env python3
"""
Валидатор качества документации
Проверяет типичные ошибки форматирования в Markdown файлах
"""

import re
import sys
from pathlib import Path
from typing import List, Tuple

# Цвета для вывода
RED = '\033[91m'
GREEN = '\033[92m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'
BOLD = '\033[1m'


class DocValidator:
    """Валидатор документации"""

    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.errors = []
        self.warnings = []
        self.total_files = 0
        self.checked_files = 0

    def validate_all(self) -> bool:
        """Проверить всю документацию"""
        print("╔══════════════════════════════════════════════════════════════════╗")
        print("║           🔍 ВАЛИДАЦИЯ ДОКУМЕНТАЦИИ 🔍                           ║")
        print("╚══════════════════════════════════════════════════════════════════╝")
        print()

        # Находим все Markdown файлы
        md_files = self._find_markdown_files()
        self.total_files = len(md_files)

        if not md_files:
            print("⚠️  Markdown файлы не найдены")
            return True

        print(f"📊 Найдено Markdown файлов: {self.total_files}")
        print()
        print("═══════════════════════════════════════════════════════════════════")
        print()

        # Проверяем каждый файл
        for md_file in md_files:
            self._validate_file(md_file)

        # Показываем результаты
        self._print_results()

        return len(self.errors) == 0

    def _find_markdown_files(self) -> List[Path]:
        """Найти все Markdown файлы"""
        md_files = []

        # Исключаемые директории
        exclude_dirs = {
            '.git', 'node_modules', '__pycache__',
            '.venv', 'venv', 'audits', 'backups',
            '.storage', 'deps', 'tts'
        }

        for md_file in self.project_root.rglob('*.md'):
            # Проверяем что файл не в исключаемых директориях
            if any(excluded in md_file.parts for excluded in exclude_dirs):
                continue
            md_files.append(md_file)

        return sorted(md_files)

    def _validate_file(self, filepath: Path):
        """Проверить один файл"""
        rel_path = filepath.relative_to(self.project_root)

        try:
            content = filepath.read_text(encoding='utf-8')
            lines = content.split('\n')

            # Счетчики для этого файла
            file_errors = []

            # ПРОВЕРКА 1: ```bash\n```text (самая критичная!)
            file_errors.extend(self._check_broken_code_blocks(lines, rel_path))

            # ПРОВЕРКА 2: ```text сразу после закрывающего ``` (без пустой строки)
            file_errors.extend(self._check_missing_newline_between_blocks(lines, rel_path))

            # ПРОВЕРКА 3: Trailing spaces после закрывающих ```
            file_errors.extend(self._check_trailing_spaces_after_fence(lines, rel_path))

            # ПРОВЕРКА 4: Пустые блоки кода
            file_errors.extend(self._check_empty_code_blocks(lines, rel_path))

            # ПРОВЕРКА 5: Незакрытые блоки кода
            file_errors.extend(self._check_unclosed_code_blocks(lines, rel_path))

            # ПРОВЕРКА 6: Hardcoded пути пользователя
            file_errors.extend(self._check_hardcoded_paths(lines, rel_path))

            if file_errors:
                print(f"📄 {rel_path} ... {RED}❌ ОШИБКИ!{RESET}")
                for error in file_errors:
                    self.errors.append(error)
                    print(f"   {RED}•{RESET} {error}")
                print()
            else:
                print(f"📄 {rel_path} ... {GREEN}✅{RESET}")

            self.checked_files += 1

        except Exception as e:
            error = f"{rel_path}: Ошибка чтения файла: {e}"
            self.errors.append(error)
            print(f"📄 {rel_path} ... {RED}❌ ОШИБКА ЧТЕНИЯ!{RESET}")

    def _check_broken_code_blocks(self, lines: List[str], filepath: Path) -> List[str]:
        """Проверить на ```bash\n```text паттерн"""
        errors = []

        for i in range(len(lines) - 1):
            line = lines[i].strip()
            next_line = lines[i + 1].strip() if i + 1 < len(lines) else ""

            # Ищем закрывающий ``` за которым сразу идет ```text (или другой язык)
            if re.match(r'^```\s*$', line):
                # Следующая строка начинается с ``` (учитываем отступы)
                if next_line.startswith('```') and not next_line == '```':
                    errors.append(
                        f"Строка {i + 1}: Сломанный блок кода - закрывающий ``` "
                        f"сразу за которым идет открывающий {next_line}"
                    )

        return errors

    def _check_missing_newline_between_blocks(self, lines: List[str], filepath: Path) -> List[str]:
        """Проверить что между закрывающим и открывающим ``` есть пустая строка"""
        errors = []
        in_code_block = False

        for i in range(len(lines) - 1):
            line = lines[i].strip()
            next_line = lines[i + 1].strip() if i + 1 < len(lines) else ""

            # Отслеживаем состояние блока
            if line.startswith('```'):
                in_code_block = not in_code_block

                # Если закрываем блок
                if not in_code_block and line == '```':
                    # И сразу следующая строка - новый блок
                    if next_line.startswith('```') and next_line != '```':
                        errors.append(
                            f"Строка {i + 2}: Отсутствует пустая строка между блоками кода "
                            f"(после ``` должна быть пустая строка перед {next_line})"
                        )

        return errors

    def _check_trailing_spaces_after_fence(self, lines: List[str], filepath: Path) -> List[str]:
        """Проверить на trailing spaces после ``` в конце строки с языком"""
        errors = []

        for i, line in enumerate(lines):
            # Закрывающий ``` с пробелами
            if re.match(r'^```\s+$', line):
                errors.append(
                    f"Строка {i + 1}: Trailing spaces после закрывающего ``` "
                    f"(должно быть: ``` без пробелов)"
                )

        return errors

    def _check_empty_code_blocks(self, lines: List[str], filepath: Path) -> List[str]:
        """Проверить на пустые блоки кода"""
        warnings = []
        in_code_block = False
        block_start = 0
        block_lines = []

        for i, line in enumerate(lines):
            if line.startswith('```'):
                if not in_code_block:
                    # Начало блока
                    in_code_block = True
                    block_start = i + 1
                    block_lines = []
                else:
                    # Конец блока
                    in_code_block = False
                    # Проверяем что блок не пустой
                    if not any(l.strip() for l in block_lines):
                        warnings.append(
                            f"Строка {block_start}: Пустой блок кода"
                        )
            elif in_code_block:
                block_lines.append(line)

        self.warnings.extend(warnings)
        return []

    def _check_unclosed_code_blocks(self, lines: List[str], filepath: Path) -> List[str]:
        """Проверить на незакрытые блоки кода"""
        errors = []
        fence_count = 0

        for i, line in enumerate(lines):
            # Учитываем ``` в любой позиции (могут быть с отступом в списках)
            if '```' in line:
                fence_count += 1

        if fence_count % 2 != 0:
            errors.append(
                f"Незакрытый блок кода: нечетное количество ``` ({fence_count})"
            )

        return errors

    def _check_hardcoded_paths(self, lines: List[str], filepath: Path) -> List[str]:
        """Проверить на hardcoded пути пользователей"""
        errors = []

        # Паттерны для поиска
        patterns = [
            (r'/home/[a-z]+/', 'Используйте ~ вместо /home/username/'),
            (r'/Users/[A-Za-z]+/', 'Используйте ~ вместо /Users/username/'),
        ]

        for i, line in enumerate(lines):
            # Пропускаем если это внутри code block или уже использует ~
            if '```' in line or line.strip().startswith('~'):
                continue

            for pattern, message in patterns:
                if re.search(pattern, line):
                    match = re.search(pattern, line)
                    errors.append(
                        f"Строка {i + 1}: Hardcoded путь '{match.group()}' - {message}"
                    )

        return errors

    def _print_results(self):
        """Вывести итоговые результаты"""
        print()
        print("═══════════════════════════════════════════════════════════════════")
        print()
        print("📊 Результаты:")
        print(f"   Проверено файлов: {self.checked_files}")
        print(f"   {GREEN}✅ Без ошибок:    {self.checked_files - len(set(e.split(':')[0] for e in self.errors))}{RESET}")
        print(f"   {RED}❌ С ошибками:    {len(set(e.split(':')[0] for e in self.errors))}{RESET}")

        if self.warnings:
            print(f"   {YELLOW}⚠️  Предупреждения: {len(self.warnings)}{RESET}")

        print()

        if not self.errors:
            print("╔══════════════════════════════════════════════════════════════════╗")
            print("║           ✅ ВСЯ ДОКУМЕНТАЦИЯ ВАЛИДНА! ✅                        ║")
            print("╚══════════════════════════════════════════════════════════════════╝")
        else:
            print("╔══════════════════════════════════════════════════════════════════╗")
            print("║        ❌ ОБНАРУЖЕНЫ ОШИБКИ В ДОКУМЕНТАЦИИ! ❌                  ║")
            print("╚══════════════════════════════════════════════════════════════════╝")
            print()
            print("💡 Исправьте ошибки и запустите проверку снова")
            print()

            # Группируем ошибки по типам
            broken_blocks = [e for e in self.errors if 'Сломанный блок кода' in e]
            trailing = [e for e in self.errors if 'Trailing spaces' in e]
            hardcoded = [e for e in self.errors if 'Hardcoded путь' in e]
            unclosed = [e for e in self.errors if 'Незакрытый блок кода' in e]

            if broken_blocks:
                print(f"{RED}🔴 Сломанные блоки кода (```bash сразу за ```text):{RESET}")
                print(f"   Найдено: {len(broken_blocks)}")
                print()

            if trailing:
                print(f"{YELLOW}🟡 Trailing spaces после ```:{RESET}")
                print(f"   Найдено: {len(trailing)}")
                print()

            if hardcoded:
                print(f"{YELLOW}🟡 Hardcoded пути пользователей:{RESET}")
                print(f"   Найдено: {len(hardcoded)}")
                print()

            if unclosed:
                print(f"{RED}🔴 Незакрытые блоки кода:{RESET}")
                print(f"   Найдено: {len(unclosed)}")
                print()


def main():
    """Главная функция"""
    # Определяем корень проекта
    script_dir = Path(__file__).parent
    project_root = script_dir.parent

    # Создаем валидатор
    validator = DocValidator(project_root)

    # Запускаем проверку
    success = validator.validate_all()

    # Возвращаем код выхода
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
