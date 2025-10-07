# ⚡ Примеры: Энергосбережение

Готовые сценарии

---

## 1. Отключение при уходе

```yaml
automation:
  - alias: "Ушли из дома"
    trigger:
      - platform: state
        entity_id: group.family
        to: "not_home"
        for: "00:05:00"
    action:
      - service: light.turn_off
        entity_id: all
      - service: climate.set_temperature
        data:
          entity_id: all
          temperature: 18
      - service: switch.turn_off
        entity_id:
          - switch.socket_1
          - switch.socket_2
```

## 2. Ночной режим

```yaml
automation:
  - alias: "Ночной режим"
    trigger:
      - platform: time
        at: "23:30:00"
    action:
      - service: climate.set_temperature
        data:
          entity_id: all
          temperature: 19
      - service: light.turn_off
        entity_id: all
```

## 3. Мониторинг потребления

```yaml
sensor:
  - platform: template
    sensors:
      daily_energy_cost:
        friendly_name: "Стоимость энергии сегодня"
        unit_of_measurement: "₽"
        value_template: >
          {{ states('sensor.daily_energy')|float * 5.0 }}
```
