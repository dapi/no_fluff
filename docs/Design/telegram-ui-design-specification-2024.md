# Техническое задание: Telegram UI Design Specification 2024

## Обзор

Документ содержит детальные спецификации для создания аутентичного интерфейса в стиле Telegram (2024), основанные на официальных исходниках Telegram Desktop, Telegram Mini Apps SDK и Telegram API.

## 1. Цветовая схема

### Основные цвета Telegram

#### Фоновые цвета
```css
/* Основной фон чата */
--tg-theme-bg-color: #ffffff; /* Белый для светлой темы */
--tg-theme-secondary-bg-color: #f7f7f7; /* Вторичный фон */

/* Тёмная тема */
--tg-theme-bg-color-dark: #18222d;
--tg-theme-secondary-bg-color-dark: #0f1419;

/* Секции */
--tg-theme-section-bg-color: #ffffff;
--tg-theme-section-bg-color-dark: #18222d;
```

#### Текстовые цвета
```css
/* Основной текст */
--tg-theme-text-color: #000000;
--tg-theme-text-color-dark: #ffffff;

/* Дополнительный текст */
--tg-theme-hint-color: #999999;
--tg-theme-hint-color-dark: #999999;

/* Заголовки */
--tg-theme-header-bg-color: #ffffff;
--tg-theme-header-bg-color-dark: #18222d;

/* Подзаголовки */
--tg-theme-subtitle-text-color: #999999;
--tg-theme-section-header-text-color: #000000;
```

#### Акцентные цвета
```css
/* Основной акцент (синий Telegram) */
--tg-theme-button-color: #0088cc; /* #00a32b в некоторых источниках */
--tg-theme-accent-text-color: #2481cc;

/* Линии-разделители */
--tg-theme-section-separator-color: #e5e5e5;
--tg-theme-section-separator-color-dark: #2f2f2f;

/* Ссылки */
--tg-theme-link-color: #2481cc;

/* Деструктивные действия */
--tg-theme-destructive-text-color: #ff3b30;
```

### Цветовые константы (из исходного кода Telegram Desktop)
```css
/* Системные цвета */
COLOR_GREEN_LIGHT: #15cd7d;
windowActiveTextFg: #15cd7d;
msgInServiceFg: windowActiveTextFg;

/* Кнопки */
activeButtonBgOver: #00a32b;
windowBoldFgOver: COLOR_GREEN_LIGHT;
menuIconFgOver: COLOR_GREEN_LIGHT;
```

## 2. Типографика

### Шрифты
- **Основной шрифт**: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif
- **Моноширинный**: "SF Mono", Monaco, Inconsolata, "Roboto Mono", Consolas, "Courier New", monospace

### Размеры шрифтов
```css
/* Основной текст */
font-size: 15px; /* Основной текст сообщений */
line-height: 1.3125; /* ~20px для 15px шрифта */

/* Заголовки */
font-size: 17px; /* Заголовки чатов и секций */
font-weight: 600; /* Semi-bold для заголовков */

/* Мелкий текст */
font-size: 13px; /* Время сообщений, статус */
font-size: 12px; /* Подписи и пояснения */

/* Крупные заголовки */
font-size: 22px; /* Заголовки разделов */
font-size: 34px; /* Крупные заголовки экранов */
```

### Вес шрифтов
```css
font-weight: 400; /* Regular - основной текст */
font-weight: 500; /* Medium - выделенный текст */
font-weight: 600; /* Semi-bold - заголовки */
font-weight: 700; /* Bold - важные элементы */
```

## 3. Отступы и Spacing

### Базовая сетка
- **Базовый unit**: 4px
- **Минимальный отступ**: 4px
- **Стандартный отступ**: 8px
- **Увеличенный отступ**: 16px
- **Большой отступ**: 24px
- **Огромный отступ**: 32px

