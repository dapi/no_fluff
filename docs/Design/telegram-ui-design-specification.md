# Telegram UI Design Specification 2024

**Дата:** 2 ноября 2024
**Версия:** 1.0
**Статус:** Готово к передаче дизайнеру

## 📋 Обзор задания

Создать аутентичный Telegram-интерфейс для демонстрации работы бота Без Шелухи. Дизайн должен быть точной копией реального Telegram приложения для максимальной узнаваемости и доверия пользователей.

---

## 🎨 Цветовая схема

### Светлая тема (основная)
```css
:root {
  /* Основные цвета */
  --tg-primary: #0088cc;           /* Основной синий */
  --tg-primary-dark: #0066aa;       /* Темный синий */
  --tg-primary-light: #53a9d3;      /* Светлый синий */

  /* Фоны */
  --tg-background: #ffffff;        /* Белый фон */
  --tg-surface: #f8f9fa;           /* Поверхность */
  --tg-message-bg: #dcf8c6;        /* Фон входящих сообщений */
  --tg-message-out: #e3f2fd;        /* Фон исходящих сообщений */

  /* Текст */
  --tg-text-primary: #1c1e21;      /* Основной текст */
  --tg-text-secondary: #8696a0;    /* Вторичный текст */
  --tg-text-hint: #a0aec0;          /* Подсказки */

  /* Границы */
  --tg-border: #e9edef;            /* Основная граница */
  --tg-border-secondary: #dfe4ea;  /* Вторичная граница */

  /* Статусы */
  --tg-success: #28a745;           /* Успех */
  --tg-warning: #ffc107;           /* Предупреждение */
  --tg-error: #dc3545;             /* Ошибка */
  --tg-info: #17a2b8;              /* Информация */
}
```

### Темная тема (опционально)
```css
:root[data-theme="dark"] {
  --tg-background: #18222d;
  --tg-surface: #1c1e21;
  --tg-message-bg: #2b5278;
  --tg-message-out: #0088cc;
  --tg-text-primary: #ffffff;
  --tg-text-secondary: #b1b3b8;
}
```

---

## 📝 Типографика

### Шрифты
```css
.tg-font {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
               "Helvetica Neue", Arial, sans-serif;
}

/* Размеры шрифтов */
.tg-text-h1 { font-size: 32px; font-weight: 600; line-height: 1.2; }
.tg-text-h2 { font-size: 24px; font-weight: 600; line-height: 1.2; }
.tg-text-h3 { font-size: 20px; font-weight: 600; line-height: 1.2; }
.tg-text-large { font-size: 18px; font-weight: 500; line-height: 1.3; }
.tg-text-medium { font-size: 16px; font-weight: 500; line-height: 1.4; }
.tg-text-regular { font-size: 15px; font-weight: 400; line-height: 1.3125; }
.tg-text-small { font-size: 13px; font-weight: 400; line-height: 1.384; }
.tg-text-caption { font-size: 11px; font-weight: 500; line-height: 1.36; }
```

---

## 📏 Отступы и Spacing

### Базовая сетка
- **Базовый unit:** 4px
- **Минимальное касание:** 44px × 44px
- **Плотные отступы:** 8px, 12px, 16px, 20px, 24px

### Стандартные отступы
```css
.tg-padding-xs { padding: 4px 8px; }    /* Минимальный */
.tg-padding-sm { padding: 8px 12px; }   /* Маленький */
.tg-padding-md { padding: 12px 16px; }  /* Средний */
.tg-padding-lg { padding: 16px 20px; }  /* Большой */
.tg-padding-xl { padding: 20px 24px; }  /* Очень большой */
```

---

## 🧩 Компоненты интерфейса

