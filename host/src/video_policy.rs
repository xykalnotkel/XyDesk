//! Negotiated H264 limits and requested spatial quality; never change Windows mode.
use std::sync::{
    atomic::{AtomicU8, Ordering},
    Mutex,
};
static LEVEL: AtomicU8 = AtomicU8::new(31);
static REQUESTED: AtomicU8 = AtomicU8::new(1);
static APPLIED: Mutex<Option<crate::video_layout::VideoLayout>> = Mutex::new(None);
fn effective_mode(locked720: bool, requested: u8) -> u8 {
    if locked720 {
        0
    } else {
        requested
    }
}
pub fn level() -> u8 {
    LEVEL.load(Ordering::Relaxed)
}
pub fn requested() -> u8 {
    effective_mode(
        crate::virtual_target::enabled(),
        REQUESTED.load(Ordering::Relaxed),
    )
}
pub fn configure(level: u8) {
    LEVEL.store(
        if level >= 51 {
            51
        } else if level >= 40 {
            40
        } else {
            31
        },
        Ordering::Relaxed,
    );
    REQUESTED.store(1, Ordering::Relaxed);
    record(None);
}
pub fn request(mode: u8) -> bool {
    if mode > 2 || (crate::virtual_target::enabled() && mode != 0) {
        return false;
    }
    REQUESTED.store(mode, Ordering::Relaxed);
    true
}
pub fn fps() -> u32 {
    if requested() == 2 && level() >= 51 {
        15
    } else {
        30
    }
}
pub fn record(size: Option<(usize, usize)>) {
    record_layout(size.map(|(w, h)| crate::video_layout::VideoLayout {
        canvas: [w, h],
        content: [0, 0, w, h],
    }));
}
pub fn record_layout(layout: Option<crate::video_layout::VideoLayout>) {
    *APPLIED
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner) = layout;
}
pub fn layout() -> Option<crate::video_layout::VideoLayout> {
    *APPLIED
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner)
}
pub fn telemetry() -> serde_json::Value {
    let layout = layout();
    serde_json::json!({"level":level(),"requested":requested(),"applied":layout.map(|r|r.canvas),"contentRect":layout.map(|r|r.content),"fpsLimit":fps()})
}
pub fn output_size(w: usize, h: usize, mode: u8, level: u8) -> Result<(usize, usize), String> {
    if w < 2 || h < 2 {
        return Err("capture lebih kecil dari 2x2".into());
    }
    let (mw, mh) = if mode == 0 || level < 40 {
        (1280, 720)
    } else if mode == 2 && level >= 51 {
        (4096, 2160)
    } else {
        (1920, 1080)
    };
    let scale = (mw as f64 / w as f64).min(mh as f64 / h as f64).min(1.0);
    Ok((
        ((w as f64 * scale).round() as usize & !1).max(2),
        ((h as f64 * scale).round() as usize & !1).max(2),
    ))
}
pub fn offer_level(sdp: &str) -> u8 {
    let mut video = false;
    let mut codecs = std::collections::HashSet::new();
    let mut fmtps = Vec::new();
    for line in sdp.lines() {
        let line = line.trim();
        if line.starts_with("m=") {
            video = line.starts_with("m=video ");
        }
        if !video {
            continue;
        }
        if let Some(rest) = line.strip_prefix("a=rtpmap:") {
            if let Some((pt, codec)) = rest.split_once(' ') {
                if codec.eq_ignore_ascii_case("H264/90000") {
                    codecs.insert(pt);
                }
            }
        }
        if let Some(rest) = line.strip_prefix("a=fmtp:") {
            fmtps.push(rest);
        }
    }
    fmtps
        .into_iter()
        .filter_map(|s| {
            let (pt, params) = s.split_once(' ')?;
            if !codecs.contains(pt) {
                return None;
            }
            let p: std::collections::HashMap<_, _> = params
                .split(';')
                .filter_map(|x| x.trim().split_once('='))
                .collect();
            if p.get("packetization-mode") != Some(&"1") {
                return None;
            }
            let profile = p.get("profile-level-id")?;
            if !profile.is_ascii()
                || profile.len() != 6
                || !profile[..4].eq_ignore_ascii_case("42e0")
            {
                return None;
            }
            u8::from_str_radix(&profile[4..], 16).ok()
        })
        .max()
        .map(|n| {
            if n >= 51 {
                51
            } else if n >= 40 {
                40
            } else {
                31
            }
        })
        .unwrap_or(31)
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn dimensions_no_crop_upscale_or_level_overflow() {
        assert_eq!(output_size(2336, 1080, 1, 40).unwrap(), (1920, 888));
        assert_eq!(output_size(2336, 1080, 2, 51).unwrap(), (2336, 1080));
        assert_eq!(output_size(1920, 1080, 1, 40).unwrap(), (1920, 1080));
        assert_eq!(output_size(640, 360, 1, 51).unwrap(), (640, 360));
        for level in [31, 40, 51] {
            for mode in 0..=2 {
                for (w, h) in [(3840, 2160), (2336, 1080), (2160, 3840), (7680, 4320)] {
                    let (w, h) = output_size(w, h, mode, level).unwrap();
                    assert!(
                        w.div_ceil(16) * h.div_ceil(16)
                            <= if level == 31 {
                                3600
                            } else if level == 40 {
                                8192
                            } else {
                                36864
                            }
                    );
                }
            }
        }
    }
    #[test]
    fn only_video_constrained_baseline_packetization_one() {
        let s="m=video 9 UDP/TLS/RTP/SAVPF 108\r\na=rtpmap:108 H264/90000\r\na=fmtp:108 packetization-mode=1;profile-level-id=42e028\r\n";
        assert_eq!(offer_level(s), 40);
        assert_eq!(offer_level(&s.replace("42e028", "42e033")), 51);
        assert_eq!(offer_level(&s.replace("m=video", "m=audio")), 31);
        assert_eq!(offer_level(&s.replace("H264", "VP8")), 31);
        assert_eq!(offer_level(&s.replace("mode=1", "mode=0")), 31);
    }
}

#[cfg(test)]
mod virtual720_tests {
    #[test]
    fn strict_canvas_cannot_be_changed_by_client_preset() {
        for requested in 0..=2 {
            let mode = super::effective_mode(true, requested);
            assert_eq!(mode, 0);
            let layout = crate::video_layout::VideoLayout::new(1280, 720, mode, 51).unwrap();
            assert_eq!(layout.canvas, [1280, 720]);
            assert_eq!(layout.content, [0, 0, 1280, 720]);
            assert_eq!(super::effective_mode(false, requested), requested);
        }
    }
}
