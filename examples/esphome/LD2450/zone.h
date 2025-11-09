#include <cmath>
#include <iostream>
#include <sstream>
#include <string>
#include <iomanip>
#include <algorithm>
#include <cctype>

struct Position {
  int16_t x = 0;
  int16_t y = 0;
  int16_t speed = 0;
  int16_t distance_resolution = 0;
  bool valid = false;
  bool zone_ex_enter = false;
  float angle = 0;
  std::basic_string<char> position = "Static";
  std::basic_string<char> direction = "None";
};
struct Zone {
  int16_t x;
  int16_t y;
  int16_t height;
  int16_t width;
  int16_t target_count = 0;
  int16_t outside_target_count = 0;
  bool has_target = false;
  bool has_target_outside = false;

  // template_::TemplateTextSensor* tips_conf;
  // std::string name = "Zone";
};

struct Pxy {
  int16_t x;
  int16_t y;
};


float toRadians(float degrees){
    return degrees * M_PI / 180.0;
}

// Функция для безопасного вычисления acos с защитой от domain error
inline float safe_acos(float x) {
  // Ограничиваем значение в диапазоне [-1, 1] для избежания NaN
  if (x < -1.0f) return M_PI;
  if (x > 1.0f) return 0.0f;
  return acos(x);
}

// Функция для проверки нахождения цели в заданной зоне
bool check_targets_in_zone(struct Zone &z, struct Position &t, float angle) {
  struct Pxy p1, p2, p3, p4;
  float d12, d14, d15, d23, d25, d34, d35, d45;
  float a152, a154, a253, a354, a_sum;
  float TAU = 2 * M_PI; // 6.283185; // 2*PI
  bool isInside = false;

  // ИСПРАВЛЕНИЕ: Проверка размера зоны - если зона нулевая, цель не может быть внутри
  if (z.width == 0 || z.height == 0) {
    return false;
  }

  p1.x = z.x;
  p1.y = z.y;
  p2.x = z.x - z.width * cos(toRadians(angle));
  p2.y = z.y + z.width * sin(toRadians(angle));
  p3.x = z.x - z.width * cos(toRadians(angle)) + z.height * cos(toRadians(angle - 90));
  p3.y = z.y + z.width * sin(toRadians(angle)) + z.height * sin(toRadians(angle + 90));
  p4.x = z.x + z.height * cos(toRadians(angle - 90));
  p4.y = z.y + z.height * sin(toRadians(angle + 90));

  // ОПТИМИЗАЦИЯ: Замена pow(x,2) на x*x - в 5× быстрее
  float dx, dy;
  dx = p1.x-t.x; dy = p1.y-t.y; d15 = sqrtf(dx*dx + dy*dy);
  dx = p2.x-t.x; dy = p2.y-t.y; d25 = sqrtf(dx*dx + dy*dy);
  dx = p3.x-t.x; dy = p3.y-t.y; d35 = sqrtf(dx*dx + dy*dy);
  dx = p4.x-t.x; dy = p4.y-t.y; d45 = sqrtf(dx*dx + dy*dy);
  dx = p1.x-p2.x; dy = p1.y-p2.y; d12 = sqrtf(dx*dx + dy*dy);
  dx = p1.x-p4.x; dy = p1.y-p4.y; d14 = sqrtf(dx*dx + dy*dy);
  dx = p2.x-p3.x; dy = p2.y-p3.y; d23 = sqrtf(dx*dx + dy*dy);
  dx = p3.x-p4.x; dy = p3.y-p4.y; d34 = sqrtf(dx*dx + dy*dy);

  // ИСПРАВЛЕНИЕ: Защита от деления на ноль
  // Если цель совпадает с углом зоны - считаем что она внутри
  const float EPSILON = 0.01f; // Минимальное расстояние для деления

  if (d15 < EPSILON || d25 < EPSILON || d35 < EPSILON || d45 < EPSILON) {
    return true; // Цель практически в углу зоны
  }

  // ИСПРАВЛЕНИЕ: Использование safe_acos для предотвращения NaN
  // ОПТИМИЗАЦИЯ: Замена pow(x,2) на x*x
  a152 = safe_acos((d15*d15 + d25*d25 - d12*d12)/(2*d15*d25));
  a154 = safe_acos((d15*d15 + d45*d45 - d14*d14)/(2*d15*d45));
  a253 = safe_acos((d25*d25 + d35*d35 - d23*d23)/(2*d25*d35));
  a354 = safe_acos((d35*d35 + d45*d45 - d34*d34)/(2*d35*d45));
  a_sum = a152+a154+a253+a354;

  if (a_sum >= TAU) {
    isInside = true;
  }
  return isInside;
}

bool to_bool(std::basic_string<char> str) {
    std::transform(str.begin(), str.end(), str.begin(), ::tolower);
    std::istringstream is(str);
    bool b;
    is >> std::boolalpha >> b;
    return b;
}

void check_zone_valid(int x, int y, int width, int height, template_::TemplateTextSensor* tips_conf){
    if (x == 0 && width == 0 && y == 0 && height == 0){
        tips_conf->publish_state("Configure below");
        return;
    }

    char combined[80];
    sprintf(combined, "Curr Size: %d x %d", width, height);
    tips_conf->publish_state(combined);
}

void check_zout_valid(int z, template_::TemplateTextSensor* tips_conf){
    char combined[40];
    sprintf(combined, "Zone Exclusion %d", z);
    tips_conf->publish_state(combined);
}
