#!/usr/bin/env python3
"""
Валидатор качества документации V2
ИСПРАВЛЕНА КРИТИЧЕСКАЯ ОШИБКА: различение открывающих и закрывающих fence markers
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
        print("║           🔍 ВАЛИДАЦИЯ ДОКУМЕНТАЦИИ V2 🔍                        ║")
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

            # ПРОВЕРКА 1: Неправильные fence markers (```text вместо ```)
            file_errors.extend(self._check_wrong_fence_markers(lines, rel_path))

            # ПРОВЕРКА 2: Незакрытые блоки кода
            file_errors.extend(self._check_unclosed_code_blocks(lines, rel_path))

            # ПРОВЕРКА 3: Отсутствие пустой строки между блоками
            file_errors.extend(self._check_missing_newline_between_blocks(lines, rel_path))

            # ПРОВЕРКА 4: Hardcoded пути пользователя
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

    def _check_wrong_fence_markers(self, lines: List[str], filepath: Path) -> List[str]:
        """Проверить на неправильные fence markers (```text вместо ```)"""
        errors = []
        in_code_block = False
        opening_line = 0

        for i, line in enumerate(lines):
            stripped = line.strip()

            # Открывающий fence: ```язык
            if re.match(r'^```[a-z]+', stripped):
                if in_code_block:
                    # Ошибка: открываем блок внутри блока!
                    errors.append(
                        f"Строка {i + 1}: Открывающий fence {stripped} внутри блока "
                        f"(начатого на строке {opening_line + 1})"
                    )
                else:
                    in_code_block = True
                    opening_line = i

            # Закрывающий fence: ТОЛЬКО ```
            elif stripped == '```':
                if not in_code_block:
                    errors.append(
                        f"Строка {i + 1}: Закрывающий ``` без открывающего блока"
                    )
                else:
                    in_code_block = False

            # ОШИБКА: ```текст (не язык, а продолжение)
            elif stripped.startswith('```') and len(stripped) > 3:
                # Это может быть ошибочный fence вроде ```text на отдельной строке
                if in_code_block:
                    # Это внутри блока - возможно, пример кода
                    pass
                else:
                    # Это вне блока - ОШИБКА!
                    errors.append(
                        f"Строка {i + 1}: Неправильный fence marker '{stripped}' "
                        f"(должен быть '```язык' для открытия или '```' для закрытия)"
                    )

        return errors

    def _check_unclosed_code_blocks(self, lines: List[str], filepath: Path) -> List[str]:
        """Проверить на незакрытые блоки кода"""
        errors = []
        in_code_block = False
        opening_line = 0

        for i, line in enumerate(lines):
            stripped = line.strip()

            # Открывающий: ```язык
            if re.match(r'^```[a-z]+', stripped):
                in_code_block = True
                opening_line = i

            # Закрывающий: ```
            elif stripped == '```':
                in_code_block = False

        if in_code_block:
            errors.append(
                f"Незакрытый блок кода начатый на строке {opening_line + 1}"
            )

        return errors

    def _check_missing_newline_between_blocks(self, lines: List[str], filepath: Path) -> List[str]:
        """Проверить что между блоками есть пустая строка"""
        errors = []
        prev_closing = -1

        for i, line in enumerate(lines):
            stripped = line.strip()

            # Закрывающий fence
            if stripped == '```':
                prev_closing = i

            # Открывающий fence
            elif re.match(r'^```[a-z]+', stripped):
                # Если предыдущий закрывающий был на i-1, значит нет пустой строки
                if prev_closing == i - 1:
                    errors.append(
                        f"Строка {i + 1}: Отсутствует пустая строка между блоками кода "
                        f"(после ``` должна быть пустая строка перед {stripped})"
                    )

        return errors

    def _check_hardcoded_paths(self, lines: List[str], filepath: Path) -> List[str]:
        """Проверить на hardcoded пути пользователей"""
        errors = []
        in_code_block = False

        # Паттерны для поиска
        patterns = [
            (r'/home/[a-z]+/', 'Используйте ~ вместо /home/username/'),
            (r'/Users/[A-Za-z]+/', 'Используйте ~ вместо /Users/username/'),
        ]

        for i, line in enumerate(lines):
            stripped = line.strip()

            # Отслеживаем блоки кода
            if re.match(r'^```[a-z]*$', stripped):
                in_code_block = not in_code_block
                continue

            # Пропускаем код внутри блоков
            if in_code_block:
                continue

            # Пропускаем строки где это пример в описании
            if 'вместо' in line.lower() or '~/path' in line or '~/' in line:
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
