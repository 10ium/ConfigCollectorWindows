#![windows_subsystem = "windows"]

pub mod config;
pub mod converter;
pub mod scraper;
pub mod sender;
pub mod storage;
pub mod tester;
pub mod ui;
pub mod updater;

use crate::ui::AppState;
use eframe::egui;

fn build_freedom_bird_icon() -> egui::IconData {
    let width = 64usize;
    let height = 64usize;
    let mut rgba = vec![0u8; width * height * 4];

    let paint = |x: usize, y: usize, r: u8, g: u8, b: u8, a: u8, buf: &mut [u8]| {
        if x >= width || y >= height {
            return;
        }
        let i = (y * width + x) * 4;
        buf[i] = r;
        buf[i + 1] = g;
        buf[i + 2] = b;
        buf[i + 3] = a;
    };

    for y in 0..height {
        for x in 0..width {
            let xf = x as f32 / width as f32;
            let yf = y as f32 / height as f32;

            let bg = (20.0 + 50.0 * (1.0 - yf)) as u8;
            paint(x, y, bg, (bg as f32 * 1.2) as u8, 90, 255, &mut rgba);

            let left_wing = (xf - 0.28).powi(2) / 0.05 + (yf - 0.45).powi(2) / 0.02 < 1.0;
            let right_wing = (xf - 0.72).powi(2) / 0.05 + (yf - 0.45).powi(2) / 0.02 < 1.0;
            let body = (xf - 0.5).powi(2) / 0.01 + (yf - 0.52).powi(2) / 0.02 < 1.0;

            if left_wing || right_wing || body {
                paint(x, y, 245, 245, 250, 255, &mut rgba);
            }
        }
    }

    egui::IconData {
        rgba,
        width: width as u32,
        height: height as u32,
    }
}

fn main() -> eframe::Result<()> {
    // تنظیمات پنجره اصلی نرم‌افزار
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([1100.0, 750.0])
            .with_min_inner_size([900.0, 600.0])
            .with_icon(build_freedom_bird_icon()),
        ..Default::default()
    };

    // راه‌اندازی رابط کاربری گرافیکی و اجرای برنامه
    eframe::run_native(
        "Freedom Config Collector",
        options,
        Box::new(|_cc| Ok(Box::new(AppState::bootstrap()))),
    )
}
