#!/usr/bin/env python3
"""
Анализатор зависимостей конфигурации Home Assistant
Находит связи между сущностями, неиспользуемые объекты, circular dependencies
"""

import yaml
import re
import json
from pathlib import Path
from collections import defaultdict
from typing import Dict, List, Set, Any


class DependencyAnalyzer:
    """Анализатор зависимостей конфигурации"""

    def __init__(self, config_dir: str):
        self.config_dir = Path(config_dir)
        self.entities: Dict[str, Dict] = defaultdict(lambda: {
            'type': 'unknown',
            'used_in': [],
            'depends_on': set(),
            'file': None,
            'definition': None
        })
        self.automations: Dict[str, Dict] = {}
        self.scripts: Dict[str, Dict] = {}

    def analyze(self) -> Dict[str, Any]:
        """Полный анализ конфигурации"""
        print("🔍 Сканирование конфигурации...")

        # 1. Сканируем все файлы
        self._scan_automations()
        self._scan_scripts()
        self._scan_sensors()
        self._scan_configuration()

        # 2. Анализируем зависимости
        self._build_dependencies()

        # 3. Находим проблемы
        orphaned = self.find_orphaned()
        circular = self.find_circular_dependencies()

        # 4. Генерируем отчет
        return {
            'total_entities': len(self.entities),
            'total_automations': len(self.automations),
            'total_scripts': len(self.scripts),
            'orphaned_entities': orphaned,
            'circular_dependencies': circular,
            'entities': dict(self.entities)
        }

    def _scan_automations(self):
        """Сканирование автоматизаций"""
        auto_file = self.config_dir / 'automations.yaml'
        if not auto_file.exists():
            return

        try:
            with open(auto_file, 'r', encoding='utf-8') as f:
                automations = yaml.safe_load(f) or []

            for auto in automations:
                auto_id = auto.get('id') or auto.get('alias', 'unknown')
                self.automations[auto_id] = auto

                # Извлекаем все entity_id
                auto_str = yaml.dump(auto)
                entities_used = self._extract_entities(auto_str)

                for entity in entities_used:
                    self.entities[entity]['used_in'].append({
                        'type': 'automation',
                        'id': auto_id,
                        'alias': auto.get('alias'),
                        'file': 'automations.yaml'
                    })

        except Exception as e:
            print(f"⚠️  Ошибка чтения automations.yaml: {e}")

    def _scan_scripts(self):
        """Сканирование скриптов"""
        scripts_file = self.config_dir / 'scripts.yaml'
        if not scripts_file.exists():
            return

        try:
            with open(scripts_file, 'r', encoding='utf-8') as f:
                scripts = yaml.safe_load(f) or {}

            for script_id, script_data in scripts.items():
                self.scripts[script_id] = script_data

                script_str = yaml.dump(script_data)
                entities_used = self._extract_entities(script_str)

                for entity in entities_used:
                    self.entities[entity]['used_in'].append({
                        'type': 'script',
                        'id': script_id,
                        'file': 'scripts.yaml'
                    })

        except Exception as e:
            print(f"⚠️  Ошибка чтения scripts.yaml: {e}")

    def _scan_sensors(self):
        """Сканирование сенсоров"""
        for sensor_file in ['sensors.yaml', 'binary_sensors.yaml']:
            file_path = self.config_dir / sensor_file
            if not file_path.exists():
                continue

            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    sensors = yaml.safe_load(f) or []

                for sensor in sensors:
                    if isinstance(sensor, dict):
                        entity_id = sensor.get('unique_id') or sensor.get('name', 'unknown')
                        self.entities[entity_id]['type'] = 'sensor'
                        self.entities[entity_id]['file'] = sensor_file
                        self.entities[entity_id]['definition'] = sensor

            except Exception as e:
                print(f"⚠️  Ошибка чтения {sensor_file}: {e}")

    def _scan_configuration(self):
        """Сканирование основного файла конфигурации"""
        config_file = self.config_dir / 'configuration.yaml'
        if not config_file.exists():
            return

        try:
            with open(config_file, 'r', encoding='utf-8') as f:
                config = yaml.safe_load(f) or {}

            # Извлекаем entity_id из всей конфигурации
            config_str = yaml.dump(config)
            entities = self._extract_entities(config_str)

            for entity in entities:
                if entity not in self.entities:
                    self.entities[entity]['type'] = 'config'
                    self.entities[entity]['file'] = 'configuration.yaml'

        except Exception as e:
            print(f"⚠️  Ошибка чтения configuration.yaml: {e}")

    def _extract_entities(self, text: str) -> Set[str]:
        """Извлечение entity_id из текста"""
        # Паттерн для entity_id: domain.entity_name
        pattern = r'\b([a-z_]+\.[a-z0-9_]+)\b'
        entities = set(re.findall(pattern, text))

        # Фильтруем false positives
        valid_domains = {
            'sensor', 'binary_sensor', 'light', 'switch', 'climate',
            'cover', 'fan', 'lock', 'media_player', 'person', 'device_tracker',
            'automation', 'script', 'input_boolean', 'input_number', 'input_select',
            'input_text', 'input_datetime', 'timer', 'counter', 'zone', 'sun',
            'weather', 'camera', 'alarm_control_panel', 'vacuum', 'notify',
            'group', 'scene', 'mqtt', 'homeassistant'
        }

        return {e for e in entities if e.split('.')[0] in valid_domains}

    def _build_dependencies(self):
        """Построение графа зависимостей"""
        # Для каждой сущности находим от чего она зависит
        for entity_id, data in self.entities.items():
            if data.get('definition'):
                # Анализируем определение сущности
                def_str = yaml.dump(data['definition'])
                depends = self._extract_entities(def_str)
                data['depends_on'] = depends - {entity_id}  # Исключаем саму себя

    def find_orphaned(self) -> List[str]:
        """Поиск неиспользуемых сущностей"""
        orphaned = []

        for entity_id, data in self.entities.items():
            # Пропускаем служебные сущности
            domain = entity_id.split('.')[0]
            if domain in ['sun', 'homeassistant']:
                continue

            # Если не используется нигде и не device/person
            if not data['used_in'] and data['type'] not in ['device', 'person', 'zone']:
                orphaned.append(entity_id)

        return sorted(orphaned)

    def find_circular_dependencies(self) -> List[List[str]]:
        """Поиск циклических зависимостей"""
        circular = []
        visited = set()
        rec_stack = set()

        def dfs(entity: str, path: List[str]) -> bool:
            """DFS для поиска циклов"""
            visited.add(entity)
            rec_stack.add(entity)
            path.append(entity)

            for dep in self.entities[entity].get('depends_on', set()):
                if dep not in visited:
                    if dfs(dep, path.copy()):
                        return True
                elif dep in rec_stack:
                    # Найден цикл!
                    cycle_start = path.index(dep)
                    circular.append(path[cycle_start:] + [dep])
                    return True

            rec_stack.remove(entity)
            return False

        for entity in self.entities:
            if entity not in visited:
                dfs(entity, [])

        return circular

    def analyze_impact(self, entity_id: str) -> Dict[str, Any]:
        """Анализ влияния удаления сущности"""
        if entity_id not in self.entities:
            return {'error': 'Entity not found'}

        data = self.entities[entity_id]
        used_in = data.get('used_in', [])

        impact = {
            'entity_id': entity_id,
            'direct_usage': len(used_in),
            'automations': [u for u in used_in if u['type'] == 'automation'],
            'scripts': [u for u in used_in if u['type'] == 'script'],
            'depends_on': list(data.get('depends_on', set())),
            'severity': 'low'
        }

        # Определяем серьезность
        if impact['direct_usage'] > 5:
            impact['severity'] = 'critical'
        elif impact['direct_usage'] > 2:
            impact['severity'] = 'high'
        elif impact['direct_usage'] > 0:
            impact['severity'] = 'medium'

        return impact

    def generate_mermaid_graph(self, entity_id: str = None, depth: int = 2) -> str:
        """Генерация Mermaid диаграммы"""
        lines = ['graph TD']

        if entity_id:
            # Граф для конкретной сущности
            self._add_entity_to_graph(lines, entity_id, depth, set())
        else:
            # Граф топ-10 самых используемых
            top_entities = sorted(
                self.entities.items(),
                key=lambda x: len(x[1].get('used_in', [])),
                reverse=True
            )[:10]

            for entity, _ in top_entities:
                self._add_entity_to_graph(lines, entity, 1, set())

        return '\n'.join(lines)

    def _add_entity_to_graph(self, lines: List[str], entity: str, depth: int, visited: Set[str]):
        """Добавление сущности в граф"""
        if depth <= 0 or entity in visited:
            return

        visited.add(entity)
        data = self.entities.get(entity, {})

        # Добавляем узел
        node_id = entity.replace('.', '_')
        entity_type = data.get('type', 'unknown')
        lines.append(f'    {node_id}["{entity}<br/>({entity_type})"]')

        # Добавляем связи "используется в"
        for usage in data.get('used_in', [])[:5]:  # Ограничиваем 5
            usage_id = usage['id'].replace('.', '_').replace(' ', '_')
            usage_type = usage['type']
            lines.append(f'    {usage_id}["{usage["id"]}<br/>({usage_type})"]')
            lines.append(f'    {node_id} --> {usage_id}')

        # Добавляем зависимости
        for dep in list(data.get('depends_on', set()))[:3]:  # Ограничиваем 3
            if dep in self.entities:
                self._add_entity_to_graph(lines, dep, depth - 1, visited)
                dep_id = dep.replace('.', '_')
                lines.append(f'    {dep_id} --> {node_id}')


