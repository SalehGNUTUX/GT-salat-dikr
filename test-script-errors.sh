#!/bin/bash
#
# سكربت فحص الأخطاء في gt-salat-dikr.sh
#

SCRIPT_FILE="$HOME/.GT-salat-dikr/gt-salat-dikr.sh"

echo "🔍 فحص أخطاء البناء في السكربت..."
echo "════════════════════════════════════════"

if [ ! -f "$SCRIPT_FILE" ]; then
    echo "❌ الملف غير موجود: $SCRIPT_FILE"
    exit 1
fi

# فحص صحة البناء
if bash -n "$SCRIPT_FILE" 2>&1; then
    echo "✅ لا توجد أخطاء بناء"
    echo ""
    
    # اختبارات إضافية
    echo "🧪 اختبارات إضافية:"
    echo "────────────────────────────────────────"
    
    # فحص استخدام local خارج الدوال
    if grep -n "^[[:space:]]*local " "$SCRIPT_FILE" | grep -v "^[[:space:]]*#"; then
        echo "⚠️  تحذير: وجدت 'local' خارج دالة (قد تسبب خطأ)"
    else
        echo "✅ لا توجد متغيرات local خارج الدوال"
    fi
    
    # فحص الأقواس المتطابقة
    if_count=$(grep -c "^[[:space:]]*if " "$SCRIPT_FILE")
    fi_count=$(grep -c "^[[:space:]]*fi$" "$SCRIPT_FILE")
    echo "✅ if: $if_count, fi: $fi_count"
    
    # فحص case/esac
    case_count=$(grep -c "^[[:space:]]*case " "$SCRIPT_FILE")
    esac_count=$(grep -c "^[[:space:]]*esac" "$SCRIPT_FILE")
    echo "✅ case: $case_count, esac: $esac_count"
    
    # فحص الدوال
    func_count=$(grep -c "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*() {" "$SCRIPT_FILE")
    echo "✅ عدد الدوال: $func_count"
    
    echo ""
    echo "════════════════════════════════════════"
    echo "✅ السكربت جاهز للاستخدام!"
    
else
    echo ""
    echo "❌ وجدت أخطاء في البناء - راجع الرسائل أعلاه"
    exit 1
fi
