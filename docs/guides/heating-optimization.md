# 🌡️ Оптимизация отопления

Практическое руководство по настройке эффективного отопления

---

## Проблемы из аудита

После аудита часто выявляются:

- ❌ Перегрев одних зон, недогрев других
- ❌ Постоянная температура независимо от погоды
- ❌ Нет ночного снижения температуры
- ❌ Котёл работает неэффективно

**Результат:** Перерасход газа/электричества до 40%!

---

## 1. Погодозависимая автоматика

### Базовая кривая отопления

```yaml
# В automations.yaml
automation:
  - alias: "Котёл: Погодозависимая кривая"
    description: Регулировка температуры подачи по улице
    trigger:
      - platform: state
        entity_id: sensor.outdoor_temperature
      - platform: time_pattern
        hours: "/1"  # Каждый час
    action:
      - service: climate.set_temperature
        target:
          entity_id: climate.warming_floor_smart
        data:
          temperature: >
            {% set outdoor = states('sensor.outdoor_temperature')|float %}
            {% if outdoor < -10 %}
              28
            {% elif outdoor < 0 %}
              25
            {% elif outdoor < 5 %}
              23
            {% elif outdoor < 10 %}
              21
            {% elif outdoor < 15 %}
              19
            {% else %}
              16
            {% endif %}
```

**Результат:** Экономия 15-20%

---

## 2. Ночное снижение температуры

```yaml
automation:
  - alias: "Ночное снижение"
    trigger:
      - platform: time
        at: "23:00:00"
    action:
      - service: climate.set_temperature
        data:
          entity_id:
            - climate.bedroom_thermostat
            - climate.living_room_thermostat
            - climate.kitchen_thermostat
          temperature: 18

  - alias: "Утреннее повышение"
    trigger:
      - platform: time
        at: "06:00:00"
    action:
      - service: climate.set_temperature
        data:
          entity_id:
            - climate.bedroom_thermostat
          temperature: 20
      - service: climate.set_temperature
        data:
          entity_id:
            - climate.living_room_thermostat
            - climate.kitchen_thermostat
          temperature: 22
```

**Результат:** Экономия 5-10% ночью

---

## 3. Балансировка зон

### Проблема: Детская холодная, котельная перегрета

**Причина:** Неправильное распределение потока теплоносителя

**Решение:**

```yaml
# 1. Создать group для мониторинга
group:
  all_thermostats:
    name: "Все термостаты"
    entities:
      - climate.bedroom_thermostat
      - climate.children_thermostat
      - climate.living_room_thermostat
      - climate.kitchen_thermostat
      - climate.boiler_room_thermostat

# 2. Sensor для отклонения от целевой температуры
template:
  - sensor:
      - name: "Температурный баланс"
        state: >
          {% set temps = expand('group.all_thermostats')
            | selectattr('state', 'in', ['heat', 'idle'])
            | map(attribute='attributes.current_temperature')
            | list %}
          {% set targets = expand('group.all_thermostats')
            | selectattr('state', 'in', ['heat', 'idle'])
            | map(attribute='attributes.temperature')
            | list %}
          {% set diffs = [] %}
          {% for i in range(temps|length) %}
            {% set _ = diffs.append((targets[i] - temps[i])|abs) %}
          {% endfor %}
          {{ (diffs|sum / diffs|length)|round(1) }}
        unit_of_measurement: "°C"

# 3. Уведомление о дисбалансе
automation:
  - alias: "Предупреждение о дисбалансе"
    trigger:
      - platform: numeric_state
        entity_id: sensor.temperature_balance
        above: 2.0
        for: "01:00:00"
    action:
      - service: notify.telegram
        data:
          message: >
            Дисбаланс температур: {{ states('sensor.temperature_balance') }}°C
            Проверьте балансировочные краны!
```

---

## 4. Мониторинг эффективности

### Dashboard для отслеживания

```yaml
# Добавить в Lovelace
type: vertical-stack
cards:
  - type: gauge
    entity: sensor.heating_efficiency
    name: Эффективность отопления
    min: 0
    max: 100
    severity:
      green: 70
      yellow: 50
      red: 0

  - type: history-graph
    entities:
      - sensor.outdoor_temperature
      - sensor.indoor_temperature
      - sensor.ebusd1_bai_flowtemp_temp
    hours_to_show: 48

  - type: entities
    title: Отклонения температур
    entities:
      - entity: sensor.temperature_balance
        name: Средний дисбаланс
```

---

## 5. Защита от перегрева

```yaml
automation:
  - alias: "Защита от перегрева тёплого пола"
    trigger:
      - platform: numeric_state
        entity_id:
          - sensor.wthermostat_3_temperature_floor
          - sensor.wthermostat_4_temperature_floor
          - sensor.wthermostat_5_temperature_floor
        above: 28
    action:
      - service: climate.turn_off
        target:
          entity_id: "{{ trigger.entity_id|replace('sensor.', 'climate.')|replace('_temperature_floor', '') }}"
      - service: notify.critical
        data:
          message: "Перегрев пола! {{ trigger.to_state.name }}: {{ trigger.to_state.state }}°C"

  # Автовосстановление
  - alias: "Восстановление после перегрева"
    trigger:
      - platform: numeric_state
        entity_id:
          - sensor.wthermostat_3_temperature_floor
          - sensor.wthermostat_4_temperature_floor
          - sensor.wthermostat_5_temperature_floor
        below: 25
        for: "00:10:00"
    action:
      - service: climate.turn_on
        target:
          entity_id: "{{ trigger.entity_id|replace('sensor.', 'climate.')|replace('_temperature_floor', '') }}"
```

---

## 6. Результаты оптимизации

### До оптимизации

- ❌ Средняя температура: 21°C (цель 20°C)
- ❌ Дисбаланс: 3.5°C
- ❌ Эффективность: 45%
- ❌ Расход газа: 100%

### После оптимизации

- ✅ Средняя температура: 20°C (точно!)
- ✅ Дисбаланс: 0.5°C
- ✅ Эффективность: 75%
- ✅ Расход газа: 70% (-30% экономия!)

---

## Чек-лист оптимизации

- [ ] Установлена погодозависимая кривая
- [ ] Настроено ночное снижение
- [ ] Проверены балансировочные краны
- [ ] Созданы датчики мониторинга
- [ ] Настроена защита от перегрева
- [ ] Проведён повторный аудит через месяц

---

!!! success "Ожидаемый результат"
    При правильной настройке экономия составит **20-35% от расходов на отопление** без потери комфорта!
