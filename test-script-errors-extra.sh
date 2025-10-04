#!/bin/bash
#
# سكربت فحص الأخطاء المتقدم في gt-salat-dikr.sh
#

SCRIPT_FILE="${1:-$HOME/.GT-salat-dikr/gt-salat-dikr.sh}"
SCRIPT_DIR="$(dirname "$SCRIPT_FILE")"
TEMP_FILE="/tmp/gt-salat-debug-$$.log"

# الألوان
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# دالة التلوين
color_echo() {
    local color="$1"
    shift
    echo -e "${color}$*${NC}"
}

# دالة التحقق من الملف
check_file_exists() {
    if [ ! -f "$SCRIPT_FILE" ]; then
        color_echo "$RED" "❌ الملف غير موجود: $SCRIPT_FILE"
        color_echo "$YELLOW" "💡 حاول: $0 /مسار/إلى/gt-salat-dikr.sh"
        exit 1
    fi
    color_echo "$GREEN" "✅ الملف موجود: $(basename "$SCRIPT_FILE")"
}

# فحص البناء الأساسي
check_syntax() {
    color_echo "$CYAN" "🔍 فحص صحة بناء السكربت..."
    echo "────────────────────────────────────────"

    if bash -n "$SCRIPT_FILE" 2>"$TEMP_FILE"; then
        color_echo "$GREEN" "✅ لا توجد أخطاء بناء"
        return 0
    else
        color_echo "$RED" "❌ أخطاء في البناء:"
        cat "$TEMP_FILE"
        return 1
    fi
}

# فحص المتغيرات local
check_local_vars() {
    color_echo "$CYAN" "📊 فحص المتغيرات المحلية..."
    echo "────────────────────────────────────────"

    local issues=0
    local in_function=false
    local current_function=""
    local line_num=0

    while IFS= read -r line; do
        ((line_num++))

        # اكتشاف بداية دالة
        if [[ "$line" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*\(\)[[:space:]]*\{?[[:space:]]*$ ]]; then
            in_function=true
            current_function=$(echo "$line" | sed 's/().*//' | tr -d '[:space:]')
            continue
        fi

        # اكتشاف نهاية دالة
        if [[ "$line" =~ ^[[:space:]]*\}[[:space:]]*$ ]] && [ "$in_function" = true ]; then
            in_function=false
            current_function=""
            continue
        fi

        # فحص local خارج الدوال
        if [[ "$line" =~ ^[[:space:]]*local[[:space:]]+ ]] && [ "$in_function" = false ]; then
            color_echo "$YELLOW" "⚠️  سطر $line_num: 'local' خارج دالة: ${line:0:50}"
            ((issues++))
        fi
    done < "$SCRIPT_FILE"

    if [ $issues -eq 0 ]; then
        color_echo "$GREEN" "✅ جميع متغيرات local داخل دوال"
    else
        color_echo "$YELLOW" "📝 وجدت $issues متغير local خارج الدوال"
    fi
}

# فحص التوازن في الهيكل
check_structure_balance() {
    color_echo "$CYAN" "🏗️  فحص توازن الهيكل..."
    echo "────────────────────────────────────────"

    local if_count=$(grep -c "^[[:space:]]*if " "$SCRIPT_FILE")
    local fi_count=$(grep -c "^[[:space:]]*fi" "$SCRIPT_FILE")
    local case_count=$(grep -c "^[[:space:]]*case " "$SCRIPT_FILE")
    local esac_count=$(grep -c "^[[:space:]]*esac" "$SCRIPT_FILE")
    local do_count=$(grep -c "^[[:space:]]*do" "$SCRIPT_FILE")
    local done_count=$(grep -c "^[[:space:]]*done" "$SCRIPT_FILE")

    local balanced=true

    if [ "$if_count" -ne "$fi_count" ]; then
        color_echo "$RED" "❌ عدم توازن if/fi: if=$if_count, fi=$fi_count"
        balanced=false
    else
        color_echo "$GREEN" "✅ if/fi متوازن: $if_count"
    fi

    if [ "$case_count" -ne "$esac_count" ]; then
        color_echo "$RED" "❌ عدم توازن case/esac: case=$case_count, esac=$esac_count"
        balanced=false
    else
        color_echo "$GREEN" "✅ case/esac متوازن: $case_count"
    fi

    if [ "$do_count" -ne "$done_count" ]; then
        color_echo "$RED" "❌ عدم توازن do/done: do=$do_count, done=$done_count"
        balanced=false
    else
        color_echo "$GREEN" "✅ do/done متوازن: $do_count"
    fi

    [ "$balanced" = true ] && return 0 || return 1
}

