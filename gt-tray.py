#!/usr/bin/env python3
"""
GT-salat-dikr - System Tray Icon المحسن
إصدار يعمل مع جميع بيئات سطح المكتب
"""

import os
import sys
import subprocess
import threading
import time
import tempfile
from pathlib import Path

# إضافة المسار للوحدات
INSTALL_DIR = os.path.expanduser("~/.GT-salat-dikr")
sys.path.insert(0, INSTALL_DIR)

try:
    from pystray import Icon, Menu, MenuItem
    from PIL import Image, ImageDraw
    import gi
    gi.require_version('Gtk', '3.0')
    from gi.repository import Gtk, GLib
    LIBRARIES_AVAILABLE = True
except ImportError as e:
    print(f"❌ المكتبات المطلوبة غير مثبتة: {e}")
    print("\n💡 قم بتثبيت الحزم المطلوبة:")
    print("   Arch: sudo pacman -S python-pystray python-pillow python-gobject")
    print("   Ubuntu: sudo apt install python3-pystray python3-pil python3-gi")
    print("   أو: pip install --user pystray pillow pygobject")
    LIBRARIES_AVAILABLE = False
    sys.exit(1)

class PrayerTray:
    def __init__(self):
        self.icon = None
        self.install_dir = INSTALL_DIR
        self.main_script = os.path.join(self.install_dir, "gt-salat-dikr.sh")
        self.icon_dir = os.path.join(self.install_dir, "icons")

    def run_in_terminal(self, cmd, title="GT-salat-dikr"):
        """تشغيل أمر في طرفية - محسّن"""
        try:
            # أولاً: محاولة استخدام ديسكوب لإظهار النافذة
            desktop_file = tempfile.NamedTemporaryFile(
                mode='w',
                suffix='.desktop',
                delete=False
            )

            desktop_content = f"""[Desktop Entry]
Type=Application
Name={title}
Exec=sh -c 'cd "{self.install_dir}" && {cmd} && echo "Press Enter to close..." && read'
Terminal=true
Icon={self.icon_dir}/prayer-icon-32.png
Categories=Utility;
"""

            desktop_file.write(desktop_content)
            desktop_file.close()
            os.chmod(desktop_file.name, 0o755)

            # تشغيل باستخدام gtk-launch أو xdg-open
            subprocess.Popen(
                ['gtk-launch', desktop_file.name],
                start_new_session=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )

            # تنظيف الملف المؤقت بعد ثانية
            threading.Timer(2.0, lambda: os.unlink(desktop_file.name)).start()
            return True

        except Exception as e:
            # ثانياً: محاولة استخدام طرفية مباشرة
            terminals = [
                ('gnome-terminal', f'-- bash -c "cd \\"{self.install_dir}\\" && {cmd}; exec bash"'),
                ('konsole', f'-e bash -c "cd \\"{self.install_dir}\\" && {cmd}; exec bash"'),
                ('xfce4-terminal', f'-e "bash -c \\"cd \\\\\\"{self.install_dir}\\\\\\" && {cmd}; exec bash\\""'),
                ('mate-terminal', f'-e "bash -c \\"cd \\\\\\"{self.install_dir}\\\\\\" && {cmd}; exec bash\\""'),
                ('xterm', f'-e "bash -c \\"cd \\\"{self.install_dir}\\\" && {cmd}; exec bash\\""'),
                ('terminator', f'-e "bash -c \\"cd \\\"{self.install_dir}\\\" && {cmd}; exec bash\\""'),
            ]

            for terminal, args in terminals:
                if subprocess.run(['which', terminal], capture_output=True).returncode == 0:
                    try:
                        subprocess.Popen(
                            [terminal] + args.split(),
                            start_new_session=True
                        )
                        return True
                    except:
                        continue

            # ثالثاً: تشغيل مباشر وعرض الإخراج في سطر الأوامر الحالي
            try:
                result = subprocess.run(
                    cmd,
                    shell=True,
                    cwd=self.install_dir,
                    capture_output=True,
                    text=True,
                    timeout=10
                )

                if result.stdout:
                    # إظهار الإخراج في نافذة GTK بسيطة
                    self.show_gtk_dialog(title, result.stdout)
                return True

            except Exception as inner_e:
                print(f"⚠️  خطأ في تشغيل الأمر: {inner_e}")
                return False

    def show_gtk_dialog(self, title, message):
        """إظهار نافذة GTK بسيطة"""
        def show_dialog():
            dialog = Gtk.MessageDialog(
                transient_for=None,
                flags=0,
                message_type=Gtk.MessageType.INFO,
                buttons=Gtk.ButtonsType.OK,
                text=title
            )
            dialog.format_secondary_text(message[:500] + ("..." if len(message) > 500 else ""))
            dialog.run()
            dialog.destroy()

        GLib.idle_add(show_dialog)

    def get_prayer_times(self):
        """الحصول على مواقيت الصلاة"""
        try:
            result = subprocess.run(
                [self.main_script, "--show-timetable"],
                capture_output=True,
                text=True,
                timeout=5,
                cwd=self.install_dir
            )
            if result.returncode == 0:
                return result.stdout.strip()
        except:
            pass
        return "مواقيت الصلاة اليوم:\nالفجر: 06:00\nالظهر: 12:00\nالعصر: 15:00\nالمغرب: 18:00\nالعشاء: 19:00"

    def get_next_prayer(self):
        """الحصول على الصلاة القادمة"""
        try:
            result = subprocess.run(
                [self.main_script],
                capture_output=True,
                text=True,
                timeout=5,
                cwd=self.install_dir
            )
            if result.returncode == 0:
                for line in result.stdout.split('\n'):
                    if 'الصلاة القادمة:' in line:
                        return line.strip()
        except:
            pass
        return "الصلاة القادمة: جاري التحديث..."

    def get_status(self):
        """الحصول على حالة البرنامج"""
        try:
            result = subprocess.run(
                [self.main_script, "--status"],
                capture_output=True,
                text=True,
                timeout=5,
                cwd=self.install_dir
            )
            if result.returncode == 0:
                return result.stdout.strip()
        except:
            pass
        return "حالة البرنامج: جاري التحديث..."

    def load_icon_image(self, size=32):
        """تحميل صورة الأيقونة"""
        # محاولة تحميل الأيقونة المحفوظة
        icon_paths = [
            os.path.join(self.icon_dir, f"prayer-icon-{size}.png"),
            os.path.join(self.icon_dir, "prayer-icon-32.png"),
            os.path.join(self.icon_dir, "icon.png"),
        ]

        for path in icon_paths:
            if os.path.exists(path):
                try:
                    return Image.open(path)
                except:
                    continue

        # إنشاء أيقونة افتراضية
        print(f"ℹ️  إنشاء أيقونة {size}x{size} افتراضية...")
        image = Image.new('RGBA', (size, size), (255, 255, 255, 0))
        draw = ImageDraw.Draw(image)

        # رسم تصميم بسيط
        # قاعدة المسجد
        draw.rectangle([size//4, size*3//5, size*3//4, size*4//5], fill=(46, 125, 50))
        # جدار المسجد
        draw.rectangle([size*5//16, size*7//16, size*11//16, size*3//5], fill=(56, 142, 60))
        # قبة المسجد
        draw.ellipse([size*3//8, size//8, size*5//8, size*3//8], fill=(33, 97, 140))
        # هلال
        draw.arc([size*7//16, size//4, size*9//16, size*3//8], 30, 150, fill=(255, 235, 59), width=2)

        return image

    def create_menu(self):
        """إنشاء قائمة النظام"""
        next_prayer = self.get_next_prayer()

        menu_items = [
            MenuItem("🕌 GT-salat-dikr v3.2", None, enabled=False),
            MenuItem("══════════════════════", None, enabled=False),
            MenuItem(f"⏰ {next_prayer}", None, enabled=False),
            MenuItem("", None, enabled=False),
            MenuItem("📊 مواقيت اليوم",
                lambda: self.run_in_terminal(f"{self.main_script} --show-timetable", "مواقيت الصلاة")),
            MenuItem("🕊️  إظهار ذكر",
                lambda: self.run_in_terminal(f"{self.main_script}", "ذكر اليوم")),
            MenuItem("📈 حالة البرنامج",
                lambda: self.run_in_terminal(f"{self.main_script} --status", "حالة البرنامج")),
            MenuItem("", None, enabled=False),
            MenuItem("══════════════════════", None, enabled=False),
            MenuItem("⚙️  الإعدادات",
                lambda: self.run_in_terminal(f"{self.main_script} --settings", "إعدادات البرنامج")),
            MenuItem("🔄 تحديث المواقيت",
                lambda: self.run_in_terminal(f"{self.main_script} --update-timetables", "تحديث المواقيت")),
            MenuItem("", None, enabled=False),
            MenuItem("🔔 التحكم بالإشعارات:", None, enabled=False),
            MenuItem("  ▶️  تشغيل الإشعارات",
                lambda: self.run_in_terminal(f"{self.main_script} --notify-start", "تشغيل الإشعارات")),
            MenuItem("  ⏸️  إيقاف الإشعارات",
                lambda: self.run_in_terminal(f"{self.main_script} --notify-stop", "إيقاف الإشعارات")),
            MenuItem("", None, enabled=False),
            MenuItem("🖥️  إدارة الأيقونة:", None, enabled=False),
            MenuItem("  🔄 إعادة تشغيل الأيقونة",
                lambda: self.restart_tray()),
            MenuItem("  📝 إظهار سجل التشغيل",
                lambda: self.run_in_terminal("tail -20 notify.log", "سجل البرنامج")),
            MenuItem("  ❌ إغلاق الأيقونة",
                lambda: self.icon.stop()),
            MenuItem("", None, enabled=False),
            MenuItem("══════════════════════", None, enabled=False),
            MenuItem("❓ المساعدة",
                lambda: self.run_in_terminal(f"{self.main_script} --help", "مساعدة البرنامج")),
            MenuItem("🚪 إغلاق كامل",
                lambda: self.full_exit())
        ]

        return Menu(*menu_items)

    def restart_tray(self):
        """إعادة تشغيل الأيقونة"""
        print("🔄 إعادة تشغيل الأيقونة...")
        # إيقاف الأيقونة الحالية
        if self.icon:
            self.icon.stop()

        # تشغيل نسخة جديدة
        time.sleep(1)
        os.execv(sys.executable, [sys.executable] + sys.argv)

    def full_exit(self):
        """إغلاق كامل للبرنامج"""
        print("🚪 إغلاق كامل للبرنامج...")
        try:
            # إيقاف الإشعارات أولاً
            subprocess.run([self.main_script, "--notify-stop"],
                         timeout=3,
                         cwd=self.install_dir)
        except:
            pass

        # إيقاف الأيقونة
        if self.icon:
            self.icon.stop()

    def update_tooltip(self):
        """تحديث التلميح تلقائياً"""
        while True:
            if self.icon and hasattr(self.icon, 'visible') and self.icon.visible:
                try:
                    next_prayer = self.get_next_prayer()
                    self.icon.title = f"GT-salat-dikr\n{next_prayer}"
                except:
                    pass
            time.sleep(60)  # تحديث كل دقيقة

    def run(self):
        """تشغيل الأيقونة"""
        print("🚀 تشغيل أيقونة شريط المهام...")
        print("📌 الأيقونة في منطقة الإشعارات (بجانب الساعة)")
        print("🖱️  انقر بزر الماوس الأيمن للقائمة الكاملة")
        print("💡 إذا لم تظهر الأيقونة، تأكد من دعم System Tray في بيئتك")

        # تحميل الأيقونة
        icon_image = self.load_icon_image(32)

        # إنشاء الأيقونة
        self.icon = Icon(
            "gt_salat_dikr",
            icon_image,
            "GT-salat-dikr - تذكير الصلاة والأذكار",
            self.create_menu()
        )

        # بدء تحديث التلميح
        updater = threading.Thread(target=self.update_tooltip, daemon=True)
        updater.start()

        # تشغيل حلقة GTK في خيط منفصل
        gtk_thread = threading.Thread(target=Gtk.main, daemon=True)
        gtk_thread.start()

        # تشغيل الأيقونة
        try:
            self.icon.run()
        except KeyboardInterrupt:
            print("\n✅ تم الإغلاق بواسطة المستخدم")
        except Exception as e:
            print(f"❌ خطأ في تشغيل الأيقونة: {e}")
        finally:
            Gtk.main_quit()

def main():
    """الدالة الرئيسية"""
    if not LIBRARIES_AVAILABLE:
        print("❌ لا يمكن تشغيل System Tray - المكتبات غير مثبتة")
        return 1

    # التأكد من وجود البرنامج الرئيسي
    if not os.path.exists(os.path.expanduser("~/.GT-salat-dikr/gt-salat-dikr.sh")):
        print("❌ البرنامج الرئيسي غير مثبت")
        print("💡 قم بتشغيل install.sh أولاً")
        return 1

    # تشغيل الأيقونة
    tray = PrayerTray()
    tray.run()

    return 0

if __name__ == "__main__":
    sys.exit(main())
