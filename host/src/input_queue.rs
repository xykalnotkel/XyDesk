//! Antrean injeksi bounded. Tunggu ruang tanpa memblokir runtime async;
//! coalesce hanya gerak absolut berurutan, tidak melintasi klik/tombol.
use crate::input::InputEvent;
use tokio::sync::{mpsc, watch};

pub const CAPACITY: usize = 32;

pub fn channel() -> (mpsc::Sender<InputEvent>, mpsc::Receiver<InputEvent>) {
    mpsc::channel(CAPACITY)
}

/// Full bukan disconnect. Backpressure dibatalkan jika sesi ditutup.
pub async fn send(
    tx: &mpsc::Sender<InputEvent>,
    closed: &mut watch::Receiver<bool>,
    event: InputEvent,
) -> bool {
    if *closed.borrow() {
        return false;
    }
    tokio::select! {
        biased;
        _ = closed.changed() => false,
        result = tx.send(event) => result.is_ok(),
    }
}

/// Snapshot terbatas agar producer yang terus mengirim tidak menunda injeksi.
/// Relative motion tidak dijumlahkan: Windows acceleration dapat bergantung
/// pada tiap event, dan menggabungkannya mengubah gerakan pengguna.
pub fn ready_batch(rx: &mut mpsc::Receiver<InputEvent>, first: InputEvent) -> Vec<InputEvent> {
    let mut batch = vec![first];
    for _ in 1..CAPACITY {
        let Ok(event) = rx.try_recv() else {
            break;
        };
        if matches!(event, InputEvent::MouseMoveAbs { .. })
            && matches!(batch.last(), Some(InputEvent::MouseMoveAbs { .. }))
        {
            *batch.last_mut().unwrap() = event;
        } else {
            batch.push(event);
        }
    }
    batch
}

#[cfg(test)]
mod tests {
    use super::*;
    fn abs(x: u16) -> InputEvent {
        InputEvent::MouseMoveAbs { x, y: x }
    }
    fn key(down: bool) -> InputEvent {
        InputEvent::Key { vk: 65, down }
    }

    #[tokio::test]
    async fn queued_absolute_motion_collapses_to_latest_position() {
        let (tx, mut rx) = channel();
        for i in 0..CAPACITY {
            tx.try_send(abs(i as u16)).unwrap();
        }
        let first = rx.recv().await.unwrap();
        assert_eq!(ready_batch(&mut rx, first), vec![abs(31)]);
    }

    #[tokio::test]
    async fn clicks_keys_text_and_relative_motion_are_ordering_barriers() {
        let (tx, mut rx) = channel();
        let button = InputEvent::MouseButton {
            button: 0,
            down: true,
        };
        let release = InputEvent::MouseButton {
            button: 0,
            down: false,
        };
        let relative = InputEvent::MouseMoveRel { dx: 32767, dy: -2 };
        let text = InputEvent::Text("D".into());
        let scroll = InputEvent::Scroll { dx: 0, dy: 120 };
        let events = vec![
            abs(1),
            abs(2),
            button.clone(),
            abs(3),
            key(true),
            abs(4),
            abs(5),
            key(false),
            relative.clone(),
            relative.clone(),
            text.clone(),
            scroll.clone(),
            release.clone(),
        ];
        for event in events {
            tx.try_send(event).unwrap();
        }
        let first = rx.recv().await.unwrap();
        assert_eq!(
            ready_batch(&mut rx, first),
            vec![
                abs(2),
                button,
                abs(3),
                key(true),
                abs(5),
                key(false),
                relative.clone(),
                relative,
                text,
                scroll,
                release
            ]
        );
    }

    #[tokio::test]
    async fn saturation_waits_and_preserves_key_release_instead_of_stopping_input() {
        let (tx, mut rx) = channel();
        let (_close, mut closed) = watch::channel(false);
        for _ in 0..CAPACITY {
            tx.try_send(key(true)).unwrap();
        }
        let worker = tokio::spawn(async move {
            assert!(send(&tx, &mut closed, key(false)).await);
            assert!(send(&tx, &mut closed, abs(999)).await);
        });
        tokio::task::yield_now().await;
        assert!(!worker.is_finished());
        for _ in 0..CAPACITY {
            assert_eq!(rx.recv().await, Some(key(true)));
        }
        assert_eq!(rx.recv().await, Some(key(false)));
        assert_eq!(rx.recv().await, Some(abs(999)));
        worker.await.unwrap();
    }

    #[tokio::test]
    async fn saturated_send_is_cancelled_by_session_close() {
        let (tx, _rx) = channel();
        let (close, mut closed) = watch::channel(false);
        for _ in 0..CAPACITY {
            tx.try_send(abs(1)).unwrap();
        }
        let task = tokio::spawn(async move { send(&tx, &mut closed, key(false)).await });
        close.send(true).unwrap();
        assert!(
            !tokio::time::timeout(std::time::Duration::from_secs(1), task)
                .await
                .unwrap()
                .unwrap()
        );
    }

    #[tokio::test]
    async fn receiver_disconnect_is_reported_without_waiting() {
        let (tx, rx) = channel();
        drop(rx);
        let (_close, mut closed) = watch::channel(false);
        assert!(!send(&tx, &mut closed, key(true)).await);
    }
}
