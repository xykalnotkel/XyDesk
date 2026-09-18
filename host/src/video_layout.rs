//! Encoded canvas and its visible desktop, in the same physical pixel space.
#[derive(Clone, Copy, Debug, PartialEq, Eq, serde::Serialize)]
pub struct VideoLayout {
    pub canvas: [usize; 2],
    pub content: [usize; 4], // left, top, width, height
}
impl VideoLayout {
    pub fn new(width: usize, height: usize, mode: u8, level: u8) -> Result<Self, String> {
        let (w, h) = crate::video_policy::output_size(width, height, mode, level)?;
        let (cw, ch) = if mode == 2 && level >= 51 {
            (w, h)
        } else if mode == 0 || level < 40 {
            (1280, 720)
        } else {
            (1920, 1080)
        };
        // Even origins keep chroma planes aligned. At most two pixels of asymmetry.
        let x = ((cw - w) / 2) & !1;
        let y = ((ch - h) / 2) & !1;
        Ok(Self {
            canvas: [cw, ch],
            content: [x, y, w, h],
        })
    }
    /// Map encoded-frame coordinates to desktop coordinates; bars are not input.
    pub fn desktop_point(self, x: u16, y: u16) -> Option<(u16, u16)> {
        fn axis(n: u16, canvas: usize, start: usize, size: usize) -> Option<u16> {
            let p = n as f64 * (canvas - 1) as f64 / 65535.0;
            if p < start as f64 - 0.51 || p > (start + size - 1) as f64 + 0.51 {
                return None;
            }
            Some(
                (((p - start as f64) / (size - 1).max(1) as f64).clamp(0.0, 1.0) * 65535.0).round()
                    as u16,
            )
        }
        Some((
            axis(x, self.canvas[0], self.content[0], self.content[2])?,
            axis(y, self.canvas[1], self.content[1], self.content[3])?,
        ))
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn exact_letterbox_without_upscale() {
        assert_eq!(
            VideoLayout::new(2336, 1080, 0, 51).unwrap(),
            VideoLayout {
                canvas: [1280, 720],
                content: [0, 64, 1280, 592]
            }
        );
        assert_eq!(
            VideoLayout::new(2336, 1080, 1, 51).unwrap(),
            VideoLayout {
                canvas: [1920, 1080],
                content: [0, 96, 1920, 888]
            }
        );
        assert_eq!(
            VideoLayout::new(640, 360, 1, 51).unwrap().content,
            [640, 360, 640, 360]
        );
        assert_eq!(
            VideoLayout::new(2336, 1080, 2, 51).unwrap().canvas,
            [2336, 1080]
        );
        assert_eq!(
            VideoLayout::new(1920, 1080, 1, 31).unwrap().canvas,
            [1280, 720]
        );
    }
    #[test]
    fn bars_rejected_center_and_edges_round_trip() {
        let r = VideoLayout::new(2336, 1080, 1, 51).unwrap();
        assert_eq!(r.desktop_point(0, 0), None);
        assert_eq!(r.desktop_point(65535, 65535), None);
        let (x, y) = r.desktop_point(32768, 32768).unwrap();
        assert!((x as i32 - 32768).abs() < 2 && (y as i32 - 32768).abs() < 2);
        for &(x, y) in &[(0, 0), (65535, 0), (0, 65535), (65535, 65535)] {
            let fx = ((r.content[0] as f64 + x as f64 / 65535.0 * (r.content[2] - 1) as f64)
                / (r.canvas[0] - 1) as f64
                * 65535.0)
                .round() as u16;
            let fy = ((r.content[1] as f64 + y as f64 / 65535.0 * (r.content[3] - 1) as f64)
                / (r.canvas[1] - 1) as f64
                * 65535.0)
                .round() as u16;
            assert_eq!(r.desktop_point(fx, fy), Some((x, y)));
        }
    }
}
