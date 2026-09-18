//! Real-time regression for the old 30-second expiry; no physical device used.
use std::{sync::Arc, time::Duration};
use xydesk_host::session::Session;

#[tokio::test]
async fn mic_waits_beyond_old_deadline_and_exits_on_session_close() -> anyhow::Result<()> {
    let session = Arc::new(Session::new(vec![], vec![]).await?);
    let (sink, _rx) = std::sync::mpsc::sync_channel(4);
    let worker = session.clone();
    let task = tokio::spawn(async move { worker.receive_mic(sink).await });
    tokio::time::sleep(Duration::from_secs(32)).await;
    assert!(
        !task.is_finished(),
        "mic receiver expired before user enabled mic"
    );
    session.close().await?;
    tokio::time::timeout(Duration::from_secs(2), task).await???;
    Ok(())
}
