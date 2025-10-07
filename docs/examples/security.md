# 🔒 Примеры: Безопасность

Готовые сценарии

---

## 1. Умное уведомление

```yaml
automation:
  - alias: "Человек ночью"
    trigger:
      - platform: state
        entity_id: binary_sensor.motion
        to: "on"
    condition:
      - condition: time
        after: "22:00:00"
        before: "06:00:00"
    action:
      - service: notify.telegram
        data:
          message: "Движение!"
          data:
            photo:
              - url: "http://ha:8123/api/camera_proxy/camera.street"
```text

## 2. Автоматический свет

```yaml
automation:
  - alias: "Свет при движении"
    trigger:
      - platform: state
        entity_id: binary_sensor.doorbell_pir
        to: "on"
    action:
      - service: light.turn_on
        entity_id: light.entrance
      - delay: "00:03:00"
      - service: light.turn_off
        entity_id: light.entrance
```text

**Полное руководство:** [Безопасность умного дома](../guides/security.md)
