#!/usr/bin/env python3
"""
Анализатор сложности конфигурации Home Assistant
Оценивает maintainability, находит code smells и anti-patterns
"""

import yaml
import re
from pathlib import Path
from typing import Dict, List, Any
from collections import Counter


class ComplexityChecker:
    """Анализатор сложности конфигурации"""

    def __init__(self, config_dir: str):
        self.config_dir = Path(config_dir)
        self.issues = []
        self.metrics = {
            'total_automations': 0,
            'total_scripts': 0,
            'total_templates': 0,
            'avg_complexity': 0,
            'high_complexity_count': 0
        }

    def analyze(self) -> Dict[str, Any]:
        """Полный анализ сложности"""
        print("📈 Анализ сложности конфигурации...")

        # Анализируем автоматизации
        self._analyze_automations()

        # Анализируем скрипты
        self._analyze_scripts()

        # Анализируем сенсоры с шаблонами
        self._analyze_template_sensors()

        # Генерируем отчет
        return {
            'metrics': self.metrics,
            'issues': sorted(self.issues, key=lambda x: x['severity'], reverse=True)
        }

    def _analyze_automations(self):
        """Анализ автоматизаций"""
        auto_file = self.config_dir / 'automations.yaml'
        if not auto_file.exists():
            return

        try:
            with open(auto_file, 'r', encoding='utf-8') as f:
                automations = yaml.safe_load(f) or []

            self.metrics['total_automations'] = len(automations)
            complexities = []

            for auto in automations:
                auto_id = auto.get('id') or auto.get('alias', 'unknown')
                complexity = self._calculate_automation_complexity(auto)
                complexities.append(complexity['score'])

                if complexity['score'] > 20:
                    self.issues.append({
                        'type': 'high_complexity',
                        'severity': 'high' if complexity['score'] > 30 else 'medium',
                        'entity_type': 'automation',
                        'entity_id': auto_id,
                        'alias': auto.get('alias'),
                        'score': complexity['score'],
                        'reasons': complexity['reasons'],
                        'file': 'automations.yaml'
                    })

            if complexities:
                self.metrics['avg_complexity'] = sum(complexities) / len(complexities)
                self.metrics['high_complexity_count'] = sum(1 for c in complexities if c > 20)

        except Exception as e:
            print(f"⚠️  Ошибка анализа automations.yaml: {e}")

    def _calculate_automation_complexity(self, automation: Dict) -> Dict[str, Any]:
        """Расчет сложности автоматизации"""
        score = 0
        reasons = []

        auto_str = yaml.dump(automation)

        # 1. Количество триггеров
        triggers = automation.get('trigger', [])
        if not isinstance(triggers, list):
            triggers = [triggers]
        trigger_count = len(triggers)
        if trigger_count > 3:
            score += trigger_count * 2
            reasons.append(f"Много триггеров ({trigger_count})")

        # 2. Вложенность условий
        conditions = automation.get('condition', [])
        if conditions:
            depth = self._calculate_nesting_depth(conditions)
            if depth > 3:
                score += depth * 5
                reasons.append(f"Глубокая вложенность условий ({depth})")

        # 3. Количество действий
        actions = automation.get('action', [])
        if not isinstance(actions, list):
            actions = [actions]
        action_count = len(actions)
        if action_count > 5:
            score += action_count * 2
            reasons.append(f"Много действий ({action_count})")

        # 4. Сложность шаблонов
        template_complexity = self._analyze_templates_in_text(auto_str)
        score += template_complexity['score']
        if template_complexity['issues']:
            reasons.extend(template_complexity['issues'])

        # 5. Длина YAML
        line_count = len(auto_str.split('\n'))
        if line_count > 100:
            score += (line_count - 100) // 10
            reasons.append(f"Большой объем кода ({line_count} строк)")

        # 6. Использование choose
        if 'choose' in auto_str:
            choose_count = auto_str.count('choose')
            score += choose_count * 5
            reasons.append(f"Использование choose ({choose_count})")

        return {
            'score': score,
            'reasons': reasons
        }

    def _calculate_nesting_depth(self, obj: Any, current_depth: int = 0) -> int:
        """Расчет глубины вложенности"""
        if isinstance(obj, dict):
            if 'condition' in obj or 'and' in obj or 'or' in obj:
                return max(
                    self._calculate_nesting_depth(v, current_depth + 1)
                    for v in obj.values()
                ) if obj else current_depth
            return max(
                (self._calculate_nesting_depth(v, current_depth) for v in obj.values()),
                default=current_depth
            )
        elif isinstance(obj, list):
            return max(
                (self._calculate_nesting_depth(item, current_depth) for item in obj),
                default=current_depth
            )
        return current_depth

    def _analyze_templates_in_text(self, text: str) -> Dict[str, Any]:
        """Анализ шаблонов Jinja2"""
        score = 0
        issues = []

        # Находим все шаблоны
        templates = re.findall(r'\{\{.*?\}\}', text, re.DOTALL)
        templates.extend(re.findall(r'\{%.*?%\}', text, re.DOTALL))

        for template in templates:
            length = len(template)

            # Длинные шаблоны
            if length > 200:
                score += 5
                issues.append(f"Длинный шаблон ({length} символов)")

            # Вложенные условия в шаблонах
            if_count = template.count('if ')
            if if_count > 2:
                score += if_count * 2
                issues.append(f"Сложный шаблон ({if_count} условий)")

            # Множественные фильтры
            pipe_count = template.count('|')
            if pipe_count > 5:
                score += pipe_count
                issues.append(f"Много фильтров ({pipe_count})")

        return {'score': score, 'issues': issues}

    def _analyze_scripts(self):
        """Анализ скриптов"""
        scripts_file = self.config_dir / 'scripts.yaml'
        if not scripts_file.exists():
            return

        try:
            with open(scripts_file, 'r', encoding='utf-8') as f:
                scripts = yaml.safe_load(f) or {}

            self.metrics['total_scripts'] = len(scripts)

            for script_id, script_data in scripts.items():
                complexity = self._calculate_script_complexity(script_data)

                if complexity['score'] > 15:
                    self.issues.append({
                        'type': 'high_complexity',
                        'severity': 'high' if complexity['score'] > 25 else 'medium',
                        'entity_type': 'script',
                        'entity_id': script_id,
                        'score': complexity['score'],
                        'reasons': complexity['reasons'],
                        'file': 'scripts.yaml'
                    })

        except Exception as e:
            print(f"⚠️  Ошибка анализа scripts.yaml: {e}")

    def _calculate_script_complexity(self, script: Dict) -> Dict[str, Any]:
        """Расчет сложности скрипта"""
        score = 0
        reasons = []

        sequence = script.get('sequence', [])
        if not isinstance(sequence, list):
            sequence = [sequence]

        # Количество шагов
        step_count = len(sequence)
        if step_count > 10:
            score += step_count
            reasons.append(f"Много шагов ({step_count})")

        # Вложенность (repeat, choose, if)
        script_str = yaml.dump(script)
        if 'repeat' in script_str:
            score += 5
            reasons.append("Использование repeat")
        if 'choose' in script_str:
            score += 5
            reasons.append("Использование choose")

        # Шаблоны
        template_complexity = self._analyze_templates_in_text(script_str)
        score += template_complexity['score']
        reasons.extend(template_complexity['issues'])

        return {'score': score, 'reasons': reasons}

    def _analyze_template_sensors(self):
        """Анализ template сенсоров"""
        sensors_file = self.config_dir / 'sensors.yaml'
        if not sensors_file.exists():
            return

        try:
            with open(sensors_file, 'r', encoding='utf-8') as f:
                sensors = yaml.safe_load(f) or []

            template_count = 0

            for sensor in sensors:
                if isinstance(sensor, dict):
                    if 'state_template' in str(sensor) or 'value_template' in str(sensor):
                        template_count += 1

                        sensor_str = yaml.dump(sensor)
                        template_complexity = self._analyze_templates_in_text(sensor_str)

                        if template_complexity['score'] > 10:
                            sensor_name = sensor.get('name', sensor.get('unique_id', 'unknown'))
                            self.issues.append({
                                'type': 'complex_template',
                                'severity': 'medium',
                                'entity_type': 'sensor',
                                'entity_id': sensor_name,
                                'score': template_complexity['score'],
                                'reasons': template_complexity['issues'],
                                'file': 'sensors.yaml'
                            })

            self.metrics['total_templates'] = template_count

        except Exception as e:
            print(f"⚠️  Ошибка анализа sensors.yaml: {e}")

    def detect_code_duplication(self) -> List[Dict[str, Any]]:
        """Обнаружение дублирования кода"""
        # TODO: Реализовать поиск похожих автоматизаций/скриптов
        duplicates = []
        return duplicates

    def detect_anti_patterns(self) -> List[Dict[str, Any]]:
        """Обнаружение анти-паттернов"""
        anti_patterns = []

        # Паттерн 1: Автоматизация без условий (всегда срабатывает)
        # Паттерн 2: Polling вместо event-driven
        # Паттерн 3: Hardcoded значения вместо input_*
        # TODO: Реализовать детекцию

        return anti_patterns