def main():
    """Главная функция"""
    import sys

    config_dir = sys.argv[1] if len(sys.argv) > 1 else 'config'

    print("╔══════════════════════════════════════════════════════════════════╗")
    print("║           🕸️  АНАЛИЗ ЗАВИСИМОСТЕЙ КОНФИГУРАЦИИ 🕸️               ║")
    print("╚══════════════════════════════════════════════════════════════════╝")
    print()

    analyzer = DependencyAnalyzer(config_dir)
    report = analyzer.analyze()

    print(f"📊 Статистика:")
    print(f"   Всего сущностей:   {report['total_entities']}")
    print(f"   Автоматизаций:     {report['total_automations']}")
    print(f"   Скриптов:          {report['total_scripts']}")
    print()

    # Orphaned entities
    if report['orphaned_entities']:
        print(f"🔴 Неиспользуемые сущности ({len(report['orphaned_entities'])}):")
        for entity in report['orphaned_entities'][:10]:
            print(f"   • {entity}")
        if len(report['orphaned_entities']) > 10:
            print(f"   ... и еще {len(report['orphaned_entities']) - 10}")
        print()

    # Circular dependencies
    if report['circular_dependencies']:
        print(f"⚠️  Циклические зависимости ({len(report['circular_dependencies'])}):")
        for cycle in report['circular_dependencies'][:5]:
            print(f"   • {' → '.join(cycle)}")
        print()

    # Топ-10 самых используемых
    top_used = sorted(
        report['entities'].items(),
        key=lambda x: len(x[1].get('used_in', [])),
        reverse=True
    )[:10]

    if top_used:
        print("🔝 Топ-10 самых используемых сущностей:")
        for entity, data in top_used:
            usage_count = len(data.get('used_in', []))
            if usage_count > 0:
                print(f"   {usage_count:3d}x • {entity}")
        print()

    # Impact analysis для примера
    if report['total_entities'] > 0:
        example_entity = list(report['entities'].keys())[0]
        impact = analyzer.analyze_impact(example_entity)

        print(f"💥 Пример Impact Analysis: {example_entity}")
        print(f"   Severity: {impact['severity']}")
        print(f"   Используется в {impact['direct_usage']} местах")
        print(f"   Автоматизаций: {len(impact['automations'])}")
        print(f"   Скриптов: {len(impact['scripts'])}")
        print()


if __name__ == '__main__':
    main()
