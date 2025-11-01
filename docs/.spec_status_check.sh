#!/bin/bash

# Script to check specification statuses
# Usage: ./docs/.spec_status_check.sh

echo "🔍 Анализ статусов спецификаций NoFluff Bot"
echo "=========================================="

SPECS_DIR="docs/Specs"
IMPL_DIR="docs/Implementation"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "\n📊 Статусы спецификаций:"
echo "----------------------------------------"

draft_count=0
need_plan_count=0
approved_count=0
implemented_count=0

for spec in "$SPECS_DIR"/*.md; do
    if [ -f "$spec" ]; then
        spec_name=$(basename "$spec" .md)
        status=$(grep "\*\*Статус:\*\*" "$spec" | cut -d: -f2 | tr -d ' *')

        case $status in
            "draft")
                echo -e "🟡 ${spec_name}: ${RED}$status${NC}"
                ((draft_count++))
                ;;
            "business_review"|"need_plan"|"tech_review")
                echo -e "🟠 ${spec_name}: ${YELLOW}$status${NC}"
                ((need_plan_count++))
                ;;
            "approved"|"in_progress"|"testing")
                echo -e "🟢 ${spec_name}: ${GREEN}$status${NC}"
                ((approved_count++))
                ;;
            "implemented"|"delivered")
                echo -e "🔵 ${spec_name}: ${BLUE}$status${NC}"
                ((implemented_count++))
                ;;
            *)
                echo -e "❓ ${spec_name}: Статус не определен"
                ;;
        esac
    fi
done

total=$((draft_count + need_plan_count + approved_count + implemented_count))

echo -e "\n📈 Сводка по статусам:"
echo "----------------------------------------"
echo -e "🟡 Draft: $draft_count"
echo -e "🟠 Review/Plan: $need_plan_count"
echo -e "🟢 Active: $approved_count"
echo -e "🔵 Completed: $implemented_count"
echo -e "📁 Всего спецификаций: $total"

echo -e "\n📋 Проверка планов имплементации:"
echo "----------------------------------------"

missing_impl=0
for spec in "$SPECS_DIR"/*.md; do
    if [ -f "$spec" ]; then
        spec_name=$(basename "$spec" .md)
        spec_number=$(echo "$spec_name" | grep -o '^[0-9]*')

        if [ -n "$spec_number" ]; then
            impl_file="$IMPL_DIR/Spec_${spec_number}_"*"_Implementation.md"
            if ls $impl_file 1> /dev/null 2>&1; then
                echo -e "✅ $spec_name: План найден"
            else
                echo -e "❌ $spec_name: План имплементации отсутствует"
                ((missing_impl++))
            fi
        fi
    fi
done

if [ $missing_impl -gt 0 ]; then
    echo -e "\n⚠️  Найдено $missing_impl спецификаций без планов имплементации"
else
    echo -e "\n✅ Все спецификации имеют планы имплементации"
fi

echo -e "\n🔄 Рекомендации:"
echo "----------------------------------------"

if [ $need_plan_count -gt 0 ]; then
    echo -e "📝 Создать планы для $need_plan_count спецификаций со статусом 'need_plan'"
fi

if [ $draft_count -gt 0 ]; then
    echo -e "✏️  Завершить $draft_count черновиков спецификаций"
fi

if [ $approved_count -gt 0 ]; then
    echo -e "🚀 Начать реализацию $approved_count одобренных спецификаций"
fi

echo -e "\n🔍 Валидация спецификаций:"
echo "----------------------------------------"

# Run validation using rake task
echo "🔄 Запуск валидации..."
if ./bin/rake specs:validate_all > /dev/null 2>&1; then
    echo -e "✅ Все спецификации прошли валидацию"
else
    echo -e "⚠️  Некоторые спецификации имеют замечания"
    echo -e "💡 Черновики и реализованные спецификации не блокируют коммит"
    echo -e "📝 Детали: ./bin/rake specs:validate_all"
fi

echo -e "\n📚 Используемые ресурсы:"
echo "----------------------------------------"
echo "📖 Что такое спецификация: docs/What_Is_Specification.md"
echo "📖 Регламент работы: docs/Specification_Workflow_Guide.md"
echo "📋 Шаблон спецификации: docs/Specification_Template.md"
echo "📁 Общая документация: docs/README.md"
echo "🔧 Валидация: ./bin/rake specs:validate_all"