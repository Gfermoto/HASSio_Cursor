# 🌡️ Примеры: Автоматизация отопления

Готовые сценарии для копирования

---

## 1. Погодозависимое управление

```yaml
automation:
  - alias: "Погодозависимая кривая"
    trigger:
      - platform: numeric_state
        entity_id: sensor.outdoor_temperature
        below: 15
      - platform: time_pattern
        hours: "/2"
    action:
      - service: climate.set_temperature
        target:
          entity_id: climate.warming_floor_smart
        data:
          temperature: >
            {{ 25 - (states('sensor.outdoor_temperature')|float * 0.5) }}
```

## 2. Ночное снижение

```yaml
automation:
  - alias: "Ночь: Снижение"
    trigger:
      - platform: time
        at: "23:00:00"
    action:
      - service: climate.set_temperature
        data:
          entity_id: all
          temperature: 18
```

## 3. Защита от перегрева

```yaml
automation:
  - alias: "Защита от перегрева"
    trigger:
      - platform: numeric_state
        entity_id: sensor.wthermostat_temperature_floor
        above: 28
    action:
      - service: climate.turn_off
        entity_id: climate.wthermostat
```

**Полное руководство:** [Оптимизация отопления](../guides/heating-optimization.md)
