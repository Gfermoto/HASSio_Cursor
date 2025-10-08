#!/usr/bin/env python3
"""
Анализатор различий между версиями конфигурации
Показывает что изменилось и какое влияние это окажет
"""

import yaml
import subprocess
from pathlib import Path
from typing import Dict, List, Any, Set
from collections import defaultdict


class ConfigDiff:
    """Анализатор различий конфигураций"""

    def __init__(self, config_dir: str):
        self.config_dir = Path(config_dir)
        self.changes = defaultdict(list)

    def compare_commits(self, commit1: str = 'HEAD~1', commit2: str = 'HEAD') -> Dict[str, Any]:
        """Сравнение между двумя коммитами"""
        print(f"🔄 Сравнение: {commit1} → {commit2}")

        # Получаем список измененных файлов
        try:
            result = subprocess.run(
                ['git', 'diff', '--name-status', commit1, commit2],
                cwd=self.config_dir.parent,
                capture_output=True,
                text=True,
                check=True
            )

            changed_files = result.stdout.strip().split('\n')

        except subprocess.CalledProcessError as e:
            print(f"⚠️  Ошибка git diff: {e}")
            return {}

        # Анализируем изменения
        for line in changed_files:
            if not line:
                continue

            parts = line.split('\t')
            if len(parts) < 2:
                continue

            status = parts[0]
            filepath = parts[1]

            # Фильтруем только файлы конфигурации
            if not (filepath.endswith('.yaml') or filepath.endswith('.yml')):
                continue

            if filepath.startswith('config/'):
                self._analyze_file_change(status, filepath, commit1, commit2)

        return self._generate_report()

    def _analyze_file_change(self, status: str, filepath: str, commit1: str, commit2: str):
        """Анализ изменений в файле"""
        change_type = {
            'A': 'added',
            'M': 'modified',
            'D': 'deleted',
            'R': 'renamed'
        }.get(status[0], 'unknown')

        # Получаем содержимое файлов
        try:
            # Старая версия
            if change_type != 'added':
                old_content = subprocess.run(
                    ['git', 'show', f'{commit1}:{filepath}'],
                    cwd=self.config_dir.parent,
                    capture_output=True,
                    text=True
                ).stdout
                old_data = yaml.safe_load(old_content) if old_content else {}
            else:
                old_data = {}

            # Новая версия
            if change_type != 'deleted':
                new_content = subprocess.run(
                    ['git', 'show', f'{commit2}:{filepath}'],
                    cwd=self.config_dir.parent,
                    capture_output=True,
                    text=True
                ).stdout
                new_data = yaml.safe_load(new_content) if new_content else {}
            else:
                new_data = {}

            # Анализируем конкретные изменения
            self._compare_yaml_data(filepath, old_data, new_data, change_type)

        except Exception as e:
            print(f"⚠️  Ошибка анализа {filepath}: {e}")

    def _compare_yaml_data(self, filepath: str, old_data: Any, new_data: Any, change_type: str):
        """Сравнение YAML данных"""
        filename = Path(filepath).name

        if filename == 'automations.yaml':
            self._compare_automations(old_data, new_data, change_type)
        elif filename == 'scripts.yaml':
            self._compare_scripts(old_data, new_data, change_type)
        elif filename in ['sensors.yaml', 'binary_sensors.yaml']:
            self._compare_sensors(old_data, new_data, change_type)
        else:
            # Общее сравнение
            self.changes['other'].append({
                'file': filepath,
                'change_type': change_type
            })

    def _compare_automations(self, old_data: List, new_data: List, change_type: str):
        """Сравнение автоматизаций"""
        old_automations = {a.get('id') or a.get('alias'): a for a in (old_data or [])}
        new_automations = {a.get('id') or a.get('alias'): a for a in (new_data or [])}

        # Добавленные
        for auto_id in set(new_automations) - set(old_automations):
            self.changes['automations_added'].append({
                'id': auto_id,
                'alias': new_automations[auto_id].get('alias'),
                'data': new_automations[auto_id]
            })

        # Удаленные
        for auto_id in set(old_automations) - set(new_automations):
            self.changes['automations_deleted'].append({
                'id': auto_id,
                'alias': old_automations[auto_id].get('alias'),
                'severity': 'high'  # Удаление автоматизации - важно!
            })

        # Измененные
        for auto_id in set(old_automations) & set(new_automations):
            if old_automations[auto_id] != new_automations[auto_id]:
                diff_details = self._find_automation_differences(
                    old_automations[auto_id],
                    new_automations[auto_id]
                )
                self.changes['automations_modified'].append({
                    'id': auto_id,
                    'alias': new_automations[auto_id].get('alias'),
                    'changes': diff_details
                })

    def _find_automation_differences(self, old_auto: Dict, new_auto: Dict) -> List[str]:
        """Находит конкретные различия в автоматизации"""
        differences = []

        # Сравниваем ключевые секции
        for section in ['trigger', 'condition', 'action']:
            old_section = yaml.dump(old_auto.get(section, {}))
            new_section = yaml.dump(new_auto.get(section, {}))

            if old_section != new_section:
                differences.append(f"Изменен {section}")

        return differences

    def _compare_scripts(self, old_data: Dict, new_data: Dict, change_type: str):
        """Сравнение скриптов"""
        old_scripts = set(old_data.keys()) if old_data else set()
        new_scripts = set(new_data.keys()) if new_data else set()

        # Добавленные
        for script_id in new_scripts - old_scripts:
            self.changes['scripts_added'].append({'id': script_id})

        # Удаленные
        for script_id in old_scripts - new_scripts:
            self.changes['scripts_deleted'].append({
                'id': script_id,
                'severity': 'medium'
            })

        # Измененные
        for script_id in old_scripts & new_scripts:
            if old_data[script_id] != new_data[script_id]:
                self.changes['scripts_modified'].append({'id': script_id})

    def _compare_sensors(self, old_data: List, new_data: List, change_type: str):
        """Сравнение сенсоров"""
        old_sensors = {s.get('unique_id') or s.get('name'): s for s in (old_data or []) if isinstance(s, dict)}
        new_sensors = {s.get('unique_id') or s.get('name'): s for s in (new_data or []) if isinstance(s, dict)}

        # Добавленные
        for sensor_id in set(new_sensors) - set(old_sensors):
            self.changes['sensors_added'].append({'id': sensor_id})

        # Удаленные
        for sensor_id in set(old_sensors) - set(new_sensors):
            self.changes['sensors_deleted'].append({
                'id': sensor_id,
                'severity': 'high'  # Может сломать автоматизации!
            })

        # Измененные
        for sensor_id in set(old_sensors) & set(new_sensors):
            if old_sensors[sensor_id] != new_sensors[sensor_id]:
                self.changes['sensors_modified'].append({'id': sensor_id})

    def _generate_report(self) -> Dict[str, Any]:
        """Генерация отчета об изменениях"""
        total_changes = sum(len(v) for v in self.changes.values())

        # Оценка риска
        risk_score = 0
        warnings = []

        # Удаленные сенсоры - высокий риск
        if self.changes['sensors_deleted']:
            risk_score += len(self.changes['sensors_deleted']) * 10
            warnings.append(
                f"⚠️  Удалено {len(self.changes['sensors_deleted'])} сенсоров - "
                "может сломать автоматизации!"
            )

        # Удаленные автоматизации
        if self.changes['automations_deleted']:
            risk_score += len(self.changes['automations_deleted']) * 5
            warnings.append(
                f"⚠️  Удалено {len(self.changes['automations_deleted'])} автоматизаций"
            )

        # Много изменений
        if total_changes > 20:
            risk_score += 10
            warnings.append(f"⚠️  Большое количество изменений ({total_changes})")

        risk_level = 'low'
        if risk_score > 50:
            risk_level = 'critical'
        elif risk_score > 20:
            risk_level = 'high'
        elif risk_score > 5:
            risk_level = 'medium'

        return {
            'total_changes': total_changes,
            'changes': dict(self.changes),
            'risk_score': risk_score,
            'risk_level': risk_level,
            'warnings': warnings
        }