### Отступы в компонентах
```css
/* Сообщения */
message-padding: 12px 16px;
message-margin: 8px 0;
message-avatar-gap: 12px;

/* Заголовки */
header-padding: 12px 16px;
header-margin: 0 0 16px 0;

/* Кнопки */
button-padding: 12px 24px;
button-margin: 8px;
button-gap: 8px;

/* Секции */
section-padding: 16px;
section-margin: 24px 0;
section-gap: 16px;
```

## 4. Компоненты интерфейса

### 4.1 Пузыри сообщений

#### Входящие сообщения
```css
.incoming-message {
  background-color: #e5f3ff;
  border-radius: 18px;
  padding: 12px 16px;
  max-width: 75%;
  margin: 4px 0;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
}

.incoming-message-dark {
  background-color: #1b2f41;
  color: #ffffff;
}
```

#### Исходящие сообщения
```css
.outgoing-message {
  background-color: #0088cc;
  border-radius: 18px;
  padding: 12px 16px;
  max-width: 75%;
  margin: 4px 0;
  color: #ffffff;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
  align-self: flex-end;
}

.outgoing-message-dark {
  background-color: #0b6582;
}
```

#### Сообщения с аватарами
```css
.message-with-avatar {
  margin-left: 52px; /* Отступ для аватара 36px + gap 16px */
}

.message-avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  position: absolute;
  left: 8px;
  top: 8px;
}
```

### 4.2 Заголовки

#### Заголовок чата
```css
.chat-header {
  height: 56px;
  padding: 0 16px;
  background-color: var(--tg-theme-header-bg-color);
  border-bottom: 1px solid var(--tg-theme-section-separator-color);
  display: flex;
  align-items: center;
  gap: 12px;
}

.chat-title {
  font-size: 17px;
  font-weight: 600;
  color: var(--tg-theme-text-color);
  flex: 1;
}

.chat-subtitle {
  font-size: 13px;
  color: var(--tg-theme-hint-color);
  margin-top: 2px;
}
```

#### Заголовки секций
```css
.section-header {
  font-size: 15px;
  font-weight: 600;
  color: var(--tg-theme-section-header-text-color);
  padding: 16px 16px 8px 16px;
  margin: 0;
}

.section-subtitle {
  font-size: 13px;
  color: var(--tg-theme-hint-color);
  padding: 0 16px 16px 16px;
  margin: 0;
}
```

### 4.3 Кнопки

#### Основная кнопка (Main Button)
```css
.main-button {
  background-color: var(--tg-theme-button-color);
  color: #ffffff;
  border: none;
  border-radius: 8px;
  padding: 12px 24px;
  font-size: 17px;
  font-weight: 600;
  min-height: 48px;
  transition: all 0.2s ease;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.main-button:hover {
  background-color: #0077b3;
  box-shadow: 0 2px 5px rgba(0, 0, 0, 0.15);
}

.main-button:active {
  transform: translateY(1px);
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
}

.main-button:disabled {
  background-color: #cccccc;
  color: #999999;
  box-shadow: none;
}
```

#### Вторичная кнопка (Secondary Button)
```css
.secondary-button {
  background-color: transparent;
  color: var(--tg-theme-button-color);
  border: 1px solid var(--tg-theme-button-color);
  border-radius: 8px;
  padding: 12px 24px;
  font-size: 17px;
  font-weight: 600;
  min-height: 48px;
  transition: all 0.2s ease;
}

.secondary-button:hover {
  background-color: rgba(0, 136, 204, 0.1);
}
```

#### Кнопки с иконками
```css
.icon-button {
  width: 44px;
  height: 44px;
  border-radius: 22px;
  background-color: transparent;
  border: none;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: background-color 0.2s ease;
}

.icon-button:hover {
  background-color: rgba(0, 0, 0, 0.05);
}

.icon-button-dark:hover {
  background-color: rgba(255, 255, 255, 0.1);
}
```

### 4.4 Поля ввода

