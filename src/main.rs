#![windows_subsystem = "windows"]

pub mod config;
pub mod scraper;
pub mod storage;
pub mod ui;

use eframe::egui;
use ui::AppState;

fn generate_icon() -> egui::IconData {
    let width = 32;
    let height = 32;
    let mut rgba = Vec::with_capacity((width * height * 4) as usize);
    for _y in 0..height {
        for _x in 0..width {
            rgba.push(30);
            rgba.push(160);
            rgba.push(100);
            rgba.push(255);
        }
    }
    egui::IconData { rgba, width, height }
}

fn main() {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([1100.0, 750.0])
            .with_min_inner_size([900.0, 600.0])
            .with_icon(generate_icon()),
        ..Default::default()
    };
    let _ = eframe::run_native(
        "⚡ Config Collector Pro (Modular Phase 1)",
        options,
        Box::new(|_| Ok(Box::new(AppState::bootstrap()))),
    );
}