### 1. Заголовок чата (Chat Header)
```css
.tg-chat-header {
  background: var(--tg-background);
  border-bottom: 1px solid var(--tg-border);
  padding: 10px 16px;
  display: flex;
  align-items: center;
  height: 56px;
  box-shadow: 0 1px 0 rgba(0, 0, 0, 0.1);
}

.tg-chat-back {
  display: flex;
  align-items: center;
  gap: 12px;
}

.tg-chat-avatar {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: var(--tg-primary);
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-weight: 600;
  font-size: 16px;
}

.tg-chat-info {
  flex: 1;
}

.tg-chat-title {
  font-size: 17px;
  font-weight: 600;
  color: var(--tg-text-primary);
  margin: 0;
}

.tg-chat-subtitle {
  font-size: 13px;
  color: var(--tg-text-secondary);
  margin: 0;
}
```

### 2. Пузырь сообщения (Message Bubble)
```css
.tg-message {
  max-width: 75%;
  margin: 8px 0;
  animation: tg-message-appear 0.2s ease-out;
}

.tg-message-incoming {
  background: var(--tg-message-bg);
  border-radius: 18px 18px 4px 18px;
  margin-right: auto;
  margin-left: 56px;
}

.tg-message-outgoing {
  background: var(--tg-primary);
  color: white;
  border-radius: 18px 18px 18px 4px;
  margin-left: auto;
  margin-right: 56px;
}

.tg-message-tail {
  position: absolute;
  bottom: 0;
  width: 0;
  height: 0;
  border-style: solid;
}

.tg-message-incoming .tg-message-tail {
  right: -7px;
  border-width: 10px 0 10px 10px;
  border-color: transparent transparent transparent var(--tg-message-bg);
}

.tg-message-outgoing .tg-message-tail {
  left: -7px;
  border-width: 10px 10px 10px 0;
  border-color: transparent var(--tg-primary) transparent transparent;
}

.tg-message-content {
  padding: 10px 14px;
  color: var(--tg-text-primary);
  font-size: 15px;
  line-height: 1.3125;
  word-wrap: break-word;
}

.tg-message-time {
  font-size: 11px;
  color: var(--tg-text-hint);
  margin: 4px 0 0 0;
}
```

### 3. Кнопки (Buttons)
```css
.tg-button {
  background: var(--tg-primary);
  color: white;
  border: none;
  border-radius: 8px;
  padding: 10px 20px;
  font-size: 15px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
  min-height: 36px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  text-decoration: none;
}

.tg-button:hover {
  background: var(--tg-primary-dark);
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(0, 136, 204, 0.3);
}

.tg-button:active {
  transform: translateY(0);
  box-shadow: 0 2px 4px rgba(0, 136, 204, 0.2);
}

.tg-button-secondary {
  background: var(--tg-surface);
  color: var(--tg-primary);
  border: 1px solid var(--tg-border);
}

.tg-button-outline {
  background: transparent;
  color: var(--tg-primary);
  border: 2px solid var(--tg-primary);
}
```

### 4. Поля ввода (Input Fields)
```css
.tg-input {
  background: var(--tg-background);
  border: 1px solid var(--tg-border);
  border-radius: 8px;
  padding: 10px 14px;
  font-size: 15px;
  color: var(--tg-text-primary);
  outline: none;
  transition: border-color 0.2s ease;
  width: 100%;
  box-sizing: border-box;
}

.tg-input:focus {
  border-color: var(--tg-primary);
  box-shadow: 0 0 0 2px rgba(0, 136, 204, 0.2);
}

.tg-textarea {
  resize: vertical;
  min-height: 80px;
  font-family: inherit;
}
```

---

## ✨ Визуальные детали

### Border Radius
```css
.tg-radius-sm { border-radius: 4px; }   /* Кнопки, поля ввода */
.tg-radius-md { border-radius: 8px; }   /* Карточки */
.tg-radius-lg { border-radius: 12px; }  /* Модальные окна */
.tg-radius-xl { border-radius: 16px; }  /* Большие контейнеры */
.tg-radius-full { border-radius: 50%; } /* Аватары, иконки */
```

### Тени
```css
.tg-shadow-sm {
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
}

.tg-shadow-md {
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
}

.tg-shadow-lg {
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.2);
}

.tg-shadow-button {
  box-shadow: 0 2px 4px rgba(0, 136, 204, 0.2);
}

.tg-shadow-button-hover {
  box-shadow: 0 4px 12px rgba(0, 136, 204, 0.3);
}
```

