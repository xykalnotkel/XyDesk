// Matikan jendela konsol cmd di Windows release
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    xydesk_desktop_lib::run();
}