#### Текстовые поля
```css
.text-input {
  background-color: var(--tg-theme-bg-color);
  border: 1px solid var(--tg-theme-section-separator-color);
  border-radius: 8px;
  padding: 12px 16px;
  font-size: 17px;
  color: var(--tg-theme-text-color);
  min-height: 44px;
  transition: border-color 0.2s ease;
}

.text-input:focus {
  border-color: var(--tg-theme-button-color);
  outline: none;
}

.text-input::placeholder {
  color: var(--tg-theme-hint-color);
}
```

## 5. Визуальные детали

### Border Radius
```css
/* Округления элементов */
border-radius-small: 6px;   /* Маленькие элементы */
border-radius-medium: 8px;  /* Кнопки, поля ввода */
border-radius-large: 12px;  /* Карточки */
border-radius-xlarge: 16px; /* Большие карточки */
border-radius-round: 50%;   /* Аватары, круглые кнопки */
border-radius-bubble: 18px; /* Пузыри сообщений */
```

### Тени
```css
/* Тени для элементов */
shadow-small: 0 1px 2px rgba(0, 0, 0, 0.1);
shadow-medium: 0 2px 8px rgba(0, 0, 0, 0.15);
shadow-large: 0 4px 16px rgba(0, 0, 0, 0.2);
shadow-button: 0 1px 3px rgba(0, 0, 0, 0.1);
shadow-card: 0 1px 3px rgba(0, 0, 0, 0.1);
```

### Анимации

#### Длительность анимаций
```css
/* Стандартные длительности */
animation-fast: 0.15s;     /* Быстрые переходы */
animation-normal: 0.2s;    /* Стандартные переходы */
animation-slow: 0.3s;      /* Медленные переходы */
animation-page: 0.25s;     /* Переходы между экранами */
```

#### Функции анимации
```css
/* Тайминги */
ease-in-out: cubic-bezier(0.4, 0.0, 0.2, 1); /* Стандартная */
ease-out: cubic-bezier(0.0, 0.0, 0.2, 1);    /* Плавное завершение */
ease-in: cubic-bezier(0.4, 0.0, 1, 1);      /* Плавное начало */
bounce: cubic-bezier(0.68, -0.55, 0.265, 1.55); /* Отскок */
```

#### Типовые анимации
```css
/* Появление элементов */
@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

/* Появление снизу */
@keyframes slideInUp {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* Пульсация для загрузки */
@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

/* Shine эффект для кнопок */
@keyframes shine {
  0% { background-position: -200% center; }
  100% { background-position: 200% center; }
}
```

## 6. Адаптивность и платформы

### Mobile优先 подход
```css
/* Базовые стили для мобильных устройств */
.container {
  padding: 0 16px;
  max-width: 100%;
}

/* Планшеты */
@media (min-width: 768px) {
  .container {
    max-width: 768px;
    margin: 0 auto;
    padding: 0 24px;
  }
}

/* Десктоп */
@media (min-width: 1024px) {
  .container {
    max-width: 1200px;
    padding: 0 32px;
  }
}
```

### Safe Areas для мобильных устройств
```css
/* Поддержка вырезов и системных областей */
.safe-area-top {
  padding-top: env(safe-area-inset-top);
}

.safe-area-bottom {
  padding-bottom: env(safe-area-inset-bottom);
}

.safe-area-left {
  padding-left: env(safe-area-inset-left);
}

.safe-area-right {
  padding-right: env(safe-area-inset-right);
}
```

### Telegram Mini Apps интеграция
```css
/* CSS переменные из Telegram Mini Apps SDK */
:root {
  /* Автоматически подставляются Telegram */
  --tg-viewport-height: 100vh;
  --tg-viewport-width: 100vw;
  --tg-viewport-stable-height: 100vh;

  /* Тема */
  --tg-theme-bg-color: #ffffff;
  --tg-theme-text-color: #000000;
  --tg-theme-button-color: #0088cc;
  /* ... остальные переменные темы */
}
```