### Анимации
```css
@keyframes tg-message-appear {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes tg-button-press {
  0% { transform: scale(1); }
  50% { transform: scale(0.98); }
  100% { transform: scale(1); }
}

.tg-transition {
  transition: all 0.2s ease-in-out;
}

.tg-transition-fast {
  transition: all 0.15s ease-out;
}

.tg-transition-slow {
  transition: all 0.3s ease-in-out;
}
```

---

## 📱 Адаптивность

### Mobile-first подход
```css
/* Mobile (320px - 767px) */
.tg-responsive-mobile {
  /* Мобильные стили */
}

.tg-message {
  max-width: 85%;
}

.tg-message-incoming {
  margin-left: 48px;
}

.tg-message-outgoing {
  margin-right: 48px;
}

/* Tablet (768px - 1023px) */
@media (min-width: 768px) {
  .tg-responsive-tablet {
    /* Планшетные стили */
  }

  .tg-message {
    max-width: 70%;
  }
}

/* Desktop (1024px+) */
@media (min-width: 1024px) {
  .tg-responsive-desktop {
    /* Десктопные стили */
  }

  .tg-message {
    max-width: 60%;
  }
}
```

### Safe Areas для мобильных устройств
```css
.tg-safe-area {
  padding-top: env(safe-area-inset-top);
  padding-right: env(safe-area-inset-right);
  padding-bottom: env(safe-area-inset-bottom);
  padding-left: env(safe-area-inset-left);
}
```

---

## ♿ Доступность (Accessibility)

### Контрастность
```css
.tg-high-contrast {
  /* Высококонтрастные цвета для WCAG AAA */
}

.tg-text-contrast {
  color: #000000; /* Черный текст на светлом фоне */
  background: #ffffff;
}

.tg-button-contrast {
  color: #ffffff;
  background: #000000;
  border: 2px solid #000000;
}
```

### Размеры для касания
```css
.tg-touch-target {
  min-width: 44px;
  min-height: 44px;
  padding: 12px 16px;
}

.tg-focus-visible {
  outline: 2px solid var(--tg-primary);
  outline-offset: 2px;
}
```

### Семантическая разметка
```html
<div class="tg-chat" role="application" aria-label="Telegram chat">
  <div class="tg-chat-header">
    <button class="tg-chat-back" aria-label="Back">
      <span class="tg-icon">←</span>
    </button>
    <div class="tg-chat-info">
      <h2 class="tg-chat-title">Без Шелухи</h2>
      <p class="tg-chat-subtitle">online</p>
    </div>
  </div>
  <div class="tg-messages" role="log" aria-live="polite">
    <div class="tg-message tg-message-incoming">
      <div class="tg-message-content">
        <p>Пример сообщения</p>
        <time class="tg-message-time">14:30</time>
      </div>
    </div>
  </div>
</div>
```

---

## 🔄 Состояния интерактивных элементов

### Кнопки
```css
.tg-button {
  /* Default state */
}

.tg-button:hover {
  /* Hover state */
}

.tg-button:active {
  /* Active/Pressed state */
  transform: translateY(1px);
}

.tg-button:disabled {
  /* Disabled state */
  opacity: 0.5;
  cursor: not-allowed;
  pointer-events: none;
}

.tg-button:focus {
  /* Focus state */
  outline: 2px solid var(--tg-primary);
}

.tg-button:focus:not(:focus-visible) {
  /* Remove focus outline when not keyboard navigation */
  outline: none;
}
```

### Поля ввода
```css
.tg-input {
  /* Default state */
}

.tg-input:focus {
  /* Focus state */
  border-color: var(--tg-primary);
  box-shadow: 0 0 0 2px rgba(0, 136, 204, 0.2);
}

.tg-input:invalid {
  /* Error state */
  border-color: var(--tg-error);
}

.tg-input::placeholder {
  color: var(--tg-text-hint);
  opacity: 0.7;
}
```

