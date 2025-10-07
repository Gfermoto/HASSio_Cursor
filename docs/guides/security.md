# 🔒 Безопасность умного дома

Настройка эффективной системы безопасности

---

## 📑 Содержание

- [Компоненты системы](#компоненты-системы)
- [1. Умные оповещения](#1-умные-оповещения)
  - [Проблема: Слишком много ложных срабатываний](#проблема-слишком-много-ложных-срабатываний)
  - [Машина во дворе](#машина-во-дворе)
- [2. Зоны детекции](#2-зоны-детекции)
  - [Настройка правильных зон](#настройка-правильных-зон)
- [3. Автоматизация освещения](#3-автоматизация-освещения)
- [4. Контроль доступа](#4-контроль-доступа)
  - [Видеодомофон с умным открытием](#видеодомофон-с-умным-открытием)
  - [Умные замки](#умные-замки)
- [5. Режимы охраны](#5-режимы-охраны)
- [6. Мониторинг событий](#6-мониторинг-событий)
  - [Dashboard безопасности](#dashboard-безопасности)
- [7. Периодические проверки](#7-периодические-проверки)
- [Чек-лист безопасности](#чек-лист-безопасности)

---

## Компоненты системы

Из аудита определяются:

- 📹 **Камеры** (Hikvision, Dahua, тепловизоры)
- 🚨 **Датчики движения** (PIR, thermal)
- 🚪 **Датчики открытия** (двери, окна)
- 🔔 **Видеодомофоны**
- 🔒 **Замки** (умные замки)

---

## 1. Умные оповещения

### Проблема: Слишком много ложных срабатываний

**Решение:** Фильтрация по типу объекта

```yaml
automation:
  - alias: "Тревога: Человек ночью"
    trigger:
      - platform: state
        entity_id: binary_sensor.street_ptz_smart_motion_human
        to: "on"
    condition:
      - condition: time
        after: "22:00:00"
        before: "06:00:00"
      # Игнорировать если дома
      - condition: state
        entity_id: alarm_control_panel.home
        state: "armed_away"
    action:
      - service: notify.telegram
        data:
          message: "⚠️ Человек возле дома!"
          data:
            photo:
              - url: "http://YOUR_HA_IP:8123/api/camera_proxy/camera.street_ptz"
      - service: light.turn_on
        entity_id: light.street_lights
        data:
          brightness: 255
```

### Машина во дворе

```yaml
automation:
  - alias: "Тревога: Машина у ворот"
    trigger:
      - platform: state
        entity_id: binary_sensor.street_ptz_smart_motion_vehicle
        to: "on"
    condition:
      - condition: state
        entity_id: binary_sensor.gate_lock
        state: "off"  # Ворота закрыты
    action:
      - service: notify.telegram
        data:
          message: "🚗 Машина у ворот!"
          data:
            inline_keyboard:
              - "Открыть ворота:/open_gate"
              - "Игнорировать:/ignore"
```

---

## 2. Зоны детекции

### Настройка правильных зон

Неправильно:

- ❌ Вся камера активна → ложные срабатывания на деревья
- ❌ Постоянная тревога на улице

Правильно:

- ✅ Зона у калитки
- ✅ Зона у входной двери
- ✅ Периметр забора

**Настройка через Hikvision:**

1. Настройки камеры → Детекция → Smart Event
2. Выбрать "Intrusion Detection" (вторжение)
3. Нарисовать зону интереса
4. Настроить чувствительность: 60-70%

---

## 3. Автоматизация освещения

```yaml
automation:
  - alias: "Свет при движении ночью"
    trigger:
      - platform: state
        entity_id:
          - binary_sensor.doorbell_pir
          - binary_sensor.garden_thermal_motion_alarm
        to: "on"
    condition:
      - condition: sun
        after: sunset
        before: sunrise
    action:
      - service: light.turn_on
        entity_id:
          - light.entrance
          - light.garden_thermal_infrared
        data:
          brightness: 200
      - delay: "00:03:00"
      - service: light.turn_off
        entity_id:
          - light.entrance
          - light.garden_thermal_infrared
```

---

## 4. Контроль доступа

### Видеодомофон с умным открытием

```yaml
automation:
  - alias: "Домофон: Уведомление"
    trigger:
      - platform: state
        entity_id: binary_sensor.vto2111_invite
        to: "on"
    action:
      - service: notify.telegram
        data:
          message: "🔔 Звонок в домофон!"
          data:
            photo:
              - url: "http://YOUR_HA_IP:8123/api/camera_proxy/camera.vto2111"
            inline_keyboard:
              - "Открыть:/open_door"
              - "Говорить:/talk"
```

### Умные замки

```yaml
automation:
  - alias: "Автозакрытие двери"
    trigger:
      - platform: state
        entity_id: binary_sensor.door_sensor
        to: "off"  # Дверь закрыта
        for: "00:00:30"
    condition:
      - condition: state
        entity_id: lock.door_lock
        state: "unlocked"
    action:
      - service: lock.lock
        entity_id: lock.door_lock
```

---

## 5. Режимы охраны

```yaml
# В input_select.yaml
input_select:
  security_mode:
    name: Режим охраны
    options:
      - "Дома"
      - "Ушли"
      - "Отпуск"
      - "Сон"
    initial: "Дома"
    icon: mdi:shield-home

# Автоматизация режимов
automation:
  - alias: "Режим: Ушли"
    trigger:
      - platform: state
        entity_id: group.family
        to: "not_home"
        for: "00:05:00"
    action:
      - service: input_select.select_option
        target:
          entity_id: input_select.security_mode
        data:
          option: "Ушли"
      - service: alarm_control_panel.alarm_arm_away
        entity_id: alarm_control_panel.home
      - service: climate.set_temperature
        data:
          entity_id: all
          temperature: 18
      - service: light.turn_off
        entity_id: all

  - alias: "Режим: Вернулись"
    trigger:
      - platform: state
        entity_id: group.family
        to: "home"
    action:
      - service: input_select.select_option
        target:
          entity_id: input_select.security_mode
        data:
          option: "Дома"
      - service: alarm_control_panel.alarm_disarm
        entity_id: alarm_control_panel.home
```

---

## 6. Мониторинг событий

### Dashboard безопасности

```yaml
type: vertical-stack
cards:
  - type: picture-entity
    entity: camera.street_ptz
    camera_image: camera.street_ptz
    show_state: false

  - type: horizontal-stack
    cards:
      - type: entity
        entity: binary_sensor.street_ptz_smart_motion_human
        name: Человек
      - type: entity
        entity: binary_sensor.street_ptz_smart_motion_vehicle
        name: Машина

  - type: history-graph
    entities:
      - binary_sensor.doorbell_pir
      - binary_sensor.garden_thermal_motion_alarm
      - binary_sensor.gate_lock
    hours_to_show: 24

  - type: logbook
    entities:
      - binary_sensor.street_ptz_smart_motion_human
      - binary_sensor.vto2111_invite
    hours_to_show: 24
```

---

## 7. Периодические проверки

```yaml
automation:
  - alias: "Тест камер каждую ночь"
    trigger:
      - platform: time
        at: "03:00:00"
    action:
      - service: script.check_all_cameras

script:
  check_all_cameras:
    sequence:
      - repeat:
          for_each:
            - camera.street_ptz
            - camera.garden_thermal
            - camera.vto2111
          sequence:
            - service: camera.snapshot
              target:
                entity_id: "{{ repeat.item }}"
              data:
                filename: "/config/www/snapshots/{{ repeat.item }}_test.jpg"
            - delay: 1
      - service: notify.telegram
        data:
          message: "✅ Все камеры работают"
```

---

## Чек-лист безопасности

- [ ] Настроены зоны детекции на камерах
- [ ] Отключены ложные срабатывания
- [ ] Умные уведомления (только критичные)
- [ ] Режимы охраны автоматизированы
- [ ] Есть снимки с камер при тревоге
- [ ] Периодическая проверка оборудования
- [ ] Резервное питание для критичных устройств

---

!!! warning "Важно"
    Проверяйте камеры и датчики раз в месяц! Неработающая система безопасности хуже её отсутствия.