## 7. Особенности десктопной версии

### Оконная структура Telegram Desktop
```css
/* Главное окно */
.main-window {
  background-color: #ffffff;
  border-radius: 8px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.1);
}

/* Сайдбар со списком чатов */
.chat-list {
  width: 320px;
  background-color: #f7f7f7;
  border-right: 1px solid #e5e5e5;
}

/* Область чата */
.chat-area {
  flex: 1;
  background-color: #ffffff;
  display: flex;
  flex-direction: column;
}

/* Панель ввода */
.input-panel {
  background-color: #ffffff;
  border-top: 1px solid #e5e5e5;
  padding: 12px 16px;
}
```

### Hover состояния для десктопа
```css
/* Только для десктопа */
@media (hover: hover) {
  .interactive-element:hover {
    background-color: rgba(0, 136, 204, 0.05);
    cursor: pointer;
  }

  .button:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  }
}
```

## 8. Доступность (Accessibility)

### Контрастность
- Текст на фоне должен иметь контрастность минимум 4.5:1
- Крупный текст (18px+) минимум 3:1
- Интерактивные элементы минимум 3:1

### Размеры для касания
```css
/* Минимальные размеры для touch */
.touch-target {
  min-width: 44px;
  min-height: 44px;
}

/* Пространство вокруг интерактивных элементов */
.interactive-element {
  margin: 4px;
  padding: 8px;
}
```

### Фокус состояния
```css
.focusable:focus {
  outline: 2px solid var(--tg-theme-button-color);
  outline-offset: 2px;
}

/* Скрытие outline для мышки, сохранение для клавиатуры */
.focusable:focus:not(:focus-visible) {
  outline: none;
}
```

## 9. Рекомендации по реализации

### Использование CSS переменных
```css
/* Определение базовых переменных */
:root {
  --spacing-unit: 4px;
  --border-radius: 8px;
  --transition-duration: 0.2s;
  --shadow: 0 1px 3px rgba(0, 0, 0, 0.1);

  /* Использование базовых переменных */
  --spacing-small: calc(var(--spacing-unit) * 2);
  --spacing-medium: calc(var(--spacing-unit) * 4);
  --spacing-large: calc(var(--spacing-unit) * 6);
}
```

### Компонентный подход
```css
/* Базовый компонент кнопки */
.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: var(--border-radius);
  font-weight: 600;
  transition: all var(--transition-duration) ease;
  min-height: 44px;
  padding: 0 24px;
  cursor: pointer;
  border: none;
}

/* Модификаторы */
.btn--primary {
  background-color: var(--tg-theme-button-color);
  color: #ffffff;
}

.btn--secondary {
  background-color: transparent;
  color: var(--tg-theme-button-color);
  border: 1px solid var(--tg-theme-button-color);
}

.btn--small {
  min-height: 36px;
  padding: 0 16px;
  font-size: 15px;
}
```

## 10. Проверка качества

### Список контроля
- [ ] Все цвета соответствуют Telegram палитре
- [ ] Размеры шрифтов соответствуют спецификации
- [ ] Отступы кратны 4px
- [ ] Border radius соответствуют компонентам
- [ ] Анимации имеют правильную длительность
- [ ] Hover состояния реализованы для десктопа
- [ ] Touch targets достаточно большие (44px мин)
- [ ] Контрастность соответствует WCAG AA
- [ ] Safe areas поддерживаются на мобильных устройствах
- [ ] CSS переменные используются для темизации

### Инструменты для проверки
- **Contrast Checker**: проверка контрастности
- **WAVE**: оценка доступности
- **Lighthouse**: общее качество UI
- **Responsive Design Checker**: проверка адаптивности

---

*Документ основан на официальных источниках Telegram API, Telegram Desktop исходном коде и Telegram Mini Apps SDK. Актуальность: Ноябрь 2024.*