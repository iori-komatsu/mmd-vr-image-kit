use std::f32::consts::PI;

use anyhow::bail;
use glam::{vec2, vec3, Vec3};
use image::{DynamicImage, GenericImage, ImageBuffer, Pixel, RgbImage};

pub struct Direction {
    pub name: &'static str,
    #[allow(dead_code)]
    pub vector: Vec3,
}

pub const DIRECTIONS: [Direction; 6] = [
    Direction {
        name: "front",
        vector: vec3(0.0, 0.0, 1.0),
    },
    Direction {
        name: "top",
        vector: vec3(0.0, 1.0, 0.0),
    },
    Direction {
        name: "bottom",
        vector: vec3(0.0, -1.0, 0.0),
    },
    Direction {
        name: "right",
        vector: vec3(1.0, 0.0, 0.0),
    },
    Direction {
        name: "left",
        vector: vec3(-1.0, 0.0, 0.0),
    },
    Direction {
        name: "back",
        vector: vec3(0.0, 0.0, -1.0),
    },
];

pub fn make_stereo_vr_image(
    images_l: &[DynamicImage],
    images_r: &[DynamicImage],
) -> anyhow::Result<RgbImage> {
    assert!(images_l.len() == images_r.len());

    if images_l[0].width() != images_r[0].width() {
        bail!("All input images must have the same size.");
    }

    let l = make_monaural_vr_image(images_l)?;
    let r = make_monaural_vr_image(images_r)?;

    let mut combined = ImageBuffer::new(l.width() + r.width(), l.height());
    combined.copy_from(&l, 0, 0)?;
    combined.copy_from(&r, l.width(), 0)?;
    Ok(combined)
}

pub fn make_monaural_vr_image(images: &[DynamicImage]) -> anyhow::Result<RgbImage> {
    assert!(images.len() == 5 || images.len() == 6);

    let is_360 = images.len() == 6;
    let h = images[0].height();

    // サイズチェック
    for img in images {
        if img.height() != h {
            bail!("All input images must have the same size.");
        }
        if img.width() != h {
            bail!("All input images must be square (i.e. width == height).");
        }
    }

    let w = if is_360 { 2 * h } else { h };

    let output = ImageBuffer::from_par_fn(w, h, |x_out, y_out| {
        let x_out = x_out as f32;
        let y_out = y_out as f32;
        let wf = w as f32;
        let hf = h as f32;
        let lonlat = (vec2(x_out, y_out) - vec2(wf / 2.0, hf / 2.0)) * (PI / hf);

        // レイを飛ばす方向ベクトルを求める
        let x_ray = lonlat.x.sin() * lonlat.y.cos();
        let y_ray = lonlat.y.sin();
        let z_ray = lonlat.x.cos() * lonlat.y.cos();

        // 絶対値が最大な要素によってレイがヒットする入力画像が決まる
        #[allow(clippy::collapsible_else_if)]
        let (idx, point) = if x_ray.abs() < y_ray.abs() {
            if y_ray.abs() < z_ray.abs() {
                if z_ray >= 0.0 {
                    (0, vec2(x_ray, y_ray) / z_ray)
                } else {
                    (5, -vec2(-x_ray, y_ray) / z_ray)
                }
            } else {
                if y_ray >= 0.0 {
                    (2, vec2(x_ray, -z_ray) / y_ray)
                } else {
                    (1, -vec2(x_ray, z_ray) / y_ray)
                }
            }
        } else {
            if x_ray.abs() < z_ray.abs() {
                if z_ray >= 0.0 {
                    (0, vec2(x_ray, y_ray) / z_ray)
                } else {
                    (5, -vec2(-x_ray, y_ray) / z_ray)
                }
            } else {
                if x_ray >= 0.0 {
                    (3, vec2(-z_ray, y_ray) / x_ray)
                } else {
                    (4, -vec2(z_ray, y_ray) / x_ray)
                }
            }
        };

        let x_in = ((point.x + 1.0) / 2.0 * hf).clamp(0.0, hf - 1.00001);
        let y_in = ((point.y + 1.0) / 2.0 * hf).clamp(0.0, hf - 1.00001);
        let rgba = image::imageops::interpolate_bilinear(&images[idx], x_in, y_in).unwrap();
        rgba.to_rgb()
    });
    Ok(output)
}
