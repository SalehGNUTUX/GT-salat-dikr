#!/usr/bin/env python3
"""
GT-salat-dikr System Tray - الإصدار المحسن
يمنع التكرار ويوفر واجهة أفضل
"""

import os
import sys
import subprocess
import threading
import time
import tempfile
import re
import fcntl
from pathlib import Path

# إضافة المسار للوحدات
INSTALL_DIR = os.path.expanduser("~/.GT-salat-dikr")
sys.path.insert(0, INSTALL_DIR)

try:
    from pystray import Icon, Menu, MenuItem
    from PIL import Image, ImageDraw
    LIBRARIES_AVAILABLE = True
except ImportError as e:
    print(f"❌ المكتبات المطلوبة غير مثبتة: {e}")
    print("\n💡 قم بتثبيت الحزم المطلوبة:")
    print("   pip install --user pystray pillow")
    LIBRARIES_AVAILABLE = False
    sys.exit(1)

# ملف قفل لمنع التكرار
LOCK_FILE = "/tmp/gt-salat-tray.lock"

def acquire_lock():
    """الحصول على قفل لمنع تشغيل نسختين"""
    try:
        lock_fd = os.open(LOCK_FILE, os.O_CREAT | os.O_WRONLY)
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return lock_fd
    except (IOError, BlockingIOError):
        print("✅ System Tray يعمل بالفعل")
        sys.exit(0)

def remove_ansi_codes(text):
    """إزالة أكواد ANSI من النص"""
    if not text:
        return text
    
    ansi_escape = re.compile(r'''
        \x1B  # ESC
        (?:   # 7-bit C1 Fe
        [@-Z\\-_]
        |     # أو تسلسل 8-bit
        \[    # CSI
        [0-?]*  # Parameter bytes
        [ -/]*  # Intermediate bytes
        [@-~]   # Final byte
        )
    ''', re.VERBOSE)
    
    return ansi_escape.sub('', text)

