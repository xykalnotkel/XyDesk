//! Probe manual control API — untuk debug dengan curl.
use std::sync::{Arc, Mutex};
use xydesk_host::control::{start, ControlState};

#[tokio::main]
async fn main() {
    let state = Arc::new(Mutex::new(ControlState::new(
        "123456789".into(),
        "RAHASIA-1".into(),
        "ws://localhost:8787/ws".into(),
    )));
    let srv = start(state, 0).await.unwrap();
    println!("addr={} token={}", srv.addr, srv.token);
    loop {
        tokio::time::sleep(std::time::Duration::from_secs(60)).await;
    }
}