# فحص الدوال
check_functions() {
    color_echo "$CYAN" "🔧 فحص الدوال..."
    echo "────────────────────────────────────────"

    local functions=($(grep -E "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*\(\)[[:space:]]*\{?" "$SCRIPT_FILE" | \
                      sed 's/().*//' | sed 's/^[[:space:]]*//'))

    color_echo "$GREEN" "✅ عدد الدوال: ${#functions[@]}"

    if [ ${#functions[@]} -gt 0 ]; then
        color_echo "$BLUE" "📋 قائمة الدوال:"
        printf "   %s\n" "${functions[@]}"
    fi
}

# فحص المتغيرات غير المعرفة
check_undefined_vars() {
    color_echo "$CYAN" "🔎 فحص المتغيرات المحتملة..."
    echo "────────────────────────────────────────"

    # استخراج جميع المتغيرات المستخدمة
    local used_vars=$(grep -o '\$[A-Za-z_][A-Za-z0-9_]*' "$SCRIPT_FILE" | sort -u | sed 's/\$//')

    # استخراج المتغيرات المعرفة
    local defined_vars=$(grep -E '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=' "$SCRIPT_FILE" | \
                        sed 's/=[^=]*$//' | sed 's/^[[:space:]]*//' | sort -u)

    local potential_issues=0

    for var in $used_vars; do
        # تخطي المتغيرات الخاصة
        [[ "$var" =~ ^[0-9] ]] && continue
        [[ "$var" == "*" ]] && continue
        [[ "$var" == "?" ]] && continue

        # التحقق إذا تم تعريف المتغير
        if ! echo "$defined_vars" | grep -q "^$var$"; then
            # تخطي المتغيرات المعرفة في السكربت
            if ! grep -q "^[[:space:]]*$var=" "$SCRIPT_FILE" && \
               ! grep -q "for[[:space:]]\+$var" "$SCRIPT_FILE" && \
               ! grep -q "local[[:space:]]\+$var" "$SCRIPT_FILE"; then
                color_echo "$YELLOW" "⚠️  متغير محتمل غير معرف: \$$var"
                ((potential_issues++))
            fi
        fi
    done

    if [ $potential_issues -eq 0 ]; then
        color_echo "$GREEN" "✅ لا توجد متغيرات غير معروفة"
    fi
}

# فحص الأخطاء الشائعة
check_common_issues() {
    color_echo "$CYAN" "🚨 فحص الأخطاء الشائعة..."
    echo "────────────────────────────────────────"

    local issues=0

    # فحص [ ] vs [[ ]]
    if grep -q '^[^#]*\[' "$SCRIPT_FILE" && ! grep -q '^[^#]*\[\[' "$SCRIPT_FILE"; then
        color_echo "$YELLOW" "⚠️  يستخدم [ ] بدلاً من [[ ]] للاختبارات"
        ((issues++))
    fi

    # فحص echo بدون اقتباسات
    if grep -q '^[^#]*echo[[:space:]]\+[^"]' "$SCRIPT_FILE" | head -3; then
        color_echo "$YELLOW" "⚠️  بعض أوامر echo بدون اقتباسات"
        ((issues++))
    fi

    # فحص case بدون ;;
    local case_lines=$(grep -n "case.*in" "$SCRIPT_FILE")
    while IFS= read -r case_line; do
        local line_num=$(echo "$case_line" | cut -d: -f1)
        local in_section=false

        # التحقق من وجود ;; في حالة case
        sed -n "${line_num},\$p" "$SCRIPT_FILE" | while IFS= read -r line; do
            [[ "$line" =~ ^[[:space:]]*esac ]] && break
            [[ "$line" =~ ^[[:space:]]*[a-zA-Z0-9_]*\) ]] && in_section=true
            if [ "$in_section" = true ] && [[ "$line" =~ ^[[:space:]]*;;[[:space:]]*$ ]]; then
                in_section=false
            fi
        done
    done <<< "$case_lines"

    if [ $issues -eq 0 ]; then
        color_echo "$GREEN" "✅ لا توجد أخطاء شائعة"
    fi
}

# فحص الأداء
check_performance() {
    color_echo "$CYAN" "⚡ فحص مؤشرات الأداء..."
    echo "────────────────────────────────────────"

    local total_lines=$(wc -l < "$SCRIPT_FILE")
    local comment_lines=$(grep -c '^[[:space:]]*#' "$SCRIPT_FILE")
    local code_lines=$((total_lines - comment_lines))
    local function_count=$(grep -c "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*()" "$SCRIPT_FILE")

    color_echo "$BLUE" "📊 إحصائيات السكربت:"
    echo "   📄 إجمالي الأسطر: $total_lines"
    echo "   💬 أسطر التعليقات: $comment_lines"
    echo "   🖥️  أسطر الكود: $code_lines"
    echo "   🔧 عدد الدوال: $function_count"

    if [ $function_count -gt 0 ]; then
        local avg_lines_per_func=$((code_lines / function_count))
        echo "   📈 متوسط الأسطر لكل دالة: $avg_lines_per_func"
    fi

    # فحص استخدام subshells مكلفة
    local backtick_count=$(grep -c '`' "$SCRIPT_FILE")
    local dollar_paren_count=$(grep -c '$(' "$SCRIPT_FILE")

    if [ $((backtick_count + dollar_paren_count)) -gt 10 ]; then
        color_echo "$YELLOW" "⚠️  عدد كبير من subshells: $((backtick_count + dollar_paren_count))"
    else
        color_echo "$GREEN" "✅ استخدام معقول للـ subshells"
    fi
}

# التنظيف
cleanup() {
    rm -f "$TEMP_FILE" 2>/dev/null
}

# التنفيذ الرئيسي
main() {
    color_echo "$BLUE" "════════════════════════════════════════"
    color_echo "$BLUE" "🔍 فحص أخطاء البناء في السكربت"
    color_echo "$BLUE" "📁 الملف: $SCRIPT_FILE"
    color_echo "$BLUE" "════════════════════════════════════════"
    echo ""

    # التحقق من الملف
    check_file_exists

    # الفحوصات
    local all_passed=true

    check_syntax || all_passed=false
    echo ""

    check_local_vars
    echo ""

    check_structure_balance || all_passed=false
    echo ""

    check_functions
    echo ""

    check_undefined_vars
    echo ""

    check_common_issues
    echo ""

    check_performance
    echo ""

    # النتيجة النهائية
    color_echo "$BLUE" "════════════════════════════════════════"
    if [ "$all_passed" = true ]; then
        color_echo "$GREEN" "🎉 السكربت جاهز للاستخدام!"
        color_echo "$GREEN" "✅ جميع الفحوصات الأساسية ناجحة"
    else
        color_echo "$YELLOW" "⚠️  السكربت يحتاج بعض التعديلات"
        color_echo "$YELLOW" "💡 راجع التحذيرات أعلاه"
    fi
    color_echo "$BLUE" "════════════════════════════════════════"
}

# معالجة الإشارات
trap cleanup EXIT

# التشغيل
main "$@"
