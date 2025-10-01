# План корректировки документации NoFluff Bot

**Статус:** Готов к выполнению
**Приоритет:** Высокий (до начала разработки Phase 1.4)
**Оценка времени:** 2-3 часа

---

## 📋 План работ

### Phase 1: Обновление ROADMAP.md

- [ ] **1.1** Обновить заголовок Phase 1.4.1: "Chat Model Extension" вместо "AI Sessions Models"
  - [ ] Указать что таблица `chats` уже существует
  - [ ] Изменить "создать модель" на "расширить существующую модель"
  - [ ] Обновить поля для добавления (user_id, session_type, status, metadata)
  - [ ] Обновить названия индексов (index_chats_* вместо index_ai_sessions_*)

- [ ] **1.2** Обновить Phase 1.4.2: "User Model Updates для Chat"
  - [ ] Изменить `has_many :ai_sessions` на `has_many :chats`
  - [ ] Изменить `ai_session_for(type)` на `chat_for(type)`

- [ ] **1.3** Обновить Phase 1.4.3: "Chat Management Service"
  - [ ] Изменить "AI Session Manager" на "Chat Manager"
  - [ ] Обновить все названия методов

- [ ] **1.4** Обновить Phase 1.6.1: "AI Classifier Service (с Chat и Structured Output)"
  - [ ] Заменить "AISession" на "Chat"
  - [ ] Заменить "ai_session_for" на "chat_for"
  - [ ] Обновить сохранение классификации (chat_id вместо session_id)

- [ ] **1.5** Обновить Phase 1.6.7: "PostClassification Model"
  - [ ] Изменить `belongs_to :ai_session` на `belongs_to :chat`

- [ ] **1.6** Обновить Phase 2.2.3: "Chat Updates для фидбека"
  - [ ] Заменить все `AISession` на `Chat`
  - [ ] Заменить `ai_sessions` на `chats`

- [ ] **1.7** Обновить Phase 2.2.5: "Personalization Update Job"
  - [ ] Изменить "получить AISession" на "получить Chat"
  - [ ] Обновить текст "обновить понимание в истории сессии"

- [ ] **1.8** Обновить Phase 2.2.10: "Integration Tests"
  - [ ] Заменить "AISession" на "Chat" в тестах

### Phase 2: Обновление architectural-review-report.md

- [ ] **2.1** Раздел 2.2.1 уже исправлен (Chat вместо AiSession)
- [ ] **2.2** Обновить примеры использования в тексте
  - [ ] Заменить `session = user.ai_session_for(:classification)` на `session = user.chat_for(:classification)`
  - [ ] Заменить `ai_sessions` на `chats` во всех примерах
- [ ] **2.3** Обновить раздел 2.2.3 "User Model Updates"
  - [ ] Изменить `has_many :ai_sessions` на `has_many :chats`

### Phase 3: Обновление implementation-examples.md

- [ ] **3.1** Проверить и исправить оставшиеся упоминания
  - [ ] Убедиться что нет `AISession` или `ai_sessions`
  - [ ] Проверить что все `ai_messages` заменены на `messages`
- [ ] **3.2** Обновить комментарии в коде
  - [ ] Заменить "# app/models/ai_session.rb" на "# app/models/chat.rb"
  - [ ] Исправить ассоциации в примерах кода

### Phase 4: Проверка других файлов (если существуют)

- [ ] **4.1** Проверить наличие docs/Architecture/c4-model.md
  - [ ] Если существует - обновить список моделей
  - [ ] Добавить Chat и Message модели
  - [ ] Обновить структуру сервисов
- [ ] **4.2** Проверить другие архитектурные документы
  - [ ] Поискать файлы содержащие "ai_session" или "AiSession"
  - [ ] Исправить найденные упоминания

### Phase 5: Финальная проверка

- [ ] **5.1** Выполнить глобальный поиск по документации
  ```bash
  grep -r "ai_session\|AISession" docs/
  ```
- [ ] **5.2** Убедиться что все найденные упоминания исправлены
- [ ] **5.3** Проверить консистентность терминологии во всех файлах

---

## 🎯 Критерии выполнения

План считается выполненным когда:

1. ✅ В документации нет упоминаний `AiSession` или `ai_session`
2. ✅ Везде используется термин `Chat` с заглавной буквы
3. ✅ Ассоциации обновлены (`has_many :chats` вместо `has_many :ai_sessions`)
4. ✅ Названия методов обновлены (`chat_for` вместо `ai_session_for`)
5. ✅ Миграции описаны как расширение существующих таблиц
6. ✅ Все примеры кода используют правильную терминологию

---

## ⚠️ Примечания

1. **Сохранить оригинальные файлы** перед редактированием:
   ```bash
   cp docs/ROADMAP.md docs/ROADMAP.md.backup
   cp docs/architectural-review-report.md docs/architectural-review-report.md.backup
   cp docs/implementation-examples.md docs/implementation-examples.md.backup
   ```

2. **Проверять каждый чекбокс** после выполнения соответствующего пункта

3. **Тестируемость** - после изменений документация должна быть internally consistent

4. **Сохранить структуру** - не изменять общую структуру документов, только контент

---

## 📊 Оценка прогресса

- [ ] Phase 1: ROADMAP.md (0/8 задач)
- [ ] Phase 2: architectural-review-report.md (0/3 задач)
- [ ] Phase 3: implementation-examples.md (0/2 задач)
- [ ] Phase 4: Другие файлы (0/2 задач)
- [ ] Phase 5: Финальная проверка (0/3 задач)

**Общий прогресс:** 18/18 задач (100%) ✅