def main():
    """Главная функция"""
    import sys

    config_dir = sys.argv[1] if len(sys.argv) > 1 else 'config'

    print("╔══════════════════════════════════════════════════════════════════╗")
    print("║             📈 АНАЛИЗ СЛОЖНОСТИ КОНФИГУРАЦИИ 📈                  ║")
    print("╚══════════════════════════════════════════════════════════════════╝")
    print()

    checker = ComplexityChecker(config_dir)
    report = checker.analyze()

    metrics = report['metrics']
    issues = report['issues']

    print("📊 Метрики:")
    print(f"   Автоматизаций:     {metrics['total_automations']}")
    print(f"   Скриптов:          {metrics['total_scripts']}")
    print(f"   Template сенсоров: {metrics['total_templates']}")
    if metrics['total_automations'] > 0:
        print(f"   Средняя сложность: {metrics['avg_complexity']:.1f}")
        print(f"   Высокая сложность: {metrics['high_complexity_count']}")
    print()

    # Группируем проблемы по severity
    critical = [i for i in issues if i['severity'] == 'critical']
    high = [i for i in issues if i['severity'] == 'high']
    medium = [i for i in issues if i['severity'] == 'medium']

    if critical:
        print(f"🔴 КРИТИЧЕСКИЕ проблемы ({len(critical)}):")
        for issue in critical[:5]:
            print(f"   {issue['entity_type']}.{issue['entity_id']} (complexity: {issue['score']})")
            for reason in issue['reasons'][:3]:
                print(f"      - {reason}")
        print()

    if high:
        print(f"🟠 ВЫСОКАЯ сложность ({len(high)}):")
        for issue in high[:5]:
            alias = issue.get('alias', issue['entity_id'])
            print(f"   {issue['entity_type']}: {alias} (score: {issue['score']})")
            for reason in issue['reasons'][:2]:
                print(f"      - {reason}")
        print()

    if medium:
        print(f"🟡 СРЕДНЯЯ сложность ({len(medium)}):")
        for issue in medium[:5]:
            print(f"   {issue['entity_type']}.{issue['entity_id']} (score: {issue['score']})")
        if len(medium) > 5:
            print(f"   ... и еще {len(medium) - 5}")
        print()

    # Рекомендации
    if issues:
        print("💡 Рекомендации:")
        if metrics['high_complexity_count'] > 0:
            print("   • Разбить сложные автоматизации на подскрипты")
        if any('Длинный шаблон' in str(i.get('reasons', [])) for i in issues):
            print("   • Переместить сложные шаблоны в template sensors")
        if any('Много действий' in str(i.get('reasons', [])) for i in issues):
            print("   • Использовать scripts для повторяющихся действий")
        print()


if __name__ == '__main__':
    main()