---

## 📐 Компоненты для демонстрации

### 1. Контейнер сравнения "До/После"
```css
.tg-comparison {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24px;
  padding: 24px;
  background: var(--tg-surface);
  border-radius: 16px;
}

.tg-comparison-column {
  background: var(--tg-background);
  border-radius: 16px;
  overflow: hidden;
  box-shadow: var(--tg-shadow-md);
}

@media (max-width: 767px) {
  .tg-comparison {
    grid-template-columns: 1fr;
    gap: 16px;
  }
}
```

### 2. Индикатор статуса
```css
.tg-status-indicator {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 8px;
  border-radius: 12px;
  font-size: 11px;
  font-weight: 500;
}

.tg-status-success {
  background: rgba(40, 167, 69, 0.1);
  color: var(--tg-success);
}

.tg-status-info {
  background: rgba(23, 162, 184, 0.1);
  color: var(--tg-info);
}
```

### 3. Бейдж с количеством
```css
.tg-badge {
  background: var(--tg-error);
  color: white;
  border-radius: 10px;
  padding: 2px 6px;
  font-size: 10px;
  font-weight: 600;
  min-width: 18px;
  text-align: center;
}
```

---

## 🎯 Специфичные требования для бота Без Шелухи

### Брендинговые элементы
```css
.tg-brand-primary {
  background: linear-gradient(135deg, #0088cc, #0066aa);
}

.tg-brand-success {
  background: linear-gradient(135deg, #25d366, #128c7e);
}

.tg-highlight-important {
  background: rgba(40, 167, 69, 0.1);
  border-left: 3px solid var(--tg-success);
  padding: 8px 12px;
  margin: 4px 0;
  border-radius: 0 4px 4px 0;
}
```

### Специальные классы для типов контента
```css
.tg-message-important {
  border: 2px solid var(--tg-success);
  background: #dcf8c6;
}

.tg-message-ad {
  background: #fffacd;
  opacity: 0.9;
}

.tg-message-duplicate {
  background: #ffe4e1;
  opacity: 0.8;
}

.tg-message-summary {
  background: rgba(40, 167, 69, 0.08);
  border-left: 3px solid #25d366;
  color: #075e54;
  font-style: italic;
  margin: 8px 0;
  padding: 8px 12px;
  border-radius: 0 8px 8px 0;
}
```

---

## 📋 Критерии приемки

### Обязательные требования:
1. [ ] Полное соответствие цветовой схеме Telegram
2. [ ] Использование системных шрифтов
3. [ ] Корректные border radius (18px для сообщений)
4. [ ] Адаптивность для всех устройств
5. [ ] Доступность (WCAG AA уровень)
6. [ ] Анимации с правильным timing
7. [ ] Семантическая HTML-разметка

### Рекомендуемые практики:
1. [ ] Использование CSS переменных для легкой кастомизации
2. [ ] Progressive enhancement для старых браузеров
3. [ ] Оптимизация производительности анимаций
4. [ ] Тестирование на реальных устройствах
5. [ ] Проверка контрастности и читаемости

### Файлы для entrega:
- `telegram-ui.html` - основная структура
- `telegram-ui.css` - стили
- `telegram-ui.js` - интерактивность
- `telegram-ui-components.json` - документация компонентов

---

## 📚 Дополнительные ресурсы

### Документация Telegram:
- [Telegram Bot API Documentation](https://core.telegram.org/bots/api)
- [Telegram Mini Apps Documentation](https://core.telegram.org/mini-apps)
- [Telegram Design Guidelines](https://core.telegram.org/design/draft)

### Инструменты:
- Figma UI Kit для Telegram
- Telegram Color Picker
- Telegram Font Generator

---

**Примечание:** Данное техническое задание основано на актуальных стандартах Telegram 2024 года и включает все необходимые детали для создания аутентичного интерфейса. Дизайнер должен строго следовать указанным параметрам для достижения максимального сходства с реальным приложением.