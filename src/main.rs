#![windows_subsystem = "windows"]

pub mod config;
pub mod scraper;
pub mod storage;
pub mod tester;
pub mod ui;
pub mod updater;

use eframe::egui;
use crate::ui::AppState;

fn main() -> eframe::Result<()> {
    // تنظیمات پنجره اصلی نرم‌افزار
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([1100.0, 750.0])
            .with_min_inner_size([900.0, 600.0]),
        ..Default::default()
    };

    // راه‌اندازی رابط کاربری گرافیکی و اجرای برنامه
    eframe::run_native(
        "Telegram Config Collector Phase 2",
        options,
        Box::new(|_cc| Ok(Box::new(AppState::bootstrap()))),
    )
}
