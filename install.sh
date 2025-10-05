#!/usr/bin/env bash
Restart=on-failure
RestartSec=10
# systemd user service will run in the user's session environment


[Install]
WantedBy=default.target
EOF
echo "تم إنشاء $SYSTEMD_SERVICE_FILE"


# اعادة تحميل وتفعيل
systemctl --user daemon-reload || true
systemctl --user enable --now "$SYSTEMD_SERVICE_NAME" || echo "تنبيه: فشل تفعيل systemd user (ربما لا تكون الجلسة تدعم systemd)."
}


case "$SELECTED_MODE" in
systemd)
if [ "$has_systemd_user" -eq 1 ]; then
install_systemd
else
echo "systemd user غير متوفر — سيتم إنشاء autostart بدلاً منه."
install_autostart
fi
;;
autostart)
install_autostart
;;
both)
if [ "$has_systemd_user" -eq 1 ]; then
install_systemd
else
echo "systemd user غير متوفر — سيتم الاكتفاء بـ autostart"
fi
install_autostart
;;
none)
echo "لم يتم إعداد تشغيل تلقائي كما طلبت." ;;
*) echo "خيار غير معروف: $SELECTED_MODE" >&2; exit 4;;
esac


# إصلاح محتمل لسطر 1013 إن وُجد
if [ -f "$SCRIPT_PATH" ]; then
if sed -n '1013p' "$SCRIPT_PATH" >/dev/null 2>&1; then
sed -i '1013s/"\$PRAYER_NAME""\$PRAYER_TIME"/"\$PRAYER_NAME" "\$PRAYER_TIME"/' "$SCRIPT_PATH" || true
fi
fi


# فحص صياغي
if ! bash -n "$SCRIPT_PATH"; then
echo "تحذير: فحص الصياغة (bash -n) فشل — راجع $SCRIPT_PATH"
else
echo "فحص الصياغة ناجح."
fi


# تعليمات إلغاء التثبيت
cat <<EOF


تم التثبيت بنجاح.
لتشغيل الآن (واختبار):
$HOME/.GT-salat-dikr/$SCRIPT_NAME --on-terminal-start


لإلغاء التثبيت:
rm -rf "$INSTALL_DIR"
rm -f "$DESKTOP_FILE"
systemctl --user disable --now "$SYSTEMD_SERVICE_NAME" || true
rm -f "$SYSTEMD_SERVICE_FILE" || true
systemctl --user daemon-reload || true


EOF


exit 0