class PrayerTray:
    def __init__(self):
        self.icon = None
        self.install_dir = INSTALL_DIR
        self.main_script = os.path.join(self.install_dir, "gt-salat-dikr.sh")
        self.icon_dir = os.path.join(self.install_dir, "icons")
        self.lock_fd = acquire_lock()
        
    def __del__(self):
        """تنظيف عند الخروج"""
        if hasattr(self, 'lock_fd'):
            try:
                os.close(self.lock_fd)
                os.remove(LOCK_FILE)
            except:
                pass

    def run_cmd_in_terminal(self, cmd, title="GT-salat-dikr"):
        """تشغيل أمر في terminal جديد"""
        try:
            # إنشاء سكربت مؤقت
            script_content = f"""#!/bin/bash
echo "{title}"
echo "══════════════════════════════════════════════════"
cd "{self.install_dir}"
{cmd}
echo ""
echo "══════════════════════════════════════════════════"
read -p "اضغط Enter للإغلاق... "
"""

            script_file = tempfile.NamedTemporaryFile(
                mode='w',
                suffix='.sh',
                delete=False
            )
            script_file.write(script_content)
            script_file.close()
            os.chmod(script_file.name, 0o755)

            # تشغيل في terminal
            terminals = [
                ('gnome-terminal', ['--', 'bash', script_file.name]),
                ('konsole', ['-e', 'bash', script_file.name]),
                ('xfce4-terminal', ['-e', 'bash', script_file.name]),
                ('mate-terminal', ['-e', 'bash', script_file.name]),
                ('xterm', ['-e', 'bash', script_file.name]),
            ]

            for terminal, args in terminals:
                if subprocess.run(['which', terminal], capture_output=True).returncode == 0:
                    subprocess.Popen([terminal] + args, start_new_session=True)
                    return True

            # تشغيل مباشر
            subprocess.Popen(['bash', script_file.name], start_new_session=True)
            return True

        except Exception as e:
            print(f"❌ خطأ في فتح terminal: {e}")
            return False

    def get_prayer_info(self):
        """الحصول على معلومات الصلاة بشكل نظيف"""
        try:
            # جلب معلومات الصلاة القادمة
            result = subprocess.run(
                [self.main_script, '--status'],
                capture_output=True,
                text=True,
                timeout=5,
                cwd=self.install_dir
            )
            
            if result.returncode == 0:
                output = remove_ansi_codes(result.stdout)
                
                # استخراج معلومات الصلاة
                lines = output.split('\n')
                prayer_info = "🕌 الصلاة القادمة: جاري التحديث..."
                
                for line in lines:
                    line = line.strip()
                    if 'الصلاة القادمة:' in line:
                        # تنظيف النص
                        clean_line = line.replace('الصلاة القادمة:', '').strip()
                        prayer_info = f"🕌 {clean_line}"
                        break
                
                return prayer_info
                
        except Exception as e:
            print(f"⚠️  خطأ في الحصول على معلومات الصلاة: {e}")
        
        return "🕌 الصلاة القادمة: جاري التحديث..."

    def load_icon(self):
        """تحميل الأيقونة"""
        icon_paths = [
            os.path.join(self.icon_dir, "prayer-icon-32.png"),
            os.path.join(self.icon_dir, "prayer-icon-64.png"),
            os.path.join(self.icon_dir, "prayer-icon-48.png"),
            os.path.join(self.icon_dir, "prayer-icon-128.png"),
            os.path.join(self.icon_dir, "icon.png"),
        ]

        for path in icon_paths:
            if os.path.exists(path):
                try:
                    return Image.open(path)
                except:
                    continue

        # إنشاء أيقونة افتراضية
        img = Image.new('RGBA', (32, 32), (255, 255, 255, 0))
        draw = ImageDraw.Draw(img)

        # تصميم بسيط
        draw.rectangle([8, 20, 24, 26], fill=(46, 125, 50))
        draw.rectangle([10, 14, 22, 20], fill=(56, 142, 60))
        draw.ellipse([10, 6, 22, 14], fill=(33, 97, 140))
        draw.arc([14, 8, 18, 12], 30, 150, fill=(255, 235, 59), width=2)

        return img

    def create_menu(self):
        """إنشاء قائمة System Tray"""
        prayer_info = self.get_prayer_info()

        menu_items = []

        # العنوان
        menu_items.append(MenuItem("🕌 GT-salat-dikr", None, enabled=False))
        menu_items.append(MenuItem("══════════════════", None, enabled=False))

        # معلومات الصلاة
        menu_items.append(MenuItem(f"{prayer_info}", None, enabled=False))
        menu_items.append(MenuItem("", None, enabled=False))

        # الأوامر الأساسية
        menu_items.append(MenuItem("📊 مواقيت اليوم",
            lambda: self.run_cmd_in_terminal("./gt-salat-dikr.sh --show-timetable", "مواقيت الصلاة")))

        menu_items.append(MenuItem("🕊️  إظهار ذكر",
            lambda: self.run_cmd_in_terminal("./gt-salat-dikr.sh", "ذكر اليوم")))

        menu_items.append(MenuItem("📈 حالة البرنامج",
            lambda: self.run_cmd_in_terminal("./gt-salat-dikr.sh --status", "حالة البرنامج")))

        menu_items.append(MenuItem("", None, enabled=False))
        menu_items.append(MenuItem("══════════════════", None, enabled=False))

        # التحكم
        menu_items.append(MenuItem("⚙️  الإعدادات",
            lambda: self.run_cmd_in_terminal("./gt-salat-dikr.sh --settings", "الإعدادات")))

        menu_items.append(MenuItem("🔄 تحديث المواقيت",
            lambda: self.run_cmd_in_terminal("./gt-salat-dikr.sh --update-timetables", "تحديث المواقيت")))

        menu_items.append(MenuItem("", None, enabled=False))

        # الإشعارات
        menu_items.append(MenuItem("🔔 الإشعارات:", None, enabled=False))
        menu_items.append(MenuItem("  ▶️  تشغيل",
            lambda: subprocess.run([self.main_script, '--notify-start'], cwd=self.install_dir)))
        
        menu_items.append(MenuItem("  ⏸️  إيقاف",
            lambda: subprocess.run([self.main_script, '--notify-stop'], cwd=self.install_dir)))

        menu_items.append(MenuItem("", None, enabled=False))

        # System Tray
        menu_items.append(MenuItem("🖥️  الأيقونة:", None, enabled=False))
        menu_items.append(MenuItem("  🔄 إعادة تشغيل", self.restart_tray))
        menu_items.append(MenuItem("  ❌ إغلاق", self.stop_tray))

        menu_items.append(MenuItem("", None, enabled=False))
        menu_items.append(MenuItem("══════════════════", None, enabled=False))
        menu_items.append(MenuItem("❓ المساعدة",
            lambda: self.run_cmd_in_terminal("./gt-salat-dikr.sh --help", "مساعدة")))

        return Menu(*menu_items)

    def restart_tray(self):
        """إعادة تشغيل System Tray"""
        print("🔄 إعادة تشغيل الأيقونة...")
        if self.icon:
            self.icon.stop()
        time.sleep(1)
        os.execv(sys.executable, [sys.executable] + sys.argv)

    def stop_tray(self):
        """إيقاف System Tray"""
        print("⏹️  إيقاف الأيقونة...")
        if self.icon:
            self.icon.stop()

    def update_tooltip(self):
        """تحديث التلميح تلقائياً"""
        while True:
            if self.icon and hasattr(self.icon, 'visible') and self.icon.visible:
                try:
                    info = self.get_prayer_info()
                    self.icon.title = f"GT-salat-dikr\n{info}"
                except:
                    pass
            time.sleep(60)  # تحديث كل دقيقة

    def run(self):
        """تشغيل System Tray"""
        print("🚀 بدء أيقونة System Tray...")
        print("📌 الأيقونة في شريط المهام")
        print("🖱️  انقر بزر الماوس الأيمن للقائمة")

        icon_image = self.load_icon()
        self.icon = Icon(
            "gt_salat_dikr",
            icon_image,
            "GT-salat-dikr - تذكير الصلاة والأذكار",
            self.create_menu()
        )

        # تحديث التلميح في خيط منفصل
        updater = threading.Thread(target=self.update_tooltip, daemon=True)
        updater.start()

        try:
            self.icon.run()
        except KeyboardInterrupt:
            print("\n✅ تم الإغلاق")
        except Exception as e:
            print(f"❌ خطأ: {e}")
        finally:
            # تنظيف القفل
            if hasattr(self, 'lock_fd'):
                try:
                    os.close(self.lock_fd)
                    os.remove(LOCK_FILE)
                except:
                    pass

def main():
    if not LIBRARIES_AVAILABLE:
        print("❌ لا يمكن تشغيل System Tray - المكتبات غير مثبتة")
        return 1

    if not os.path.exists(os.path.expanduser("~/.GT-salat-dikr/gt-salat-dikr.sh")):
        print("❌ البرنامج الرئيسي غير مثبت")
        print("💡 قم بتشغيل install.sh أولاً")
        return 1

    tray = PrayerTray()
    tray.run()
    return 0

if __name__ == "__main__":
    sys.exit(main())