def main():
    """Главная функция"""
    import sys

    config_dir = sys.argv[1] if len(sys.argv) > 1 else 'config'
    commit1 = sys.argv[2] if len(sys.argv) > 2 else 'HEAD~1'
    commit2 = sys.argv[3] if len(sys.argv) > 3 else 'HEAD'

    print("╔══════════════════════════════════════════════════════════════════╗")
    print("║              🔄 АНАЛИЗ ИЗМЕНЕНИЙ КОНФИГУРАЦИИ 🔄                 ║")
    print("╚══════════════════════════════════════════════════════════════════╝")
    print()

    analyzer = ConfigDiff(config_dir)
    report = analyzer.compare_commits(commit1, commit2)

    if not report:
        print("❌ Не удалось проанализировать изменения")
        return

    changes = report['changes']

    print(f"📊 Всего изменений: {report['total_changes']}")
    print(f"🎯 Уровень риска: {report['risk_level'].upper()} (score: {report['risk_score']})")
    print()

    # Автоматизации
    if changes.get('automations_added'):
        print(f"✅ Добавлено автоматизаций: {len(changes['automations_added'])}")
        for auto in changes['automations_added'][:5]:
            print(f"   • {auto.get('alias', auto['id'])}")
        print()

    if changes.get('automations_deleted'):
        print(f"🔴 Удалено автоматизаций: {len(changes['automations_deleted'])}")
        for auto in changes['automations_deleted']:
            print(f"   • {auto.get('alias', auto['id'])}")
        print()

    if changes.get('automations_modified'):
        print(f"🔄 Изменено автоматизаций: {len(changes['automations_modified'])}")
        for auto in changes['automations_modified'][:5]:
            print(f"   • {auto.get('alias', auto['id'])}")
            for change in auto.get('changes', []):
                print(f"      - {change}")
        print()

    # Сенсоры
    if changes.get('sensors_deleted'):
        print(f"🔴 Удалено сенсоров: {len(changes['sensors_deleted'])}")
        for sensor in changes['sensors_deleted']:
            print(f"   • {sensor['id']}")
        print()

    # Предупреждения
    if report['warnings']:
        print("⚠️  ПРЕДУПРЕЖДЕНИЯ:")
        for warning in report['warnings']:
            print(f"   {warning}")
        print()

    # Рекомендации
    if report['risk_level'] in ['high', 'critical']:
        print("💡 РЕКОМЕНДАЦИИ:")
        print("   • Создать бэкап перед развертыванием")
        print("   • Протестировать изменения на dev-окружении")
        print("   • Проверить зависимости удаленных сущностей")
        print()


if __name__ == '__main__':
    main()
