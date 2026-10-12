use std::process::Command;
use std::env;

fn main() {
    println!("============================================================");
    println!("🚀 Freedom Config Collector v2 - Windows Engine Launcher");
    println!("============================================================");
    
    let mut exe_dir = match env::current_exe() {
        Ok(p) => p,
        Err(_) => std::path::PathBuf::from("."),
    };
    exe_dir.pop();
    
    let mut script_path = exe_dir.join("tools").join("comprehensive_test_runner.py");
    if !script_path.exists() {
        script_path = std::path::PathBuf::from(r"tools\comprehensive_test_runner.py");
    }

    println!("Running engine from: {:?}", script_path);

    let status = Command::new("python")
        .arg(&script_path)
        .status();

    match status {
        Ok(s) => {
            println!("\nEngine execution finished with exit code: {:?}", s.code());
        }
        Err(e) => {
            eprintln!("\nFailed to run python engine: {:?}", e);
        }
    }

    println!("\nPress Enter to exit...");
    let mut input = String::new();
    let _ = std::io::stdin().read_line(&mut input);
}
