//! ABI compile only, not device installation or an RDP visibility test.
#[path="../../../host/src/desktop_geometry.rs"] pub mod desktop_geometry;
#[path="../../../host/src/desktop_mode.rs"] pub mod desktop_mode;
#[path="../../../host/src/virtual_display.rs"] pub mod virtual_display;
#[path="../../../host/src/virtual_target.rs"] pub mod virtual_target;
pub mod screen {
    #[derive(Clone,Debug,serde::Serialize)]
    pub struct DisplayInfo {pub index:usize,pub name:String,pub width:u32,pub height:u32,pub is_primary:bool,pub refresh_rate:Option<u32>}
    pub fn list_displays()->Vec<DisplayInfo>{vec![]}
    pub fn is_rdp_session()->bool{false}
    pub fn select_display(_:usize)->bool{false}
}
